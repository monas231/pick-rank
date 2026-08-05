-- =============================================================================
-- pick-rank 0002: 랭킹 계산 함수 · 뷰
-- 근거: DESIGN.md 5장 (랭킹 계산 로직), 6장 (랭커 가중치), 10.4 (핫딜 시간 감쇠)
--
-- 계산을 클라이언트가 아니라 DB 뷰에 두는 이유:
--   - 랭킹은 전체 김치를 가로질러야(카테고리 최저/최고가, 전역 평균 m) 나오는 값이라
--     한 화면 분량만 받는 클라이언트에서는 원리적으로 정확히 계산할 수 없다
--   - 파라미터(C, gravity 등)를 ranking_config 에서 읽으므로 앱 배포 없이 튜닝 가능
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 헬퍼 함수
-- -----------------------------------------------------------------------------

-- 랭커 등급별 리뷰 가중치. DESIGN.md 6.3
create or replace function public.ranker_weight(tier text)
returns numeric language sql immutable parallel safe as $$
  select case tier
           when 'ranker'  then 4.0
           when 'trusted' then 2.0
           else 1.0
         end::numeric;
$$;

-- 시간 가중치. DESIGN.md 5장 Step 2
--   최근 3개월 ×3.0 / 3~6개월 ×2.0 / 6개월~1년 ×1.0
-- [구현 결정] 설계 표는 1년까지만 정의돼 있다. 1년을 넘긴 리뷰를 0으로 떨어뜨리면
-- 초기 기여자의 평가가 통째로 사라지므로, 표의 마지막 값 1.0을 하한으로 이어 쓴다.
create or replace function public.time_weight(created timestamptz)
returns numeric language sql stable parallel safe as $$
  select case
           when created >= now() - interval '3 months' then 3.0
           when created >= now() - interval '6 months' then 2.0
           else 1.0
         end::numeric;
$$;

-- ranking_config 값 읽기 (없으면 fallback)
create or replace function public.cfg(p_key text, p_fallback numeric)
returns numeric language sql stable parallel safe as $$
  select coalesce((select value from public.ranking_config where key = p_key), p_fallback);
$$;

-- 품평회 수상 등급 정렬용. DESIGN.md 5장 (대상 > 금상 > 은상 > 동상)
create or replace function public.award_rank(award text)
returns int language sql immutable parallel safe as $$
  select case award
           when '대상' then 1
           when '금상' then 2
           when '은상' then 3
           when '동상' then 4
           else 99
         end;
$$;


-- -----------------------------------------------------------------------------
-- deals — 유효 상태가 반영된 딜 목록
-- DESIGN.md 10.5: ends_at 이 지나면 자동 ended.
-- 상태 전환 배치(expire_deals)가 아직 안 돌았어도 조회 시점에 만료로 보이게 한다.
-- -----------------------------------------------------------------------------
create or replace view public.deals with (security_invoker = true) as
select
  p.*,
  case
    when p.status = 'active' and p.ends_at is not null and p.ends_at < now() then 'ended'
    else p.status
  end as effective_status
from public.price_posts p;

-- 마감일 지난 딜을 실제로 ended 로 내린다 (pg_cron 등에서 주기 호출)
create or replace function public.expire_deals()
returns int language sql volatile security definer set search_path = public as $$
  with updated as (
    update public.price_posts
       set status = 'ended', updated_at = now()
     where status = 'active' and ends_at is not null and ends_at < now()
    returning 1
  )
  select count(*)::int from updated;
$$;


-- -----------------------------------------------------------------------------
-- hot_deals — 핫딜 인기글 (시간 감쇠 랭킹). DESIGN.md 10.4
--
--   hot_score = (추천수 − 1) / (경과시간_h + 2)^gravity     ← 설계 원문 (Hacker News)
--
-- [구현 결정 2가지]
--  1) 분자의 −1 은 HN 이 "작성자 자동 self-upvote 1표"를 상쇄하려고 두는 항이다.
--     pick-rank 는 self-vote 를 금지(0003 RLS)하므로 새 딜의 추천수가 0이고,
--     −1 을 그대로 쓰면 점수가 음수가 되어 정렬이 뒤집힌다.
--     → (가중 추천 + 1) 로 바꿔 0표 딜도 최신순으로 자연 정렬되게 한다.
--  2) 분자에 raw upvote_count 대신 랭커 가중 합(upvote_weight)을 쓴다.
--     DESIGN.md 10.4 "upvote 에도 랭커/신뢰도 가중치를 재활용(셀러 자작 추천 방어)".
-- -----------------------------------------------------------------------------
-- deal_items — 딜 + 김치 정보 + hot_score (상태 무관, 지난 딜 포함)
-- 김치 이름·브랜드를 함께 실어 보낸다. 딜 목록과 상세의 "이 김치 랭킹 보기"
-- (DESIGN.md 10.2 딜 → 랭킹) 가 매번 추가 조회를 하지 않도록.
create or replace view public.deal_items with (security_invoker = true) as
select
  d.*,
  k.name       as kimchi_name,
  k.brand      as kimchi_brand,
  k.category   as kimchi_category,
  k.image_path as kimchi_image_path,
  (d.upvote_weight + 1)
    / power(extract(epoch from (now() - d.created_at)) / 3600.0 + 2,
            public.cfg('hot_gravity', 1.5))                       as hot_score,
  (d.upvote_count >= public.cfg('hot_promote_upvotes', 10))       as is_promoted
from public.deals d
join public.kimchi k on k.id = d.kimchi_id;

-- 인기글 목록은 진행 중인 딜만. 종료된 딜은 "지난 딜"로 빠진다 (DESIGN.md 10.5)
create or replace view public.hot_deals with (security_invoker = true) as
select * from public.deal_items where effective_status = 'active';


-- -----------------------------------------------------------------------------
-- kimchi_satisfaction — 종합 만족도 (시간·랭커 가중 + 베이지안 보정)
-- DESIGN.md 5장. 랭킹의 기준이 되는 유일한 품질 점수.
-- -----------------------------------------------------------------------------
create or replace view public.kimchi_satisfaction with (security_invoker = true) as
with taste as (
  -- 맛평가가 있는 리뷰만 (별점이 맛평가의 기준값)
  select
    r.kimchi_id,
    r.score_overall,
    r.created_at,
    public.time_weight(r.created_at)
      * public.ranker_weight(coalesce(p.ranker_tier, 'general')) as weight
  from public.reviews r
  left join public.profiles p on p.user_id = r.user_id
  where r.score_overall is not null
),
counts as (
  -- Step 1. 구간 결정에 필요한 리뷰 수
  select
    kimchi_id,
    count(*) filter (where created_at >= now() - interval '3 months') as n3,
    count(*) filter (where created_at >= now() - interval '6 months') as n6,
    count(*)                                                          as n_all
  from taste
  group by kimchi_id
),
picked as (
  select
    c.kimchi_id,
    c.n_all,
    case
      when c.n3 >= public.cfg('time_window_min_reviews', 5) then now() - interval '3 months'
      when c.n6 >= public.cfg('time_window_min_reviews', 5) then now() - interval '6 months'
      else '-infinity'::timestamptz                     -- 전체 기간
    end as cutoff,
    -- 전체 리뷰 수가 임계 미만이면 가중치 없이 단순 평균
    (c.n_all < public.cfg('time_window_min_reviews', 5)) as simple_avg
  from counts c
),
agg as (
  select
    p.kimchi_id,
    p.n_all                                                    as taste_review_count,
    count(*)                                                   as window_review_count,
    -- W = Σ(시간가중치 × 랭커가중치)
    sum(case when p.simple_avg then 1.0 else t.weight end)     as w_sum,
    -- S = Σ(만족도 × 시간가중치 × 랭커가중치)
    sum(t.score_overall
        * case when p.simple_avg then 1.0 else t.weight end)   as s_sum
  from picked p
  join taste t
    on t.kimchi_id = p.kimchi_id
   and t.created_at >= p.cutoff
  group by p.kimchi_id, p.n_all
),
prior as (
  -- m = 전체 김치의 전역 평균 만족도. 리뷰가 하나도 없으면 척도 중앙값 3.0
  select coalesce(avg(score_overall), 3.0) as m
  from public.reviews
  where score_overall is not null
)
select
  a.kimchi_id,
  a.taste_review_count,
  a.window_review_count,
  a.w_sum,
  a.s_sum,
  round(prior.m, 3)                                            as global_mean,
  -- Step 2. 베이지안 보정: (C×m + S) / (C + W)
  round(
    (public.cfg('bayesian_c', 5) * prior.m + a.s_sum)
      / (public.cfg('bayesian_c', 5) + a.w_sum)
  , 3)                                                         as satisfaction_score,
  -- 보정 전 가중 평균 (비교·디버깅용)
  round(a.s_sum / nullif(a.w_sum, 0), 3)                       as raw_weighted_avg
from agg a
cross join prior;


-- -----------------------------------------------------------------------------
-- kimchi_profile — 맛 프로필 3축 가중 평균 (레이더 차트 표시용)
-- DESIGN.md 3.2 / 5장: 랭킹 계산에는 쓰지 않는다. 보정도 하지 않는다.
-- 축마다 입력한 사람 수가 다르므로 축별로 따로 집계한다.
-- -----------------------------------------------------------------------------
create or replace view public.kimchi_profile with (security_invoker = true) as
with w as (
  select
    r.kimchi_id,
    r.score_spicy, r.score_sweet, r.score_fishiness,
    public.time_weight(r.created_at)
      * public.ranker_weight(coalesce(p.ranker_tier, 'general')) as weight
  from public.reviews r
  left join public.profiles p on p.user_id = r.user_id
)
select
  kimchi_id,
  round(sum(score_spicy     * weight) filter (where score_spicy     is not null)
        / nullif(sum(weight) filter (where score_spicy     is not null), 0), 2) as avg_spicy,
  round(sum(score_sweet     * weight) filter (where score_sweet     is not null)
        / nullif(sum(weight) filter (where score_sweet     is not null), 0), 2) as avg_sweet,
  round(sum(score_fishiness * weight) filter (where score_fishiness is not null)
        / nullif(sum(weight) filter (where score_fishiness is not null), 0), 2) as avg_fishiness,
  count(*) filter (where score_spicy     is not null) as spicy_count,
  count(*) filter (where score_sweet     is not null) as sweet_count,
  count(*) filter (where score_fishiness is not null) as fishiness_count
from w
group by kimchi_id;


-- -----------------------------------------------------------------------------
-- kimchi_defect — 하자율 (표시 전용, 어떤 랭킹에도 미반영). DESIGN.md 3.3
--
--   하자율 = 하자 신고된 리뷰 수 / 전체 리뷰 수
--
-- 분모가 "제품평가를 켠 리뷰"가 아니라 "전체 리뷰"인 것이 핵심이다.
-- 문제없이 맛평가만 하고 지나간 사람도 분모에 들어가야 불만 편향이 걷힌다.
-- -----------------------------------------------------------------------------
create or replace view public.kimchi_defect with (security_invoker = true) as
select
  r.kimchi_id,
  count(*)                                                as review_count_total,
  count(*) filter (where r.defect_types is not null)      as defect_report_count,
  round(
    (count(*) filter (where r.defect_types is not null))::numeric
      / nullif(count(*), 0)
  , 4)                                                    as defect_rate,
  -- 유형별 분포: {"delivery_issue": 4, "spoilage": 1}
  coalesce(
    (select jsonb_object_agg(t.code, t.cnt)
       from (select unnest(r2.defect_types) as code, count(*) as cnt
               from public.reviews r2
              where r2.kimchi_id = r.kimchi_id and r2.defect_types is not null
              group by 1) t),
    '{}'::jsonb
  )                                                       as defect_breakdown
from public.reviews r
group by r.kimchi_id;


-- -----------------------------------------------------------------------------
-- kimchi_price — 김치별 최저가 (진행 중 딜 기준). DESIGN.md 10.3
-- -----------------------------------------------------------------------------
create or replace view public.kimchi_price with (security_invoker = true) as
select
  k.id                                       as kimchi_id,
  k.category,
  min(d.price_per_100g)                      as best_price_per_100g,
  count(d.id)                                as active_deal_count
from public.kimchi k
left join public.deals d
       on d.kimchi_id = k.id and d.effective_status = 'active'
group by k.id, k.category;


-- -----------------------------------------------------------------------------
-- kimchi_ranked — 화면이 읽는 최종 랭킹 뷰
-- DESIGN.md 5장 "랭킹별 계산"
-- -----------------------------------------------------------------------------
create or replace view public.kimchi_ranked with (security_invoker = true) as
with price_bounds as (
  -- 가격 정규화는 같은 카테고리 안에서만 (배추김치는 배추김치끼리)
  select category,
         min(best_price_per_100g) as cat_min,
         max(best_price_per_100g) as cat_max
  from public.kimchi_price
  where best_price_per_100g is not null
  group by category
),
scored as (
  select
    k.id, k.name, k.brand, k.category, k.image_path,
    k.competition_year, k.competition_award, k.created_at,

    coalesce(s.taste_review_count, 0)                  as taste_review_count,
    coalesce(dfc.review_count_total, 0)                as review_count_total,
    s.satisfaction_score,
    coalesce(dfc.defect_report_count, 0)               as defect_report_count,
    coalesce(dfc.defect_rate, 0)                       as defect_rate,
    coalesce(dfc.defect_breakdown, '{}'::jsonb)        as defect_breakdown,

    pf.avg_spicy, pf.avg_sweet, pf.avg_fishiness,
    coalesce(pf.spicy_count, 0)                        as profile_sample_count,

    kp.best_price_per_100g,
    coalesce(kp.active_deal_count, 0)                  as active_deal_count,

    -- 만족도 정규화: 별점 1.0 → 0, 5.0 → 1
    case when s.satisfaction_score is not null
         then (s.satisfaction_score - 1) / 4.0 end     as satisfaction_norm,

    -- 가격 정규화 (쌀수록 1). 카테고리에 가격 있는 제품이 하나뿐이면 중립 0.5
    case
      when kp.best_price_per_100g is null then null
      when pb.cat_max = pb.cat_min then 0.5
      else (pb.cat_max - kp.best_price_per_100g) / (pb.cat_max - pb.cat_min)
    end                                                as price_norm,

    -- 가성비 원값 (정규화는 아래 단계에서)
    case when s.satisfaction_score is not null and kp.best_price_per_100g is not null
         then s.satisfaction_score / kp.best_price_per_100g end as value_raw
  from public.kimchi k
  left join public.kimchi_satisfaction s   on s.kimchi_id = k.id
  left join public.kimchi_profile      pf  on pf.kimchi_id = k.id
  left join public.kimchi_defect       dfc on dfc.kimchi_id = k.id
  left join public.kimchi_price        kp  on kp.kimchi_id = k.id
  left join price_bounds               pb  on pb.category  = k.category
),
value_bounds as (
  select min(value_raw) as v_min, max(value_raw) as v_max
  from scored where value_raw is not null
)
select
  sc.*,
  -- 전체 랭킹 = 만족도(정규화)×0.7 + 가격(정규화)×0.3
  -- 가격 정보가 없는 김치는 전체·가격·가성비 랭킹에서 제외 → null
  case when sc.satisfaction_norm is not null and sc.price_norm is not null
       then round(
              sc.satisfaction_norm * public.cfg('satisfaction_weight', 0.7)
            + sc.price_norm        * public.cfg('price_weight',        0.3)
       , 4) end                                        as overall_score,

  -- 가성비 랭킹: 만족도 / 100g당 가격 을 0~1 로 정규화
  case
    when sc.value_raw is null then null
    when vb.v_max = vb.v_min then 0.5
    else round((sc.value_raw - vb.v_min) / (vb.v_max - vb.v_min), 4)
  end                                                  as value_score,

  public.award_rank(sc.competition_award)              as award_rank,

  -- 콜드 스타트: 리뷰가 임계치를 넘긴 제품부터 종합 랭킹에 노출 (DESIGN.md 9.3)
  (sc.taste_review_count >= public.cfg('min_reviews_for_rank', 5)) as is_rankable
from scored sc
cross join value_bounds vb;


-- -----------------------------------------------------------------------------
-- reviews_with_author — 리뷰 목록 (작성자 닉네임·등급 포함)
-- reviews.user_id 는 auth.users 를 가리키므로 PostgREST 가 profiles 를
-- 자동 임베드하지 못한다. 조인을 뷰로 미리 만들어 둔다.
-- -----------------------------------------------------------------------------
create or replace view public.reviews_with_author with (security_invoker = true) as
select
  r.id, r.kimchi_id, r.user_id,
  r.score_overall, r.score_spicy, r.score_sweet, r.score_fishiness, r.comment,
  r.defect_types, r.defect_note, r.is_event,
  r.created_at, r.updated_at,
  coalesce(p.nickname, '알 수 없음')      as author_nickname,
  coalesce(p.ranker_tier, 'general')      as author_tier,
  (select count(*) from public.review_likes l where l.review_id = r.id) as like_count
from public.reviews r
left join public.profiles p on p.user_id = r.user_id;


-- -----------------------------------------------------------------------------
-- 조회 권한 (RLS 는 security_invoker 로 하위 테이블 정책이 그대로 적용된다)
-- -----------------------------------------------------------------------------
grant select on public.deals, public.deal_items, public.hot_deals,
                public.kimchi_satisfaction, public.kimchi_profile,
                public.kimchi_defect, public.kimchi_price,
                public.kimchi_ranked, public.reviews_with_author
  to anon, authenticated;

-- =============================================================================
-- pick-rank 0001: 테이블 · 제약 · 인덱스
-- 근거: DESIGN.md 4장 (DB 스키마)
--
-- Supabase 대시보드 > SQL Editor 에 순서대로 붙여넣어 실행한다.
-- (0001 → 0002 → 0003 → 0004 → seed.sql)
-- =============================================================================

-- gen_random_uuid()
create extension if not exists pgcrypto;


-- -----------------------------------------------------------------------------
-- profiles — 사용자 프로필 (Supabase Auth 확장). DESIGN.md 4장 / 6장
-- -----------------------------------------------------------------------------
create table if not exists public.profiles (
  user_id          uuid primary key references auth.users(id) on delete cascade,
  nickname         text not null,
  reputation_score int  not null default 0,
  -- 6.3 등급: 0~99 general / 100~299 trusted / 300+ ranker
  ranker_tier      text not null default 'general'
                     check (ranker_tier in ('general', 'trusted', 'ranker')),
  -- [설계 추가] 관리자 플래그. DESIGN.md 2장 "관리자 기능"(상품 등록, 품평회 입력,
  -- 딜 큐레이션)을 RLS로 강제하려면 서버가 아는 관리자 표식이 필요하다.
  is_admin         boolean not null default false,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

comment on table public.profiles is '사용자 프로필. auth.users 생성 시 트리거로 자동 생성(0004)';


-- -----------------------------------------------------------------------------
-- kimchi — 김치 상품 (관리자 등록). DESIGN.md 4장
-- -----------------------------------------------------------------------------
create table if not exists public.kimchi (
  id                uuid primary key default gen_random_uuid(),
  name              text not null,
  brand             text not null,
  -- [설계 조정] DESIGN.md 4장은 image_url 이지만 8.1이 "DB에는 전체 URL이 아니라
  -- 경로(path)만 저장"으로 못박았으므로 이름을 image_path 로 맞춘다.
  -- 표시할 때 getPublicUrl(path) 로 URL을 만든다.
  image_path        text,
  category          text not null,
  competition_year  int,
  competition_award text check (competition_award in ('대상', '금상', '은상', '동상')),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),

  -- 수상 정보는 연도와 등급이 함께 있거나 함께 없어야 의미가 있다
  constraint kimchi_award_pair check (
    (competition_year is null) = (competition_award is null)
  )
);

create index if not exists kimchi_category_idx on public.kimchi (category);
create index if not exists kimchi_competition_idx
  on public.kimchi (competition_year desc, competition_award)
  where competition_award is not null;

comment on column public.kimchi.image_path is 'Supabase Storage 내 경로. 전체 URL 저장 금지 (DESIGN.md 8.1)';


-- -----------------------------------------------------------------------------
-- defect_type_meta — 하자 유형 사전. DESIGN.md 3.3
-- 책임 주체를 함께 들고 있어 "배송 탓 / 제조 탓" 필터를 나중에 붙일 수 있다.
-- -----------------------------------------------------------------------------
create table if not exists public.defect_type_meta (
  code           text primary key,
  label          text not null,
  responsibility text not null,   -- 'delivery' | 'manufacturing' | 'distribution' | 'none'
  sort_order     int  not null
);

insert into public.defect_type_meta (code, label, responsibility, sort_order) values
  ('packaging_damage',     '포장 파손 / 국물 누수',            'delivery',       1),
  ('spoilage',             '변질·상함 (곰팡이, 과발효, 이취)', 'distribution',   2),
  ('foreign_object',       '이물질 혼입',                      'manufacturing',  3),
  ('manufacturing_defect', '제조 불량 (양 부족, 상태 불량)',   'manufacturing',  4),
  ('delivery_issue',       '배송 문제 (지연, 미온/해동 등)',   'delivery',       5),
  ('other',                '기타',                             'none',           6)
on conflict (code) do nothing;


-- -----------------------------------------------------------------------------
-- reviews — 사용자 리뷰 (1인 1리뷰, 수정 가능). DESIGN.md 3장 / 4장
--
-- 리뷰 하나가 맛평가·제품평가를 각각 또는 함께 담는다.
--   맛평가 했다     = score_overall IS NOT NULL   (별점이 맛평가의 필수·기준값)
--   맛 프로필 3축   = 선택 입력. 별점만 남기고 비워도 된다
--   제품평가만 했다 = 맛 점수 전부 null + defect_types 존재
-- -----------------------------------------------------------------------------
create table if not exists public.reviews (
  id                uuid primary key default gen_random_uuid(),
  kimchi_id         uuid not null references public.kimchi(id)   on delete cascade,
  user_id           uuid not null references auth.users(id)      on delete cascade,

  -- 맛평가 ------------------------------------------------------------------
  -- 종합 만족도: 1.0~5.0, 0.5 단위. 랭킹에 쓰이는 유일한 품질 지표
  score_overall     numeric(2,1)
                      check (score_overall between 1.0 and 5.0
                             and (score_overall * 2) = trunc(score_overall * 2)),
  -- 맛 프로필 3축: "좋고 나쁨"이 아니라 "어떤 맛인지". 랭킹 계산에 쓰지 않는다
  score_spicy       int check (score_spicy     between 1 and 10),
  score_sweet       int check (score_sweet     between 1 and 10),
  score_fishiness   int check (score_fishiness between 1 and 10),
  comment           text,

  -- 제품평가(하자 신고) ------------------------------------------------------
  defect_types      text[],
  defect_note       text,
  defect_image_path text,          -- 향후. 초기엔 미사용 (DESIGN.md 3.3)

  -- 이벤트 리뷰 태그. 편향 모니터링·필요 시 가중치 조정용 (DESIGN.md 9.5)
  is_event          boolean not null default false,

  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),

  unique (kimchi_id, user_id),

  -- 맛평가·제품평가 중 최소 하나는 있어야 한다
  constraint reviews_has_content check (
    score_overall is not null or defect_types is not null
  ),
  -- 하자 유형을 켰다면 최소 1개는 골라야 한다 (빈 배열 = 신고 없음과 구분 불가)
  constraint reviews_defect_types_nonempty check (
    defect_types is null or array_length(defect_types, 1) >= 1
  ),
  -- 알 수 없는 하자 코드 차단 (defect_type_meta 와 동일 목록)
  constraint reviews_defect_types_known check (
    defect_types is null or defect_types <@ array[
      'packaging_damage', 'spoilage', 'foreign_object',
      'manufacturing_defect', 'delivery_issue', 'other'
    ]::text[]
  ),
  -- 하자 설명·사진은 하자 신고가 있을 때만
  constraint reviews_defect_detail_requires_report check (
    defect_types is not null
    or (defect_note is null and defect_image_path is null)
  )
);

create index if not exists reviews_kimchi_idx  on public.reviews (kimchi_id);
create index if not exists reviews_user_idx    on public.reviews (user_id);
create index if not exists reviews_created_idx on public.reviews (created_at desc);
-- 만족도 집계는 score_overall 있는 행만 훑는다
create index if not exists reviews_taste_idx
  on public.reviews (kimchi_id, created_at)
  where score_overall is not null;

comment on constraint reviews_has_content on public.reviews
  is '맛평가(별점) 또는 제품평가(하자) 중 최소 하나 필수 — DESIGN.md 3장';


-- -----------------------------------------------------------------------------
-- review_likes — 리뷰 공감. DESIGN.md 4장
-- self-like 차단은 RLS(0003) + 신뢰도 집계(0004) 양쪽에서 건다
-- -----------------------------------------------------------------------------
create table if not exists public.review_likes (
  id         uuid primary key default gen_random_uuid(),
  review_id  uuid not null references public.reviews(id) on delete cascade,
  user_id    uuid not null references auth.users(id)     on delete cascade,
  created_at timestamptz not null default now(),
  unique (review_id, user_id)
);

create index if not exists review_likes_review_idx on public.review_likes (review_id);
create index if not exists review_likes_user_idx   on public.review_likes (user_id);


-- -----------------------------------------------------------------------------
-- price_posts — 딜/가격 게시물. DESIGN.md 4장 / 10.3
-- 가격 데이터 + 핫딜 커뮤니티 레이어를 함께 담는다.
-- 최저가·가격 랭킹은 status='active' 인 딜 중 최저 price_per_100g.
-- -----------------------------------------------------------------------------
create table if not exists public.price_posts (
  id              uuid primary key default gen_random_uuid(),
  -- 딜 ↔ 랭킹 양방향 연결의 핵심 키 (DESIGN.md 10.2)
  -- 카탈로그에 없는 김치 딜 허용 여부는 미확정(10.8) → 현재는 NOT NULL
  kimchi_id       uuid not null references public.kimchi(id)  on delete cascade,
  user_id         uuid not null references auth.users(id)     on delete cascade,

  title           text not null,
  body            text,
  discount_info   text,

  price           int not null check (price    > 0),
  volume_g        int not null check (volume_g > 0),
  price_per_100g  numeric generated always as (price::numeric * 100 / volume_g) stored,

  store_name      text not null,
  purchase_url    text,
  purchase_method text check (purchase_method in ('online', 'offline', 'app')),

  ends_at         timestamptz,
  status          text not null default 'active'
                    check (status in ('active', 'ended', 'soldout')),

  upvote_count    int not null default 0,   -- 표시용 원시 추천 수
  -- [설계 추가] 랭커/신뢰도 가중 추천 합. DESIGN.md 10.4가 "upvote에도 랭커
  -- 가중치를 재활용(셀러 자작 추천 방어)"을 요구하므로 원시 카운트와 분리해 둔다.
  -- hot_score 계산은 이 값을 쓴다.
  upvote_weight   numeric not null default 0,
  comment_count   int not null default 0,
  view_count      int not null default 0,
  is_official     boolean not null default false,   -- 운영자 큐레이션 (10.6)

  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index if not exists price_posts_kimchi_idx on public.price_posts (kimchi_id);
create index if not exists price_posts_user_idx   on public.price_posts (user_id);
-- 최저가 조회: 진행 중 딜을 100g당 가격 오름차순으로
create index if not exists price_posts_active_price_idx
  on public.price_posts (kimchi_id, price_per_100g)
  where status = 'active';
-- 핫딜 목록: 진행 중 딜을 최신순으로 (hot_score는 조회 시점 계산 — 0002)
create index if not exists price_posts_active_recent_idx
  on public.price_posts (created_at desc)
  where status = 'active';

-- [설계 조정] DESIGN.md 4장의 hot_score 캐시 컬럼은 두지 않았다.
-- hot_score 는 now() 에 의존해 매 순간 변하므로 컬럼에 캐시하면 갱신 배치가
-- 없을 때 곧바로 낡은 값이 된다. 0002 의 hot_deals 뷰에서 조회 시점에 계산한다.
-- 트래픽이 커져 정렬 비용이 문제가 되면 그때 캐시 컬럼 + cron 갱신으로 전환.


-- -----------------------------------------------------------------------------
-- deal_votes — 딜 추천(upvote). DESIGN.md 4장
-- UNIQUE(price_post_id, user_id) · self-vote 금지는 RLS(0003)에서
-- -----------------------------------------------------------------------------
create table if not exists public.deal_votes (
  id            uuid primary key default gen_random_uuid(),
  price_post_id uuid not null references public.price_posts(id) on delete cascade,
  user_id       uuid not null references auth.users(id)         on delete cascade,
  created_at    timestamptz not null default now(),
  unique (price_post_id, user_id)
);

create index if not exists deal_votes_post_idx on public.deal_votes (price_post_id);
create index if not exists deal_votes_user_idx on public.deal_votes (user_id);


-- -----------------------------------------------------------------------------
-- deal_comments — 딜 댓글. DESIGN.md 4장 (상세 설계는 10.8에서 미확정)
-- price_posts.comment_count 가 가리킬 대상이 필요해 최소 형태로 먼저 둔다.
-- -----------------------------------------------------------------------------
create table if not exists public.deal_comments (
  id            uuid primary key default gen_random_uuid(),
  price_post_id uuid not null references public.price_posts(id) on delete cascade,
  user_id       uuid not null references auth.users(id)         on delete cascade,
  body          text not null check (length(btrim(body)) > 0),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists deal_comments_post_idx on public.deal_comments (price_post_id, created_at);


-- -----------------------------------------------------------------------------
-- ranking_config — 랭킹 파라미터
-- DESIGN.md 곳곳의 "실데이터 확인 후 조정" 값들을 코드가 아닌 DB에 둬서
-- 배포 없이 튜닝할 수 있게 한다.
-- -----------------------------------------------------------------------------
create table if not exists public.ranking_config (
  key         text primary key,
  value       numeric not null,
  description text not null
);

insert into public.ranking_config (key, value, description) values
  ('bayesian_c',              5,   '베이지안 prior 강도 C — 가상 리뷰 가중치 (5장, 미확정)'),
  ('time_window_min_reviews', 5,   '시간 구간 선택 임계 리뷰 수 (5장)'),
  ('satisfaction_weight',     0.7, '전체 랭킹 내 만족도 비중 (5장)'),
  ('price_weight',            0.3, '전체 랭킹 내 가격 비중 (5장)'),
  ('hot_gravity',             1.5, '핫딜 시간 감쇠 지수 gravity (10.4, 미확정)'),
  ('hot_promote_upvotes',     10,  '🔥핫딜 승격 추천 임계 (10.4, 미확정)'),
  ('min_reviews_for_rank',    5,   '종합 랭킹 노출 최소 리뷰 수 (9.3, 미확정)')
on conflict (key) do nothing;

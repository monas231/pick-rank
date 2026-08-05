-- =============================================================================
-- pick-rank 0004: 트리거 · RPC
-- 근거: DESIGN.md 6장 (신뢰도 점수·등급), 10.4 (가중 추천), 10.5 (딜 만료)
--
-- 집계값은 전부 "처음부터 다시 센다"(recompute). +1/-1 증분 방식보다 느리지만
-- 어긋날 여지가 없고, 현재 데이터 규모에서는 비용 차이가 무의미하다.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- updated_at 자동 갱신
-- -----------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

drop trigger if exists kimchi_set_updated_at on public.kimchi;
create trigger kimchi_set_updated_at before update on public.kimchi
  for each row execute function public.set_updated_at();

drop trigger if exists reviews_set_updated_at on public.reviews;
create trigger reviews_set_updated_at before update on public.reviews
  for each row execute function public.set_updated_at();

drop trigger if exists price_posts_set_updated_at on public.price_posts;
create trigger price_posts_set_updated_at before update on public.price_posts
  for each row execute function public.set_updated_at();

drop trigger if exists deal_comments_set_updated_at on public.deal_comments;
create trigger deal_comments_set_updated_at before update on public.deal_comments
  for each row execute function public.set_updated_at();


-- -----------------------------------------------------------------------------
-- 가입 시 프로필 자동 생성
-- 소셜 로그인(카카오/네이버)의 메타데이터에서 닉네임을 뽑고, 없으면 이메일 앞부분
-- -----------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (user_id, nickname)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data ->> 'nickname',  ''),
      nullif(new.raw_user_meta_data ->> 'name',      ''),
      nullif(new.raw_user_meta_data ->> 'full_name', ''),
      nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
      '사용자'
    )
  )
  on conflict (user_id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- -----------------------------------------------------------------------------
-- 신뢰도 점수 · 등급. DESIGN.md 6.2 / 6.3
--   리뷰 작성 +2 / 가격 게시물 등록 +1
--   내 리뷰가 받은 공감 +1 / 내 가격 게시물이 받은 공감(추천) +1
--
-- self-like·self-vote 는 RLS 에서 이미 막지만, 점수 계산에서도 한 번 더 걸러
-- 과거 데이터나 service_role 경로로 들어온 것까지 안전하게 처리한다 (6.4)
-- -----------------------------------------------------------------------------
create or replace function public.recalc_reputation(p_user uuid)
returns void language sql volatile security definer set search_path = public as $$
  update public.profiles pf
     set reputation_score = sc.score,
         ranker_tier = case
                         when sc.score >= 300 then 'ranker'
                         when sc.score >= 100 then 'trusted'
                         else 'general'
                       end
    from (
      select
          2 * (select count(*) from public.reviews r      where r.user_id  = p_user)
        + 1 * (select count(*) from public.price_posts pp where pp.user_id = p_user)
        + (select count(*)
             from public.review_likes l
             join public.reviews r on r.id = l.review_id
            where r.user_id = p_user and l.user_id <> p_user)
        + (select count(*)
             from public.deal_votes v
             join public.price_posts pp on pp.id = v.price_post_id
            where pp.user_id = p_user and v.user_id <> p_user)
        as score
    ) sc
   where pf.user_id = p_user;
$$;

-- 리뷰/딜 작성자 본인의 점수 갱신
create or replace function public.trg_reputation_owner()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.recalc_reputation(coalesce(new.user_id, old.user_id));
  return coalesce(new, old);
end $$;

drop trigger if exists reviews_reputation on public.reviews;
create trigger reviews_reputation after insert or delete on public.reviews
  for each row execute function public.trg_reputation_owner();

drop trigger if exists price_posts_reputation on public.price_posts;
create trigger price_posts_reputation after insert or delete on public.price_posts
  for each row execute function public.trg_reputation_owner();

-- 공감받은 리뷰의 작성자 점수 갱신
create or replace function public.trg_reputation_review_author()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_author uuid;
begin
  -- 리뷰가 함께 삭제되는 cascade 상황에서는 작성자를 못 찾을 수 있는데,
  -- 그때는 reviews 쪽 트리거가 어차피 같은 사용자를 다시 계산한다
  select r.user_id into v_author
    from public.reviews r
   where r.id = coalesce(new.review_id, old.review_id);
  if v_author is not null then
    perform public.recalc_reputation(v_author);
  end if;
  return coalesce(new, old);
end $$;

drop trigger if exists review_likes_reputation on public.review_likes;
create trigger review_likes_reputation after insert or delete on public.review_likes
  for each row execute function public.trg_reputation_review_author();


-- -----------------------------------------------------------------------------
-- 딜 카운트 (추천 수 · 가중 추천 · 댓글 수)
--
-- upvote_weight = Σ 추천자의 랭커 가중치. hot_score 는 이 값을 쓴다 (DESIGN.md 10.4)
-- ⚠️ 추천한 사람의 등급이 나중에 오르내려도 과거 딜의 upvote_weight 는 따라가지
--    않는다. 딜은 시효가 짧아 소급이 무의미하고, 전체 재계산 비용만 커진다.
-- -----------------------------------------------------------------------------
create or replace function public.refresh_deal_counts(p_post_id uuid)
returns void language sql volatile security definer set search_path = public as $$
  update public.price_posts p
     set upvote_count = (
           select count(*) from public.deal_votes v where v.price_post_id = p.id
         ),
         upvote_weight = coalesce((
           select sum(public.ranker_weight(coalesce(pr.ranker_tier, 'general')))
             from public.deal_votes v
             left join public.profiles pr on pr.user_id = v.user_id
            where v.price_post_id = p.id
         ), 0),
         comment_count = (
           select count(*) from public.deal_comments c where c.price_post_id = p.id
         )
   where p.id = p_post_id;
$$;

create or replace function public.trg_deal_counts()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_post uuid;
begin
  v_post := coalesce(new.price_post_id, old.price_post_id);
  perform public.refresh_deal_counts(v_post);

  -- 추천은 딜 작성자의 신뢰도에도 반영된다
  perform public.recalc_reputation(pp.user_id)
     from public.price_posts pp where pp.id = v_post;

  return coalesce(new, old);
end $$;

drop trigger if exists deal_votes_counts on public.deal_votes;
create trigger deal_votes_counts after insert or delete on public.deal_votes
  for each row execute function public.trg_deal_counts();

drop trigger if exists deal_comments_counts on public.deal_comments;
create trigger deal_comments_counts after insert or delete on public.deal_comments
  for each row execute function public.trg_deal_counts();


-- -----------------------------------------------------------------------------
-- RPC
-- -----------------------------------------------------------------------------

-- 조회수 증가. price_posts.view_count 는 사용자 UPDATE 권한에서 빠져 있으므로
-- 이 함수만이 유일한 증가 경로다.
create or replace function public.increment_deal_view(p_post_id uuid)
returns void language sql volatile security definer set search_path = public as $$
  update public.price_posts set view_count = view_count + 1 where id = p_post_id;
$$;

-- 내부용 함수는 클라이언트에서 못 부르게 막는다
revoke all on function public.recalc_reputation(uuid)   from public, anon, authenticated;
revoke all on function public.refresh_deal_counts(uuid) from public, anon, authenticated;
revoke all on function public.expire_deals()            from public, anon, authenticated;

grant execute on function public.increment_deal_view(uuid) to anon, authenticated;
grant execute on function public.is_admin()                to anon, authenticated;
grant execute on function public.cfg(text, numeric)        to anon, authenticated;
grant execute on function public.ranker_weight(text)       to anon, authenticated;
grant execute on function public.time_weight(timestamptz)  to anon, authenticated;
grant execute on function public.award_rank(text)          to anon, authenticated;

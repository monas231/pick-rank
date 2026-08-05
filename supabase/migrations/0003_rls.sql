-- =============================================================================
-- pick-rank 0003: RLS 정책 · 권한
--
-- 원칙
--   조회 : 랭킹 서비스이므로 대부분 공개 (비로그인도 랭킹·리뷰를 볼 수 있어야 함)
--   쓰기 : 본인 것만. 카탈로그·설정은 관리자만
--   집계값(추천 수, 신뢰도 점수 등)은 트리거만 건드린다 → 컬럼 권한으로 차단
--
-- ⚠️ RLS 는 "어느 행"만 가리고 "어느 컬럼"은 못 가린다.
--    그래서 신뢰도·카운트처럼 사용자가 조작하면 안 되는 컬럼은
--    RLS 가 아니라 컬럼 단위 GRANT 로 막는다.
-- =============================================================================

-- 현재 로그인 사용자가 관리자인가
-- profiles 를 읽어야 하는데 자기 자신에 RLS 가 걸리므로 security definer 로 우회
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select p.is_admin from public.profiles p where p.user_id = auth.uid()), false);
$$;

alter table public.profiles         enable row level security;
alter table public.kimchi           enable row level security;
alter table public.defect_type_meta enable row level security;
alter table public.reviews          enable row level security;
alter table public.review_likes     enable row level security;
alter table public.price_posts      enable row level security;
alter table public.deal_votes       enable row level security;
alter table public.deal_comments    enable row level security;
alter table public.ranking_config   enable row level security;


-- -----------------------------------------------------------------------------
-- profiles
-- -----------------------------------------------------------------------------
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select using (true);

drop policy if exists profiles_insert_self on public.profiles;
create policy profiles_insert_self on public.profiles
  for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- 닉네임만 사용자가 고칠 수 있다.
-- reputation_score / ranker_tier 는 트리거가, is_admin 은 운영자가 직접 관리한다.
revoke all on public.profiles from anon, authenticated;
grant select on public.profiles to anon, authenticated;
grant insert (user_id, nickname) on public.profiles to authenticated;
grant update (nickname)          on public.profiles to authenticated;


-- -----------------------------------------------------------------------------
-- kimchi — 카탈로그는 관리자만 쓴다 (DESIGN.md 2장 관리자 기능)
-- -----------------------------------------------------------------------------
drop policy if exists kimchi_select on public.kimchi;
create policy kimchi_select on public.kimchi
  for select using (true);

drop policy if exists kimchi_admin_write on public.kimchi;
create policy kimchi_admin_write on public.kimchi
  for all to authenticated using (public.is_admin()) with check (public.is_admin());


-- -----------------------------------------------------------------------------
-- defect_type_meta / ranking_config — 읽기 공개, 쓰기 관리자
-- -----------------------------------------------------------------------------
drop policy if exists defect_meta_select on public.defect_type_meta;
create policy defect_meta_select on public.defect_type_meta for select using (true);

drop policy if exists defect_meta_admin_write on public.defect_type_meta;
create policy defect_meta_admin_write on public.defect_type_meta
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists ranking_config_select on public.ranking_config;
create policy ranking_config_select on public.ranking_config for select using (true);

drop policy if exists ranking_config_admin_write on public.ranking_config;
create policy ranking_config_admin_write on public.ranking_config
  for all to authenticated using (public.is_admin()) with check (public.is_admin());


-- -----------------------------------------------------------------------------
-- reviews — 1인 1리뷰(UNIQUE 제약), 본인만 수정·삭제
-- -----------------------------------------------------------------------------
drop policy if exists reviews_select on public.reviews;
create policy reviews_select on public.reviews
  for select using (true);

-- is_event 는 이벤트 리뷰 편향 모니터링용 태그(DESIGN.md 9.5)라
-- 사용자가 스스로 붙이면 의미가 없다 → 관리자만 true 로 넣을 수 있다
drop policy if exists reviews_insert_self on public.reviews;
create policy reviews_insert_self on public.reviews
  for insert to authenticated
  with check (auth.uid() = user_id and (is_event = false or public.is_admin()));

drop policy if exists reviews_update_self on public.reviews;
create policy reviews_update_self on public.reviews
  for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id and (is_event = false or public.is_admin()));

drop policy if exists reviews_delete_self on public.reviews;
create policy reviews_delete_self on public.reviews
  for delete to authenticated
  using (auth.uid() = user_id or public.is_admin());


-- -----------------------------------------------------------------------------
-- review_likes — 자기 리뷰에 자기가 공감 금지 (DESIGN.md 6.4 self-like 방지)
-- -----------------------------------------------------------------------------
drop policy if exists review_likes_select on public.review_likes;
create policy review_likes_select on public.review_likes for select using (true);

drop policy if exists review_likes_insert on public.review_likes;
create policy review_likes_insert on public.review_likes
  for insert to authenticated
  with check (
    auth.uid() = user_id
    and not exists (
      select 1 from public.reviews r
       where r.id = review_id and r.user_id = auth.uid()
    )
  );

drop policy if exists review_likes_delete on public.review_likes;
create policy review_likes_delete on public.review_likes
  for delete to authenticated using (auth.uid() = user_id);


-- -----------------------------------------------------------------------------
-- price_posts — 딜 게시물
-- is_official(운영자 큐레이션, DESIGN.md 10.6)은 관리자만 세울 수 있다
-- -----------------------------------------------------------------------------
drop policy if exists price_posts_select on public.price_posts;
create policy price_posts_select on public.price_posts for select using (true);

drop policy if exists price_posts_insert_self on public.price_posts;
create policy price_posts_insert_self on public.price_posts
  for insert to authenticated
  with check (auth.uid() = user_id and (is_official = false or public.is_admin()));

drop policy if exists price_posts_update_own on public.price_posts;
create policy price_posts_update_own on public.price_posts
  for update to authenticated
  using (auth.uid() = user_id or public.is_admin())
  with check (
    (auth.uid() = user_id or public.is_admin())
    and (is_official = false or public.is_admin())
  );

drop policy if exists price_posts_delete_own on public.price_posts;
create policy price_posts_delete_own on public.price_posts
  for delete to authenticated
  using (auth.uid() = user_id or public.is_admin());

-- 카운트 계열은 트리거 전용. view_count 는 increment_deal_view() RPC 로만 오른다.
revoke all on public.price_posts from anon, authenticated;
grant select on public.price_posts to anon, authenticated;
grant insert (kimchi_id, user_id, title, body, discount_info, price, volume_g,
              store_name, purchase_url, purchase_method, ends_at, status, is_official)
  on public.price_posts to authenticated;
grant update (title, body, discount_info, price, volume_g,
              store_name, purchase_url, purchase_method, ends_at, status, is_official)
  on public.price_posts to authenticated;
grant delete on public.price_posts to authenticated;


-- -----------------------------------------------------------------------------
-- deal_votes — 자기 딜에 자기가 추천 금지 (DESIGN.md 10.4 self-vote 금지)
-- -----------------------------------------------------------------------------
drop policy if exists deal_votes_select on public.deal_votes;
create policy deal_votes_select on public.deal_votes for select using (true);

drop policy if exists deal_votes_insert on public.deal_votes;
create policy deal_votes_insert on public.deal_votes
  for insert to authenticated
  with check (
    auth.uid() = user_id
    and not exists (
      select 1 from public.price_posts p
       where p.id = price_post_id and p.user_id = auth.uid()
    )
  );

drop policy if exists deal_votes_delete on public.deal_votes;
create policy deal_votes_delete on public.deal_votes
  for delete to authenticated using (auth.uid() = user_id);


-- -----------------------------------------------------------------------------
-- deal_comments
-- -----------------------------------------------------------------------------
drop policy if exists deal_comments_select on public.deal_comments;
create policy deal_comments_select on public.deal_comments for select using (true);

drop policy if exists deal_comments_insert_self on public.deal_comments;
create policy deal_comments_insert_self on public.deal_comments
  for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists deal_comments_update_self on public.deal_comments;
create policy deal_comments_update_self on public.deal_comments
  for update to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists deal_comments_delete_self on public.deal_comments;
create policy deal_comments_delete_self on public.deal_comments
  for delete to authenticated using (auth.uid() = user_id or public.is_admin());


-- -----------------------------------------------------------------------------
-- 나머지 테이블 기본 권한 (RLS 가 행 단위로 다시 거른다)
-- -----------------------------------------------------------------------------
revoke all on public.reviews from anon, authenticated;
grant select on public.reviews to anon, authenticated;
grant insert (kimchi_id, user_id, score_overall, score_spicy, score_sweet,
              score_fishiness, comment, defect_types, defect_note, defect_image_path, is_event)
  on public.reviews to authenticated;
-- kimchi_id / user_id 가 update 목록에도 있는 이유: 리뷰 수정은 upsert
-- (INSERT ... ON CONFLICT DO UPDATE) 로 처리하는데, 그러려면 payload 에 실린
-- 모든 컬럼에 update 권한이 있어야 한다. 남의 리뷰로 바꿔치기하는 것은
-- RLS 의 with check (auth.uid() = user_id) 가 막는다.
grant update (kimchi_id, user_id, score_overall, score_spicy, score_sweet,
              score_fishiness, comment, defect_types, defect_note,
              defect_image_path, is_event)
  on public.reviews to authenticated;
grant delete on public.reviews to authenticated;

grant select on public.kimchi, public.defect_type_meta, public.ranking_config
  to anon, authenticated;
grant insert, update, delete on public.kimchi, public.defect_type_meta, public.ranking_config
  to authenticated;   -- 실제 허용 여부는 위 RLS(is_admin)가 판단

grant select on public.review_likes, public.deal_votes, public.deal_comments
  to anon, authenticated;
grant insert, delete on public.review_likes, public.deal_votes to authenticated;
grant insert, update, delete on public.deal_comments to authenticated;

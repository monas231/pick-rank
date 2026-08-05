-- =============================================================================
-- pick-rank 0005: Storage 버킷 · 정책
-- 근거: DESIGN.md 8.1 (이미지 처리 방침)
--
-- 별도 이미지 서버를 두지 않는다. Supabase Storage 가 저장소 + CDN 을 겸한다.
-- DB(kimchi.image_path 등)에는 전체 URL 이 아니라 버킷 내 경로만 저장하고,
-- 표시할 때 getPublicUrl(path) 로 URL 을 만든다.
-- =============================================================================

-- 김치 상품 이미지: 누구나 조회, 업로드는 관리자만
insert into storage.buckets (id, name, public)
values ('kimchi-images', 'kimchi-images', true)
on conflict (id) do nothing;

-- 하자 사진: 신고성 자료라 비공개. 초기엔 미사용 (DESIGN.md 3.3 "향후")
insert into storage.buckets (id, name, public)
values ('defect-photos', 'defect-photos', false)
on conflict (id) do nothing;


-- -----------------------------------------------------------------------------
-- kimchi-images
-- -----------------------------------------------------------------------------
drop policy if exists "kimchi images are publicly readable" on storage.objects;
create policy "kimchi images are publicly readable" on storage.objects
  for select using (bucket_id = 'kimchi-images');

drop policy if exists "only admins upload kimchi images" on storage.objects;
create policy "only admins upload kimchi images" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'kimchi-images' and public.is_admin());

drop policy if exists "only admins modify kimchi images" on storage.objects;
create policy "only admins modify kimchi images" on storage.objects
  for update to authenticated
  using (bucket_id = 'kimchi-images' and public.is_admin())
  with check (bucket_id = 'kimchi-images' and public.is_admin());

drop policy if exists "only admins delete kimchi images" on storage.objects;
create policy "only admins delete kimchi images" on storage.objects
  for delete to authenticated
  using (bucket_id = 'kimchi-images' and public.is_admin());


-- -----------------------------------------------------------------------------
-- defect-photos — 업로드는 로그인 사용자, 조회는 본인 또는 관리자
-- 경로 규칙: {user_id}/{review_id}.jpg  → 첫 폴더명으로 소유자를 판별한다
-- -----------------------------------------------------------------------------
drop policy if exists "users upload own defect photos" on storage.objects;
create policy "users upload own defect photos" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'defect-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "users read own defect photos" on storage.objects;
create policy "users read own defect photos" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'defect-photos'
    and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin())
  );

drop policy if exists "users delete own defect photos" on storage.objects;
create policy "users delete own defect photos" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'defect-photos'
    and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin())
  );

-- ⚠️ 썸네일 자동 변환(transform)은 Supabase 유료(Pro) 플랜 기능이다 (DESIGN.md 8.1).
--    무료 티어로 갈 경우 업로드 시 클라이언트에서 리사이즈한 이미지를 올린다.
-- ⚠️ 쇼핑몰 상품 이미지 핫링크 금지. 직접 받아 이 버킷에 올린다.

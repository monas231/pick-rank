-- =============================================================================
-- pick-rank 개발용 시드 데이터
--
-- ⚠️ 개발·로컬 확인 전용이다. 운영 프로젝트에 실행하지 말 것.
--    여기 들어 있는 상품은 화면을 띄워 보기 위한 가상의 이름이며,
--    실제 브랜드·제품이 아니다.
--
-- 실제 카탈로그 씨딩(DESIGN.md 9.2, 50~100개)은 catalog_template.csv 를 채워
-- Supabase 대시보드 > Table Editor > Import data from CSV 로 넣는다.
-- 이때 넣는 것은 이름·브랜드·용량 같은 사실 정보뿐이며,
-- 외부 몰의 별점·리뷰를 긁어와 우리 리뷰인 척 넣지 않는다.
-- =============================================================================

insert into public.kimchi (name, brand, category, competition_year, competition_award) values
  ('테스트 포기김치 1kg',   '샘플식품',   '배추김치', 2025, '대상'),
  ('테스트 맛김치 500g',    '샘플식품',   '배추김치', null, null),
  ('테스트 포기김치 2kg',   '가상농장',   '배추김치', 2025, '금상'),
  ('테스트 총각김치 800g',  '가상농장',   '총각김치', null, null),
  ('테스트 깍두기 1kg',     '테스트푸드', '깍두기',   2025, '은상'),
  ('테스트 열무김치 900g',  '테스트푸드', '열무김치', null, null),
  ('테스트 백김치 1kg',     '샘플식품',   '백김치',   null, null),
  ('테스트 갓김치 700g',    '가상농장',   '갓김치',   2025, '동상')
on conflict do nothing;

-- 딜(가격) 데이터는 작성자(user_id)가 필요해 시드에 넣지 않는다.
-- 로그인한 뒤 앱에서 직접 등록하거나, 아래처럼 본인 uid 를 넣어 실행한다.
--
--   insert into public.price_posts
--     (kimchi_id, user_id, title, price, volume_g, store_name, purchase_method)
--   select k.id, auth.uid(), k.name || ' 최저가', 12900, 1000, '테스트몰', 'online'
--     from public.kimchi k where k.name = '테스트 포기김치 1kg';

-- 관리자 지정: 본인 계정으로 로그인한 뒤 아래를 실행한다 (이메일 교체)
--   update public.profiles set is_admin = true
--    where user_id = (select id from auth.users where email = 'monas231@gmail.com');

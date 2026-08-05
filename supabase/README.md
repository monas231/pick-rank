# Supabase 설정

## 적용 순서

Supabase 대시보드 > **SQL Editor** 에서 아래 순서대로 붙여넣어 실행한다.

| 순서 | 파일 | 내용 |
|---|---|---|
| 1 | `migrations/0001_schema.sql` | 테이블 · 제약 · 인덱스 · 랭킹 파라미터 기본값 |
| 2 | `migrations/0002_ranking.sql` | 랭킹 계산 함수 · 뷰 (5장 / 10.4) |
| 3 | `migrations/0003_rls.sql` | RLS 정책 · 컬럼 권한 |
| 4 | `migrations/0004_triggers.sql` | 트리거 · RPC (신뢰도, 딜 카운트) |
| 5 | `migrations/0005_storage.sql` | Storage 버킷 · 정책 (8.1) |
| 6 | `seed_dev.sql` | **개발용에만** — 화면 확인용 가상 상품 |

> 아직 실제 Postgres에서 실행 검증하지 않은 상태다. 첫 실행 때 오류가 나면 그 메시지를 보고 고친다.

## 관리자 지정

카탈로그 등록·딜 큐레이션은 관리자만 가능하다. 본인 계정으로 한 번 로그인한 뒤:

```sql
update public.profiles set is_admin = true
 where user_id = (select id from auth.users where email = '내이메일@example.com');
```

## 앱 연결

접속 값은 [CONNECTION.md](CONNECTION.md) 에 있다.

```bash
cd pick_rank && flutter run -d chrome --dart-define=SUPABASE_URL=https://bxzslhnczspxnhfngxqh.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_TFBeG5wHC0trMxg0-NrAXg_loB28qMT
```

publishable key는 클라이언트에 박히도록 만들어진 공개용 키라 노출돼도 된다. 데이터를 지키는 것은
이 키가 아니라 **RLS 정책**(0003)이다. 반면 **secret key(옛 service_role)는 RLS를 통째로 우회하므로
앱에 절대 넣지 않는다.**

## 화면이 읽는 뷰

앱은 테이블을 직접 집계하지 않고 아래 뷰를 읽는다. 랭킹은 전체 김치를 가로질러야
나오는 값(카테고리 최저·최고가, 전역 평균 m)이라 한 페이지만 받은 클라이언트에서는
정확히 계산할 수 없다.

| 뷰 | 용도 |
|---|---|
| `kimchi_ranked` | 목록·랭킹 전부. `overall_score` / `satisfaction_score` / `best_price_per_100g` / `value_score` / `award_rank` 로 정렬 |
| `hot_deals` | 핫딜 탭. `hot_score` 내림차순 |
| `deals` | 딜 목록 (마감일 지난 건 `effective_status='ended'`) |
| `kimchi_defect` | 하자율 · 유형 분포 |
| `kimchi_profile` | 맛 프로필 3축 가중 평균 (레이더 차트) |

## 튜닝 파라미터

`ranking_config` 테이블에서 배포 없이 바꾼다.

| key | 기본값 | 설계 근거 |
|---|---|---|
| `bayesian_c` | 5 | 5장 — 클수록 리뷰 적은 제품을 보수적으로 |
| `time_window_min_reviews` | 5 | 5장 — 시간 구간 선택 임계 |
| `satisfaction_weight` / `price_weight` | 0.7 / 0.3 | 5장 전체 랭킹 배합 |
| `hot_gravity` | 1.5 | 10.4 시간 감쇠 |
| `hot_promote_upvotes` | 10 | 10.4 🔥핫딜 승격 |
| `min_reviews_for_rank` | 5 | 9.3 콜드 스타트 노출 임계 |

## 정기 작업 (나중에)

마감일 지난 딜을 내리는 `expire_deals()` 는 `hot_deals` 뷰가 조회 시점에 걸러주므로
당장은 없어도 동작한다. 데이터가 쌓이면 pg_cron 으로 하루 한 번 돌린다.

```sql
select cron.schedule('expire-deals', '0 * * * *', $$select public.expire_deals()$$);
```

## 설계 문서와 다르게 구현한 부분

| 항목 | DESIGN.md | 구현 | 이유 |
|---|---|---|---|
| `kimchi.image_url` | 컬럼명 `image_url` | `image_path` | 8.1이 "경로만 저장"으로 정했으므로 이름을 실제와 맞춤 |
| `price_posts.hot_score` | 캐시 컬럼 | 컬럼 없음, `hot_deals` 뷰에서 계산 | `now()`에 의존해 매 순간 변하는 값이라 캐시하면 갱신 배치 없이는 곧 낡음 |
| hot_score 분자 | `(추천수 − 1)` | `(가중 추천 + 1)` | `−1`은 HN의 작성자 self-upvote 상쇄항. self-vote를 금지했으므로 0표 딜이 음수가 됨. 가중치는 10.4 요구사항 |
| `profiles` | — | `is_admin` 추가 | 관리자 기능을 RLS로 강제하려면 서버가 아는 표식이 필요 |
| `price_posts` | — | `upvote_weight` 추가 | 10.4 "upvote에도 랭커 가중치 재활용" — 표시용 원시 카운트와 분리 |
| 1년 초과 리뷰 가중치 | 표에 없음 | 1.0 (하한) | 0으로 두면 초기 기여자 평가가 통째로 사라짐 |

## 아직 안 정한 것

- `price_posts.kimchi_id` 를 nullable 로 풀지 (카탈로그에 없는 김치 딜 허용, 10.8)
- `deal_comments` 상세 설계 — 지금은 `comment_count` 가 가리킬 최소 형태만 (10.8)
- 랭커 등급 강등 조건 (6.4)
- 이벤트 리뷰(`is_event`) 태그를 언제 붙일지 — 현재 관리자만 세울 수 있게 해둠

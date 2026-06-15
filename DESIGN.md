# pick-rank 프로젝트 설계 문서

작성일: 2026-06-15

---

## 1. 프로젝트 개요

| 항목 | 내용 |
|------|------|
| 이름 | pick-rank |
| GitHub | github.com/monas231/pick-rank |
| 설명 | 김치(및 향후 식품/생활용품) 평가 및 랭킹 플랫폼 |
| 플랫폼 | Flutter (웹 / Android / iOS) |
| 백엔드 | Supabase |
| 사용자 구조 | 멀티유저 (여러 명이 각자 평가하는 플랫폼) |

**확장 계획:** 현재 김치 전용 → 반응 좋으면 다른 식품, 생활용품으로 확장

---

## 2. 주요 기능

### 랭킹
- 전체 랭킹 (맛 70% + 가성비 30%)
- 맛 랭킹 (5개 항목 가중 평균)
- 가격 랭킹 (100g당 가격 오름차순)
- 가성비 랭킹 (맛 점수 / 100g당 가격, 정규화)
- 품평회 랭킹 (aT 대한민국 김치품평회 수상작 기준)

### 김치 상세 페이지
- 오각형 레이더 차트 (5개 맛 항목)
- 가격 변동 그래프 (시계열)
- 현재 최저가 정보 (판매처, 링크, 구매방법)
- 사용자 리뷰 목록

### 사용자 기능
- 맛 평가 입력 (5개 항목, 1~10점, 1인 1리뷰 + 수정 가능)
- 가격 게시물 등록 (판매처, 가격, 용량, 링크 등)

### 관리자 기능
- 김치 상품 등록/관리
- 품평회 수상 결과 입력 (aT 공식 PDF 참고하여 수동 입력)

---

## 3. 맛 평가 항목 (5개 — 오각형 레이더 차트)

| # | 항목 | 설명 | 범위 |
|---|------|------|------|
| 1 | 매운맛 | 고춧가루 화끈한 정도 | 1~10 |
| 2 | 신맛 | 발효 숙성도 | 1~10 |
| 3 | 젓갈맛 | 젓갈 풍미 강도 | 1~10 |
| 4 | 단맛 | 달달한 정도 | 1~10 |
| 5 | 아삭함 | 식감/신선도 | 1~10 |

> 세계김치연구소 관능검사 기준 및 학술 자료 기반으로 선정  
> 감칠맛은 젓갈맛과 중복 가능성이 높아 제외

---

## 4. DB 스키마 (Supabase)

### `kimchi` — 김치 상품 (관리자 등록)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid, PK | |
| name | text | 상품명 |
| brand | text | 브랜드/제조사 |
| image_url | text | |
| category | text | 배추김치, 깍두기, 열무김치 등 |
| competition_year | int | 품평회 연도 (예: 2025) |
| competition_award | text | 대상, 금상, 은상, 동상 등 |
| created_at | timestamptz | |

### `price_posts` — 가격 게시물 (사용자 입력)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid, PK | |
| kimchi_id | uuid, FK → kimchi.id | |
| user_id | uuid, FK → auth.users.id | |
| price | int | 판매가 (원) |
| volume_g | int | 용량 (g) |
| price_per_100g | numeric | 자동 계산: price / volume_g × 100 |
| store_name | text | 판매처명 |
| purchase_url | text | 구매 링크 |
| purchase_method | text | 온라인 / 오프라인 / 앱 |
| notes | text | 메모 |
| created_at | timestamptz | |

### `reviews` — 사용자 리뷰 (1인 1리뷰, 수정 가능)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid, PK | |
| kimchi_id | uuid, FK → kimchi.id | |
| user_id | uuid, FK → auth.users.id | |
| score_spicy | int (1~10) | 매운맛 |
| score_sour | int (1~10) | 신맛 |
| score_fishiness | int (1~10) | 젓갈맛 |
| score_sweet | int (1~10) | 단맛 |
| score_crunch | int (1~10) | 아삭함 |
| comment | text | |
| created_at | timestamptz | |
| updated_at | timestamptz | |

> UNIQUE(kimchi_id, user_id)

---

## 5. 랭킹 계산 로직

### 시간 기반 가중치 — 동적 구간 + 구간 내 가중치

**Step 1. 구간 결정**
- 최근 3개월 리뷰 수 >= 5 → 3개월 구간 사용
- 최근 6개월 리뷰 수 >= 5 → 6개월 구간 사용
- 전체 리뷰 수 < 5 → 전체 기간 단순 평균

**Step 2. 구간 내 가중치**
- 최근 3개월 × 3.0
- 3~6개월 × 2.0
- 6개월~1년 × 1.0

### 랭킹별 계산

| 랭킹 | 계산식 |
|------|--------|
| 맛 점수 | (매운맛 + 신맛 + 젓갈맛 + 단맛 + 아삭함) / 5 (가중 평균 적용) |
| 가격 랭킹 | price_per_100g 오름차순 |
| 가성비 | 맛 점수 / price_per_100g (0~1 정규화 후 비교) |
| 전체 랭킹 | 맛 점수 × 0.7 + 가성비 점수 × 0.3 |
| 품평회 | competition_award 기준 (대상 > 금상 > 은상 > 동상) |

---

## 6. 참고 자료

- **aT 대한민국 김치품평회** (제14회, 2025)
  - 주최: 한국농수산식품유통공사 (aT)
  - 심사: 전문가 + 일반 소비자 관능평가 + 현장 위생 평가
  - 수상: 대상, 금상, 은상, 동상
  - 결과: 매년 PDF 공개 → 관리자 수동 입력 방식

- **세계김치연구소 관능검사 매뉴얼**: https://www.wikim.re.kr

- **김치 관능평가 학술 기준**: 맛(신맛, 단맛, 감칠맛, 매운맛) + 식감(아삭함, 씹힘성) + 외관(색)
  - 출처: Journal of Sensory Studies, ResearchGate 등

---

## 7. 기술 스택

| 역할 | 기술 |
|------|------|
| Frontend | Flutter (멀티플랫폼: 웹 / Android / iOS) |
| Backend | Supabase (PostgreSQL + Auth + Storage + Edge Functions) |
| 차트 | 레이더 차트 (오각형), 시계열 가격 차트 |
| 인증 | Supabase Auth |
| 이미지 저장 | Supabase Storage |

# Supabase 접속 정보

| 항목 | 값 |
|---|---|
| Project URL | `https://bxzslhnczspxnhfngxqh.supabase.co` |
| 프로젝트 ref | `bxzslhnczspxnhfngxqh` |
| 대시보드 | https://supabase.com/dashboard/project/bxzslhnczspxnhfngxqh |

## 데이터베이스 비밀번호

```
DZjlGPaTRpT5KhCX
```

프로젝트 생성 시 정한 Postgres `postgres` 계정 비밀번호다. **쓰이는 곳은 두 군데뿐**이다.

- `psql`로 DB에 직접 접속할 때
- Supabase CLI의 `supabase link` / `db push`

**Flutter 앱에는 들어가지 않는다.** 앱은 아래 anon key만 쓴다.

## 앱이 쓰는 값 — publishable key

```
SUPABASE_URL              = https://bxzslhnczspxnhfngxqh.supabase.co
SUPABASE_PUBLISHABLE_KEY  = sb_publishable_TFBeG5wHC0trMxg0-NrAXg_loB28qMT
```

> 이 키는 **클라이언트에 박히도록 만들어진 공개용 키**다. 웹으로 배포하면 브라우저에서
> 누구나 볼 수 있고, 그게 정상이다. 데이터를 지키는 것은 이 키가 아니라 **RLS 정책**(0003)이다.
>
> Supabase가 키 이름을 `anon key` → `publishable key` 로 바꾸는 중이다. 앱의 `Env`는
> `SUPABASE_ANON_KEY` / `SUPABASE_PUBLISHABLE_KEY` 둘 다 받는다.
>
> ⚠️ **`secret key`(예전 이름 service_role)는 RLS를 통째로 우회한다.** 앱에도 이 문서에도 넣지 않는다.

실행:

```bash
cd pick_rank && flutter run -d chrome --dart-define=SUPABASE_URL=https://bxzslhnczspxnhfngxqh.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_TFBeG5wHC0trMxg0-NrAXg_loB28qMT
```

## DB 직접 접속 (PostgreSQL 클라이언트를 깐 뒤)

```bash
psql "postgresql://postgres:DZjlGPaTRpT5KhCX@db.bxzslhnczspxnhfngxqh.supabase.co:5432/postgres"
```

⚠️ 위는 **직접 접속(Direct connection)** 형식이다. 프로젝트에 따라 IPv4로는 안 붙고
**Session pooler** 주소를 써야 할 수 있다. 안 되면 대시보드 > Project Settings > Database >
**Connection string** 에서 실제 값을 복사할 것 (호스트·포트·사용자명이 다르다).

## 비밀번호를 새로 발급하려면

대시보드 > Project Settings > Database > **Reset database password**. 한 번 누르면 끝이고,
바뀐 값을 이 문서에 다시 적으면 된다. 앱은 이 값을 안 쓰므로 재배포도 필요 없다.

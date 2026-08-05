# Supabase 접속 정보

## 데이터베이스 비밀번호

```
DZjlGPaTRpT5KhCX
```

프로젝트 생성 시 정한 Postgres `postgres` 계정 비밀번호다. **쓰이는 곳은 두 군데뿐**이다.

- `psql`로 DB에 직접 접속할 때
- Supabase CLI의 `supabase link` / `db push`

**Flutter 앱에는 들어가지 않는다.** 앱은 아래 anon key만 쓴다.

## 앱이 쓰는 값 (아직 못 받음 — 채워넣을 것)

Supabase 대시보드 > Project Settings > API 에서 복사한다.

```
SUPABASE_URL       = https://________.supabase.co
SUPABASE_ANON_KEY  = eyJ...
```

실행할 때 이렇게 넘긴다.

```bash
cd pick_rank && flutter run -d chrome --dart-define=SUPABASE_URL=<위 URL> --dart-define=SUPABASE_ANON_KEY=<위 anon key>
```

> anon key는 클라이언트에 박히는 공개용 키라 노출돼도 된다.
> **service_role key는 RLS를 통째로 우회하므로 앱에도 이 파일에도 넣지 않는다.**

## DB 직접 접속 (PostgreSQL 클라이언트를 깐 뒤)

대시보드 > Project Settings > Database > Connection string 에서 정확한 호스트를 확인한다.

```bash
psql "postgresql://postgres:DZjlGPaTRpT5KhCX@db.________.supabase.co:5432/postgres"
```

## 비밀번호를 새로 발급하려면

대시보드 > Project Settings > Database > **Reset database password**. 한 번 누르면 끝이고,
바뀐 값을 이 문서에 다시 적으면 된다. 앱은 이 값을 안 쓰므로 재배포도 필요 없다.

/// 빌드/실행 시 --dart-define 으로 주입한다.
///
///   flutter run -d chrome \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJ...
///
/// anon key 는 클라이언트에 박히는 공개용 키라 노출돼도 된다.
/// service_role key 는 RLS 를 통째로 우회하므로 앱에 절대 넣지 않는다.
class Env {
  const Env._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  // Supabase 가 이 키의 이름을 anon key → publishable key 로 바꾸는 중이라
  // 대시보드 버전에 따라 둘 중 아무 이름으로나 넘겨도 되게 해 둔다.
  static const _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const _publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static String get supabaseKey =>
      _publishableKey.isNotEmpty ? _publishableKey : _anonKey;

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
}

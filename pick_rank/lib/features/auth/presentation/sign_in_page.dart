import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../providers.dart';

/// 소셜 로그인만 받는다. DESIGN.md 9.5
///
/// 이메일 가입을 열지 않는 이유는 이벤트 보상을 노린 다계정을 막기 위해서다.
///
/// ⚠️ 네이버는 Supabase 기본 제공 provider 가 아니다. 설계상 카카오/네이버를
///    쓰기로 했지만, 네이버는 별도 작업(커스텀 OIDC 또는 Edge Function)이 필요해
///    여기서는 카카오만 붙였다. 구글은 개발 중 확인용이다.
class SignInPage extends ConsumerWidget {
  const SignInPage({super.key});

  Future<void> _signIn(
    BuildContext context,
    WidgetRef ref,
    OAuthProvider provider,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(supabaseClientProvider).auth.signInWithOAuth(
        provider,
        redirectTo: kIsWeb ? null : 'io.supabase.pickrank://login-callback/',
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('로그인하지 못했습니다: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('로그인')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '평가를 남기려면 로그인이 필요합니다',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '한 사람이 여러 계정으로 평가하는 것을 막기 위해 소셜 계정으로만 가입받습니다.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: () => _signIn(context, ref, OAuthProvider.kakao),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('카카오로 시작하기'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _signIn(context, ref, OAuthProvider.google),
                  icon: const Icon(Icons.g_mobiledata, size: 22),
                  label: const Text('Google로 시작하기'),
                ),
                const SizedBox(height: 20),
                Text(
                  'Supabase 대시보드 > Authentication > Providers 에서 해당 provider 를 '
                  '먼저 켜야 동작합니다.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

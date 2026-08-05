import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/env.dart';
import 'core/theme.dart';
import 'features/auth/presentation/sign_in_page.dart';
import 'features/catalog/presentation/kimchi_detail_page.dart';
import 'features/deals/presentation/deal_detail_page.dart';
import 'features/home/home_page.dart';
import 'features/reviews/presentation/review_form_page.dart';

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const HomePage()),
    GoRoute(
      path: '/kimchi/:id',
      builder: (_, state) =>
          KimchiDetailPage(kimchiId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/kimchi/:id/review',
      builder: (_, state) =>
          ReviewFormPage(kimchiId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/deal/:id',
      builder: (_, state) => DealDetailPage(dealId: state.pathParameters['id']!),
    ),
    GoRoute(path: '/sign-in', builder: (_, _) => const SignInPage()),
  ],
);

class PickRankApp extends StatelessWidget {
  const PickRankApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Env.isConfigured) {
      return MaterialApp(
        title: 'pick-rank',
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const _SetupRequiredPage(),
      );
    }

    return MaterialApp.router(
      title: 'pick-rank',
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      routerConfig: _router,
    );
  }
}

/// Supabase 키가 없을 때 나오는 안내 화면.
/// 이게 보인다는 건 --dart-define 을 안 넘겼다는 뜻이다.
class _SetupRequiredPage extends StatelessWidget {
  const _SetupRequiredPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.settings_outlined,
                  size: 40,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text('Supabase 연결 정보가 없습니다', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(
                  '프로젝트 설정 > API 에서 Project URL 과 anon public key 를 복사해 '
                  '실행 인자로 넘기세요.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SelectableText(
                    'flutter run -d chrome \\\n'
                    '  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \\\n'
                    '  --dart-define=SUPABASE_ANON_KEY=eyJ...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'service_role key 는 RLS 를 통째로 우회하므로 앱에 넣지 마세요.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
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

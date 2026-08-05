import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers.dart';
import '../catalog/presentation/ranking_tab.dart';
import '../deals/presentation/deals_tab.dart';

/// 홈 = [랭킹] 탭 / [핫딜] 탭. DESIGN.md 10.1
///
/// 평가/랭킹은 가끔 하는 행동이고 딜은 자주 확인하는 행동이라 성격이 다르다.
/// 탭은 분리하되 김치 단위로 서로 연결된다 (10.2).
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'pick-rank',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          actions: [
            if (user == null)
              TextButton(
                onPressed: () => context.push('/sign-in'),
                child: const Text('로그인'),
              )
            else
              PopupMenuButton<String>(
                icon: const Icon(Icons.account_circle_outlined),
                onSelected: (value) async {
                  if (value == 'signOut') {
                    await ref.read(supabaseClientProvider).auth.signOut();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Text(user.email ?? user.id),
                  ),
                  const PopupMenuItem(
                    value: 'signOut',
                    child: Text('로그아웃'),
                  ),
                ],
              ),
            const SizedBox(width: 4),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: '랭킹'),
              Tab(text: '핫딜'),
            ],
          ),
        ),
        body: const TabBarView(children: [RankingTab(), DealsTab()]),
      ),
    );
  }
}

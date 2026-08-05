import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers.dart';
import '../data/deal_repository.dart';
import 'deal_card.dart';

/// 핫딜 탭. DESIGN.md 10장
///
/// 정렬 기본값은 인기(hot_score) — 추천 수를 시간으로 감쇠시킨 값이다.
/// 딜은 시효가 생명이라 오래된 글은 추천이 많아도 밀려나야 한다 (10.4).
class DealsTab extends ConsumerStatefulWidget {
  const DealsTab({super.key});

  @override
  ConsumerState<DealsTab> createState() => _DealsTabState();
}

class _DealsTabState extends ConsumerState<DealsTab> {
  DealSort _sort = DealSort.hot;

  Future<void> _vote(String dealId, bool nowVoted) async {
    final messenger = ScaffoldMessenger.of(context);
    if (ref.read(currentUserProvider) == null) {
      messenger.showSnackBar(const SnackBar(content: Text('로그인이 필요합니다')));
      return;
    }

    try {
      await ref
          .read(dealRepositoryProvider)
          .toggleVote(dealId, nowVoted: nowVoted);
      ref.invalidate(myVotedDealsProvider);
      ref.invalidate(dealsProvider(_sort));
    } catch (error) {
      // 자기 딜에 자기가 추천하는 경우는 RLS 가 막는다
      messenger.showSnackBar(SnackBar(content: Text('추천하지 못했습니다: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final deals = ref.watch(dealsProvider(_sort));
    final voted = ref.watch(myVotedDealsProvider).value ?? const <String>{};
    final kimchiRepository = ref.watch(kimchiRepositoryProvider);

    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: DealSort.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final sort = DealSort.values[index];
              return Center(
                child: ChoiceChip(
                  label: Text(sort.label),
                  selected: sort == _sort,
                  onSelected: (_) => setState(() => _sort = sort),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(dealsProvider(_sort)),
            child: deals.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _Message(text: '딜을 불러오지 못했습니다\n$error'),
              data: (items) {
                if (items.isEmpty) {
                  return const _Message(
                    text: '진행 중인 딜이 없습니다.\n초기 딜은 운영자가 직접 등록합니다.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final deal = items[index];
                    return DealCard(
                      deal: deal,
                      imageUrl: kimchiRepository.publicImageUrl(
                        deal.kimchiImagePath,
                      ),
                      voted: voted.contains(deal.id),
                      onTap: () => context.push('/deal/${deal.id}'),
                      onVote: () => _vote(deal.id, !voted.contains(deal.id)),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers.dart';
import '../data/kimchi_repository.dart';
import 'kimchi_card.dart';

/// 랭킹 탭. DESIGN.md 2장 / 5장
///
/// 기본 정렬이 고정이 아니다. 리뷰가 쌓이기 전에는 종합 랭킹이 통째로 비므로
/// 품평회 랭킹을 먼저 보여준다 (9.3 콜드 스타트 UX 우회).
class RankingTab extends ConsumerStatefulWidget {
  const RankingTab({super.key});

  @override
  ConsumerState<RankingTab> createState() => _RankingTabState();
}

class _RankingTabState extends ConsumerState<RankingTab> {
  /// 사용자가 직접 고른 정렬. null 이면 데이터 상태를 보고 자동으로 정한다.
  RankingSort? _chosen;

  @override
  Widget build(BuildContext context) {
    final hasRankable = ref.watch(hasRankableProvider).value;
    final sort =
        _chosen ??
        (hasRankable == true ? RankingSort.overall : RankingSort.competition);

    final ranking = ref.watch(rankingProvider(sort));
    final repository = ref.watch(kimchiRepositoryProvider);

    return Column(
      children: [
        _SortSelector(
          selected: sort,
          onChanged: (value) => setState(() => _chosen = value),
        ),
        if (hasRankable == false && _chosen == null) const _ColdStartNotice(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(rankingProvider(sort));
              ref.invalidate(hasRankableProvider);
            },
            child: ranking.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorView(
                error: error,
                onRetry: () => ref.invalidate(rankingProvider(sort)),
              ),
              data: (items) {
                if (items.isEmpty) return _EmptyView(sort: sort);
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final kimchi = items[index];
                    return KimchiCard(
                      rank: index + 1,
                      kimchi: kimchi,
                      sort: sort,
                      imageUrl: repository.publicImageUrl(kimchi.imagePath),
                      onTap: () => context.push('/kimchi/${kimchi.id}'),
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

class _SortSelector extends StatelessWidget {
  const _SortSelector({required this.selected, required this.onChanged});

  final RankingSort selected;
  final ValueChanged<RankingSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: RankingSort.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final sort = RankingSort.values[index];
          // Center 로 감싸야 칩이 제 높이를 갖는다. 가로 ListView 가 높이를
          // 꽉 조이면 칩 내부가 눌려 라벨이 잘린다.
          return Center(
            child: ChoiceChip(
              label: Text(sort.label),
              selected: sort == selected,
              onSelected: (_) => onChanged(sort),
            ),
          );
        },
      ),
    );
  }
}

/// 리뷰가 아직 임계치에 못 미쳐 종합 랭킹을 못 만드는 상태임을 알린다.
class _ColdStartNotice extends StatelessWidget {
  const _ColdStartNotice();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: scheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '아직 평가가 충분히 모이지 않아 품평회 수상 결과를 먼저 보여드립니다.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.sort});

  final RankingSort sort;

  @override
  Widget build(BuildContext context) {
    final message = switch (sort) {
      RankingSort.overall =>
        '종합 랭킹에 올릴 만큼 평가가 쌓인 김치가 아직 없습니다.\n'
            '평가와 가격 정보가 모두 있어야 순위가 만들어집니다.',
      RankingSort.taste => '평가가 충분히 쌓인 김치가 아직 없습니다.',
      RankingSort.price => '등록된 가격 정보가 없습니다. 핫딜 탭에서 가격을 올려주세요.',
      RankingSort.value => '가성비를 계산하려면 평가와 가격이 모두 필요합니다.',
      RankingSort.competition => '등록된 품평회 수상 정보가 없습니다.',
    };

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
          child: Column(
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 40,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
          child: Column(
            children: [
              Icon(
                Icons.error_outline,
                size: 40,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                '불러오지 못했습니다',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(onPressed: onRetry, child: const Text('다시 시도')),
            ],
          ),
        ),
      ],
    );
  }
}

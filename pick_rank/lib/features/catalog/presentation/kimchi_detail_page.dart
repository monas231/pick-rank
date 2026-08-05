import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../providers.dart';
import '../../../widgets/defect_badge.dart';
import '../../../widgets/kimchi_thumbnail.dart';
import '../../../widgets/star_rating.dart';
import '../../../widgets/taste_radar_chart.dart';
import '../../deals/domain/deal.dart';
import '../../reviews/presentation/review_tile.dart';
import '../domain/kimchi_ranked.dart';

class KimchiDetailPage extends ConsumerWidget {
  const KimchiDetailPage({super.key, required this.kimchiId});

  final String kimchiId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(kimchiDetailProvider(kimchiId));

    return Scaffold(
      appBar: AppBar(title: Text(detail.value?.name ?? '김치 상세')),
      floatingActionButton: detail.value == null
          ? null
          : _ReviewFab(kimchiId: kimchiId),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('불러오지 못했습니다\n$error')),
        data: (kimchi) => kimchi == null
            ? const Center(child: Text('없는 김치입니다'))
            : _Body(kimchi: kimchi),
      ),
    );
  }
}

class _ReviewFab extends ConsumerWidget {
  const _ReviewFab({required this.kimchiId});

  final String kimchiId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(myReviewProvider(kimchiId)).value;
    final signedIn = ref.watch(currentUserProvider) != null;

    return FloatingActionButton.extended(
      onPressed: () => context.push(
        signedIn ? '/kimchi/$kimchiId/review' : '/sign-in',
      ),
      icon: Icon(mine == null ? Icons.rate_review_outlined : Icons.edit_outlined),
      label: Text(mine == null ? '평가하기' : '내 평가 수정'),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.kimchi});

  final KimchiRanked kimchi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final repository = ref.watch(kimchiRepositoryProvider);

    return RefreshIndicator(
      onRefresh: () async => invalidateKimchi(ref, kimchi.id),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KimchiThumbnail(
                url: repository.publicImageUrl(kimchi.imagePath),
                size: 88,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(kimchi.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${kimchi.brand} · ${kimchi.category}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (kimchi.hasAward) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${kimchi.competitionYear} 김치품평회 ${kimchi.competitionAward}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onTertiaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          _SatisfactionBlock(kimchi: kimchi),

          const SizedBox(height: 20),
          _SectionTitle(
            '맛 프로필',
            trailing: kimchi.hasProfile ? '${kimchi.profileSampleCount}명 입력' : null,
          ),
          const SizedBox(height: 8),
          _ProfileBlock(kimchi: kimchi),

          if (kimchi.defectReportCount > 0) ...[
            const SizedBox(height: 20),
            const _SectionTitle('제품 하자'),
            const SizedBox(height: 8),
            DefectBadge(
              reportCount: kimchi.defectReportCount,
              rate: kimchi.defectRate,
              breakdown: kimchi.defectBreakdown,
            ),
            const SizedBox(height: 6),
            Text(
              '하자율은 배송·포장 사고가 맛 평가를 왜곡하지 않도록 랭킹에 반영하지 않습니다.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],

          const SizedBox(height: 20),
          const _SectionTitle('관련 핫딜'),
          const SizedBox(height: 8),
          _RelatedDeals(kimchiId: kimchi.id),

          const SizedBox(height: 20),
          _SectionTitle('리뷰', trailing: '${kimchi.reviewCountTotal}개'),
          _ReviewList(kimchiId: kimchi.id),
        ],
      ),
    );
  }
}

class _SatisfactionBlock extends StatelessWidget {
  const _SatisfactionBlock({required this.kimchi});

  final KimchiRanked kimchi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                formatScore(kimchi.satisfactionScore),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StarRating(score: kimchi.satisfactionScore, size: 18),
                  const SizedBox(height: 2),
                  Text(
                    '맛평가 ${kimchi.tasteReviewCount}개',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (kimchi.bestPricePer100g != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatPricePer100g(kimchi.bestPricePer100g!),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                    Text(
                      '진행 중인 딜 ${kimchi.activeDealCount}개',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (!kimchi.isRankable) ...[
            const SizedBox(height: 10),
            Text(
              '아직 평가가 적어 순위에 올리지 않았습니다. '
              '리뷰가 적을 때 극단적인 별점이 순위를 뒤집지 않도록 전체 평균 쪽으로 보정합니다.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileBlock extends StatelessWidget {
  const _ProfileBlock({required this.kimchi});

  final KimchiRanked kimchi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 프로필 데이터가 부족하면 차트 대신 안내를 띄운다 (DESIGN.md 3.2)
    if (!kimchi.hasProfile) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          children: [
            Text(
              '프로필 정보 부족',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '매운맛·단맛·젓갈맛을 입력한 평가가 아직 없습니다.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Center(
          child: TasteRadarChart(
            spicy: kimchi.avgSpicy!,
            sweet: kimchi.avgSweet!,
            fishiness: kimchi.avgFishiness!,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '세 축은 품질이 아니라 "어떤 맛인지"를 나타냅니다. 순위 계산에는 쓰이지 않습니다.',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RelatedDeals extends ConsumerWidget {
  const _RelatedDeals({required this.kimchiId});

  final String kimchiId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deals = ref.watch(kimchiDealsProvider(kimchiId));
    final theme = Theme.of(context);

    return deals.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Text('딜을 불러오지 못했습니다: $error'),
      data: (items) {
        if (items.isEmpty) {
          return Text(
            '진행 중인 딜이 없습니다.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );
        }
        return Column(
          children: [
            for (final deal in items) _RelatedDealTile(deal: deal),
          ],
        );
      },
    );
  }
}

class _RelatedDealTile extends StatelessWidget {
  const _RelatedDealTile({required this.deal});

  final Deal deal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        deal.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium,
      ),
      subtitle: Text(
        '${deal.storeName} · ${formatPricePer100g(deal.pricePer100g)}',
        style: theme.textTheme.labelSmall,
      ),
      trailing: Text(
        formatWon(deal.price),
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.primary,
        ),
      ),
      onTap: () => context.push('/deal/${deal.id}'),
    );
  }
}

class _ReviewList extends ConsumerWidget {
  const _ReviewList({required this.kimchiId});

  final String kimchiId;

  Future<void> _like(
    BuildContext context,
    WidgetRef ref,
    String reviewId,
    bool nowLiked,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (ref.read(currentUserProvider) == null) {
      messenger.showSnackBar(const SnackBar(content: Text('로그인이 필요합니다')));
      return;
    }

    try {
      await ref
          .read(reviewRepositoryProvider)
          .toggleLike(reviewId, nowLiked: nowLiked);
      ref.invalidate(myLikedReviewsProvider(kimchiId));
      ref.invalidate(kimchiReviewsProvider(kimchiId));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('공감하지 못했습니다: $error')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(kimchiReviewsProvider(kimchiId));
    final liked =
        ref.watch(myLikedReviewsProvider(kimchiId)).value ??
        const <String>{};
    final myId = ref.watch(currentUserProvider)?.id;

    return reviews.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Text('리뷰를 불러오지 못했습니다: $error'),
      data: (items) {
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              '첫 평가를 남겨보세요.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        return Column(
          children: [
            for (final review in items)
              ReviewTile(
                review: review,
                isMine: review.userId == myId,
                liked: liked.contains(review.id),
                onLike: () => _like(
                  context,
                  ref,
                  review.id,
                  !liked.contains(review.id),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Text(
          text,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 6),
          Text(
            trailing!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

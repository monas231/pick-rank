import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme.dart';
import '../../../widgets/defect_badge.dart';
import '../../../widgets/kimchi_thumbnail.dart';
import '../../../widgets/star_rating.dart';
import '../data/kimchi_repository.dart';
import '../domain/kimchi_ranked.dart';

class KimchiCard extends StatelessWidget {
  const KimchiCard({
    super.key,
    required this.rank,
    required this.kimchi,
    required this.sort,
    required this.imageUrl,
    required this.onTap,
  });

  final int rank;
  final KimchiRanked kimchi;
  final RankingSort sort;
  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '$rank',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: rankColor(rank, scheme),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              KimchiThumbnail(url: imageUrl, size: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kimchi.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${kimchi.brand} · ${kimchi.category}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _primaryMetric(context),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (kimchi.hasAward)
                          _Pill(
                            text:
                                '${kimchi.competitionYear} ${kimchi.competitionAward}',
                            background: scheme.tertiaryContainer,
                            foreground: scheme.onTertiaryContainer,
                          ),
                        if (kimchi.activeDealCount > 0)
                          _Pill(
                            text: '딜 ${kimchi.activeDealCount}',
                            background: scheme.secondaryContainer,
                            foreground: scheme.onSecondaryContainer,
                          ),
                        if (kimchi.defectReportCount > 0)
                          DefectBadge(
                            reportCount: kimchi.defectReportCount,
                            rate: kimchi.defectRate,
                            breakdown: kimchi.defectBreakdown,
                            compact: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 어떤 랭킹을 보고 있느냐에 따라 큰 글씨로 보여줄 숫자가 달라진다.
  Widget _primaryMetric(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final price = kimchi.bestPricePer100g;
    final priceText = price == null ? '가격 정보 없음' : formatPricePer100g(price);

    Widget stars() => Row(
      children: [
        StarRating(score: kimchi.satisfactionScore),
        const SizedBox(width: 6),
        Text(
          formatScore(kimchi.satisfactionScore),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '(${kimchi.tasteReviewCount})',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    return switch (sort) {
      RankingSort.price => Text(
        priceText,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.primary,
        ),
      ),
      RankingSort.competition => stars(),
      _ => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          stars(),
          const SizedBox(height: 2),
          Text(
            priceText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    };
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

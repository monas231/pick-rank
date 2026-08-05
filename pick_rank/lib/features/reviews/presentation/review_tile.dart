import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../widgets/star_rating.dart';
import '../domain/defect_type.dart';
import '../domain/review.dart';

class ReviewTile extends StatelessWidget {
  const ReviewTile({
    super.key,
    required this.review,
    required this.isMine,
    required this.liked,
    required this.onLike,
  });

  final Review review;
  final bool isMine;
  final bool liked;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final badge = review.tierBadge;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                review.authorNickname,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              if (isMine) ...[
                const SizedBox(width: 6),
                Text(
                  '내 평가',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                  ),
                ),
              ],
              const Spacer(),
              Text(
                formatRelativeTime(review.createdAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),

          // 맛평가 --------------------------------------------------------
          if (review.hasTaste) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                StarRating(score: review.scoreOverall, size: 15),
                const SizedBox(width: 6),
                Text(
                  formatScore(review.scoreOverall),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (review.hasProfile) ...[
              const SizedBox(height: 4),
              Text(
                '매운맛 ${review.scoreSpicy} · 단맛 ${review.scoreSweet} · 젓갈맛 ${review.scoreFishiness}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (review.comment != null) ...[
              const SizedBox(height: 6),
              Text(review.comment!, style: theme.textTheme.bodyMedium),
            ],
          ],

          // 제품평가(하자 신고) --------------------------------------------
          if (review.hasDefect) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.errorContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final code in review.defectTypes)
                        Text(
                          '⚠️ ${DefectType.fromCode(code)?.label ?? code}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onErrorContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  if (review.defectNote != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      review.defectNote!,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: isMine ? null : onLike,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: Icon(
                liked ? Icons.favorite : Icons.favorite_border,
                size: 15,
                color: liked ? scheme.primary : scheme.onSurfaceVariant,
              ),
              label: Text(
                '공감 ${review.likeCount}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: liked ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

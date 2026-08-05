import 'package:flutter/material.dart';

import '../core/format.dart';
import '../features/reviews/domain/defect_type.dart';

/// 하자율 배지. DESIGN.md 3.3
///
/// 표시 전용이다. 배송 사고나 포장 불량이 제품 본연의 맛 평가를 왜곡하지 않도록
/// 어떤 랭킹에도 반영하지 않는다.
///
/// 분모가 "제품평가를 켠 리뷰"가 아니라 "전체 리뷰"인 것이 중요하다.
/// 문제없이 맛평가만 하고 지나간 사람도 분모에 들어가야 불만 편향이 걷힌다.
class DefectBadge extends StatelessWidget {
  const DefectBadge({
    super.key,
    required this.reportCount,
    required this.rate,
    required this.breakdown,
    this.compact = false,
  });

  final int reportCount;
  final double rate;
  final Map<String, int> breakdown;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (reportCount == 0) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final summary = _breakdownSummary();

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '하자 ${formatPercent(rate)}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: scheme.onErrorContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: scheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '하자 신고 $reportCount건 · 하자율 ${formatPercent(rate)}'
              '${summary.isEmpty ? '' : ' ($summary)'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  String _breakdownSummary() {
    final entries = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .map((entry) {
          final label = DefectType.fromCode(entry.key)?.shortLabel ?? entry.key;
          return '$label ${entry.value}';
        })
        .join(' · ');
  }
}

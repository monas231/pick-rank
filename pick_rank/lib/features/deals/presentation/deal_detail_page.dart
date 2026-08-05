import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/format.dart';
import '../../../providers.dart';
import '../domain/deal.dart';

class DealDetailPage extends ConsumerStatefulWidget {
  const DealDetailPage({super.key, required this.dealId});

  final String dealId;

  @override
  ConsumerState<DealDetailPage> createState() => _DealDetailPageState();
}

class _DealDetailPageState extends ConsumerState<DealDetailPage> {
  @override
  void initState() {
    super.initState();
    // 조회수는 view_count 컬럼에 직접 쓸 권한이 없어 RPC 로만 오른다.
    // 실패해도 화면에는 영향이 없으므로 조용히 넘긴다.
    Future.microtask(() {
      ref.read(dealRepositoryProvider).incrementView(widget.dealId).ignore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final deal = ref.watch(dealDetailProvider(widget.dealId));

    return Scaffold(
      appBar: AppBar(title: const Text('딜 정보')),
      body: deal.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('불러오지 못했습니다\n$error')),
        data: (value) => value == null
            ? const Center(child: Text('삭제되었거나 없는 딜입니다'))
            : _DealBody(deal: value),
      ),
    );
  }
}

class _DealBody extends ConsumerWidget {
  const _DealBody({required this.deal});

  final Deal deal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (!deal.isActive)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${deal.statusLabel}입니다. 가격·재고가 지금과 다를 수 있습니다.',
              style: theme.textTheme.bodySmall,
            ),
          ),

        Text(deal.title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          '${deal.storeName} · ${formatRelativeTime(deal.createdAt)}'
          '${deal.isOfficial ? ' · 운영자 등록' : ''}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    formatWon(deal.price),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('/ ${deal.volumeG}g', style: theme.textTheme.bodyMedium),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                formatPricePer100g(deal.pricePer100g),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (deal.discountInfo != null) ...[
                const SizedBox(height: 8),
                Text(deal.discountInfo!, style: theme.textTheme.bodyMedium),
              ],
              if (deal.remaining != null) ...[
                const SizedBox(height: 8),
                Text(
                  '마감까지 ${deal.remaining}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),

        if (deal.body != null) ...[
          const SizedBox(height: 16),
          Text(deal.body!, style: theme.textTheme.bodyMedium),
        ],

        const SizedBox(height: 20),
        if (deal.purchaseUrl != null)
          FilledButton.icon(
            onPressed: () => launchUrl(
              Uri.parse(deal.purchaseUrl!),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('구매하러 가기'),
          ),

        const SizedBox(height: 12),
        // 딜 → 랭킹 연결 (DESIGN.md 10.2)
        OutlinedButton.icon(
          onPressed: () => context.push('/kimchi/${deal.kimchiId}'),
          icon: const Icon(Icons.leaderboard_outlined, size: 18),
          label: Text('${deal.kimchiName} 평가·랭킹 보기'),
        ),

        const SizedBox(height: 20),
        Text(
          '추천 ${deal.upvoteCount} · 댓글 ${deal.commentCount} · 조회 ${deal.viewCount}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

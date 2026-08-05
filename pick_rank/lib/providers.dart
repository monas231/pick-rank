import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/catalog/data/kimchi_repository.dart';
import 'features/catalog/domain/kimchi_ranked.dart';
import 'features/deals/data/deal_repository.dart';
import 'features/deals/domain/deal.dart';
import 'features/reviews/data/review_repository.dart';
import 'features/reviews/domain/review.dart';

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final kimchiRepositoryProvider = Provider(
  (ref) => KimchiRepository(ref.watch(supabaseClientProvider)),
);

final dealRepositoryProvider = Provider(
  (ref) => DealRepository(ref.watch(supabaseClientProvider)),
);

final reviewRepositoryProvider = Provider(
  (ref) => ReviewRepository(ref.watch(supabaseClientProvider)),
);

/// 로그인 상태 변화. 로그인/로그아웃하면 아래 currentUserProvider 가 다시 계산된다.
final authChangesProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(supabaseClientProvider).auth.onAuthStateChange,
);

final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authChangesProvider);
  return ref.watch(supabaseClientProvider).auth.currentUser;
});

// --- 랭킹 -------------------------------------------------------------------

final rankingProvider = FutureProvider.family<List<KimchiRanked>, RankingSort>(
  (ref, sort) => ref.watch(kimchiRepositoryProvider).fetchRanking(sort),
);

/// 종합 랭킹에 내보낼 제품이 있는가. 없으면 첫 화면을 품평회 랭킹으로 돌린다.
/// (DESIGN.md 9.3 콜드 스타트 UX 우회)
final hasRankableProvider = FutureProvider<bool>(
  (ref) => ref.watch(kimchiRepositoryProvider).hasRankableKimchi(),
);

final kimchiDetailProvider = FutureProvider.family<KimchiRanked?, String>(
  (ref, id) => ref.watch(kimchiRepositoryProvider).fetchOne(id),
);

// --- 딜 ---------------------------------------------------------------------

final dealsProvider = FutureProvider.family<List<Deal>, DealSort>(
  (ref, sort) => ref.watch(dealRepositoryProvider).fetchDeals(sort: sort),
);

final kimchiDealsProvider = FutureProvider.family<List<Deal>, String>(
  (ref, kimchiId) =>
      ref.watch(dealRepositoryProvider).fetchDealsForKimchi(kimchiId),
);

final dealDetailProvider = FutureProvider.family<Deal?, String>(
  (ref, dealId) => ref.watch(dealRepositoryProvider).fetchOne(dealId),
);

final myVotedDealsProvider = FutureProvider<Set<String>>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(dealRepositoryProvider).fetchMyVotedDealIds();
});

// --- 리뷰 -------------------------------------------------------------------

final kimchiReviewsProvider = FutureProvider.family<List<Review>, String>(
  (ref, kimchiId) =>
      ref.watch(reviewRepositoryProvider).fetchForKimchi(kimchiId),
);

final myReviewProvider = FutureProvider.family<Review?, String>((ref, kimchiId) {
  ref.watch(currentUserProvider);
  return ref.watch(reviewRepositoryProvider).fetchMine(kimchiId);
});

final myLikedReviewsProvider = FutureProvider.family<Set<String>, String>((
  ref,
  kimchiId,
) {
  ref.watch(currentUserProvider);
  return ref.watch(reviewRepositoryProvider).fetchMyLikedReviewIds(kimchiId);
});

/// 김치 상세에서 리뷰를 쓰거나 지운 뒤, 그 김치에 딸린 화면을 한꺼번에 새로고침
void invalidateKimchi(WidgetRef ref, String kimchiId) {
  ref.invalidate(kimchiDetailProvider(kimchiId));
  ref.invalidate(kimchiReviewsProvider(kimchiId));
  ref.invalidate(myReviewProvider(kimchiId));
  ref.invalidate(hasRankableProvider);
  for (final sort in RankingSort.values) {
    ref.invalidate(rankingProvider(sort));
  }
}

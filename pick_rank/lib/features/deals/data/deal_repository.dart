import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/deal.dart';

enum DealSort {
  hot('인기'),
  recent('최신'),
  cheapest('저렴한 순');

  const DealSort(this.label);
  final String label;
}

class DealRepository {
  DealRepository(this._client);

  final SupabaseClient _client;

  /// 진행 중인 딜만 (목록·인기글용)
  static const _view = 'hot_deals';

  /// 지난 딜까지 포함 (상세용)
  static const _allView = 'deal_items';

  Future<Deal?> fetchOne(String id) async {
    final row = await _client.from(_allView).select().eq('id', id).maybeSingle();
    return row == null ? null : Deal.fromMap(row);
  }

  Future<List<Deal>> fetchDeals({
    DealSort sort = DealSort.hot,
    int limit = 50,
  }) async {
    final filter = _client.from(_view).select();
    final query = switch (sort) {
      DealSort.hot => filter.order('hot_score', ascending: false),
      DealSort.recent => filter.order('created_at', ascending: false),
      DealSort.cheapest => filter.order('price_per_100g', ascending: true),
    };
    final rows = await query.limit(limit);
    return rows.map(Deal.fromMap).toList();
  }

  /// 김치 상세에 붙는 관련 핫딜 (DESIGN.md 10.2 랭킹 → 딜)
  Future<List<Deal>> fetchDealsForKimchi(String kimchiId, {int limit = 5}) async {
    final rows = await _client
        .from(_view)
        .select()
        .eq('kimchi_id', kimchiId)
        .order('price_per_100g', ascending: true)
        .limit(limit);
    return rows.map(Deal.fromMap).toList();
  }

  /// 내가 추천한 딜 id 목록 (버튼 상태 표시용)
  Future<Set<String>> fetchMyVotedDealIds() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return {};
    final rows = await _client
        .from('deal_votes')
        .select('price_post_id')
        .eq('user_id', userId);
    return {for (final row in rows) row['price_post_id'] as String};
  }

  /// self-vote 는 DB(RLS)에서 막는다. 여기서는 토글만 담당.
  Future<void> toggleVote(String dealId, {required bool nowVoted}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('로그인이 필요합니다');

    if (nowVoted) {
      await _client.from('deal_votes').insert({
        'price_post_id': dealId,
        'user_id': userId,
      });
    } else {
      await _client
          .from('deal_votes')
          .delete()
          .eq('price_post_id', dealId)
          .eq('user_id', userId);
    }
  }

  /// view_count 는 사용자 UPDATE 권한에서 빠져 있어 이 RPC 로만 오른다.
  Future<void> incrementView(String dealId) =>
      _client.rpc('increment_deal_view', params: {'p_post_id': dealId});
}

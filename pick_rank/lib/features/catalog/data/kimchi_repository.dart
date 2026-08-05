import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/kimchi_ranked.dart';

/// DESIGN.md 5장 "랭킹별 계산" 의 다섯 가지 정렬
enum RankingSort {
  overall('전체'),
  taste('맛'),
  price('가격'),
  value('가성비'),
  competition('품평회');

  const RankingSort(this.label);
  final String label;
}

class KimchiRepository {
  KimchiRepository(this._client);

  final SupabaseClient _client;

  static const _view = 'kimchi_ranked';

  Future<List<KimchiRanked>> fetchRanking(
    RankingSort sort, {
    int limit = 50,
    String? category,
  }) async {
    var filter = _client.from(_view).select();

    if (category != null) {
      filter = filter.eq('category', category);
    }

    // 정렬별로 "이 랭킹에 낄 자격"이 다르다.
    //  - 만족도를 쓰는 랭킹은 리뷰 임계치를 넘긴 제품만 (DESIGN.md 9.3)
    //  - 가격을 쓰는 랭킹은 진행 중 딜이 있어 가격을 아는 제품만 (5장 엣지 케이스)
    final query = switch (sort) {
      RankingSort.overall => filter
          .eq('is_rankable', true)
          .not('overall_score', 'is', null)
          .order('overall_score', ascending: false),
      RankingSort.taste => filter
          .eq('is_rankable', true)
          .not('satisfaction_score', 'is', null)
          .order('satisfaction_score', ascending: false),
      RankingSort.price => filter
          .not('best_price_per_100g', 'is', null)
          .order('best_price_per_100g', ascending: true),
      RankingSort.value => filter
          .eq('is_rankable', true)
          .not('value_score', 'is', null)
          .order('value_score', ascending: false),
      RankingSort.competition => filter
          .not('competition_award', 'is', null)
          .order('competition_year', ascending: false)
          .order('award_rank', ascending: true),
    };

    final rows = await query.limit(limit);
    return rows.map((row) => KimchiRanked.fromMap(row)).toList();
  }

  Future<KimchiRanked?> fetchOne(String id) async {
    final row = await _client.from(_view).select().eq('id', id).maybeSingle();
    return row == null ? null : KimchiRanked.fromMap(row);
  }

  /// 종합 랭킹에 내보낼 제품이 하나라도 있는가.
  ///
  /// 리뷰가 없는 초기에는 종합 랭킹이 통째로 비므로, 첫 화면을 품평회 랭킹으로
  /// 돌려 볼거리를 준다 (DESIGN.md 9.3 콜드 스타트 UX 우회).
  Future<bool> hasRankableKimchi() async {
    final rows = await _client
        .from(_view)
        .select('id')
        .eq('is_rankable', true)
        .not('overall_score', 'is', null)
        .limit(1);
    return rows.isNotEmpty;
  }

  Future<List<String>> fetchCategories() async {
    final rows = await _client.from('kimchi').select('category');
    final set = <String>{for (final row in rows) row['category'] as String};
    return set.toList()..sort();
  }

  /// Storage 에는 경로만 저장한다 (DESIGN.md 8.1). 표시할 때 URL 을 만든다.
  String? publicImageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    return _client.storage.from('kimchi-images').getPublicUrl(path);
  }
}

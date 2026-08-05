import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/review.dart';

class ReviewRepository {
  ReviewRepository(this._client);

  final SupabaseClient _client;

  Future<List<Review>> fetchForKimchi(String kimchiId, {int limit = 50}) async {
    final rows = await _client
        .from('reviews_with_author')
        .select()
        .eq('kimchi_id', kimchiId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(Review.fromMap).toList();
  }

  /// 1인 1리뷰라 김치당 내 리뷰는 최대 하나다.
  Future<Review?> fetchMine(String kimchiId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final row = await _client
        .from('reviews_with_author')
        .select()
        .eq('kimchi_id', kimchiId)
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? null : Review.fromMap(row);
  }

  /// 1인 1리뷰 + 수정 가능 → upsert 한 방으로 처리한다.
  Future<void> save(ReviewDraft draft) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('로그인이 필요합니다');
    if (!draft.isValid) {
      throw ArgumentError('맛평가 또는 제품평가 중 하나는 입력해야 합니다');
    }

    await _client
        .from('reviews')
        .upsert(draft.toMap(userId), onConflict: 'kimchi_id,user_id');
  }

  Future<void> delete(String reviewId) =>
      _client.from('reviews').delete().eq('id', reviewId);

  Future<Set<String>> fetchMyLikedReviewIds(String kimchiId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return {};

    final rows = await _client
        .from('review_likes')
        .select('review_id, reviews!inner(kimchi_id)')
        .eq('user_id', userId)
        .eq('reviews.kimchi_id', kimchiId);
    return {for (final row in rows) row['review_id'] as String};
  }

  /// 자기 리뷰에 자기가 공감하는 것은 RLS 가 막는다.
  Future<void> toggleLike(String reviewId, {required bool nowLiked}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('로그인이 필요합니다');

    if (nowLiked) {
      await _client.from('review_likes').insert({
        'review_id': reviewId,
        'user_id': userId,
      });
    } else {
      await _client
          .from('review_likes')
          .delete()
          .eq('review_id', reviewId)
          .eq('user_id', userId);
    }
  }
}

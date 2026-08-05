import '../../../core/format.dart';

/// `reviews_with_author` 뷰 한 행.
///
/// 리뷰 하나가 맛평가·제품평가를 각각 또는 함께 담는다 (DESIGN.md 3장).
///   맛평가 했다     = scoreOverall != null
///   제품평가만 했다 = 맛 점수 전부 null + defectTypes 존재
class Review {
  const Review({
    required this.id,
    required this.kimchiId,
    required this.userId,
    required this.scoreOverall,
    required this.scoreSpicy,
    required this.scoreSweet,
    required this.scoreFishiness,
    required this.comment,
    required this.defectTypes,
    required this.defectNote,
    required this.isEvent,
    required this.authorNickname,
    required this.authorTier,
    required this.likeCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String kimchiId;
  final String userId;

  final double? scoreOverall;
  final int? scoreSpicy;
  final int? scoreSweet;
  final int? scoreFishiness;
  final String? comment;

  final List<String> defectTypes;
  final String? defectNote;

  final bool isEvent;
  final String authorNickname;
  final String authorTier;
  final int likeCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasTaste => scoreOverall != null;
  bool get hasDefect => defectTypes.isNotEmpty;
  bool get hasProfile =>
      scoreSpicy != null && scoreSweet != null && scoreFishiness != null;

  String? get tierBadge => switch (authorTier) {
    'ranker' => '랭커',
    'trusted' => '신뢰',
    _ => null,
  };

  factory Review.fromMap(Map<String, dynamic> map) => Review(
    id: map['id'] as String,
    kimchiId: map['kimchi_id'] as String,
    userId: map['user_id'] as String,
    scoreOverall: asDouble(map['score_overall']),
    scoreSpicy: map['score_spicy'] as int?,
    scoreSweet: map['score_sweet'] as int?,
    scoreFishiness: map['score_fishiness'] as int?,
    comment: map['comment'] as String?,
    defectTypes: (map['defect_types'] as List?)?.cast<String>() ?? const [],
    defectNote: map['defect_note'] as String?,
    isEvent: map['is_event'] as bool? ?? false,
    authorNickname: map['author_nickname'] as String? ?? '알 수 없음',
    authorTier: map['author_tier'] as String? ?? 'general',
    likeCount: asInt(map['like_count']),
    createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
  );
}

/// 리뷰 작성 화면이 서버로 보내는 값
class ReviewDraft {
  const ReviewDraft({
    required this.kimchiId,
    this.scoreOverall,
    this.scoreSpicy,
    this.scoreSweet,
    this.scoreFishiness,
    this.comment,
    this.defectTypes = const [],
    this.defectNote,
  });

  final String kimchiId;
  final double? scoreOverall;
  final int? scoreSpicy;
  final int? scoreSweet;
  final int? scoreFishiness;
  final String? comment;
  final List<String> defectTypes;
  final String? defectNote;

  /// 맛평가·제품평가 중 최소 하나는 있어야 한다 (DB CHECK 와 같은 규칙)
  bool get isValid => scoreOverall != null || defectTypes.isNotEmpty;

  Map<String, dynamic> toMap(String userId) => {
    'kimchi_id': kimchiId,
    'user_id': userId,
    'score_overall': scoreOverall,
    'score_spicy': scoreSpicy,
    'score_sweet': scoreSweet,
    'score_fishiness': scoreFishiness,
    'comment': (comment?.trim().isEmpty ?? true) ? null : comment!.trim(),
    'defect_types': defectTypes.isEmpty ? null : defectTypes,
    'defect_note': (defectNote?.trim().isEmpty ?? true) ? null : defectNote!.trim(),
  };
}

import '../../../core/format.dart';

/// `hot_deals` 뷰 한 행 — 진행 중인 딜만 담긴다.
///
/// 딜 랭킹은 평가 랭킹(베이지안)과 완전히 다른 로직이다. 딜은 시효가 생명이라
/// 오래된 글은 추천이 많아도 밀려나야 해서, 시간 감쇠 점수를 쓴다 (DESIGN.md 10.4).
class Deal {
  const Deal({
    required this.id,
    required this.kimchiId,
    required this.kimchiName,
    required this.kimchiBrand,
    required this.kimchiImagePath,
    required this.title,
    required this.body,
    required this.discountInfo,
    required this.price,
    required this.volumeG,
    required this.pricePer100g,
    required this.storeName,
    required this.purchaseUrl,
    required this.purchaseMethod,
    required this.endsAt,
    required this.effectiveStatus,
    required this.upvoteCount,
    required this.commentCount,
    required this.viewCount,
    required this.isOfficial,
    required this.isPromoted,
    required this.hotScore,
    required this.createdAt,
  });

  final String id;
  final String kimchiId;
  final String kimchiName;
  final String kimchiBrand;
  final String? kimchiImagePath;

  final String title;
  final String? body;
  final String? discountInfo;

  final int price;
  final int volumeG;
  final double pricePer100g;

  final String storeName;
  final String? purchaseUrl;
  final String? purchaseMethod;

  final DateTime? endsAt;

  /// 'active' | 'ended' | 'soldout'.
  /// 마감일이 지났으면 status 컬럼이 아직 active 라도 여기서는 ended 로 온다.
  final String effectiveStatus;

  final int upvoteCount;
  final int commentCount;
  final int viewCount;

  /// 운영자 큐레이션 딜 (DESIGN.md 10.6 — 초기 딜 확보 방식)
  final bool isOfficial;

  /// 추천 임계를 넘겨 🔥핫딜로 승격된 상태
  final bool isPromoted;

  final double hotScore;
  final DateTime createdAt;

  String? get remaining => formatRemaining(endsAt);

  bool get isActive => effectiveStatus == 'active';

  String get statusLabel => switch (effectiveStatus) {
    'soldout' => '품절',
    'ended' => '종료된 딜',
    _ => '진행 중',
  };

  factory Deal.fromMap(Map<String, dynamic> map) => Deal(
    id: map['id'] as String,
    kimchiId: map['kimchi_id'] as String,
    kimchiName: map['kimchi_name'] as String? ?? '',
    kimchiBrand: map['kimchi_brand'] as String? ?? '',
    kimchiImagePath: map['kimchi_image_path'] as String?,
    title: map['title'] as String,
    body: map['body'] as String?,
    discountInfo: map['discount_info'] as String?,
    price: asInt(map['price']),
    volumeG: asInt(map['volume_g']),
    pricePer100g: asDouble(map['price_per_100g']) ?? 0,
    storeName: map['store_name'] as String,
    purchaseUrl: map['purchase_url'] as String?,
    purchaseMethod: map['purchase_method'] as String?,
    endsAt: map['ends_at'] == null
        ? null
        : DateTime.parse(map['ends_at'] as String).toLocal(),
    effectiveStatus:
        map['effective_status'] as String? ?? map['status'] as String? ?? 'active',
    upvoteCount: asInt(map['upvote_count']),
    commentCount: asInt(map['comment_count']),
    viewCount: asInt(map['view_count']),
    isOfficial: map['is_official'] as bool? ?? false,
    isPromoted: map['is_promoted'] as bool? ?? false,
    hotScore: asDouble(map['hot_score']) ?? 0,
    createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
  );
}

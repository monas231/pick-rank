import '../../../core/format.dart';

/// `kimchi_ranked` 뷰 한 행.
///
/// 랭킹 점수는 전부 DB에서 계산해 내려온다. 카테고리 내 최저·최고가나
/// 전역 평균 m 처럼 전체 김치를 가로질러야 나오는 값이 섞여 있어서,
/// 한 페이지만 받은 클라이언트에서는 원리적으로 다시 계산할 수 없다.
class KimchiRanked {
  const KimchiRanked({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.imagePath,
    required this.competitionYear,
    required this.competitionAward,
    required this.awardRank,
    required this.tasteReviewCount,
    required this.reviewCountTotal,
    required this.satisfactionScore,
    required this.overallScore,
    required this.valueScore,
    required this.bestPricePer100g,
    required this.activeDealCount,
    required this.defectReportCount,
    required this.defectRate,
    required this.defectBreakdown,
    required this.avgSpicy,
    required this.avgSweet,
    required this.avgFishiness,
    required this.profileSampleCount,
    required this.isRankable,
  });

  final String id;
  final String name;
  final String brand;
  final String category;
  final String? imagePath;

  final int? competitionYear;
  final String? competitionAward;
  final int awardRank;

  /// 맛평가(별점)를 남긴 리뷰 수
  final int tasteReviewCount;

  /// 제품평가만 한 리뷰까지 포함한 전체 리뷰 수 (하자율의 분모)
  final int reviewCountTotal;

  /// 베이지안 보정을 거친 종합 만족도 (1.0~5.0). 랭킹의 기준
  final double? satisfactionScore;

  /// 만족도 0.7 + 가격 0.3. 가격 정보가 없으면 null
  final double? overallScore;
  final double? valueScore;

  final double? bestPricePer100g;
  final int activeDealCount;

  final int defectReportCount;
  final double defectRate;
  final Map<String, int> defectBreakdown;

  final double? avgSpicy;
  final double? avgSweet;
  final double? avgFishiness;
  final int profileSampleCount;

  /// 리뷰가 임계치를 넘겨 종합 랭킹에 노출할 수 있는 상태인가 (DESIGN.md 9.3)
  final bool isRankable;

  bool get hasProfile =>
      avgSpicy != null && avgSweet != null && avgFishiness != null;

  bool get hasAward => competitionAward != null;

  factory KimchiRanked.fromMap(Map<String, dynamic> map) {
    final breakdown = <String, int>{};
    final raw = map['defect_breakdown'];
    if (raw is Map) {
      raw.forEach((key, value) => breakdown[key.toString()] = asInt(value));
    }

    return KimchiRanked(
      id: map['id'] as String,
      name: map['name'] as String,
      brand: map['brand'] as String,
      category: map['category'] as String,
      imagePath: map['image_path'] as String?,
      competitionYear: map['competition_year'] as int?,
      competitionAward: map['competition_award'] as String?,
      awardRank: asInt(map['award_rank'], fallback: 99),
      tasteReviewCount: asInt(map['taste_review_count']),
      reviewCountTotal: asInt(map['review_count_total']),
      satisfactionScore: asDouble(map['satisfaction_score']),
      overallScore: asDouble(map['overall_score']),
      valueScore: asDouble(map['value_score']),
      bestPricePer100g: asDouble(map['best_price_per_100g']),
      activeDealCount: asInt(map['active_deal_count']),
      defectReportCount: asInt(map['defect_report_count']),
      defectRate: asDouble(map['defect_rate']) ?? 0,
      defectBreakdown: breakdown,
      avgSpicy: asDouble(map['avg_spicy']),
      avgSweet: asDouble(map['avg_sweet']),
      avgFishiness: asDouble(map['avg_fishiness']),
      profileSampleCount: asInt(map['profile_sample_count']),
      isRankable: map['is_rankable'] as bool? ?? false,
    );
  }
}

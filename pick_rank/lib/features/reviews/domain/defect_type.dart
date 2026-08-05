/// 하자 유형. DESIGN.md 3.3
///
/// `code` 는 DB(`reviews.defect_types`, `defect_type_meta.code`)와 반드시 같아야 한다.
/// `responsibility` 는 "배송 탓인지 제조 탓인지" 필터를 나중에 붙이기 위한 태그다.
enum DefectType {
  packagingDamage('packaging_damage', '포장 파손 / 국물 누수', '배송/포장'),
  spoilage('spoilage', '변질·상함 (곰팡이, 과발효, 이취)', '제조/유통'),
  foreignObject('foreign_object', '이물질 혼입', '제조'),
  manufacturingDefect('manufacturing_defect', '제조 불량 (양 부족, 상태 불량)', '제조'),
  deliveryIssue('delivery_issue', '배송 문제 (지연, 미온/해동 등)', '배송'),
  other('other', '기타', '-');

  const DefectType(this.code, this.label, this.responsibility);

  final String code;
  final String label;
  final String responsibility;

  static DefectType? fromCode(String code) {
    for (final type in DefectType.values) {
      if (type.code == code) return type;
    }
    return null;
  }

  /// 배지에 쓰는 짧은 이름
  String get shortLabel => switch (this) {
    DefectType.packagingDamage => '포장',
    DefectType.spoilage => '변질',
    DefectType.foreignObject => '이물질',
    DefectType.manufacturingDefect => '제조불량',
    DefectType.deliveryIssue => '배송',
    DefectType.other => '기타',
  };
}

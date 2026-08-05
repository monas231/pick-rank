import 'package:intl/intl.dart';

final _won = NumberFormat('#,###');

String formatWon(num value) => '${_won.format(value)}원';

/// 100g당 가격. 소수점은 의미가 없어 반올림해 보여준다.
String formatPricePer100g(num value) => '100g당 ${_won.format(value.round())}원';

String formatPercent(num ratio, {int digits = 0}) =>
    '${(ratio * 100).toStringAsFixed(digits)}%';

/// 별점 표기 (4.0 → "4.0")
String formatScore(num? score) => score?.toStringAsFixed(1) ?? '-';

String formatRelativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return '방금';
  if (diff.inHours < 1) return '${diff.inMinutes}분 전';
  if (diff.inDays < 1) return '${diff.inHours}시간 전';
  if (diff.inDays < 30) return '${diff.inDays}일 전';
  if (diff.inDays < 365) return '${diff.inDays ~/ 30}개월 전';
  return '${diff.inDays ~/ 365}년 전';
}

/// 마감까지 남은 시간. 이미 지났으면 null
String? formatRemaining(DateTime? endsAt) {
  if (endsAt == null) return null;
  final diff = endsAt.difference(DateTime.now());
  if (diff.isNegative) return null;
  if (diff.inHours < 1) return '${diff.inMinutes}분 남음';
  if (diff.inDays < 1) return '${diff.inHours}시간 남음';
  return '${diff.inDays}일 남음';
}

/// PostgREST 는 numeric 을 숫자로도 문자열로도 돌려줄 수 있다.
double? asDouble(Object? value) => switch (value) {
  null => null,
  num n => n.toDouble(),
  String s => double.tryParse(s),
  _ => null,
};

int asInt(Object? value, {int fallback = 0}) => switch (value) {
  num n => n.toInt(),
  String s => int.tryParse(s) ?? fallback,
  _ => fallback,
};

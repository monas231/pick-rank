import 'package:flutter/material.dart';

/// 별점 표시. DESIGN.md 3.1 — 1.0~5.0, 0.5 단위
class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.score, this.size = 16, this.color});

  final double? score;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final value = score ?? 0;
    final tint = color ?? const Color(0xFFE8A33D);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final filled = value - index;
        final icon = filled >= 1
            ? Icons.star_rounded
            : filled >= 0.5
            ? Icons.star_half_rounded
            : Icons.star_outline_rounded;
        return Icon(icon, size: size, color: tint);
      }),
    );
  }
}

/// 별점 입력. 별 위를 누른 가로 위치로 0.5 단위를 구분한다
/// (별의 왼쪽 절반 = 0.5, 오른쪽 절반 = 1.0).
class StarRatingInput extends StatelessWidget {
  const StarRatingInput({
    super.key,
    required this.score,
    required this.onChanged,
    this.size = 40,
  });

  final double? score;
  final ValueChanged<double> onChanged;
  final double size;

  void _handle(Offset localPosition, double width) {
    final ratio = (localPosition.dx / width).clamp(0.0, 1.0);
    // 0.5 단위로 올림 → 맨 왼쪽을 살짝만 눌러도 최소 0.5
    final raw = (ratio * 10).ceil() / 2;
    onChanged(raw.clamp(0.5, 5.0).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final width = size * 5;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) => _handle(details.localPosition, width),
      onHorizontalDragUpdate: (details) =>
          _handle(details.localPosition, width),
      child: SizedBox(
        width: width,
        height: size,
        child: StarRating(score: score, size: size),
      ),
    );
  }
}

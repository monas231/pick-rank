import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

/// 맛 프로필 삼각형 레이더 차트. DESIGN.md 3.2
///
/// 세 축(매운맛·단맛·젓갈맛)은 "좋고 나쁨"이 아니라 "어떤 맛인지"를 나타낸다.
/// 그래서 이 값들은 랭킹에 쓰이지 않고, 취향 매칭·설명용으로만 그린다.
class TasteRadarChart extends StatelessWidget {
  const TasteRadarChart({
    super.key,
    required this.spicy,
    required this.sweet,
    required this.fishiness,
    this.size = 220,
  });

  /// 1~10
  final double spicy;
  final double sweet;
  final double fishiness;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RadarPainter(
          values: [spicy, sweet, fishiness],
          labels: const ['매운맛', '단맛', '젓갈맛'],
          fill: scheme.primary.withValues(alpha: 0.18),
          stroke: scheme.primary,
          grid: scheme.outlineVariant,
          labelStyle: Theme.of(
            context,
          ).textTheme.labelMedium!.copyWith(color: scheme.onSurfaceVariant),
          valueStyle: Theme.of(context).textTheme.labelSmall!.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.values,
    required this.labels,
    required this.fill,
    required this.stroke,
    required this.grid,
    required this.labelStyle,
    required this.valueStyle,
  });

  final List<double> values;
  final List<String> labels;
  final Color fill;
  final Color stroke;
  final Color grid;
  final TextStyle labelStyle;
  final TextStyle valueStyle;

  static const _max = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // 축 라벨이 들어갈 자리를 바깥에 남긴다
    final radius = math.min(size.width, size.height) / 2 - 30;

    Offset pointAt(int axis, double ratio) {
      final angle = -math.pi / 2 + axis * 2 * math.pi / values.length;
      return center +
          Offset(math.cos(angle), math.sin(angle)) * (radius * ratio);
    }

    // 배경 격자 (25% 간격)
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = grid;

    for (final ratio in const [0.25, 0.5, 0.75, 1.0]) {
      final path = Path();
      for (var i = 0; i < values.length; i++) {
        final point = pointAt(i, ratio);
        i == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path..close(), gridPaint);
    }

    // 축선
    for (var i = 0; i < values.length; i++) {
      canvas.drawLine(center, pointAt(i, 1), gridPaint);
    }

    // 실제 값
    final valuePath = Path();
    for (var i = 0; i < values.length; i++) {
      final ratio = (values[i] / _max).clamp(0.0, 1.0);
      final point = pointAt(i, ratio);
      i == 0
          ? valuePath.moveTo(point.dx, point.dy)
          : valuePath.lineTo(point.dx, point.dy);
    }
    valuePath.close();

    canvas.drawPath(valuePath, Paint()..color = fill);
    canvas.drawPath(
      valuePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = stroke,
    );

    for (var i = 0; i < values.length; i++) {
      final ratio = (values[i] / _max).clamp(0.0, 1.0);
      canvas.drawCircle(pointAt(i, ratio), 3.5, Paint()..color = stroke);
    }

    // 축 이름 + 값
    for (var i = 0; i < values.length; i++) {
      final anchor = pointAt(i, 1.0);
      final direction = (anchor - center);
      final labelCenter = anchor + direction / direction.distance * 20;

      _paintText(
        canvas,
        '${labels[i]}\n${values[i].toStringAsFixed(1)}',
        labelCenter,
        labelStyle,
      );
    }
  }

  void _paintText(Canvas canvas, String text, Offset center, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) =>
      !listEquals(oldDelegate.values, values) ||
      oldDelegate.stroke != stroke ||
      oldDelegate.fill != fill;
}

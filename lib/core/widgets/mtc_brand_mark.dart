import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Vector reproduction of the MTC logo mark (hexagon outline framing a
/// network-style "M" — two nodes fanning up to an apex, converging to a
/// centre joint, then fanning back down to two gold endpoints). Drawn with
/// [CustomPainter] rather than shipped as a raster asset so it stays crisp
/// at any size and can be dropped into both the splash and login screens.
///
/// Colors are the literal brand mark's own palette (teal + gold on a light
/// surface) — deliberately independent from `AppColors`/the app's
/// interactive violet theme, since this is a fixed brand asset, not a
/// themed UI element.
class MtcBrandMark extends StatelessWidget {
  const MtcBrandMark({super.key, this.size = 96});

  final double size;

  static const teal = Color(0xFF0E6E5C);
  static const gold = Color(0xFFF2C230);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _BrandMarkPainter()),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final hexPaint = Paint()
      ..color = MtcBrandMark.teal
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(_hexagonPath(w, h), hexPaint);

    Offset pt(double x, double y) => Offset(w * x, h * y);

    final apex = pt(0.5, 0.20);
    final upperLeft = pt(0.315, 0.335);
    final upperRight = pt(0.685, 0.335);
    final center = pt(0.5, 0.52);
    final goldLeft = pt(0.315, 0.72);
    final goldRight = pt(0.685, 0.72);

    final dashedPaint = Paint()
      ..color = MtcBrandMark.teal
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.014
      ..strokeCap = StrokeCap.round;
    _drawDashedLine(canvas, apex, upperLeft, dashedPaint, w * 0.02, w * 0.018);
    _drawDashedLine(canvas, apex, upperRight, dashedPaint, w * 0.02, w * 0.018);

    final solidPaint = Paint()
      ..color = MtcBrandMark.teal
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.06
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(upperLeft, center, solidPaint);
    canvas.drawLine(upperRight, center, solidPaint);
    canvas.drawLine(center, goldLeft, solidPaint);
    canvas.drawLine(center, goldRight, solidPaint);

    final tealDot = Paint()..color = MtcBrandMark.teal;
    canvas.drawCircle(apex, w * 0.018, tealDot);
    canvas.drawCircle(upperLeft, w * 0.042, tealDot);
    canvas.drawCircle(upperRight, w * 0.042, tealDot);
    canvas.drawCircle(center, w * 0.042, tealDot);

    final goldDot = Paint()..color = MtcBrandMark.gold;
    canvas.drawCircle(goldLeft, w * 0.032, goldDot);
    canvas.drawCircle(goldRight, w * 0.032, goldDot);
  }

  Path _hexagonPath(double w, double h) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = (-90 + i * 60) * math.pi / 180;
      final point = Offset(
        w / 2 + (w / 2) * 0.98 * math.cos(angle),
        h / 2 + (h / 2) * 0.98 * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset from,
    Offset to,
    Paint paint,
    double dashWidth,
    double gapWidth,
  ) {
    final total = (to - from).distance;
    final direction = (to - from) / total;
    var covered = 0.0;
    while (covered < total) {
      final start = from + direction * covered;
      final end = from + direction * math.min(covered + dashWidth, total);
      canvas.drawLine(start, end, paint);
      covered += dashWidth + gapWidth;
    }
  }

  @override
  bool shouldRepaint(covariant _BrandMarkPainter oldDelegate) => false;
}

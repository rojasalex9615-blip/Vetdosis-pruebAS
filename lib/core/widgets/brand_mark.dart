import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Brand mark for VetDosis Pro painted as a vector.
///
/// A rounded square with a light blue/pink/lilac gradient and gloss, a
/// teal-to-blue paw and a white pulse line, matching the launcher icon.
class VetDosisMark extends StatelessWidget {
  const VetDosisMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Logo VetDosis Pro',
    child: SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: const _VetDosisMarkPainter()),
    ),
  );
}

class _VetDosisMarkPainter extends CustomPainter {
  const _VetDosisMarkPainter();

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final s = canvasSize.shortestSide;
    final tile = RRect.fromRectAndRadius(
      Offset.zero & canvasSize,
      Radius.circular(s * 0.24),
    );
    canvas.drawRRect(
      tile,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEAF4FF), Color(0xFFFDF0FA), Color(0xFFEFE7FD)],
          stops: [0, 0.55, 1],
        ).createShader(Offset.zero & canvasSize),
    );
    canvas.drawRRect(
      tile,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x59FFFFFF), Color(0x00FFFFFF)],
        ).createShader(
          Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height * 0.55),
        ),
    );
    final k = (s * 0.58) / 112;
    canvas.save();
    canvas.translate(s / 2 - 60 * k, s / 2 - 69 * k);
    canvas.scale(k);
    final paw = Paint()
      ..shader = const LinearGradient(
        begin: Alignment(-0.4, -1),
        end: Alignment(0.4, 1),
        colors: [Color(0xFF00D2B8), Color(0xFF3B82F6)],
      ).createShader(const Rect.fromLTWH(17, 13, 86, 112));
    final pad = Path()
      ..moveTo(50, 65)
      ..cubicTo(28, 65, 18, 85, 24, 102)
      ..cubicTo(30, 118, 45, 125, 60, 125)
      ..cubicTo(75, 125, 90, 118, 96, 102)
      ..cubicTo(102, 85, 92, 65, 70, 65)
      ..cubicTo(65, 65, 55, 65, 50, 65)
      ..close();
    canvas.drawPath(pad, paw);
    const fingers = [
      (28.0, 46.0, 11.0, 16.0, -25.0),
      (49.0, 30.0, 11.5, 17.0, -8.0),
      (71.0, 30.0, 11.5, 17.0, 8.0),
      (92.0, 46.0, 11.0, 16.0, 25.0),
    ];
    for (final (cx, cy, rx, ry, degrees) in fingers) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(degrees * math.pi / 180);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
        paw,
      );
      canvas.restore();
    }
    final pulse = Path()
      ..moveTo(28, 96)
      ..lineTo(44, 96)
      ..lineTo(50, 82)
      ..lineTo(56, 112)
      ..lineTo(64, 74)
      ..lineTo(70, 102)
      ..lineTo(76, 96)
      ..lineTo(92, 96);
    canvas.drawPath(
      pulse,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'package:flutter/material.dart';

/// "G" multicolor estilo Google, dibujada en código con degradado.
class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key, this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) {
    final bounds = Rect.fromLTWH(0, 0, size, size);
    final foreground = Paint()
      ..shader = const SweepGradient(
        startAngle: -1.5708,
        endAngle: 4.7124,
        colors: [
          Color(0xFF4285F4),
          Color(0xFF34A853),
          Color(0xFFF4B400),
          Color(0xFFEA4335),
          Color(0xFF4285F4),
        ],
      ).createShader(bounds);
    return Text(
      'G',
      style: TextStyle(
        fontSize: size * 1.2,
        height: 1,
        fontWeight: FontWeight.w700,
        foreground: foreground,
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Shared decorative halo, enabled by the neumorphic application theme.
class AccentGlowStyle extends ThemeExtension<AccentGlowStyle> {
  const AccentGlowStyle({this.enabled = false});
  final bool enabled;
  @override
  AccentGlowStyle copyWith({bool? enabled}) =>
      AccentGlowStyle(enabled: enabled ?? this.enabled);
  @override
  AccentGlowStyle lerp(covariant AccentGlowStyle? other, double t) =>
      t < .5 ? this : other ?? this;
}

/// Paint-only halo: does not alter layout, hit targets, text, or semantic states.
class AccentGlow extends StatelessWidget {
  const AccentGlow({
    super.key,
    required this.color,
    required this.child,
    this.radius = 32,
    this.enabled = true,
    this.emphasis = .75,
  });
  final Color color;
  final Widget child;
  final double radius, emphasis;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    if (!enabled ||
        Theme.of(context).extension<AccentGlowStyle>()?.enabled != true) {
      // Keep the child subtree stable if the preview option changes.
      return CustomPaint(child: child);
    }
    final hsl = HSLColor.fromColor(color);
    final luminous = hsl
        .withSaturation(hsl.saturation.clamp(.65, .85))
        .withLightness(.55)
        .toColor();
    return CustomPaint(
      painter: _AccentHalo(luminous, radius, emphasis),
      child: child,
    );
  }
}

class _AccentHalo extends CustomPainter {
  const _AccentHalo(this.color, this.radius, this.emphasis);
  final Color color;
  final double radius, emphasis;
  @override
  void paint(Canvas canvas, Size size) {
    final shape = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas.drawRRect(
      shape.inflate(1),
      Paint()
        ..color = color.withValues(alpha: .18 * emphasis)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawRRect(
      shape,
      Paint()
        ..color = color.withValues(alpha: .10 * emphasis)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }

  @override
  bool shouldRepaint(covariant _AccentHalo old) =>
      old.color != color || old.radius != radius || old.emphasis != emphasis;
}

/// Shared accent icon; neutral/unselected icons keep their original widget.
class AccentIcon extends StatelessWidget {
  const AccentIcon(
    this.icon, {
    super.key,
    this.color,
    this.size,
    this.emphasis = 1,
    this.enabled = true,
  });
  final IconData icon;
  final Color? color;
  final double? size;
  final double emphasis;
  final bool enabled;
  @override
  Widget build(BuildContext context) => AccentGlow(
    color: color ?? Theme.of(context).colorScheme.primary,
    radius: 12,
    emphasis: emphasis,
    enabled: enabled,
    child: Icon(icon, color: color, size: size),
  );
}

/// Retains the chip's key, callbacks and selected/disabled state.
Widget glowChip(Widget chip) =>
    _AccentChip(key: chip.key == null ? null : ValueKey(chip.key), child: chip);

class _AccentChip extends StatelessWidget {
  const _AccentChip({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final selected = switch (child) {
      ChoiceChip chip => chip.selected && chip.onSelected != null,
      FilterChip chip => chip.selected && chip.onSelected != null,
      _ => false,
    };
    return AccentGlow(
      color: Theme.of(context).colorScheme.primary,
      enabled: selected,
      emphasis: .6,
      radius: 16,
      child: child,
    );
  }
}

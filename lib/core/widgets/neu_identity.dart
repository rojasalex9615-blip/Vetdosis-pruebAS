import 'accent_glow.dart';
import 'package:flutter/material.dart';

const neuBackground = Color(0xFFEBECF2);
const neuInk = Color(0xFF17223D);
const neuLavender = Color(0xFF7860B5);
const neuMint = Color(0xFF98E7D9);
const neuLilac = Color(0xFFC5A8EF);

List<BoxShadow> neuShadows(bool dark, {double depth = 1}) => [
  BoxShadow(
    color: dark ? const Color(0x80000000) : const Color(0x80B8BDCE),
    offset: Offset(5 * depth, 5 * depth),
    blurRadius: 16 * depth,
  ),
  BoxShadow(
    color: dark ? const Color(0x402F4053) : const Color(0xF2FFFFFF),
    offset: Offset(-5 * depth, -5 * depth),
    blurRadius: 16 * depth,
  ),
];

/// Paints shallow inner light/shade without changing field layout or hit targets.
class NeuInputBorder extends OutlineInputBorder {
  const NeuInputBorder({
    this.dark = false,
    this.depth = 1,
    super.borderSide = BorderSide.none,
    super.borderRadius = const BorderRadius.all(Radius.circular(24)),
    super.gapPadding = 4,
  });
  final bool dark;
  final double depth;

  @override
  NeuInputBorder copyWith({
    BorderSide? borderSide,
    BorderRadius? borderRadius,
    double? gapPadding,
  }) => NeuInputBorder(
    dark: dark,
    depth: depth,
    borderSide: borderSide ?? this.borderSide,
    borderRadius: borderRadius ?? this.borderRadius,
    gapPadding: gapPadding ?? this.gapPadding,
  );

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0,
    double gapPercentage = 0,
    TextDirection? textDirection,
  }) {
    final shape = borderRadius.toRRect(rect);
    canvas.save();
    canvas.clipRRect(shape);
    for (final entry in [
      (
        Offset(3 * depth, 3 * depth),
        dark ? const Color(0x90000000) : const Color(0x99AEB5C7),
      ),
      (
        Offset(-3 * depth, -3 * depth),
        dark ? const Color(0x503E5063) : Colors.white,
      ),
    ]) {
      final outside = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(rect.inflate(32))
        ..addRRect(shape.shift(entry.$1));
      canvas.drawPath(
        outside,
        Paint()
          ..color = entry.$2
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * depth),
      );
    }
    canvas.restore();
    super.paint(
      canvas,
      rect,
      gapStart: gapStart,
      gapExtent: gapExtent,
      gapPercentage: gapPercentage,
      textDirection: textDirection,
    );
  }
}

class VetDosisBrand extends StatelessWidget {
  const VetDosisBrand({super.key, this.large = false});
  final bool large;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final logo = ClipRRect(
      borderRadius: BorderRadius.circular(large ? 24 : 10),
      child: Image.asset(
        'assets/brand/vetdosis-logo.png',
        width: large ? 136 : 38,
        height: large ? 136 : 38,
        semanticLabel: 'Logo VetDosis Pro',
      ),
    );
    final name = Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'VetDosis '),
          TextSpan(
            text: 'Pro',
            style: TextStyle(color: dark ? neuLilac : neuLavender),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: large ? 30 : 20,
        fontWeight: FontWeight.w700,
        color: dark ? const Color(0xFFE5EAF6) : neuInk,
      ),
    );
    if (large) {
      return Column(
        children: [
          logo,
          const SizedBox(height: 20),
          name,
          const SizedBox(height: 8),
          const Text('Tu espacio veterinario'),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        const SizedBox(width: 10),
        Flexible(child: name),
      ],
    );
  }
}

class NeuPrimaryButton extends StatefulWidget {
  const NeuPrimaryButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.soft = false,
    this.color,
  });
  final VoidCallback? onPressed;
  final Widget child;
  final bool soft;
  final Color? color;
  @override
  State<NeuPrimaryButton> createState() => _NeuPrimaryButtonState();
}

class _NeuPrimaryButtonState extends State<NeuPrimaryButton> {
  final states = WidgetStatesController();
  @override
  void dispose() {
    states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (widget.soft) {
      final color = widget.color ?? (dark ? const Color(0xFF284D4C) : neuMint);
      return ListenableBuilder(
        listenable: states,
        builder: (context, _) {
          final pressed = states.value.contains(WidgetState.pressed);
          return AccentGlow(
            color: color,
            enabled: widget.onPressed != null,
            emphasis: pressed ? .52 : .8,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: pressed
                      ? [
                          color,
                          Color.lerp(color, Colors.white, dark ? .01 : .08)!,
                        ]
                      : [
                          Color.lerp(color, Colors.white, dark ? .06 : .24)!,
                          color,
                        ],
                ),
                boxShadow: widget.onPressed == null
                    ? null
                    : neuShadows(dark, depth: pressed ? .3 : 1.2),
              ),
              child: FilledButton(
                statesController: states,
                style: FilledButton.styleFrom(
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: color.computeLuminance() > .4
                      ? neuInk
                      : Colors.white,
                  minimumSize: const Size(0, 58),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 18,
                  ),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: widget.onPressed,
                child: widget.child,
              ),
            ),
          );
        },
      );
    }
    return AccentGlow(
      color: widget.color ?? neuMint,
      enabled: widget.onPressed != null,
      radius: 26,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: widget.onPressed == null
              ? null
              : neuShadows(Theme.of(context).brightness == Brightness.dark),
          gradient: widget.onPressed == null
              ? null
              : const LinearGradient(colors: [neuMint, neuLilac]),
        ),
        child: FilledButton(
          style: FilledButton.styleFrom(
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: neuInk,
            shadowColor: Colors.transparent,
            minimumSize: const Size(0, 54),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: widget.onPressed,
          child: widget.child,
        ),
      ),
    );
  }
}

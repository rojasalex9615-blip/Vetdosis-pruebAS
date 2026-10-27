import 'package:flutter/material.dart';
import 'neu_identity.dart';
import 'neu_header_card.dart';
import 'workspace_panel.dart';

/// Stable identities shared by the tool selector and its calculation surface.
({Color color, IconData icon}) calculatorIdentity(String id) => switch (id) {
  'dose' => (color: const Color(0xFF087F70), icon: Icons.medication_outlined),
  'concentration' => (
    color: const Color(0xFF37734C),
    icon: Icons.medication_liquid_outlined,
  ),
  'fluids' => (color: const Color(0xFF087B91), icon: Icons.water_drop_outlined),
  'cri' => (color: const Color(0xFF7550AE), icon: Icons.speed_outlined),
  'herd' => (color: const Color(0xFF555CB0), icon: Icons.pets_outlined),
  'water' => (color: const Color(0xFF087E82), icon: Icons.water_outlined),
  'feed' => (color: const Color(0xFF94619B), icon: Icons.grass_outlined),
  'adjustment' => (color: const Color(0xFF9A36AE), icon: Icons.tune),
  'vitals' => (
    color: const Color(0xFF2F7656),
    icon: Icons.monitor_heart_outlined,
  ),
  'metabolic' => (
    color: const Color(0xFF85611F),
    icon: Icons.monitor_weight_outlined,
  ),
  'protocols' => (color: const Color(0xFF985C37), icon: Icons.checklist),
  'ruleOfThree' => (color: const Color(0xFF555CB0), icon: Icons.balance),
  'internationalUnits' => (
    color: const Color(0xFF94619B),
    icon: Icons.vaccines_outlined,
  ),
  'conversion' => (color: const Color(0xFF087B91), icon: Icons.swap_horiz),
  _ => (color: const Color(0xFF7550AE), icon: Icons.schedule),
};

/// Persistent tool colors: independent of the user's global palette.
Color calculatorPastel(String id) => switch (id) {
  'dose' => const Color(0xFFDDF3EC),
  'concentration' => const Color(0xFFE5F1DB),
  'fluids' => const Color(0xFFDDECF9),
  'cri' => const Color(0xFFECE2FA),
  'herd' => const Color(0xFFE1E4F8),
  'water' => const Color(0xFFD8F1F2),
  'feed' => const Color(0xFFF2E0EE),
  'adjustment' => const Color(0xFFF4DEEB),
  'vitals' => const Color(0xFFE4EFD9),
  'metabolic' => const Color(0xFFF4EACF),
  'protocols' => const Color(0xFFF7E4D7),
  'ruleOfThree' => const Color(0xFFE3E5FA),
  'internationalUnits' => const Color(0xFFF1DFF2),
  'conversion' => const Color(0xFFDCEFF7),
  _ => const Color(0xFFE7E8EF),
};

class CalculatorIcon extends StatelessWidget {
  const CalculatorIcon(this.id, {super.key});
  final String id;
  @override
  Widget build(BuildContext context) {
    final identity = calculatorIdentity(id);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = dark
        ? Color.lerp(identity.color, Colors.white, .5)!
        : identity.color;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(identity.icon, color: color, size: 24),
    );
  }
}

class CalculatorSurface extends StatelessWidget {
  const CalculatorSurface({
    super.key,
    required this.id,
    required this.child,
    this.referenceStyle = false,
  });
  final bool referenceStyle;
  final String id;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final dark = base.brightness == Brightness.dark;
    final neu = base.extension<WorkspaceStyle>()?.neumorphic == true;
    final identity = calculatorIdentity(id);
    final accent = dark
        ? Color.lerp(identity.color, Colors.white, .5)!
        : identity.color;
    final surface = Color.lerp(
      base.scaffoldBackgroundColor,
      dark ? identity.color : calculatorPastel(id),
      dark ? .16 : .88,
    )!;
    return Theme(
      data: base.copyWith(
        scaffoldBackgroundColor: surface,
        cardTheme: base.cardTheme.copyWith(
          color: Color.lerp(
            surface,
            dark ? Colors.black : Colors.white,
            dark ? .08 : .45,
          ),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          labelStyle: base.textTheme.bodyMedium?.copyWith(fontSize: 14),
          floatingLabelStyle: base.textTheme.bodySmall?.copyWith(fontSize: 12),
          helperStyle: base.textTheme.bodySmall?.copyWith(fontSize: 12),
          filled: true,
          fillColor: Color.lerp(
            surface,
            dark ? Colors.black : Colors.white,
            referenceStyle ? .02 : .24,
          ),
          contentPadding: referenceStyle
              ? const EdgeInsets.symmetric(horizontal: 22, vertical: 20)
              : base.inputDecorationTheme.contentPadding,
          border: neu
              ? NeuInputBorder(dark: dark, depth: referenceStyle ? 1.8 : 1)
              : null,
          enabledBorder: neu
              ? NeuInputBorder(dark: dark, depth: referenceStyle ? 1.8 : 1)
              : null,
          focusedBorder: referenceStyle
              ? NeuInputBorder(
                  dark: dark,
                  depth: 1.8,
                  borderSide: BorderSide(color: accent, width: 1.5),
                )
              : base.inputDecorationTheme.focusedBorder,
          errorBorder: referenceStyle
              ? NeuInputBorder(
                  dark: dark,
                  depth: 1.8,
                  borderSide: BorderSide(
                    color: base.colorScheme.error,
                    width: 1.5,
                  ),
                )
              : base.inputDecorationTheme.errorBorder,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: dark ? const Color(0xFF101A28) : Colors.white,
            minimumSize: const Size(0, 52),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      child: Container(
        padding: EdgeInsets.all(referenceStyle ? 22 : 20),
        margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: surface,
          gradient: neu
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(surface, Colors.white, dark ? .025 : .25)!,
                    surface,
                  ],
                )
              : null,
          border: Border.all(
            color: dark
                ? accent.withValues(alpha: .22)
                : Colors.white.withValues(alpha: .75),
          ),
          borderRadius: BorderRadius.circular(referenceStyle ? 36 : 24),
          boxShadow: neu
              ? neuShadows(dark, depth: referenceStyle ? 1.6 : 1)
              : null,
        ),
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}

/// A visible title and icon keep identity understandable without color alone.
class CalculatorHeading extends StatelessWidget {
  const CalculatorHeading({super.key, required this.id, required this.title});
  final String id, title;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
      ),
      const SizedBox(width: 12),
      CalculatorIcon(id),
    ],
  );
}

/// Keep captured units readable on narrow forms even when the floating label truncates.
String? calculatorUnitHint(String label) {
  final unit = RegExp(r'\(([^)]+)\)').firstMatch(label)?.group(1);
  return unit == null ? null : 'Unidad: $unit';
}

/// Keeps the selector label outside its field so it never overlaps the value.
class CalculatorSelectorCard extends StatelessWidget {
  const CalculatorSelectorCard({
    super.key,
    required this.id,
    required this.title,
    required this.child,
    this.referenceStyle = false,
  });
  final bool referenceStyle;
  final String id, title;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final identity = calculatorIdentity(id);
    if (referenceStyle) {
      return NeuHeaderCard(
        title: title,
        icon: identity.icon,
        color: identity.color,
        soft: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
          child: child,
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: dark
            ? theme.colorScheme.surface
            : Colors.white.withValues(alpha: .65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: identity.color.withValues(alpha: .3)),
        boxShadow: theme.extension<WorkspaceStyle>()?.neumorphic == true
            ? neuShadows(dark)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: identity.color,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(identity.icon, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
      ),
    );
  }
}

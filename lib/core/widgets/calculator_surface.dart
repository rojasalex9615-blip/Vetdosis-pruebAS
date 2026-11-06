import 'accent_glow.dart';
import 'contrast.dart';

import 'package:flutter/material.dart';

import 'neu_identity.dart';
import 'neu_header_card.dart';
import 'workspace_panel.dart';

/// Stable identities shared by the tool selector and its calculation surface.
({Color color, IconData icon}) calculatorIdentity(String id) => switch (id) {
  'dose' => (color: const Color(0xFF7BEADC), icon: Icons.medication_outlined),
  'concentration' => (
    color: const Color(0xFF7BD8EA),
    icon: Icons.medication_liquid_outlined,
  ),
  'withdrawals' => (color: const Color(0xFFAE9ACB), icon: Icons.schedule),
  'manufacturer' => (
    color: const Color(0xFF8DADD8),
    icon: Icons.medication_liquid_outlined,
  ),
  'aviculture' => (
    color: const Color(0xFF7BCFEA),
    icon: Icons.agriculture_outlined,
  ),
  'incubation' => (color: const Color(0xFFAA94D1), icon: Icons.egg_outlined),
  'fluids' => (color: const Color(0xFF7BD8EA), icon: Icons.water_drop_outlined),
  'cri' => (color: const Color(0xFFAC96CF), icon: Icons.speed_outlined),
  'herd' => (color: const Color(0xFF979BCE), icon: Icons.pets_outlined),
  'water' => (color: const Color(0xFF7BE6EA), icon: Icons.water_outlined),
  'feed' => (color: const Color(0xFFC0A1C4), icon: Icons.grass_outlined),
  'adjustment' => (color: const Color(0xFFCD8ADB), icon: Icons.tune),
  'vitals' => (
    color: const Color(0xFF7BD3EA),
    icon: Icons.monitor_heart_outlined,
  ),
  'metabolic' => (
    color: const Color(0xFFA098CD),
    icon: Icons.monitor_weight_outlined,
  ),
  'protocols' => (color: const Color(0xFF96A3CF), icon: Icons.checklist),
  'ruleOfThree' => (color: const Color(0xFF979BCE), icon: Icons.balance),
  'internationalUnits' => (
    color: const Color(0xFFC0A1C4),
    icon: Icons.vaccines_outlined,
  ),
  'conversion' => (color: const Color(0xFF7BD8EA), icon: Icons.swap_horiz),
  _ => (color: const Color(0xFFAC96CF), icon: Icons.schedule),
};

/// Persistent tool colors: independent of the user's global palette.
Color calculatorPastel(String id) => switch (id) {
  'dose' => const Color(0xFFDDF3EC),
  'concentration' => const Color(0xFFDDF2F8),
  'withdrawals' => const Color(0xFFE8DEF5),
  'manufacturer' => const Color(0xFFE1EBFB),
  'aviculture' => const Color(0xFFDDF1FC),
  'incubation' => const Color(0xFFECE0FA),
  'fluids' => const Color(0xFFDDECF9),
  'cri' => const Color(0xFFECE2FA),
  'herd' => const Color(0xFFE1E4F8),
  'water' => const Color(0xFFD8F1F2),
  'feed' => const Color(0xFFEEE4FC),
  'adjustment' => const Color(0xFFEADAF8),
  'vitals' => const Color(0xFFD8F0FC),
  'metabolic' => const Color(0xFFE5E2FC),
  'protocols' => const Color(0xFFDAE9FA),
  'ruleOfThree' => const Color(0xFFE3E5FA),
  'internationalUnits' => const Color(0xFFEFE1FA),
  'conversion' => const Color(0xFFDCEFF7),
  _ => const Color(0xFFE7E8EF),
};

/// Color de la calculadora tal como se eligio, igual en claro y en oscuro.
///
/// El tono identifica a cada calculadora y va a juego con su icono, asi que no
/// se cambia por tema. Lo unico que se corrige es la legibilidad: sobre el
/// fondo grafito unos pocos tonos quedan por debajo del minimo de 3:1 que pide
/// WCAG para iconos y componentes, y se aclaran lo justo para alcanzarlo, que
/// resulta ser entre un 2% y un 6%. Antes se aclaraban todos un 50%, que si
/// alteraba la identidad y era innecesario: la mayoria ya pasaba de sobra.
Color calculatorAccent(Color identity, Color background) =>
    readableOn(identity, background);

/// Insignia de una calculadora: su icono sobre una placa de su propio color.
///
/// El color identifica a la calculadora y es el mismo en claro y en oscuro;
/// solo se retoca si no se distinguiria sobre la placa.
class CalculatorIcon extends StatelessWidget {
  const CalculatorIcon(this.id, {super.key});
  final String id;
  @override
  Widget build(BuildContext context) {
    final identity = calculatorIdentity(id);
    // El glifo no se pinta sobre el lienzo sino sobre una placa tenida con su
    // propio color, que aclara el fondo. Se compone primero esa placa y el
    // contraste se mide contra ella.
    // La placa se tine al 35%, no al 10%. Con los tonos cargados de antes un
    // 10% ya se notaba; con la paleta palida que pidio Ale ese 10% dejaba la
    // placa indistinguible del fondo y el icono parecia flotar suelto.
    final placa = composite(
      identity.color,
      .35,
      Theme.of(context).scaffoldBackgroundColor,
    );
    final color = calculatorAccent(identity.color, placa);
    return AccentGlow(
      color: color,
      radius: 12,
      emphasis: 1, // Preserve the badge glow approved by Ale.
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: placa,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(identity.icon, color: color, size: 24),
      ),
    );
  }
}

/// Envoltura de una calculadora, con el color que la identifica aplicado al
/// fondo, al borde y al boton principal.
///
/// Sustituye el tema para su contenido, de modo que los campos y botones de
/// dentro salen ya con el tono de esa calculadora sin configurarlos uno a uno.
class CalculatorSurface extends StatelessWidget {
  const CalculatorSurface({
    super.key,
    required this.id,
    required this.child,
    this.referenceStyle = true,
  });
  final bool referenceStyle;
  final String id;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final dark = base.brightness == Brightness.dark;
    final neu = base.extension<WorkspaceStyle>()?.neumorphic == true;
    final referenceStyle = this.referenceStyle && neu;
    final identity = calculatorIdentity(id);
    final surface = Color.lerp(
      base.scaffoldBackgroundColor,
      dark ? identity.color : calculatorPastel(id),
      dark ? .16 : .88,
    )!;
    final accent = calculatorAccent(identity.color, surface);
    return Theme(
      data: base.copyWith(
        scaffoldBackgroundColor: surface,
        cardTheme: base.cardTheme.copyWith(
          color: Color.lerp(
            surface,
            dark ? Colors.black : Colors.white,
            dark ? .08 : .45,
          ),
          elevation: referenceStyle ? 5 : 0,
          shadowColor: dark ? Colors.black54 : const Color(0x809AA9BB),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(referenceStyle ? 32 : 20),
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
              ? NeuInputBorder(dark: dark, depth: referenceStyle ? 1.2 : 1)
              : null,
          enabledBorder: neu
              ? NeuInputBorder(dark: dark, depth: referenceStyle ? 1.2 : 1)
              : null,
          focusedBorder: referenceStyle
              ? NeuInputBorder(
                  dark: dark,
                  depth: 1.2,
                  borderSide: BorderSide(color: accent, width: 1.5),
                )
              : base.inputDecorationTheme.focusedBorder,
          errorBorder: referenceStyle
              ? NeuInputBorder(
                  dark: dark,
                  depth: 1.2,
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
            // La tinta se elige midiendo contra el acento ya ajustado. Fijar
            // blanco dejaba el peor caso en 4.51:1, justo en el limite de
            // 4.5:1 que pide el texto: cualquier retoque posterior lo rompia.
            foregroundColor: inkOn(accent),
            minimumSize: Size(0, referenceStyle ? 58 : 52),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(referenceStyle ? 32 : 16),
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
    this.referenceStyle = true,
  });
  final bool referenceStyle;
  final String id, title;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final identity = calculatorIdentity(id);
    if (referenceStyle &&
        theme.extension<WorkspaceStyle>()?.neumorphic == true) {
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

/// Common calculator action: the approved pill in Neu, Material in standard style.
class CalculatorActionButton extends StatelessWidget {
  const CalculatorActionButton({
    super.key,
    required this.id,
    required this.onPressed,
    required this.child,
  });
  CalculatorActionButton.icon({
    super.key,
    required this.id,
    required this.onPressed,
    required Widget icon,
    required Widget label,
  }) : child = Row(
         mainAxisSize: MainAxisSize.min,
         children: [
           icon,
           const SizedBox(width: 10),
           Flexible(child: label),
         ],
       );
  final String id;
  final VoidCallback? onPressed;
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      Theme.of(context).extension<WorkspaceStyle>()?.neumorphic == true
      ? NeuPrimaryButton(
          soft: true,
          color: Theme.of(context).brightness == Brightness.dark
              ? Color.lerp(
                  Theme.of(context).scaffoldBackgroundColor,
                  calculatorIdentity(id).color,
                  .25,
                )!
              : calculatorPastel(id),
          onPressed: onPressed,
          child: DefaultTextStyle.merge(
            textAlign: TextAlign.center,
            child: child,
          ),
        )
      : FilledButton(onPressed: onPressed, child: child);
}

/// Multiline labels remain outside the inset surface at narrow widths.
class CalculatorFieldLabel extends StatelessWidget {
  const CalculatorFieldLabel({
    super.key,
    required this.label,
    required this.child,
  });
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
        child: Text(
          label.replaceFirst(RegExp(r'\s*\([^)]+\)'), ''),
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      Semantics(label: label, child: child),
    ],
  );
}

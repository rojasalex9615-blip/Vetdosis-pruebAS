import 'package:flutter/material.dart';

/// Identidad cromática consolidada de los HTML de Stitch. Sin dependencias web.
abstract final class VetColors {
  static const canvas = Color(0xFFF1F4F8);
  static const surface = Color(0xFFF7F9FC);
  static const raised = Color(0xFFFFFFFF);
  static const recessed = Color(0xFFEDF2F7);
  static const softShadow = Color(0xFFDDE4EE);
  static const ink = Color(0xFF0B1C30);
  static const muted = Color(0xFF5A6A7E);
  static const onDarkMuted = Color(0xFFA9BACB);
  static const turquoise = Color(0xFF28D7D1);
  static const cyan = Color(0xFF49DFF0);
  static const mint = Color(0xFF61E2D0);
  static const lavender = Color(0xFFC8B5F6);
  static const lilac = Color(0xFFAE92F3);
  static const violet = Color(0xFF7D7AF2);
  static const purple = Color(0xFF7C4DFF);
  static const purpleDeep = Color(0xFF632CE5);
  static const pink = Color(0xFFFF4FB3);
  // Semánticos: NO usar el rosa decorativo como alerta médica por defecto.
  static const danger = Color(0xFFB42318);
  static const warning = Color(0xFF9A6700);
  static const success = Color(0xFF087F5B);
}

/// Sistema tipográfico y de componentes compartido.
///
/// `refine` se aplica sobre el `ThemeData` que ya eligió la app (paletas,
/// neumorfismo, modo claro/oscuro) para que todas las pantallas hereden la
/// misma jerarquía visual, etiquetas legibles y áreas táctiles de 48 px sin
/// reemplazar los colores de marca definidos por el usuario.
abstract final class VetTheme {
  static const double minTapTarget = 48;

  static ThemeData light() => refine(
    ThemeData(
      useMaterial3: true,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: VetColors.purple,
            brightness: Brightness.light,
            surface: VetColors.surface,
          ).copyWith(
            primary: VetColors.purple,
            onPrimary: Colors.white,
            secondary: VetColors.turquoise,
            onSecondary: VetColors.ink,
            error: VetColors.danger,
            surface: VetColors.surface,
            onSurface: VetColors.ink,
          ),
      scaffoldBackgroundColor: VetColors.canvas,
      fontFamily:
          null, // Cargar Plus Jakarta Sans como recurso local si se dispone de ella.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: VetColors.recessed,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: VetColors.softShadow),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: VetColors.softShadow),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: VetColors.purple, width: 2),
        ),
      ),
    ),
  );

  /// Aplica tipografía y temas de componentes conservando la paleta recibida.
  static ThemeData refine(ThemeData base) {
    final scheme = base.colorScheme;
    final dark = base.brightness == Brightness.dark;
    final onSurface = scheme.onSurface;
    final muted = dark ? VetColors.onDarkMuted : VetColors.muted;
    final text = _textTheme(onSurface, muted);
    final outline = scheme.outline;
    final subtle = scheme.outlineVariant;
    final stadium = const StadiumBorder();
    final fieldFill = base.inputDecorationTheme.fillColor;

    return base.copyWith(
      textTheme: text,
      primaryTextTheme: text.apply(
        bodyColor: scheme.onPrimary,
        displayColor: scheme.onPrimary,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: dark ? Colors.black : VetColors.softShadow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: subtle),
        ),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: text.titleSmall!.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
        subtitleTextStyle: text.bodySmall!,
        leadingAndTrailingTextStyle: text.labelMedium,
        iconColor: muted,
        minVerticalPadding: 6,
        minLeadingWidth: 28,
        horizontalTitleGap: 12,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _buttonStyle(text.labelLarge!, stadium),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _buttonStyle(text.labelLarge!, stadium).copyWith(
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.disabled)
                  ? subtle
                  : outline,
              width: 1.3,
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: _buttonStyle(
          text.labelLarge!,
          stadium,
        ).copyWith(minimumSize: const WidgetStatePropertyAll(Size(48, 44))),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          iconSize: const WidgetStatePropertyAll(22),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(11)),
          visualDensity: VisualDensity.standard,
        ),
      ),
      floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
        shape: const StadiumBorder(),
        elevation: 3,
        focusElevation: 4,
        highlightElevation: 5,
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        labelStyle: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: muted,
        ),
        floatingLabelStyle: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: scheme.primary,
          backgroundColor: fieldFill,
        ),
        hintStyle: TextStyle(fontSize: 15, height: 1.4, color: muted),
        helperStyle: TextStyle(fontSize: 12.5, height: 1.35, color: muted),
        helperMaxLines: 3,
        errorStyle: TextStyle(
          fontSize: 12.5,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: scheme.error,
        ),
        errorMaxLines: 3,
        prefixIconColor: muted,
        suffixIconColor: muted,
        iconColor: muted,
      ),
      chipTheme: base.chipTheme.copyWith(
        labelStyle: text.labelMedium!.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        backgroundColor: scheme.surface,
        selectedColor: scheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        side: BorderSide(color: subtle),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: subtle),
        ),
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        backgroundColor: base.navigationBarTheme.backgroundColor ?? scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            height: 1.2,
            letterSpacing: .2,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? scheme.primary : muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : muted,
          ),
        ),
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: base.appBarTheme.backgroundColor ?? scheme.surface,
        foregroundColor: base.appBarTheme.foregroundColor ?? onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleSpacing: base.appBarTheme.titleSpacing ?? 16,
        titleTextStyle: text.titleLarge!.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
        iconTheme: IconThemeData(color: onSurface, size: 24),
        actionsIconTheme: IconThemeData(color: onSurface, size: 24),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: text.titleLarge!.copyWith(fontSize: 20),
        contentTextStyle: text.bodyMedium!.copyWith(height: 1.5),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xFF223141) : VetColors.ink,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          height: 1.4,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: dark ? VetColors.mint : VetColors.mint,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.all(16),
        elevation: 2,
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12.5,
          height: 1.3,
          fontWeight: FontWeight.w500,
        ),
        decoration: BoxDecoration(
          color: VetColors.ink,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        waitDuration: const Duration(milliseconds: 450),
      ),
      dividerTheme: DividerThemeData(
        color: subtle,
        thickness: 1,
        space: 1,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: .22),
        selectionHandleColor: scheme.primary,
      ),
      checkboxTheme: CheckboxThemeData(
        materialTapTargetSize: MaterialTapTargetSize.padded,
        visualDensity: VisualDensity.standard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: const RadioThemeData(
        materialTapTargetSize: MaterialTapTargetSize.padded,
        visualDensity: VisualDensity.standard,
      ),
      switchTheme: const SwitchThemeData(
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(
            text.labelMedium!.copyWith(fontWeight: FontWeight.w700),
          ),
          minimumSize: const WidgetStatePropertyAll(Size(48, 44)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          visualDensity: VisualDensity.standard,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: subtle,
        circularTrackColor: subtle,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: text.bodyMedium,
      ),
      expansionTileTheme: ExpansionTileThemeData(
        textColor: onSurface,
        collapsedTextColor: onSurface,
        iconColor: muted,
        collapsedIconColor: muted,
        childrenPadding: const EdgeInsets.only(bottom: 4),
      ),
      iconTheme: IconThemeData(color: onSurface, size: 24),
      primaryIconTheme: IconThemeData(color: onSurface, size: 24),
    );
  }

  static ButtonStyle _buttonStyle(TextStyle label, OutlinedBorder shape) =>
      ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(64, minTapTarget)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
        textStyle: WidgetStatePropertyAll(
          label.copyWith(letterSpacing: .1, height: 1.15),
        ),
        shape: WidgetStatePropertyAll(shape),
        iconSize: const WidgetStatePropertyAll(20),
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.padded,
      );

  static TextTheme _textTheme(Color onSurface, Color muted) => TextTheme(
    displaySmall: TextStyle(
      fontSize: 30,
      height: 1.15,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.6,
      color: onSurface,
    ),
    headlineMedium: TextStyle(
      fontSize: 26,
      height: 1.2,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
      color: onSurface,
    ),
    headlineSmall: TextStyle(
      fontSize: 23,
      height: 1.25,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
      color: onSurface,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      height: 1.25,
      fontWeight: FontWeight.w800,
      color: onSurface,
    ),
    titleMedium: TextStyle(
      fontSize: 17,
      height: 1.3,
      fontWeight: FontWeight.w700,
      color: onSurface,
    ),
    titleSmall: TextStyle(
      fontSize: 14.5,
      height: 1.3,
      fontWeight: FontWeight.w700,
      color: onSurface,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: onSurface),
    bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: onSurface),
    bodySmall: TextStyle(
      fontSize: 12.5,
      height: 1.4,
      fontWeight: FontWeight.w500,
      color: muted,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      height: 1.15,
      fontWeight: FontWeight.w700,
      letterSpacing: .1,
      color: onSurface,
    ),
    labelMedium: TextStyle(
      fontSize: 12.5,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: .2,
      color: muted,
    ),
    labelSmall: TextStyle(
      fontSize: 11.5,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: .3,
      color: muted,
    ),
  );
}

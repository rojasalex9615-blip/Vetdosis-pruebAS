import 'package:flutter/material.dart';

/// Identidad cromática consolidada de los HTML de Stitch. Sin dependencias web.
abstract final class VetColors {
  static const canvas = Color(0xFFF1F4F8);
  static const surface = Color(0xFFF7F9FC);
  static const raised = Color(0xFFFFFFFF);
  static const recessed = Color(0xFFEDF2F7);
  static const softShadow = Color(0xFFDDE4EE);
  static const ink = Color(0xFF0B1C30);
  static const muted = Color(0xFF64748B);
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

/// Espaciado y radios consistentes para toda la app.
abstract final class VetSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;

  static const radiusSm = 12.0;
  static const radiusMd = 16.0;
  static const radiusLg = 20.0;
  static const radiusXl = 24.0;
  static const radiusFull = 999.0;
}

/// Tipografía profesional consistente para toda la app.
abstract final class VetTypography {
  // Display / Headlines
  static const displayLarge = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w800,
    height: 1.15,
    letterSpacing: -0.5,
    color: VetColors.ink,
  );
  static const displayMedium = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: -0.3,
    color: VetColors.ink,
  );
  static const displaySmall = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1.25,
    color: VetColors.ink,
  );

  // Titles
  static const headlineLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    height: 1.3,
    color: VetColors.ink,
  );
  static const headlineMedium = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: VetColors.ink,
  );
  static const headlineSmall = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 1.35,
    color: VetColors.ink,
  );

  // Body
  static const titleLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: VetColors.ink,
  );
  static const titleMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: VetColors.ink,
  );
  static const titleSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: VetColors.ink,
  );

  static const bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: VetColors.ink,
  );
  static const bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: VetColors.ink,
  );
  static const bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: VetColors.muted,
  );

  // Labels / Utility
  static const labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: VetColors.ink,
  );
  static const labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: VetColors.ink,
  );
  static const labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: VetColors.muted,
  );
}

abstract final class VetTheme {
  static ThemeData light() {
    final colors =
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
          outlineVariant: VetColors.softShadow,
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: VetColors.canvas,
      fontFamily:
          null, // Cargar Plus Jakarta Sans como recurso local si se dispone de ella.
      textTheme: const TextTheme(
        // Display
        displayLarge: VetTypography.displayLarge,
        displayMedium: VetTypography.displayMedium,
        displaySmall: VetTypography.displaySmall,
        // Headlines
        headlineLarge: VetTypography.headlineLarge,
        headlineMedium: VetTypography.headlineMedium,
        headlineSmall: VetTypography.headlineSmall,
        // Titles
        titleLarge: VetTypography.titleLarge,
        titleMedium: VetTypography.titleMedium,
        titleSmall: VetTypography.titleSmall,
        // Body
        bodyLarge: VetTypography.bodyLarge,
        bodyMedium: VetTypography.bodyMedium,
        bodySmall: VetTypography.bodySmall,
        // Labels
        labelLarge: VetTypography.labelLarge,
        labelMedium: VetTypography.labelMedium,
        labelSmall: VetTypography.labelSmall,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: VetColors.recessed,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: VetSpacing.lg,
          vertical: VetSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VetSpacing.radiusMd),
          borderSide: const BorderSide(color: VetColors.softShadow),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VetSpacing.radiusMd),
          borderSide: const BorderSide(color: VetColors.softShadow),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VetSpacing.radiusMd),
          borderSide: const BorderSide(color: VetColors.purple, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VetSpacing.radiusMd),
          borderSide: const BorderSide(color: VetColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VetSpacing.radiusMd),
          borderSide: const BorderSide(color: VetColors.danger, width: 2),
        ),
        labelStyle: VetTypography.bodyMedium.copyWith(color: VetColors.muted),
        hintStyle: VetTypography.bodyMedium.copyWith(color: VetColors.muted),
        floatingLabelStyle: VetTypography.labelMedium.copyWith(color: VetColors.purple),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: VetColors.raised,
        indicatorColor: VetColors.lavender.withValues(alpha: .35),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        color: VetColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: VetSpacing.xs, horizontal: VetSpacing.xs),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VetSpacing.radiusLg),
          side: const BorderSide(color: VetColors.softShadow),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VetSpacing.radiusFull),
          side: const BorderSide(color: VetColors.softShadow),
        ),
        labelStyle: VetTypography.labelMedium,
        side: const BorderSide(color: VetColors.softShadow),
        backgroundColor: VetColors.surface,
        selectedColor: VetColors.lavender.withValues(alpha: .35),
        checkmarkColor: VetColors.purple,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: VetSpacing.lg, vertical: VetSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VetSpacing.radiusMd),
          ),
          textStyle: VetTypography.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: VetSpacing.lg, vertical: VetSpacing.md),
          shape: const StadiumBorder(),
          textStyle: VetTypography.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: VetSpacing.lg, vertical: VetSpacing.md),
          shape: const StadiumBorder(),
          side: const BorderSide(color: VetColors.softShadow),
          textStyle: VetTypography.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: VetSpacing.md, vertical: VetSpacing.sm),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VetSpacing.radiusMd),
          ),
          textStyle: VetTypography.labelMedium,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: VetColors.softShadow,
        thickness: 1,
        space: VetSpacing.xxl,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: VetSpacing.lg,
          vertical: VetSpacing.xs,
        ),
        titleTextStyle: VetTypography.bodyLarge,
        subtitleTextStyle: VetTypography.bodySmall,
        leadingAndTrailingTextStyle: VetTypography.bodySmall,
      ),
    );
  }

  static ThemeData dark() {
    final colors =
        ColorScheme.fromSeed(
          seedColor: VetColors.purple,
          brightness: Brightness.dark,
          surface: const Color(0xFF131E2A),
        ).copyWith(
          primary: const Color(0xFF55E2D3),
          onPrimary: const Color(0xFF062321),
          secondary: const Color(0xFFB69BFF),
          error: const Color(0xFFEF5350),
          surface: const Color(0xFF131E2A),
          onSurface: const Color(0xFFF1F4F8),
          outlineVariant: const Color(0xFF2A3A4B),
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: const Color(0xFF0B121C),
      fontFamily: null,
      textTheme: TextTheme(
        displayLarge: VetTypography.displayLarge.copyWith(color: colors.onSurface),
        displayMedium: VetTypography.displayMedium.copyWith(color: colors.onSurface),
        displaySmall: VetTypography.displaySmall.copyWith(color: colors.onSurface),
        headlineLarge: VetTypography.headlineLarge.copyWith(color: colors.onSurface),
        headlineMedium: VetTypography.headlineMedium.copyWith(color: colors.onSurface),
        headlineSmall: VetTypography.headlineSmall.copyWith(color: colors.onSurface),
        titleLarge: VetTypography.titleLarge.copyWith(color: colors.onSurface),
        titleMedium: VetTypography.titleMedium.copyWith(color: colors.onSurface),
        titleSmall: VetTypography.titleSmall.copyWith(color: colors.onSurface),
        bodyLarge: VetTypography.bodyLarge.copyWith(color: colors.onSurface),
        bodyMedium: VetTypography.bodyMedium.copyWith(color: colors.onSurface),
        bodySmall: VetTypography.bodySmall.copyWith(color: colors.onSurfaceVariant),
        labelLarge: VetTypography.labelLarge.copyWith(color: colors.onSurface),
        labelMedium: VetTypography.labelMedium.copyWith(color: colors.onSurface),
        labelSmall: VetTypography.labelSmall.copyWith(color: colors.onSurfaceVariant),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1A2635),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: VetSpacing.lg,
          vertical: VetSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VetSpacing.radiusMd),
          borderSide: const BorderSide(color: Color(0xFF2A3A4B)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VetSpacing.radiusMd),
          borderSide: const BorderSide(color: Color(0xFF2A3A4B)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VetSpacing.radiusMd),
          borderSide: const BorderSide(color: Color(0xFF55E2D3), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VetSpacing.radiusMd),
          borderSide: const BorderSide(color: Color(0xFFEF5350)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VetSpacing.radiusMd),
          borderSide: const BorderSide(color: Color(0xFFEF5350), width: 2),
        ),
        labelStyle: VetTypography.bodyMedium.copyWith(color: colors.onSurfaceVariant),
        hintStyle: VetTypography.bodyMedium.copyWith(color: colors.onSurfaceVariant),
        floatingLabelStyle: VetTypography.labelMedium.copyWith(color: Color(0xFF55E2D3)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF131E2A),
        indicatorColor: const Color(0xFF55E2D3).withValues(alpha: .22),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF131E2A),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: VetSpacing.xs, horizontal: VetSpacing.xs),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VetSpacing.radiusLg),
          side: const BorderSide(color: Color(0xFF2A3A4B)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VetSpacing.radiusFull),
          side: const BorderSide(color: Color(0xFF2A3A4B)),
        ),
        labelStyle: VetTypography.labelMedium.copyWith(color: colors.onSurface),
        side: const BorderSide(color: Color(0xFF2A3A4B)),
        backgroundColor: const Color(0xFF131E2A),
        selectedColor: const Color(0xFF55E2D3).withValues(alpha: .22),
        checkmarkColor: Color(0xFF55E2D3),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: VetSpacing.lg, vertical: VetSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VetSpacing.radiusMd),
          ),
          textStyle: VetTypography.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: VetSpacing.lg, vertical: VetSpacing.md),
          shape: const StadiumBorder(),
          textStyle: VetTypography.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: VetSpacing.lg, vertical: VetSpacing.md),
          shape: const StadiumBorder(),
          side: const BorderSide(color: Color(0xFF2A3A4B)),
          textStyle: VetTypography.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: VetSpacing.md, vertical: VetSpacing.sm),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VetSpacing.radiusMd),
          ),
          textStyle: VetTypography.labelMedium,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: const Color(0xFF2A3A4B),
        thickness: 1,
        space: VetSpacing.xxl,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: VetSpacing.lg,
          vertical: VetSpacing.xs,
        ),
        titleTextStyle: VetTypography.bodyLarge.copyWith(color: colors.onSurface),
        subtitleTextStyle: VetTypography.bodySmall.copyWith(color: colors.onSurfaceVariant),
        leadingAndTrailingTextStyle: VetTypography.bodySmall.copyWith(color: colors.onSurfaceVariant),
      ),
    );
  }
}

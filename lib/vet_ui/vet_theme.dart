import 'package:flutter/material.dart';

/// Identidad cromática consolidada de los HTML de Stitch. Sin dependencias web.
abstract final class VetColors {
  static const canvas = Color(0xFFF1F4F8);
  // Modo oscuro, medido de las maquetas que entrego Ale. Vive aqui para que
  // el tema y las pruebas usen el mismo valor y no se separen.
  static const darkCanvas = Color(0xFF201F25);
  static const darkSurface = Color(0xFF25242A);
  static const darkRaised = Color(0xFF2A2932);
  static const darkHighlight = Color(0xFF2E2D35);
  static const darkBorder = Color(0xFF34333B);
  static const darkOutline = Color(0xFF39383F);
  /// Casi negro de la familia; el negro puro desentona con el tema.
  static const darkInk = Color(0xFF1A1920);
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

  // Recorrido de marca tomado pixel a pixel del boton «Iniciar Sesion» que
  // entrego Ale: mas palido que el anterior y con un paso por azul en medio
  // que antes no existia. Se guarda aqui para que tema y pruebas midan lo
  // mismo.
  static const brandAqua = Color(0xFF60E5E2);
  static const brandSky = Color(0xFF71AFE2);
  static const brandLilac = Color(0xFFAF84F0);
  static const pink = Color(0xFFFF4FB3);
  // Semánticos: NO usar el rosa decorativo como alerta médica por defecto.
  static const danger = Color(0xFFB42318);
  static const warning = Color(0xFF9A6700);
  static const success = Color(0xFF087F5B);
}

abstract final class VetTheme {
  /// Familia de la interfaz: Plus Jakarta Sans, la que el propio tema ya
  /// pedia en un comentario desde antes («cargar Plus Jakarta Sans como
  /// recurso local si se dispone de ella»).
  ///
  /// Es de trazo marcado y formas redondas, que es justo lo que le faltaba a
  /// la de sistema para que un titulo en w800 se vea como titulo y un dato
  /// pequeno siga legible. Va empaquetada, no descargada: la app trabaja en
  /// clinica y no puede depender de la red para pintar texto.
  static const fontFamily = 'PlusJakartaSans';

  /// Escala tipografica de la app.
  ///
  /// Existe porque no habia ninguna: el tema vivo (core/app.dart) nunca
  /// pasaba `textTheme`, asi que la app corria con la escala por omision de
  /// Material 3, donde titleLarge pesa w400, igual que el cuerpo. Un paso de
  /// 22 a 14 px sin ningun cambio de grosor no se lee como titulo y cuerpo,
  /// se lee como un muro: es lo que se ve en las capturas de Caja y Formatos,
  /// con «2. Llenar un consentimiento o formato» y su parrafo pesando lo
  /// mismo.
  ///
  /// Lo que cambia respecto a Material 3:
  ///
  /// - Los titulos pesan. Es el grosor, no el tamano, lo que separa un
  ///   encabezado de su parrafo cuando los dos comparten color y ancho.
  /// - El cuerpo gana interlineado (1.5). Los parrafos de esta app son
  ///   largos y en espanol, con palabras mas largas que en ingles.
  /// - Las etiquetas pesan w600, para que un boton o un rotulo de grupo no se
  ///   confunda con el dato que tiene al lado.
  ///
  /// titleLarge se queda en 22 a proposito. Es el tamano del nombre de
  /// pantalla en la barra, y `screen_title.dart` mide con el para decidir si
  /// parte en dos lineas; bajarlo descuadraria esa medida. Engorda, que es lo
  /// que le faltaba, pero no encoge.
  ///
  /// Los colores salen de la tipografia del sistema (negra en claro, blanca
  /// en oscuro) y de [scheme], no de constantes: una escala con el color
  /// fijado se ve bien en un modo y se pierde en el otro.
  static TextTheme textTheme(Brightness brightness, ColorScheme scheme) {
    final base =
        (brightness == Brightness.dark
                ? Typography.material2021().white
                : Typography.material2021().black)
            .apply(fontFamily: fontFamily);
    // Tres tonos de texto, no uno. Lo que se lee primero va al tono fuerte;
    // lo que acompana, al medio; la indicacion, al suave y en cuerpo chico.
    // Antes todo compartia el mismo tono y por eso el texto se veia
    // disperso: nada decia que mirar primero.
    final apoyo = scheme.onSurfaceVariant;
    return base.copyWith(
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        height: 1.15,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        height: 1.18,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        height: 1.2,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        height: 1.2,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: 14, height: 1.5),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12,
        height: 1.45,
        color: apoyo,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: .2,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: .3,
        color: apoyo,
      ),
    );
  }

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
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: VetColors.canvas,
      fontFamily: fontFamily,
      // La escala vive en un solo sitio: antes esta copia y el tema vivo de
      // core/app.dart podian separarse, y de hecho el tema vivo no tenia
      // ninguna.
      textTheme: textTheme(Brightness.light, colors),
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
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: VetColors.raised,
        indicatorColor: VetColors.lavender.withValues(alpha: .35),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

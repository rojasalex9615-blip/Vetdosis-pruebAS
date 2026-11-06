import 'package:flutter/material.dart';

import '../../vet_ui/vet_theme.dart';
import 'contrast.dart';

/// Degradado de marca: el mismo recorrido turquesa → violeta del icono y del
/// botón principal de acceso. Se define una sola vez para que cabecera, botón
/// flotante y acentos no se desincronicen.
const brandGradientColors = <Color>[
  VetColors.brandAqua,
  VetColors.brandSky,
  VetColors.brandLilac,
];

/// El recorrido de marca retocado lo mínimo para verse sobre [fondo].
///
/// Los tonos de marca son claros: sobre una barra casi blanca el extremo
/// turquesa se queda en 1.52:1, muy por debajo del 3:1 que piden los iconos.
/// Cada tramo pasa por [readableOn], que solo lo oscurece lo justo, así que el
/// recorrido turquesa → violeta → púrpura se mantiene en vez de sustituirse
/// por colores fijos distintos para cada tema.
List<Color> brandPaletteOn(Color fondo, {double objetivo = 3}) => [
  for (final tono in brandGradientColors) readableOn(tono, fondo, objetivo: objetivo),
];

/// El degradado de marca listo para usar, con la direccion que se le pida.
///
/// Se expone como funcion y no como constante porque cada sitio lo orienta
/// distinto: en diagonal en un boton redondo, de lado a lado en una barra.
LinearGradient brandGradient({
  AlignmentGeometry begin = Alignment.topLeft,
  AlignmentGeometry end = Alignment.bottomRight,
}) => LinearGradient(begin: begin, end: end, colors: brandGradientColors);

/// Icono pintado con el degradado de marca en lugar de un color plano.
///
/// Usa [ShaderMask] sobre el glifo, así que conserva el icono de Material tal
/// cual: no sustituye la forma, solo cómo se rellena. Los lectores de pantalla
/// siguen leyendo el tooltip de quien lo envuelve.
class BrandGradientIcon extends StatelessWidget {
  const BrandGradientIcon(
    this.icon, {
    super.key,
    this.size,
    this.colors,
    this.background,
  });

  /// El glifo de Material que se rellena con el degradado.
  final IconData icon;

  /// Tamano del glifo; si es nulo manda el del tema.
  final double? size;

  /// Recorrido a la fuerza, saltandose la medida de contraste.
  ///
  /// Solo para cuando quien llama ya sabe contra que se apoya el icono. Sin
  /// esto se mide contra el fondo del tema, que es lo que se quiere casi
  /// siempre.
  final List<Color>? colors;

  /// Sobre qué se apoya el icono, para medir el contraste.
  ///
  /// Si no se pasa se deduce del tema: primero el fondo de la barra, que es
  /// donde vive el icono de IA, y si no el del lienzo.
  final Color? background;

  /// El fondo contra el que se mide, resuelto desde [context].
  ///
  /// Se expone para que las pruebas puedan preguntar por el mismo camino que
  /// usa [build], en vez de repetir la expresión por su cuenta: medir contra
  /// un fondo copiado a mano en la prueba es justo el error que dejó pasar
  /// los glifos del resumen y el icono de IA.
  @visibleForTesting
  static Color backgroundOf(BuildContext context, {Color? override}) {
    final tema = Theme.of(context);
    return override ??
        tema.appBarTheme.backgroundColor ??
        tema.scaffoldBackgroundColor;
  }

  @override
  Widget build(BuildContext context) {
    final fondo = backgroundOf(context, override: background);
    final palette = colors ?? brandPaletteOn(fondo);
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: palette,
      ).createShader(bounds),
      // El color blanco es solo la base que el degradado sustituye; sin él
      // ShaderMask tomaría el color del tema y apagaría los tonos.
      child: Icon(icon, size: size, color: Colors.white),
    );
  }
}

import 'package:flutter/material.dart';

import '../../vet_ui/vet_theme.dart';

/// Degradado de marca: el mismo recorrido turquesa → violeta del icono y del
/// botón principal de acceso. Se define una sola vez para que cabecera, botón
/// flotante y acentos no se desincronicen.
const brandGradientColors = <Color>[
  VetColors.turquoise,
  VetColors.violet,
  VetColors.purple,
];

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
  const BrandGradientIcon(this.icon, {super.key, this.size, this.colors});

  final IconData icon;
  final double? size;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    final palette = colors ?? brandGradientColors;
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

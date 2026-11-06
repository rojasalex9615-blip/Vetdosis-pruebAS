import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../vet_ui/vet_theme.dart';

/// Relación de contraste WCAG entre dos colores opacos.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// El color de fondo real de algo translúcido pintado sobre otro color.
///
/// El contraste hay que medirlo contra lo que se ve, no contra el lienzo que
/// queda debajo: una placa teñida aclara u oscurece el fondo del glifo.
Color composite(Color translucido, double alpha, Color fondo) =>
    Color.alphaBlend(translucido.withValues(alpha: alpha), fondo);

/// Tinta legible encima de [fondo]: blanco o la tinta grafito, la que más
/// contraste dé.
///
/// Se elige midiendo en vez de fijar blanco: el acento de cada calculadora se
/// ajusta por contraste, así que no se sabe de antemano cuál de las dos gana.
///
/// Garantiza [objetivo] siempre que alguna tinta pueda alcanzarlo: si ni el
/// blanco ni la tinta grafito llegan, recurre al extremo puro. Pasa sobre un
/// acento de tono medio, como el de un boton de calculadora dentro de otra
/// superficie ya tenida.
Color inkOn(Color fondo, {double objetivo = 4.5}) {
  if (contrastRatio(Colors.white, fondo) >= objetivo) return Colors.white;
  if (contrastRatio(VetColors.darkInk, fondo) >= objetivo) {
    return VetColors.darkInk;
  }
  return contrastRatio(Colors.white, fondo) >=
          contrastRatio(Colors.black, fondo)
      ? Colors.white
      : Colors.black;
}

/// [deseado], retocado lo mínimo para ser legible sobre [fondo].
///
/// Si ya alcanza [objetivo] se devuelve intacto. Si no, se aleja del fondo en
/// pasos del 2%: hacia el blanco sobre un fondo oscuro y hacia el negro sobre
/// uno claro. Por omisión el objetivo es 3:1, que es lo que pide WCAG para
/// iconos y componentes; para texto hay que pasar 4.5.
///
/// Importa aclarar hacia dónde: empujar siempre hacia el blanco arreglaba el
/// tema oscuro y empeoraba el claro.
Color readableOn(Color deseado, Color fondo, {double objetivo = 3}) {
  if (contrastRatio(deseado, fondo) >= objetivo) return deseado;
  final extremo = fondo.computeLuminance() < 0.5 ? Colors.white : Colors.black;
  for (var paso = 1; paso <= 50; paso++) {
    final retocado = Color.lerp(deseado, extremo, paso * 0.02)!;
    if (contrastRatio(retocado, fondo) >= objetivo) return retocado;
  }
  return extremo;
}

/// Tinta legible encima de un degradado, midiendo contra todos sus tramos.
///
/// Un degradado no tiene un solo fondo: el glifo que se apoya en él tiene que
/// leerse igual en el extremo claro y en el oscuro. Se prueban las dos tintas
/// y gana la que mejor aguanta su *peor* tramo, no el promedio.
///
/// Hacía falta porque el botón flotante del escáner llevaba el glifo en blanco
/// fijo: sobre el violeta se leía (3.54:1) y sobre el turquesa no (1.79:1).
Color inkOnGradient(List<Color> tramos, {double objetivo = 3}) {
  double peor(Color tinta) => tramos
      .map((tramo) => contrastRatio(tinta, tramo))
      .reduce((a, b) => a < b ? a : b);
  final claro = peor(Colors.white);
  final oscuro = peor(VetColors.darkInk);
  if (claro >= objetivo && claro >= oscuro) return Colors.white;
  if (oscuro >= objetivo) return VetColors.darkInk;
  return claro >= oscuro ? Colors.white : Colors.black;
}

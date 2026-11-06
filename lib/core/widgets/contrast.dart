import 'dart:math' as math;

import 'package:flutter/material.dart';

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
Color inkOn(Color fondo) =>
    contrastRatio(Colors.white, fondo) >= contrastRatio(_tinta, fondo)
    ? Colors.white
    : _tinta;

/// Casi negro, de la familia grafito; el negro puro desentona con el tema.
const _tinta = Color(0xFF1A1920);

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

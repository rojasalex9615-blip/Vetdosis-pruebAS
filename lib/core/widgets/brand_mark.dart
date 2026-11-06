import 'package:flutter/material.dart';

/// Marca de VetDosis Pro: el arte real, con su transparencia intacta.
///
/// Antes se repintaba a mano con un `CustomPainter`, lo que estampaba un
/// mosaico opaco propio en lugar de usar el arte entregado. Ahora se muestra
/// el PNG de marca tal cual, sin fondo añadido, para que se apoye sobre
/// cualquier superficie —degradado, tarjeta de vidrio o tema oscuro— sin
/// recortar un rectángulo encima.
class VetDosisMark extends StatelessWidget {
  const VetDosisMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    // El arte es de 1024 px y aquí se dibuja a 34 o 132: se decodifica a la
    // medida real de pantalla para no mantener en memoria un mapa de bits
    // mucho mayor que el hueco donde se pinta.
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return Semantics(
      label: 'Logo VetDosis Pro',
      image: true,
      child: Image.asset(
        'assets/brand/app-icon-transparent.png',
        width: size,
        height: size,
        cacheWidth: pixels,
        cacheHeight: pixels,
        filterQuality: FilterQuality.medium,
        // Sin `color` ni contenedor detrás: el alfa del PNG es el que manda.
        excludeFromSemantics: true,
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Escala minima del nombre de pantalla. Por debajo de esto no se encoge mas:
/// se parte en dos lineas, y solo si aun no cabe se recorta.
///
/// El numero sale de medir. Con una sola linea y encogiendo sin limite,
/// «Produccion y grandes especies» acababa pintado a 7.7 px de alto en un
/// telefono de 360 dp y a 6.0 px en uno de 320, porque la hamburguesa y los
/// dos botones de la barra dejan unos 176 dp para el titulo. Eso no se lee.
const screenTitleMinScale = .62;

/// Cuantas lineas necesita [screen] y a que escala, con [available] de ancho.
///
/// Lo usan el titulo y el calculo de alto de la barra, para que los dos
/// decidan lo mismo en vez de suponerlo cada uno por su lado.
///
/// [scaler] es el factor de texto del sistema. Hay que pasarlo: `Text` lo
/// aplica al pintar, asi que medir sin el daba de largo. Lo encontro Greptile
/// y al comprobarlo salio peor de lo que decia: con el texto al 160% hasta
/// «Agenda», de seis letras, se recortaba, porque la medida decia una linea y
/// lo pintado no cabia en ella.
({int lines, double scale}) screenTitleFit(
  String screen,
  double available,
  TextStyle style, {
  TextScaler scaler = TextScaler.noScaling,
}) {
  if (available <= 0) return (lines: 1, scale: 1);
  final medidor = TextPainter(
    text: TextSpan(text: screen, style: style),
    maxLines: 1,
    textDirection: TextDirection.ltr,
    textScaler: scaler,
  )..layout();
  final natural = medidor.width;
  medidor.dispose();
  if (natural <= available) return (lines: 1, scale: 1);
  // En dos lineas cada una lleva aproximadamente la mitad del recorrido.
  final escalaDosLineas = (available * 2 / natural).clamp(
    screenTitleMinScale,
    1.0,
  );
  return (lines: 2, scale: escalaDosLineas);
}

/// Titulo de la barra: el nombre de la pantalla y, debajo, la clinica activa.
///
/// El nombre se parte en dos lineas antes que encogerse hasta no leerse, y se
/// encoge antes que recortarse. Con `TextOverflow.ellipsis` a secas llegaban
/// al telefono como «Produccion y g...» o «Calculos clinic...», y un nombre
/// cortado no dice en que pantalla esta uno.
///
/// Vive aparte de la barra para que la prueba mida este mismo widget en vez
/// de una copia hecha a mano, y para que el calculo del alto de la barra use
/// la misma regla que el pintado.
class ScreenTitle extends StatelessWidget {
  const ScreenTitle({super.key, required this.screen, this.clinic});

  /// Nombre de la pantalla actual.
  final String screen;

  /// Clinica activa, si hay sesion abierta.
  final String? clinic;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final base =
        tema.appBarTheme.titleTextStyle ??
        tema.textTheme.titleLarge ??
        const TextStyle(fontSize: 22);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, restricciones) {
            final ajuste = screenTitleFit(
              screen,
              restricciones.maxWidth,
              base,
              scaler: MediaQuery.textScalerOf(context),
            );
            return Text(
              screen,
              maxLines: ajuste.lines,
              overflow: TextOverflow.ellipsis,
              style: ajuste.scale == 1
                  ? base
                  : base.copyWith(
                      fontSize: (base.fontSize ?? 22) * ajuste.scale,
                      height: 1.1,
                    ),
            );
          },
        ),
        if (clinic != null)
          Text(
            clinic!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tema.textTheme.labelSmall,
          ),
      ],
    );
  }
}

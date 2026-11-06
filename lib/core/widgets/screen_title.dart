import 'package:flutter/material.dart';

/// Titulo de la barra: el nombre de la pantalla y, debajo, la clinica activa.
///
/// El nombre se encoge antes que cortarse. Con `TextOverflow.ellipsis` los
/// nombres largos llegaban al telefono como «Produccion y g...» o «Calculos
/// clinic...», y un nombre cortado no dice en que pantalla esta uno.
///
/// Vive aparte de la barra para que la prueba mida este mismo widget en vez
/// de una copia hecha a mano.
class ScreenTitle extends StatelessWidget {
  const ScreenTitle({super.key, required this.screen, this.clinic});

  /// Nombre de la pantalla actual.
  final String screen;

  /// Clinica activa, si hay sesion abierta.
  final String? clinic;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(screen, maxLines: 1, softWrap: false),
      ),
      if (clinic != null)
        Text(
          clinic!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall,
        ),
    ],
  );
}

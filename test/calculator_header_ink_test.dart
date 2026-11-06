import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/core/widgets/calculator_surface.dart';
import 'package:vetdosis_pro/core/widgets/contrast.dart';
import 'package:vetdosis_pro/vet_ui/vet_theme.dart';

/// La cabecera del estilo clasico se rellena con el color de identidad a
/// pleno y llevaba la tinta en blanco fijo. Con los tonos cargados de antes
/// funcionaba; al pasar la paleta a tonos palidos cayo a ~1.4:1 y el titulo
/// quedaba invisible. Lo encontraron Qodo y Greptile, no yo.
///
/// Estas pruebas leen el color que acaba pintado en el arbol, no el que
/// devuelve el ayudante: medir el ayudante es justo lo que dejo pasar el
/// fallo.
const _ids = [
  'dose',
  'concentration',
  'withdrawals',
  'manufacturer',
  'aviculture',
  'incubation',
  'fluids',
  'cri',
  'herd',
  'water',
  'feed',
  'adjustment',
  'vitals',
  'metabolic',
  'protocols',
  'ruleOfThree',
  'internationalUnits',
  'conversion',
  'desconocida',
];

void main() {
  for (final brillo in [Brightness.light, Brightness.dark]) {
    testWidgets('La cabecera clasica se lee en $brillo', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final id in _ids) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: brillo,
              scaffoldBackgroundColor: brillo == Brightness.dark
                  ? VetColors.darkCanvas
                  : VetColors.canvas,
            ),
            home: Scaffold(
              body: CalculatorSelectorCard(
                id: id,
                title: 'Titulo de la calculadora',
                // Sin WorkspaceStyle neumorfico se toma la rama clasica,
                // que es la que estaba rota.
                referenceStyle: false,
                child: const SizedBox(height: 20),
              ),
            ),
          ),
        );
        await tester.pump();

        final icono = tester.widget<Icon>(
          find.byIcon(calculatorIdentity(id).icon),
        );
        final titulo = tester.widget<Text>(
          find.text('Titulo de la calculadora'),
        );
        // El relleno real de la cabecera, leido del arbol.
        final relleno = tester
            .widgetList<Container>(
              find.ancestor(
                of: find.byIcon(calculatorIdentity(id).icon),
                matching: find.byType(Container),
              ),
            )
            .map((c) => c.color)
            .whereType<Color>()
            .first;

        expect(
          contrastRatio(icono.color!, relleno),
          greaterThanOrEqualTo(3),
          reason: 'el icono de $id no se ve sobre su cabecera en $brillo',
        );
        expect(
          contrastRatio(titulo.style!.color!, relleno),
          greaterThanOrEqualTo(4.5),
          reason: 'el titulo de $id no se lee sobre su cabecera en $brillo',
        );
      }
    });
  }

  test('El blanco fijo que habia antes no habria pasado', () {
    // Se deja escrito para que nadie lo devuelva a blanco pensando que da
    // igual: sobre los tonos palidos cae muy por debajo del umbral.
    final peor = _ids
        .map(
          (id) => contrastRatio(Colors.white, calculatorIdentity(id).color),
        )
        .reduce((a, b) => a < b ? a : b);
    expect(peor, lessThan(2));
  });
}

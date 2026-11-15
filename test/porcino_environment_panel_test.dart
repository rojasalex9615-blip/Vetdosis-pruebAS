import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/production/presentation/porcino_panels.dart';

/// El panel del dictamen ambiental muestra los parámetros y el reparto de
/// municipios fijados en el dominio. No se comprueba el aspecto, sino los datos.
void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  testWidgets('El panel ambiental muestra NCA y el reparto de municipios', (
    tester,
  ) async {
    await tester.pumpWidget(host(const PorcinoEnvironmentPanel()));
    await tester.pumpAndSettle();
    // El conteo aparece dos veces: en la fila de resultados del dictamen y en
    // el reparto resumido del panel.
    expect(find.text('26 municipios'), findsNWidgets(2));
    expect(find.text('4 municipios'), findsNWidgets(2));
    expect(find.text('21 municipios'), findsNWidgets(2));
    expect(find.text('51 municipios'), findsOneWidget);
    expect(find.text('18 kg N/cerdo/año'), findsOneWidget);
    expect(find.text('3.0 mg/L'), findsOneWidget);
    expect(find.text('175336 m³/km²'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('El panel ambiental agrupa por categoría y avisa la fuente', (
    tester,
  ) async {
    await tester.pumpWidget(host(const PorcinoEnvironmentPanel()));
    await tester.pumpAndSettle();
    expect(find.text('Ecuaciones'), findsOneWidget);
    expect(find.text('Parámetros NCA'), findsOneWidget);
    expect(find.text('Resultados con Cmax = 3.0'), findsOneWidget);
    expect(find.textContaining('SEMARNAT'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

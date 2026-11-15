import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/production/presentation/porcino_panels.dart';

/// El panel de modelos productivos muestra el Modelo 2400 en tres escenarios y
/// los KPIs históricos. Se comprueban los datos, no el aspecto.
void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  testWidgets('Muestra la tabla de escenarios y los KPIs históricos', (
    tester,
  ) async {
    await tester.pumpWidget(host(const PorcinoProductiveModelsPanel()));
    await tester.pumpAndSettle();
    expect(find.text('Modelos productivos: Modelo 2400'), findsOneWidget);
    // Encabezados de los tres escenarios en la tabla.
    expect(find.text('Promedio'), findsWidgets);
    expect(find.text('Top 30 %'), findsWidgets);
    expect(find.text('Top 10 %'), findsWidgets);
    // Parámetros iguales en los tres escenarios.
    expect(find.text('384 (8 salas × 48)'), findsOneWidget);
    expect(find.text('4-8-16'), findsOneWidget);
    // KPIs históricos.
    expect(find.text('1800'), findsOneWidget);
    expect(find.text('3.5 : 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('El selector cambia el detalle del escenario', (tester) async {
    await tester.pumpWidget(host(const PorcinoProductiveModelsPanel()));
    await tester.pumpAndSettle();
    // Promedio por defecto: 107 partos/semana.
    expect(find.text('107'), findsWidgets);
    await tester.tap(find.text('Top 10 %').last);
    await tester.pumpAndSettle();
    // Top 10 %: 96 partos/semana y 24.0 destetados/hembra servida/año.
    expect(find.text('96'), findsWidgets);
    expect(find.text('24'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

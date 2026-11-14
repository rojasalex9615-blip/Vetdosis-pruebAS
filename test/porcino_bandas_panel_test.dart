import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/production/presentation/porcino_panels.dart';

/// Comportamiento de las calculadoras del flujo por bandas: se dan los datos de
/// la hoja de clase y el resultado que se ve en pantalla es el que fija el
/// dominio. No se comprueba el aspecto, sino la cuenta.
void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  testWidgets('Flujo por bandas reproduce el ejemplo de la diapositiva', (
    tester,
  ) async {
    await tester.pumpWidget(host(const PorcinoBandFlowPanel()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Calcular flujo'));
    await tester.tap(find.text('Calcular flujo'));
    await tester.pumpAndSettle();
    expect(find.text('149 días'), findsOneWidget);
    expect(find.text('10.64'), findsOneWidget);
    expect(find.text('51.68'), findsOneWidget);
    expect(find.text('43.93'), findsOneWidget);
    expect(find.text('549.08'), findsOneWidget);
    expect(find.text('494.17'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Inventario por etapa encadena y suma el total', (tester) async {
    await tester.pumpWidget(host(const PorcinoInventoryPanel()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Calcular inventario'));
    await tester.tap(find.text('Calcular inventario'));
    await tester.pumpAndSettle();
    expect(find.text('Pre-iniciación'), findsOneWidget);
    expect(find.text('Finalización'), findsOneWidget);
    expect(find.text('4259.19'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ganancia diaria y conversión reproduce el pizarrón', (
    tester,
  ) async {
    await tester.pumpWidget(host(const PorcinoStagePerformancePanel()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Calcular etapa'));
    await tester.tap(find.text('Calcular etapa'));
    await tester.pumpAndSettle();
    expect(find.text('0.652 kg/día'), findsOneWidget);
    expect(find.text('22.5 kg'), findsOneWidget);
    expect(find.text('20.7 kg/animal'), findsOneWidget);
    expect(find.text('1.38 kg alim./kg'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Rendimiento de canal calcula el 75 %', (tester) async {
    await tester.pumpWidget(host(const PorcinoYieldPanel()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Calcular rendimiento'));
    await tester.tap(find.text('Calcular rendimiento'));
    await tester.pumpAndSettle();
    expect(find.text('75 %'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

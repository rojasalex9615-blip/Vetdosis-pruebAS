import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/production/presentation/porcino_panels.dart';

/// El panel de sistemas de alimentación muestra los datos del CSV y calcula la
/// boca de salida del silo. Se comprueban los datos, no el aspecto.
void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  testWidgets('El panel de alimentación muestra transporte y categorías', (
    tester,
  ) async {
    await tester.pumpWidget(host(const PorcinoFeedingSystemsPanel()));
    await tester.pumpAndSettle();
    expect(find.text('Sistemas de alimentación por etapas'), findsOneWidget);
    expect(find.text('Sistema de transporte'), findsWidgets);
    expect(find.text('Silos-Tolva'), findsOneWidget);
    expect(find.text('Tolva-Báscula'), findsOneWidget);
    expect(find.text('700 micrones'), findsOneWidget);
    // Modelo 220 seleccionado por defecto.
    expect(find.text('75 m'), findsWidgets);
    expect(find.text('400 kg/h'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('El selector de modelo cambia los resultados del transporte', (
    tester,
  ) async {
    await tester.pumpWidget(host(const PorcinoFeedingSystemsPanel()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mod. 500'));
    await tester.pumpAndSettle();
    expect(find.text('5.99 ton/h'), findsWidgets);
    expect(find.text('5"'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('La boca de salida responde al número de sistemas', (
    tester,
  ) async {
    await tester.pumpWidget(host(const PorcinoFeedingSystemsPanel()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '4');
    await tester.pumpAndSettle();
    expect(find.text('Boca de salida sugerida: 22".'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '9');
    await tester.pumpAndSettle();
    expect(
      find.text('El material solo cubre de 1 a 4 sistemas.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

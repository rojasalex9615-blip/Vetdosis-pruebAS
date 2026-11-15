import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/aviculture/presentation/broiler_screen.dart';

void main() {
  // Un solo testWidgets por archivo: un segundo intento de rootBundle no
  // completa bajo el reloj falso del entorno de pruebas.
  testWidgets('Pantalla de engorda: carga, no preselecciona y calcula', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: BroilerScreen()));
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(TextField).evaluate().isNotEmpty) break;
    }
    expect(find.text('Pollo de engorda · capacidad'), findsOneWidget);
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields, isNotEmpty);
    expect(fields.every((f) => f.controller!.text.isEmpty), isTrue);
    expect(find.text('Temperatura de la caseta'), findsOneWidget);
    expect(find.text('Calidad del aire'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '100');
    await tester.enterText(find.byType(TextField).last, '2.5');
    await tester.tap(find.text('Calcular capacidad'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('30 kg_por_m2'), findsWidgets);
    expect(find.textContaining('1200 aves'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

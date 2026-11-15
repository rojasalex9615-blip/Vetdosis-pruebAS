import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/aviculture/presentation/layer_reference_screen.dart';

void main() {
  // Un solo testWidgets por archivo: un segundo intento de rootBundle no
  // completa bajo el reloj falso del entorno de pruebas.
  testWidgets('Pantalla de postura: carga, no preselecciona y clasifica', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: LayerReferenceScreen()));
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(TextField).evaluate().isNotEmpty) break;
    }
    expect(find.text('Postura · referencias adicionales'), findsOneWidget);
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields, isNotEmpty);
    expect(fields.every((f) => f.controller!.text.isEmpty), isTrue);
    expect(find.text('Huevos por ave y año por sistema'), findsOneWidget);
    expect(find.text('Plan de luz'), findsOneWidget);
    expect(find.text('Calidad del huevo'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '65');
    await tester.enterText(find.byType(TextField).last, '7');
    await tester.ensureVisible(find.text('Clasificar'));
    await tester.tap(find.text('Clasificar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('L_grande'), findsOneWidget);
    expect(find.textContaining('categoría B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/aviculture/presentation/poultry_index_screen.dart';

void main() {
  // Un solo testWidgets por archivo: un segundo rootBundle no completa bajo
  // el reloj falso del entorno de pruebas.
  testWidgets('Índices productivos: carga, muestra fórmula y calcula', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PoultryIndexScreen()));
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(TextField).evaluate().isNotEmpty) break;
    }
    expect(find.text('Índices productivos avícolas'), findsOneWidget);
    expect(find.textContaining('existencia_actual*100'), findsOneWidget);
    expect(find.textContaining('sin_verificar'), findsWidgets);

    // Viabilidad: 980/1000 = 98 %.
    await tester.enterText(find.byType(TextField).at(0), '980');
    await tester.enterText(find.byType(TextField).at(1), '1000');
    await tester.tap(find.text('Calcular índice'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('= 98 %'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

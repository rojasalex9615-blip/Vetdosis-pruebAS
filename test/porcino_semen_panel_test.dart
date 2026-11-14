import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/production/presentation/porcino_semen_panel.dart';

void main() {
  Widget host() => const MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: PorcinoSemenPanel()),
    ),
  );

  testWidgets('Defaults reproduce the prototype dose count', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.text('Dosis seminales porcinas'), findsOneWidget);
    // 76 × 200 × 50 000 = 760 ×10⁶/ml; 200 ml, 90 % y 88 %, 2 ×10⁹ por dosis.
    expect(find.text('60'), findsOneWidget);
    expect(find.textContaining('760 ×10⁶/ml'), findsOneWidget);
    expect(find.textContaining('120.4 ×10⁹'), findsOneWidget);
    expect(find.textContaining('4600 ml'), findsOneWidget);
    expect(
      find.textContaining('Dilución y área de conteo por confirmar'),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Switching to a direct concentration recalculates', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ya la tengo'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Concentración (×10⁶/ml)'),
      '380',
    );
    await tester.pumpAndSettle();
    // 200 × 380 × 0.9 × 0.88 = 60 192 ×10⁶ = 60.192 ×10⁹ → 30 dosis.
    expect(find.text('30'), findsOneWidget);
    expect(find.textContaining('60.2 ×10⁹'), findsOneWidget);
  });

  testWidgets('Choosing cervical sets 3 ×10⁹ per dose', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cervical (3 ×10⁹)'));
    await tester.tap(find.text('Cervical (3 ×10⁹)'));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Espermas por dosis (×10⁹)'),
    );
    expect(field.controller!.text, '3');
    expect(tester.takeException(), isNull);
  });
}

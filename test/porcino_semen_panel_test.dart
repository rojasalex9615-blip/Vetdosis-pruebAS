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
    // Lectura del analizador 380 ×10⁶/ml; 200 ml, 90 % y 88 %, 2 ×10⁹ por dosis.
    expect(
      find.byKey(const ValueKey('semen-doses')),
      findsOneWidget,
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('semen-doses'))).data,
      '30',
    );
    expect(find.textContaining('380 ×10⁶/ml'), findsOneWidget);
    expect(find.textContaining('60.2 ×10⁹'), findsOneWidget);
    expect(find.textContaining('2200 ml'), findsOneWidget);
    expect(
      find.textContaining('Dilución y área de conteo pendientes de verificación'),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Counting in the chamber recalculates the concentration', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conteo en cámara'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Células contadas'),
      '76',
    );
    await tester.pumpAndSettle();
    // 76 × 200 × 50 000 = 760 ×10⁶/ml → 200 × 760 × 0.9 × 0.88 = 120.384 ×10⁹
    // → 60 dosis.
    expect(find.text('760 ×10⁶/ml'), findsOneWidget);
    expect(find.text('60'), findsOneWidget);
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

  testWidgets('Defaults are apt and show no alerts', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Cumple los mínimos de calidad'),
      findsOneWidget,
    );
    expect(
      find.textContaining('El volumen final es menor al eyaculado'),
      findsNothing,
    );
  });

  testWidgets('Low progressive motility flags the sample as not apt', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Motilidad progresiva (%)'),
      '60',
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No apto para inseminar: progresiva <70 %'),
      findsOneWidget,
    );
  });
}

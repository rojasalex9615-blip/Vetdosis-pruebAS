import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';
import 'package:vetdosis_pro/modules/production/domain/porcino_capacity.dart';
import 'package:vetdosis_pro/modules/production/domain/porcino_reference.dart';
import 'package:vetdosis_pro/modules/production/presentation/growth_panel.dart';
import 'package:vetdosis_pro/modules/production/presentation/porcino_panels.dart';
import 'package:vetdosis_pro/modules/production/presentation/production_menu.dart';
import 'section_navigation_test.dart' show admin;
import 'support/fake_auth.dart' show member;

void main() {
  test('Modelo 2400 reproduces the class figures', () {
    final plan = SwineFlowPlan(sows: 2400, weanedPerLitter: 10);
    expect(plan.farrowingsPerWeek, 96);
    expect(plan.pigletsPerWeek, 960);
    expect(plan.maternityCrates, 384);
    expect(plan.nurseryPlaces, 7680);
    expect(plan.finishingPlaces, 15360);
  });

  test('Fractional farrowings round spaces up, never down', () {
    final plan = SwineFlowPlan(sows: 2412, weanedPerLitter: 9);
    expect(plan.farrowingsPerWeek, closeTo(96.48, 1e-9));
    expect(plan.maternityCrates, 386);
  });

  test('Flow plan rejects impossible inputs', () {
    for (final build in [
      () => SwineFlowPlan(sows: 0, weanedPerLitter: 10),
      () => SwineFlowPlan(sows: 100, weanedPerLitter: 0),
      () => SwineFlowPlan(sows: 100, weanedPerLitter: 25),
      () => SwineFlowPlan(sows: 100, weanedPerLitter: 10, factor: 0),
      () => SwineFlowPlan(sows: 100, weanedPerLitter: 10, nurseryWeeks: 0),
      () => SwineFlowPlan(sows: 100, weanedPerLitter: 10, finishingWeeks: 80),
    ]) {
      expect(build, throwsFormatException);
    }
  });

  test('Silo capacity is animals × daily feed × days', () {
    final silo = SiloSizing(animals: 1000, kgPerHeadDay: 2.7, inventoryDays: 7);
    expect(silo.dailyKg, closeTo(2700, 1e-9));
    expect(silo.totalKg, closeTo(18900, 1e-9));
    expect(silo.totalTons, closeTo(18.9, 1e-9));
    expect(
      () => SiloSizing(animals: 10, kgPerHeadDay: 0, inventoryDays: 7),
      throwsFormatException,
    );
  });

  test('Space table is complete and grows with weight and floor type', () {
    for (final weights in [porcinoNurseryWeights, porcinoFinishingWeights]) {
      for (final w in weights) {
        final row = porcinoSpaceM2[w]!;
        expect(row.keys.toSet(), PorcinoFloor.values.toSet());
        expect(
          row[PorcinoFloor.slat]! < row[PorcinoFloor.partial]! &&
              row[PorcinoFloor.partial]! < row[PorcinoFloor.solid]!,
          true,
        );
      }
    }
    expect(SpaceEstimate(animals: 21, m2PerAnimal: 0.41).totalM2, closeTo(8.61, 1e-9));
  });

  Widget app(ClinicMembership who) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: ProductionMenu(member: who, onNavigate: (_) {}),
      ),
    ),
  );

  testWidgets('Reproduction flow example shows the Modelo 2400 results', (
    tester,
  ) async {
    await tester.pumpWidget(app(admin));
    await tester.ensureVisible(find.text('Porcinos'));
    await tester.tap(find.text('Porcinos'));
    await tester.pumpAndSettle();
    // El detalle de especie es mas alto que la pantalla de prueba, asi que
    // tras el desplazamiento anterior el chip queda fuera y el toque no
    // acierta. Misma pauta que con «Porcinos» arriba.
    await tester.ensureVisible(find.text('Reproducción y gestación'));
    await tester.tap(find.text('Reproducción y gestación'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Usar ejemplo Modelo 2400'));
    await tester.tap(find.text('Usar ejemplo Modelo 2400'));
    await tester.pumpAndSettle();
    expect(find.text('384'), findsOneWidget);
    expect(find.text('96'), findsOneWidget);
    expect(find.text('960'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Porcine panels respect calculator access', (tester) async {
    await tester.pumpWidget(app(member));
    await tester.ensureVisible(find.text('Porcinos'));
    await tester.tap(find.text('Porcinos'));
    await tester.pumpAndSettle();
    for (final activity in productionSpecies['Porcinos']!) {
      // Sin esto el chip cae fuera de pantalla, la actividad no se
      // selecciona y el aviso de acceso denegado no llega a pintarse.
      await tester.ensureVisible(find.text(activity));
      await tester.tap(find.text(activity));
      await tester.pumpAndSettle();
      expect(find.byType(PorcinoFlowPanel), findsNothing);
      expect(find.byType(PorcinoSiloPanel), findsNothing);
      expect(find.byType(PorcinoSpacePanel), findsNothing);
      expect(find.byType(GrowthPanel), findsNothing);
      expect(find.textContaining('no están habilitadas'), findsOneWidget);
    }
  });

  testWidgets('Biosecurity and environment activity shows its two panels', (
    tester,
  ) async {
    await tester.pumpWidget(app(admin));
    await tester.ensureVisible(find.text('Porcinos'));
    await tester.tap(find.text('Porcinos'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Bioseguridad y ambiente'));
    await tester.tap(find.text('Bioseguridad y ambiente'));
    await tester.pumpAndSettle();
    expect(find.byType(PorcinoBiosecurityPanel), findsOneWidget);
    expect(find.byType(PorcinoNitrogenPanel), findsOneWidget);
    expect(find.text('0 de 20 revisados'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('Precios cotizados', () {
    test('uno, varios, vacio y basura', () {
      expect(parseQuotedPrices(''), isEmpty);
      expect(parseQuotedPrices('1200'), [120000]);
      expect(parseQuotedPrices('1200; 1350 ;1290'), [120000, 135000, 129000]);
      // La coma vale como decimal, no como separador de lista.
      expect(parseQuotedPrices('1,5'), [150]);
      expect(parseQuotedPrices('1200,50'), [120050]);
      // Dos cotizaciones escritas con coma. Antes casaba como un solo numero
      // de cuatro decimales y entraba callado como 1 200.14 pesos.
      expect(() => parseQuotedPrices('1200,1350'), throwsFormatException);
      // El dinero no tiene tres decimales; si llegan, es otra cosa.
      expect(() => parseQuotedPrices('1200.135'), throwsFormatException);
      expect(() => parseQuotedPrices('mil'), throwsFormatException);
      expect(() => parseQuotedPrices('0'), throwsFormatException);
    });
  });

  testWidgets('El estimado de inversion suma y avisa de lo que no incluye', (
    tester,
  ) async {
    await tester.pumpWidget(app(admin));
    await tester.ensureVisible(find.text('Porcinos'));
    await tester.tap(find.text('Porcinos'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Planeación financiera'));
    await tester.tap(find.text('Planeación financiera'));
    await tester.pumpAndSettle();
    expect(find.byType(PorcinoInvestmentPanel), findsOneWidget);

    Future<void> agregar(String concepto, String cantidad, String precios) async {
      await tester.enterText(find.widgetWithText(TextField, 'Concepto'), concepto);
      await tester.enterText(find.widgetWithText(TextField, 'Cantidad'), cantidad);
      await tester.enterText(
        find.widgetWithText(TextField, 'Precios cotizados por unidad (MXN)'),
        precios,
      );
      await tester.ensureVisible(find.text('Agregar concepto'));
      await tester.tap(find.text('Agregar concepto'));
      await tester.pumpAndSettle();
    }

    await agregar('Ventilador', '4', '1200');
    expect(find.text('Total estimado'), findsOneWidget);
    // El renglon lleva el desglose completo y el total va solo con la cifra,
    // asi que find.text, que compara exacto, distingue uno de otro. Antes no:
    // con un concepto suelto los dos decian «4 800.00 MXN» y nada mas.
    expect(find.textContaining('× 1 200.00 MXN = 4 800.00 MXN'), findsOneWidget);
    expect(find.text('4 800.00 MXN'), findsOneWidget);

    // Un concepto sin precio no entra al total, y la pantalla lo dice.
    await agregar('Cielo-raso', '100', '');
    expect(find.text('4 800.00 MXN'), findsOneWidget);
    expect(find.textContaining('NO incluye 1 concepto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

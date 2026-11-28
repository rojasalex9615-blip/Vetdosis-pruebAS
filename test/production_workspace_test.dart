import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetdosis_pro/modules/production/presentation/production_workspace.dart';
import 'package:vetdosis_pro/modules/production/domain/production_session_math.dart';
import 'package:vetdosis_pro/modules/production/presentation/apiary_harvest_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'apiary uses captured yield and costs, never an assumed production target',
    () {
      final r = ApiaryHarvest(
        kilograms: '300',
        productiveHives: '50',
        days: '30',
        priceKg: '200',
        capturedCost: '12000',
      );
      expect(r.perHive.display(places: 2), '6');
      expect(r.perDay.display(places: 2), '10');
      expect(r.revenue!.display(places: 2), '60000');
      expect(r.balance!.display(places: 2), '48000');
      final missing = ApiaryHarvest(
        kilograms: '0',
        productiveHives: '2',
        days: '10',
        priceKg: '',
        capturedCost: '',
      );
      expect(missing.revenue, isNull);
      expect(missing.balance, isNull);
    },
  );
  test('apiary rejects invalid counts and nonfinite values', () {
    for (final h in ['0', '1.5', 'NaN', '-1']) {
      expect(
        () => ApiaryHarvest(
          kilograms: '3',
          productiveHives: h,
          days: '2',
          priceKg: '',
          capturedCost: '',
        ),
        throwsFormatException,
      );
    }
    expect(
      () => ApiaryHarvest(
        kilograms: '3',
        productiveHives: '2',
        days: '0',
        priceKg: '',
        capturedCost: '',
      ),
      throwsFormatException,
    );
  });
  test(
    'search normalizes accents and case',
    () => expect(
      productionSearchKey('CONVERSIÓN · Ración'),
      'conversion · racion',
    ),
  );
  test(
    'capacity floors exactly without binary floating point losing an animal',
    () {
      expect(
        CapturedCapacity(width: '1', length: '1', animalsPerM2: '1.9').animals,
        BigInt.one,
      );
      expect(
        CapturedCapacity(
          width: '0.58',
          length: '1',
          animalsPerM2: '100',
        ).animals,
        BigInt.from(58),
      );
      expect(
        () => CapturedCapacity(width: '0', length: '1', animalsPerM2: '1'),
        throwsFormatException,
      );
    },
  );
  test(
    'negative balances remain readable and integer decimal notation is accepted',
    () {
      final r = ApiaryHarvest(
        kilograms: '100',
        productiveHives: '10.0',
        days: '2',
        priceKg: '1',
        capturedCost: '200',
      );
      expect(signedSessionAmount(r.balance!), '-100');
    },
  );
  Widget host({String user = 'u1', String clinic = 'c1'}) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: ProductionWorkspace(
          scope: 'Peces/Tilapia',
          userId: user,
          clinicId: clinic,
          entries: [
            ProductionEntry(
              id: 'fca',
              title: 'Conversión alimenticia',
              area: ProductionArea.calculators,
              open: () {},
            ),
            ProductionEntry(
              id: 'water',
              title: 'Recambio de agua',
              area: ProductionArea.calculators,
              open: () {},
            ),
            ProductionEntry(
              id: 'records',
              title: 'Capturas de estanque',
              area: ProductionArea.records,
              open: () {},
            ),
            ProductionEntry(
              id: 'refs',
              title: 'Guías de cultivo',
              area: ProductionArea.references,
              open: () {},
            ),
          ],
        ),
      ),
    ),
  );
  testWidgets(
    'areas are separated and search finds accent-insensitive objectives',
    (t) async {
      await t.pumpWidget(host());
      await t.pumpAndSettle();
      expect(find.text('Capturas de estanque'), findsNothing);
      await t.enterText(
        find.byKey(const ValueKey('production-search')),
        'conversion',
      );
      await t.pumpAndSettle();
      expect(find.text('Conversión alimenticia'), findsOneWidget);
      expect(find.text('Recambio de agua'), findsNothing);
      await t.enterText(find.byKey(const ValueKey('production-search')), '');
      await t.tap(find.text('Registros'));
      await t.pumpAndSettle();
      expect(find.text('Capturas de estanque'), findsOneWidget);
      expect(find.text('Conversión alimenticia'), findsNothing);
      await t.ensureVisible(find.text('Referencias'));
      await t.pumpAndSettle();
      await t.tap(find.text('Referencias'));
      await t.pumpAndSettle();
      expect(find.text('Guías de cultivo'), findsOneWidget);
    },
  );
  testWidgets('favorites persist and are isolated by user and workspace', (
    t,
  ) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('favorite-fca')));
    await t.pumpAndSettle();
    expect(find.byTooltip('Quitar favorito'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    expect(find.byTooltip('Quitar favorito'), findsOneWidget);
    await t.tap(find.text('Solo favoritos'));
    await t.pumpAndSettle();
    expect(find.text('Recambio de agua'), findsNothing);
    await t.pumpWidget(host(user: 'u2'));
    await t.pumpAndSettle();
    expect(find.byTooltip('Quitar favorito'), findsNothing);
    await t.pumpWidget(host(user: 'u1', clinic: 'other'));
    await t.pumpAndSettle();
    expect(find.byTooltip('Quitar favorito'), findsNothing);
  });
  testWidgets('apiary screen invalidates output after an input changes', (
    t,
  ) async {
    await t.pumpWidget(
      const MaterialApp(home: ApiaryHarvestScreen(showCosts: false)),
    );
    await t.enterText(find.byType(TextField).at(0), '300');
    await t.enterText(find.byType(TextField).at(1), '50');
    await t.enterText(find.byType(TextField).at(2), '30');
    await t.tap(find.text('Calcular cosecha'));
    await t.pumpAndSettle();
    expect(find.text('6 kg/colmena productiva'), findsOneWidget);
    await t.enterText(find.byType(TextField).at(1), '60');
    await t.pump();
    expect(find.text('6 kg/colmena productiva'), findsNothing);
  });
  testWidgets('workspace controls fit at 320 px', (t) async {
    t.view.physicalSize = const Size(320, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.ensureVisible(find.text('Referencias'));
    await t.pumpAndSettle();
    await t.tap(find.text('Referencias'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}

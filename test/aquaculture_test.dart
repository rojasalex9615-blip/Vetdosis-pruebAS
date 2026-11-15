import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/production/domain/aquaculture_reference.dart';
import 'package:vetdosis_pro/modules/production/presentation/aquaculture_panels.dart';

void main() {
  group('Siembra y biomasa', () {
    test('Estanque en tierra sin aireación, nivel medio', () {
      final plan = SeedStockPlan(
        systemIndex: 0,
        areaM2: 1000,
        averageDepthM: 1.2,
        harvestWeightG: 500,
        survivalPercent: 85,
        level: 1,
      );
      expect(plan.densityKgPerUnit, closeTo(0.45, 1e-9));
      expect(plan.biomassKg, closeTo(450, 1e-9));
      expect(plan.harvestFish, closeTo(900, 1e-9));
      expect(plan.seedFish, closeTo(1058.823529, 1e-6));
      expect(plan.volumeM3, closeTo(1200, 1e-9));
      expect(plan.densityPerUnit, closeTo(1.0588, 1e-3));
    });

    test('Los sistemas por volumen usan el volumen como base', () {
      final cage = SeedStockPlan(
        systemIndex: 2,
        areaM2: 100,
        averageDepthM: 2,
        harvestWeightG: 500,
        survivalPercent: 90,
        level: 2,
      );
      expect(cage.system.perVolume, isTrue);
      expect(cage.densityBase, closeTo(200, 1e-9));
      expect(cage.densityKgPerUnit, closeTo(40, 1e-9));
      expect(cage.biomassKg, closeTo(8000, 1e-9));
    });

    test('Rechaza área, profundidad, peso y supervivencia inválidos', () {
      SeedStockPlan build({
        double area = 1000,
        double depth = 1.2,
        double harvest = 500,
        double survival = 85,
        int level = 1,
      }) => SeedStockPlan(
        systemIndex: 0,
        areaM2: area,
        averageDepthM: depth,
        harvestWeightG: harvest,
        survivalPercent: survival,
        level: level,
      );
      expect(() => build(area: 0), throwsFormatException);
      expect(() => build(depth: -1), throwsFormatException);
      expect(() => build(harvest: 0), throwsFormatException);
      expect(() => build(survival: 0), throwsFormatException);
      expect(() => build(survival: 101), throwsFormatException);
      expect(() => build(level: 3), throwsFormatException);
    });
  });

  group('Ración diaria', () {
    test('Tabla SENA por talla y factor de temperatura', () {
      expect(senaDailyPercent(4), 10);
      expect(senaDailyPercent(5), 8);
      expect(senaDailyPercent(60), 4);
      expect(senaDailyPercent(150), 3.5);
      expect(senaDailyPercent(250), 3);
      expect(senaDailyPercent(500), 2.5);
      expect(senaDailyPercent(501), isNull);
      expect(senaTemperatureFactor('24_32'), 1);
      expect(senaTemperatureFactor('18_20'), 0.29);
    });

    test('Ración = biomasa × tasa × factor', () {
      final r = DailyRationPlan(
        averageGrams: 60,
        fishCount: 1000,
        temperatureFactor: 1,
      );
      expect(r.biomassKg, closeTo(60, 1e-9));
      expect(r.dailyPercent, 4);
      expect(r.rationKg, closeTo(2.4, 1e-9));
    });

    test('Aplica el factor de temperatura', () {
      final r = DailyRationPlan(
        averageGrams: 60,
        fishCount: 1000,
        temperatureFactor: 0.71,
      );
      expect(r.rationKg, closeTo(1.704, 1e-9));
    });

    test('Fuera de la tabla (>500 g) no interpola', () {
      expect(
        () => DailyRationPlan(
          averageGrams: 600,
          fishCount: 100,
          temperatureFactor: 1,
        ),
        throwsFormatException,
      );
    });
  });

  group('Indicadores y costos', () {
    test('Ejemplo del ciclo completo', () {
      final c = CycleIndicators(
        initialFish: 18000,
        finalFish: 15000,
        initialWeightG: 5,
        finalWeightG: 772,
        feedKg: 14000,
        feedPricePerKg: 0.9,
        laborCost: 3000,
        operatingCost: 2000,
        salePricePerKg: 2.5,
        pondVolumeM3: 5000,
      );
      expect(c.initialBiomassKg, closeTo(90, 1e-9));
      expect(c.finalBiomassKg, closeTo(11580, 1e-9));
      expect(c.biomassGainKg, closeTo(11490, 1e-9));
      expect(c.survivalPercent, closeTo(83.333333, 1e-4));
      expect(c.feedConversionRatio, closeTo(1.218451, 1e-4));
      expect(c.feedCost, closeTo(12600, 1e-9));
      expect(c.totalCost, closeTo(17600, 1e-9));
      expect(c.costPerKg, closeTo(1.531767, 1e-4));
      expect(c.income, closeTo(28950, 1e-9));
      expect(c.profit, closeTo(11350, 1e-9));
      expect(c.densityPerM3, closeTo(3.6, 1e-9));
    });

    test('Rechaza peces finales mayores y ganancia no positiva', () {
      CycleIndicators build({
        int initial = 100,
        int finalFish = 90,
        double initialWeight = 5,
        double finalWeight = 100,
      }) => CycleIndicators(
        initialFish: initial,
        finalFish: finalFish,
        initialWeightG: initialWeight,
        finalWeightG: finalWeight,
        feedKg: 100,
        feedPricePerKg: 1,
        laborCost: 0,
        operatingCost: 0,
        salePricePerKg: 1,
        pondVolumeM3: 100,
      );
      expect(() => build(finalFish: 200), throwsFormatException);
      expect(
        () => build(initialWeight: 200, finalWeight: 100),
        throwsFormatException,
      );
    });
  });

  group('Oxígeno y aireación', () {
    test('A. Demanda de oxígeno por alimento', () {
      final d = OxygenDemand(
        feedKgPerDay: 100,
        peakFactor: 1.5,
        transferEfficiency: 0.15,
      );
      expect(d.oxygenKgPerDay, closeTo(35, 1e-9));
      expect(d.averageKgPerHour, closeTo(1.458333, 1e-6));
      expect(d.peakKgPerHour, closeTo(2.1875, 1e-9));
      expect(d.generatorKgPerHour, closeTo(14.583333, 1e-6));
      expect(d.generatorNm3PerHour, closeTo(10.208333, 1e-6));
    });

    test('B. Aireadores con OTR corregido por temperatura', () {
      final a = AeratorPlan(
        todKgPerHour: 3,
        sotrKgPerHour: 3.25,
        saturationMgL: 7.8,
        minimumMgL: 3.4,
        t1C: 25,
        tfC: 28,
      );
      expect(a.otrKgPerHour, closeTo(1.833333, 1e-6));
      expect(a.otrTemperatureKgPerHour, closeTo(1.70752, 1e-4));
      expect(a.aerators, closeTo(1.7569, 1e-3));
      expect(a.aeratorsToInstall, 2);
    });

    test('B. TOD derivado de CO + RC + RF × V', () {
      final a = AeratorPlan.fromConsumption(
        coMgLh: 0.5,
        rcMgLh: 0.3,
        rfMgLh: 0.2,
        volumeM3: 1000,
        sotrKgPerHour: 3.25,
        saturationMgL: 7.8,
        minimumMgL: 3.4,
        t1C: 25,
        tfC: 28,
      );
      expect(a.todKgPerHour, closeTo(1.0, 1e-9));
    });

    test('C. Reserva de oxígeno que no alcanza al amanecer', () {
      final r = OxygenReserve(
        currentMgL: 8.5,
        minimumMgL: 3.5,
        lossesMgLh: 0.6,
        readingHour: 18,
        dawnHour: 6,
      );
      expect(r.surplusMgL, closeTo(5, 1e-9));
      expect(r.reserveHours, closeTo(8.333333, 1e-6));
      expect(r.depletionHour, 2);
      expect(r.hoursUntilDawn, 12);
      expect(r.reachesDawn, isFalse);
    });

    test('C. Reserva que sí alcanza al amanecer', () {
      final r = OxygenReserve(
        currentMgL: 12,
        minimumMgL: 3,
        lossesMgLh: 0.5,
        readingHour: 20,
        dawnHour: 6,
      );
      expect(r.reserveHours, closeTo(18, 1e-9));
      expect(r.hoursUntilDawn, 10);
      expect(r.reachesDawn, isTrue);
    });

    test('C. Superávit no positivo no da hora de agotamiento', () {
      final r = OxygenReserve(
        currentMgL: 3,
        minimumMgL: 3.5,
        lossesMgLh: 0.6,
        readingHour: 18,
        dawnHour: 6,
      );
      expect(r.depletionHour, isNull);
      expect(r.reachesDawn, isFalse);
    });

    test('Rechaza entradas inválidas', () {
      expect(
        () => AeratorPlan(
          todKgPerHour: 0,
          sotrKgPerHour: 3.25,
          saturationMgL: 7.8,
          minimumMgL: 3.4,
          t1C: 25,
          tfC: 28,
        ),
        throwsFormatException,
      );
      expect(
        () => AeratorPlan(
          todKgPerHour: 3,
          sotrKgPerHour: 3.25,
          saturationMgL: 7.8,
          minimumMgL: 8,
          t1C: 25,
          tfC: 28,
        ),
        throwsFormatException,
      );
      expect(
        () => OxygenReserve(
          currentMgL: 8.5,
          minimumMgL: 3.5,
          lossesMgLh: 0,
          readingHour: 18,
          dawnHour: 6,
        ),
        throwsFormatException,
      );
      expect(
        () => OxygenReserve(
          currentMgL: 8.5,
          minimumMgL: 3.5,
          lossesMgLh: 0.6,
          readingHour: 24,
          dawnHour: 6,
        ),
        throwsFormatException,
      );
    });
  });

  testWidgets('Panel de siembra calcula y muestra los alevinos', (tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: AquacultureSeedPanel()),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Calcular siembra'));
    await tester.tap(find.text('Calcular siembra'));
    await tester.pump();
    expect(find.text('1059'), findsOneWidget);
    expect(find.text('alevinos a sembrar'), findsOneWidget);
    expect(find.text('450 kg'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

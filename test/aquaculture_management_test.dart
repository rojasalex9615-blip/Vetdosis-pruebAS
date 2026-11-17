import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/production/domain/aquaculture_management_reference.dart';

void main() {
  group('FCA y costo', () {
    test('vector de Claude: 1000 kg alimento, 10 -> 765 kg produce FCA 1,32', () {
      final plan = FeedConversionPlan(
        feedKg: 1000,
        initialBiomassKg: 10,
        finalBiomassKg: 765,
        withdrawnBiomassKg: 0,
        deadFish: 0,
        initialWeightG: 1,
        finalWeightG: 500,
        feedPricePerKg: 2800,
        salePricePerKg: 0,
        days: 100,
      );
      expect(plan.producedBiomassKg, closeTo(755, 1e-9));
      expect(plan.apparentFcr, closeTo(1.325, 0.001));
      expect(plan.feedCostPerKg, closeTo(3708.61, 0.01));
    });

    test('FCA con mortalidad estima la biomasa de los muertos', () {
      final plan = FeedConversionPlan(
        feedKg: 1000,
        initialBiomassKg: 10,
        finalBiomassKg: 765,
        withdrawnBiomassKg: 0,
        deadFish: 100,
        initialWeightG: 100,
        finalWeightG: 500,
        feedPricePerKg: 1,
        salePricePerKg: 0,
        days: 100,
      );
      // Muertos: 100 × (100+500)/2 / 1000 = 30 kg.
      expect(plan.deadBiomassKg, closeTo(30, 1e-9));
      expect(plan.fcrWithMortality, closeTo(1000 / 785, 1e-9));
    });

    test('el ahorro con un FCA objetivo es positivo al bajar el FCA', () {
      final plan = FeedConversionPlan(
        feedKg: 1000,
        initialBiomassKg: 10,
        finalBiomassKg: 765,
        withdrawnBiomassKg: 0,
        deadFish: 0,
        initialWeightG: 1,
        finalWeightG: 500,
        feedPricePerKg: 2,
        salePricePerKg: 10,
        days: 100,
      );
      expect(plan.savingsForTargetFcr(1.2), greaterThan(0));
      expect(plan.feedShareOfSalePrice, isNotNull);
    });
  });

  group('Recambio de agua', () {
    test('vector de Claude: nitrito 4,00 -> 2,50 en 10 m³ da 3750 L y 2 recambios', () {
      final plan = WaterExchangePlan(
        volumeM3: 10,
        currentAmmoniaMgL: 0,
        desiredAmmoniaMgL: 0,
        currentNitriteMgL: 4.00,
        desiredNitriteMgL: 2.50,
        currentNitrateMgL: 0,
        desiredNitrateMgL: 0,
      );
      expect(plan.requiredFraction, closeTo(0.375, 1e-9));
      expect(plan.liters, closeTo(3750, 1e-6));
      expect(plan.exchanges, 2);
    });

    test('un solo recambio si el parámetro ya cumple', () {
      final plan = WaterExchangePlan(
        volumeM3: 10,
        currentAmmoniaMgL: 0.5,
        desiredAmmoniaMgL: 1.0,
        currentNitriteMgL: 0,
        desiredNitriteMgL: 1,
        currentNitrateMgL: 0,
        desiredNitrateMgL: 1,
      );
      expect(plan.requiredFraction, 0);
      expect(plan.exchanges, 1);
    });

    test('toma el máximo entre amonio, nitrito y nitrato', () {
      final plan = WaterExchangePlan(
        volumeM3: 10,
        currentAmmoniaMgL: 1,
        desiredAmmoniaMgL: 0.5,
        currentNitriteMgL: 4,
        desiredNitriteMgL: 1,
        currentNitrateMgL: 0,
        desiredNitrateMgL: 0,
      );
      // Nitrito: (4-1)/4 = 0,75 exige más que amonio (0,5).
      expect(plan.requiredFraction, closeTo(0.75, 1e-9));
    });
  });

  group('Sal contra el nitrito', () {
    test('vector de Claude: 100 m³, NO₂-N 2,00, Cl 10 -> 23,3 kg al 99 %', () {
      final plan = NitriteSaltPlan(
        volumeM3: 100,
        nitriteNitrogenMgL: 2.00,
        currentChlorideMgL: 10,
        ratio: 20,
        maintenanceChlorideMgL: 0,
        purityPercent: 99,
      );
      expect(plan.targetChlorideMgL, closeTo(40, 1e-9));
      expect(plan.chlorideToAddMgL, closeTo(30, 1e-9));
      expect(plan.pureSaltGramPerM3, closeTo(49.5, 1e-6));
    });

    test('el mantenimiento manda cuando supera a la relación', () {
      final plan = NitriteSaltPlan(
        volumeM3: 100,
        nitriteNitrogenMgL: 2.00,
        currentChlorideMgL: 10,
        ratio: 20,
        maintenanceChlorideMgL: 150,
        purityPercent: 99,
      );
      expect(plan.targetChlorideMgL, closeTo(150, 1e-9));
      expect(plan.chlorideToAddMgL, closeTo(140, 1e-9));
      expect(plan.pureSaltGramPerM3, closeTo(231, 1e-6));
      expect(plan.saltGramPerM3, closeTo(233.33, 0.01));
      expect(plan.saltKg, closeTo(23.33, 0.01));
    });

    test('alerta cuando la relación cloruro:nitrito baja de 10', () {
      final low = NitriteSaltPlan(
        volumeM3: 100,
        nitriteNitrogenMgL: 2.00,
        currentChlorideMgL: 10,
      );
      expect(low.currentRatio, closeTo(5, 1e-9));
      expect(low.belowMinimumRatio, isTrue);

      final ok = NitriteSaltPlan(
        volumeM3: 100,
        nitriteNitrogenMgL: 2.00,
        currentChlorideMgL: 40,
      );
      expect(ok.belowMinimumRatio, isFalse);
    });
  });

  group('Alimento medicado', () {
    test('vector de Claude: 200 kg, 4 kg/día, 10 mg/kg/día al 50 %', () {
      final plan = MedicatedFeedPlan(
        biomassKg: 200,
        dailyFeedKg: 4,
        doseBasis: MedicatedDoseBasis.perFishPerDay,
        doseValue: 10,
        productConcentration: 0.5,
        treatmentDays: 10,
      );
      expect(plan.activeGramsPerDay, closeTo(2, 1e-9));
      expect(plan.productGramsPerDay, closeTo(4, 1e-9));
      expect(plan.productPerKgFeed, closeTo(1.00, 1e-9));
      expect(plan.batchGrams, closeTo(40, 1e-9));
      expect(plan.inclusionPercent, closeTo(0.10, 1e-9));
    });

    test('la dosis por kg de alimento no depende de la biomasa', () {
      final plan = MedicatedFeedPlan(
        biomassKg: 200,
        dailyFeedKg: 4,
        doseBasis: MedicatedDoseBasis.perKgFeed,
        doseValue: 500,
        productConcentration: 0.5,
        treatmentDays: 10,
      );
      // 500 mg/kg × 4 kg = 2000 mg = 2 g activo.
      expect(plan.activeGramsPerDay, closeTo(2, 1e-9));
    });

    test('si comen la mitad, la dosis real baja a la mitad', () {
      final plan = MedicatedFeedPlan(
        biomassKg: 200,
        dailyFeedKg: 4,
        doseBasis: MedicatedDoseBasis.perFishPerDay,
        doseValue: 10,
        productConcentration: 0.5,
        treatmentDays: 10,
      );
      expect(plan.realDoseAtConsumption(0.5), closeTo(5, 1e-9));
    });
  });

  group('Amonio no ionizado', () {
    test('la fracción sube con el pH y con la temperatura', () {
      final low = unionizedAmmoniaFraction(7.0, 25);
      final highPh = unionizedAmmoniaFraction(8.5, 25);
      final highTemp = unionizedAmmoniaFraction(7.0, 30);
      expect(highPh, greaterThan(low));
      expect(highTemp, greaterThan(low));
    });

    test('el TAN sube al bajar la fracción no ionizada', () {
      final tan = totalAmmoniaNitrogen(0.1, 8.0, 25);
      expect(tan, greaterThan(0.1));
    });

    test('rechaza pH fuera de rango', () {
      expect(() => unionizedAmmoniaFraction(15, 25), throwsFormatException);
    });
  });
}

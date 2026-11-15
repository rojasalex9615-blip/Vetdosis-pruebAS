import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/production/domain/porcino_upp.dart';

/// Reproduce las hojas «Fases», «Lote_Calc» y «Contaminacion» de
/// `UPP_ejemplo_tablas_base.xlsx` (Rancho La Huamuchilera, proyecto 2022).
void main() {
  PorcinoUppBalance upp() => PorcinoUppBalance(
    lines: [
      PorcinoUppLine(phase: _phase('Gestación (cerda)'), animals: 87),
      PorcinoUppLine(phase: _phase('Lactancia (cerda)'), animals: 13),
      PorcinoUppLine(phase: _phase('Lechón predestete'), animals: 20),
      PorcinoUppLine(phase: _phase('Desarrollo / Crecimiento'), animals: 60),
      PorcinoUppLine(phase: _phase('Finalización / Engorde'), animals: 60),
      PorcinoUppLine(phase: _phase('Sementales'), animals: 20),
    ],
  );

  test('Lote_Calc: alimento, agua, superficie y costo', () {
    final b = upp();
    expect(b.totalAnimals, 260);
    expect(b.totalFeedPerDayKg, closeTo(522.5, 1e-6));
    expect(b.totalFeedToCompletePhaseKg, closeTo(51616, 1e-6));
    expect(b.totalBagsPerDay, closeTo(13.0625, 1e-6));
    expect(b.totalFeedCostPerDay, closeTo(4137.25, 1e-6));
    expect(b.totalFeedCostToCompletePhase, closeTo(395000, 1e-3));
    expect(b.totalWaterPerDayL, closeTo(2566, 1e-6));
    expect(b.totalAreaM2, closeTo(544, 1e-6));
    expect(b.totalBiomassKg, closeTo(32837.5, 1e-6));
  });

  test('Contaminacion: excreta, N, P, efluente y superficie agrícola', () {
    final b = upp();
    expect(b.totalExcretaFreshKgDay, closeTo(1229.43, 1e-2));
    expect(b.totalNExcretedKgYear, closeTo(3189.65911842105, 1e-3));
    expect(b.totalPExcretedKgYear, closeTo(725.612796052632, 1e-3));
    expect(b.totalEffluentLDay, closeTo(2574.03, 1e-2));
    expect(b.agriculturalAreaHa, closeTo(18.7627006965944, 1e-3));
    expect(b.pExcretedAsP2O5KgYear, closeTo(1661.65330296053, 1e-2));
    expect(b.effluentM3Year, closeTo(939.52095, 1e-3));
    expect(b.finishingPigNKgPhase, closeTo(1.735, 1e-6));
  });

  test('Balance por fase: excretado = ingerido − retenido', () {
    final b = upp();
    final gestation = b.results.first;
    expect(gestation.nIngestedGDay, closeTo(43.2, 1e-6));
    expect(gestation.nRetainedGDay, closeTo(8.7719298245614, 1e-6));
    expect(gestation.nExcretedGDay, closeTo(34.4280701754386, 1e-6));
    expect(gestation.pExcretedGDay, closeTo(9.07017543859649, 1e-6));
    expect(gestation.excretaFreshKgDay, closeTo(516.78, 1e-2));
    expect(gestation.effluentLDay, closeTo(1343.28, 1e-2));
  });

  test('Lactancia retiene la ganancia de la camada, no la pérdida de la cerda', () {
    final phase = _phase('Lactancia (cerda)');
    expect(phase.gdpKgPerDay, lessThan(0));
    expect(phase.retainedGain, 2.25);
    final b = PorcinoUppBalance(
      lines: [PorcinoUppLine(phase: phase, animals: 13)],
    );
    final r = b.results.single;
    expect(r.nRetainedGDay, closeTo(56.25, 1e-6));
    expect(r.nExcretedGDay, closeTo(41.75, 1e-6));
  });

  test('El lechón predestete no excreta N ni P (lo retiene la camada)', () {
    final b = PorcinoUppBalance(
      lines: [PorcinoUppLine(phase: _phase('Lechón predestete'), animals: 20)],
    );
    expect(b.results.single.nExcretedGDay, 0);
    expect(b.results.single.pExcretedGDay, 0);
    expect(b.totalNExcretedKgYear, 0);
  });

  test('Rechaza fases vacías y consumos no positivos', () {
    expect(() => PorcinoUppBalance(lines: []), throwsFormatException);
    expect(
      () => PorcinoUppBalance(
        lines: [PorcinoUppLine(phase: _phase('Gestación (cerda)'), animals: -1)],
      ),
      throwsFormatException,
    );
    expect(
      () => PorcinoUppBalance(
        lines: [
          PorcinoUppLine(phase: _phase('Sementales'), animals: 1),
        ],
        assumptions: const PorcinoUppAssumptions(nLimitKgHaYear: 0),
      ),
      throwsFormatException,
    );
  });
}

PorcinoUppPhase _phase(String name) =>
    porcinoUppPhases.firstWhere((p) => p.name == name);

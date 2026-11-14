import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/production/domain/porcino_calculators.dart';

void main() {
  group('Ventilación', () {
    VentStage stage(String n) =>
        ventilationStages.firstWhere((s) => s.name == n);

    test('Gestación templado: 80 CFM por animal, 100 animales', () {
      final e = VentilationEstimate(
        stage: stage('Gestación'),
        climate: VentClimate.mild,
        animals: 100,
      );
      expect(e.totalMinCfm, closeTo(8000, 1e-6));
      expect(e.totalMinM3h, closeTo(8000 * cfmToM3h, 1e-6));
      expect(e.isMinimumOnly, isFalse);
      expect(e.isRange, isFalse);
    });

    test('Clima cálido con «>» se marca como mínimo', () {
      final e = VentilationEstimate(
        stage: stage('Maternidad'),
        climate: VentClimate.hot,
        animals: 10,
      );
      expect(e.isMinimumOnly, isTrue);
      expect(e.totalMinCfm, closeTo(7500, 1e-6));
    });

    test('Tabla métrica de destete frío es un rango 8–10 m³/h', () {
      final e = VentilationEstimate(
        stage: stage('Destete'),
        climate: VentClimate.cold,
        animals: 50,
        table: VentTable.metric,
      );
      expect(e.isRange, isTrue);
      expect(e.totalMinM3h, 400);
      expect(e.totalMaxM3h, 500);
    });

    test('Etapa sin tabla métrica la rechaza', () {
      expect(
        () => VentilationEstimate(
          stage: stage('Gestación'),
          climate: VentClimate.cold,
          animals: 5,
          table: VentTable.metric,
        ),
        throwsFormatException,
      );
    });

    test('Animales fuera de rango', () {
      expect(
        () => VentilationEstimate(
          stage: stage('Engorda'),
          climate: VentClimate.cold,
          animals: 0,
        ),
        throwsFormatException,
      );
    });
  });

  group('Capacidad inversa', () {
    test('Caso auditado de clase: 518 cerdos/semana', () {
      expect(
        InverseCapacity(pigsPerWeek: 518, weanedPerSowYear: 30).sows,
        898,
      );
      // La hoja de clase da 769 (factor redondeado a 0.673); exacto es 770.
      expect(
        InverseCapacity(pigsPerWeek: 518, weanedPerSowYear: 35).sows,
        770,
      );
    });

    test('Proyecto Tinguindín: 150000 m², 1.2 m²/cerdo, 24 semanas', () {
      final c = InverseCapacity.fromSpaces(
        totalM2: 150000,
        m2PerPig: 1.2,
        cycleWeeks: 24,
        weanedPerSowYear: 35,
      );
      expect(c.pigsPerWeek, closeTo(5208.33, 0.01));
      expect(c.sows, inInclusiveRange(7738, 7740));
    });

    test('Entradas inválidas', () {
      expect(
        () => InverseCapacity(pigsPerWeek: 0, weanedPerSowYear: 30),
        throwsFormatException,
      );
      expect(
        () => InverseCapacity(pigsPerWeek: 100, weanedPerSowYear: 5),
        throwsFormatException,
      );
    });
  });

  group('Nitrógeno', () {
    test('10 000 cerdos con constantes de Yucatán', () {
      final n = NitrogenFootprint(
        pigs: 10000,
        kgNPerPigYear: 18,
        cNaturalMgL: 1.5,
        cMaxMgL: 3.0,
        areaKm2: 1000,
        unitRechargeM3Km2: 175336,
      );
      expect(n.loadKgNYear, 180000);
      expect(n.greyWaterM3Year, closeTo(120000000, 1e-3));
      expect(n.rechargeM3Year, 175336000);
      expect(n.nca, closeTo(0.684, 0.001));
      expect(n.ncaReading, 'Dentro del rango sustentable');
    });

    test('NCA mayor que 2 es crítico', () {
      final n = NitrogenFootprint(
        pigs: 100000,
        kgNPerPigYear: 18,
        cNaturalMgL: 1.5,
        cMaxMgL: 3.0,
        areaKm2: 500,
        unitRechargeM3Km2: 175336,
      );
      expect(n.nca! > 2, isTrue);
      expect(n.ncaReading, contains('críticas'));
    });

    test('Sin superficie no hay NCA', () {
      final n = NitrogenFootprint(
        pigs: 10,
        kgNPerPigYear: 18,
        cNaturalMgL: 1.5,
        cMaxMgL: 3.0,
      );
      expect(n.nca, isNull);
      expect(n.ncaReading, isNull);
    });

    test('Cmax no puede ser menor o igual a Cnat; superficie sin recarga', () {
      expect(
        () => NitrogenFootprint(
          pigs: 1,
          kgNPerPigYear: 18,
          cNaturalMgL: 3,
          cMaxMgL: 3,
        ),
        throwsFormatException,
      );
      expect(
        () => NitrogenFootprint(
          pigs: 1,
          kgNPerPigYear: 18,
          cNaturalMgL: 1.5,
          cMaxMgL: 3,
          areaKm2: 10,
        ),
        throwsFormatException,
      );
    });
  });

  test('Distancias entre granjas', () {
    expect(classifyFarmDistance(0.2), DistanceBand.veryClose);
    expect(classifyFarmDistance(0.5), DistanceBand.risk);
    expect(classifyFarmDistance(2.9), DistanceBand.risk);
    expect(classifyFarmDistance(3), DistanceBand.intermediate);
    expect(classifyFarmDistance(10), DistanceBand.intermediate);
    expect(classifyFarmDistance(10.1), DistanceBand.far);
    expect(() => classifyFarmDistance(-1), throwsFormatException);
  });
}

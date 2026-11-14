import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/production/domain/porcino_facilities.dart';
import 'package:vetdosis_pro/modules/production/domain/porcino_reference.dart';

void main() {
  test('La densidad sale de la tabla y es nula si el peso no está', () {
    expect(swineDensityFor(25, PorcinoFloor.slat), 0.29);
    expect(swineDensityFor(120, PorcinoFloor.solid), 1.15);
    expect(swineDensityFor(45, PorcinoFloor.slat), isNull);
    expect(swineDensityWeights, [25, 30, 100, 120, 130]);
  });

  test('Capacidad de corral reproduce el ejemplo de la calculadora', () {
    // 120 m² ÷ 0.65 m²/animal ≈ 184.6 → 184 animales.
    final pen = PenCapacity(
      availableM2: 120,
      m2PerAnimal: 0.65,
      animals: 150,
    );
    expect(pen.capacity, 184);
    expect(pen.requiredM2, closeTo(97.5, 1e-9));
    expect(pen.differenceM2, closeTo(22.5, 1e-9));
    expect(pen.fits, isTrue);
  });

  test('La capacidad se redondea hacia abajo, nunca hacia arriba', () {
    final pen = PenCapacity(availableM2: 10, m2PerAnimal: 3, animals: 1);
    expect(pen.capacity, 3);
  });

  test('Diferencia negativa cuando no caben los animales declarados', () {
    final pen = PenCapacity(availableM2: 10, m2PerAnimal: 0.65, animals: 30);
    expect(pen.fits, isFalse);
    expect(pen.differenceM2, closeTo(10 - 19.5, 1e-9));
  });

  test('Rechaza superficie o densidad no positivas', () {
    expect(
      () => PenCapacity(availableM2: 0, m2PerAnimal: 0.65, animals: 1),
      throwsFormatException,
    );
    expect(
      () => PenCapacity(availableM2: 10, m2PerAnimal: 0, animals: 1),
      throwsFormatException,
    );
    expect(
      () => PenCapacity(availableM2: 10, m2PerAnimal: 0.65, animals: -1),
      throwsFormatException,
    );
  });

  test('Dimensionamiento es animales × m² por animal', () {
    final sizing = FacilitySizing(animals: 200, m2PerAnimal: 0.75);
    expect(sizing.requiredM2, closeTo(150, 1e-9));
  });

  test('Balance separa déficit de sobrante, nunca los dos', () {
    final falta = AreaBalance(existingM2: 100, requiredM2: 140);
    expect(falta.hasDeficit, isTrue);
    expect(falta.deficitM2, closeTo(40, 1e-9));
    expect(falta.surplusM2, 0);

    final sobra = AreaBalance(existingM2: 160, requiredM2: 140);
    expect(sobra.hasDeficit, isFalse);
    expect(sobra.deficitM2, 0);
    expect(sobra.surplusM2, closeTo(20, 1e-9));

    final igual = AreaBalance(existingM2: 140, requiredM2: 140);
    expect(igual.hasDeficit, isFalse);
    expect(igual.deficitM2, 0);
    expect(igual.surplusM2, closeTo(0, 1e-9));
  });

  test('Capacidad productiva por etapa y su cuello de botella', () {
    final plan = StageCapacityPlan([
      const StageArea(stage: 'Maternidad', areaM2: 96, m2PerAnimal: 1.6),
      const StageArea(stage: 'Destete', areaM2: 400, m2PerAnimal: 0.34),
      const StageArea(stage: 'Engorda', areaM2: 500, m2PerAnimal: 0.73),
    ]);
    expect(plan.capacities, [60, 1176, 684]);
    expect(plan.totalCapacity, 60 + 1176 + 684);
    expect(plan.bottleneckStage.stage, 'Maternidad');
    expect(plan.bottleneckCapacity, 60);
  });

  test('Un empate de capacidad se resuelve por el orden dado', () {
    final plan = StageCapacityPlan([
      const StageArea(stage: 'A', areaM2: 10, m2PerAnimal: 1),
      const StageArea(stage: 'B', areaM2: 20, m2PerAnimal: 2),
    ]);
    expect(plan.bottleneckStage.stage, 'A');
  });

  test('El plan rechaza etapas vacías o inválidas', () {
    expect(() => StageCapacityPlan([]), throwsFormatException);
    expect(
      () => StageCapacityPlan([
        const StageArea(stage: '  ', areaM2: 10, m2PerAnimal: 1),
      ]),
      throwsFormatException,
    );
    expect(
      () => StageCapacityPlan([
        const StageArea(stage: 'A', areaM2: 10, m2PerAnimal: 0),
      ]),
      throwsFormatException,
    );
  });

  test('Proyección: solo falta superficie si la meta crece', () {
    final crece = GrowthProjection(
      currentAnimals: 500,
      targetAnimals: 800,
      m2PerAnimal: 0.73,
    );
    expect(crece.additionalAnimals, 300);
    expect(crece.additionalM2, closeTo(219, 1e-9));

    final noCrece = GrowthProjection(
      currentAnimals: 800,
      targetAnimals: 500,
      m2PerAnimal: 0.73,
    );
    expect(noCrece.additionalAnimals, 0);
    expect(noCrece.additionalM2, 0);
  });
}

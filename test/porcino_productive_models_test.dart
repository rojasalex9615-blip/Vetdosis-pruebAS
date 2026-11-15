import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/production/domain/porcino_productive_models.dart';

/// Fija los datos del CSV
/// `VetDosis_Modelos_Productivos_PorkSchool.csv` (Pork School, ago-2026):
/// el Modelo 2400 en tres escenarios y los KPIs históricos.
void main() {
  test('El Modelo 2400 conserva los tres escenarios del CSV', () {
    final byName = {for (final s in porcinoModel2400Scenarios) s.name: s};
    expect(porcinoModel2400Scenarios, hasLength(3));

    final avg = byName['Promedio']!;
    expect(avg.farrowingsPerWeek, 107);
    expect(avg.farrowingsPerSowPerYear, 2.3);
    expect(avg.fertility, 0.85);
    expect(avg.productiveSows, 2412);
    expect(avg.servicesPerWeek, 125);
    expect(avg.weanedPerLitter, 9.0);
    expect(avg.weanedPigsPerServedSowPerYear, 20.7);
    expect(avg.overproductionTargetPct, 10);

    final top30 = byName['Top 30 %']!;
    expect(top30.farrowingsPerWeek, 101);
    expect(top30.farrowingsPerSowPerYear, 2.35);
    expect(top30.productiveSows, 2236);
    expect(top30.weanedPerLitter, 9.5);
    expect(top30.weanedPigsPerServedSowPerYear, 22.3);
    expect(top30.overproductionTargetPct, 5);

    final top10 = byName['Top 10 %']!;
    expect(top10.farrowingsPerWeek, 96);
    expect(top10.farrowingsPerSowPerYear, 2.4);
    expect(top10.fertility, 0.87);
    expect(top10.productiveSows, 2080);
    expect(top10.weanedPerLitter, 10.0);
    expect(top10.weanedPigsPerServedSowPerYear, 24.0);
    expect(top10.overproductionTargetPct, 0);
  });

  test('Los indicadores derivados reproducen las cifras publicadas', () {
    for (final s in porcinoModel2400Scenarios) {
      // Destetados/hembra servida/año = destetados/parto × partos/hembra/año.
      expect(
        s.weanedPigsPerServedSowPerYearComputed,
        closeTo(s.weanedPigsPerServedSowPerYear, 0.05),
      );
    }
    // El CSV solo publica servicios/semana para el promedio; 125 × 0.85 ≈ 107.
    final avg = porcinoModel2400Scenarios.first;
    expect(avg.farrowingsPerWeekComputed, closeTo(107, 1.5));
    expect(porcinoModel2400Scenarios[1].farrowingsPerWeekComputed, isNull);
    expect(porcinoModel2400Scenarios[2].farrowingsPerWeekComputed, isNull);
  });

  test('Lechones destetados por semana = partos × destetados por parto', () {
    final avg = porcinoModel2400Scenarios.first;
    expect(avg.weanedPigsPerWeek, closeTo(107 * 9.0, 1e-9));
    expect(avg.surplusPigsPerWeek, closeTo(107 * 9.0 * 0.10, 1e-9));
    final top10 = porcinoModel2400Scenarios.last;
    expect(top10.surplusPigsPerWeek, 0);
  });

  test('Los parámetros fijos del modelo son los del CSV', () {
    expect(porcinoModel2400Sows, 2400);
    expect(porcinoModel2400Crates, 384);
    expect(porcinoModel2400ReplacementPct, 45);
    expect(porcinoModel2400Factor, 25);
    expect(porcinoModel2400ProcessWeeks, 25);
    expect(porcinoModel2400BandSystem, '4-8-16');
  });

  test('Los KPIs históricos conservan los valores de la clase', () {
    expect(porcinoHistoricalKpis, hasLength(4));
    final byLabel = {for (final k in porcinoHistoricalKpis) k.label: k.value};
    expect(byLabel['Destetados por camada al mes'], '10');
    expect(byLabel['Vendidos por vientre al mes'], '1.5');
    expect(byLabel['Kg vendidos por hembra al año'], '1800');
    expect(byLabel['Conversión alimenticia'], '3.5 : 1');
  });
}

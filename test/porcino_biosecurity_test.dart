import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/production/domain/porcino_biosecurity.dart';

/// Fija los datos del CSV `VetDosis_Bioseguridad_PorkSchool.csv` (Pork School,
/// ago-2026): impacto económico por KPI, filtración de aire y distancias.
void main() {
  test('Los cuatro KPIs reproducen la diapositiva (€/cerdo y €/lechón)', () {
    expect(porcinoKpiImpacts.map((k) => k.label), [
      'Mortalidad destete–engorde',
      'Conversión alimenticia',
      'Lechones destetados (PSY)',
      'Día no productivo (DNP)',
    ]);
    final byLabel = {for (final k in porcinoKpiImpacts) k.label: k};
    expect(byLabel['Mortalidad destete–engorde']!.perUnitLow, 0.44);
    expect(byLabel['Mortalidad destete–engorde']!.perUnitHigh, 0.88);
    expect(byLabel['Conversión alimenticia']!.perUnitLow, 0.59);
    expect(byLabel['Conversión alimenticia']!.perUnitHigh, 3.84);
    expect(byLabel['Lechones destetados (PSY)']!.perUnitLow, 1.4);
    expect(byLabel['Día no productivo (DNP)']!.perUnitLow, 0.23);
  });

  test('Impacto de 1 punto de mortalidad da el rango 0.44–0.88 €/cerdo', () {
    final impact = PorcinoEconomicImpact(
      changes: {'Mortalidad destete–engorde': 1},
    );
    expect(impact.totalLowEur, closeTo(0.44, 1e-9));
    expect(impact.totalHighEur, closeTo(0.88, 1e-9));
  });

  test('Suma varios conceptos en cada escenario', () {
    final impact = PorcinoEconomicImpact(
      changes: {
        'Mortalidad destete–engorde': 2, // 0.88 / 1.76
        'Conversión alimenticia': 1, // 0.59 / 3.84
        'Día no productivo (DNP)': 5, // 1.15 / 1.15
      },
    );
    expect(impact.totalLowEur, closeTo(0.88 + 0.59 + 1.15, 1e-9));
    expect(impact.totalHighEur, closeTo(1.76 + 3.84 + 1.15, 1e-9));
  });

  test('Un concepto sin cambio no aporta y el mapa vacío da cero', () {
    expect(PorcinoEconomicImpact(changes: {}).totalLowEur, 0);
    final impact = PorcinoEconomicImpact(
      changes: {'Lechones destetados (PSY)': 0},
    );
    expect(impact.totalLowEur, 0);
    expect(impact.totalHighEur, 0);
  });

  test('Rechaza conceptos desconocidos y valores negativos', () {
    expect(
      () => PorcinoEconomicImpact(changes: {'Inventado': 1}),
      throwsFormatException,
    );
    expect(
      () => PorcinoEconomicImpact(changes: {'Día no productivo (DNP)': -1}),
      throwsFormatException,
    );
  });

  test('La filtración de aire reduce 8 veces el brote de PRRS', () {
    expect(porcinoPrrsFilterReductionFactor, 8.0);
  });

  test('Las distancias de referencia son 8 y 80 km', () {
    expect(porcinoDistanceReferences, [8, 80]);
  });
}

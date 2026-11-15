/// Bioseguridad porcina: impacto económico de los KPIs, efecto de la filtración
/// de aire y distancias de referencia entre granjas.
///
/// Fuente: «Concepto, manejo y diseño de Bioseguridad» (Jean Paul Cano,
/// Pork School ago-2026), volcado en `VetDosis_Bioseguridad_PorkSchool.csv`.
/// Puro y sin estado. Los importes son de la diapositiva (€/cerdo o €/lechón):
/// referencias de clase, no cotizaciones ni metas de rendimiento.
library;

FormatException _invalid(String message) => FormatException(message);

/// Impacto de una mejora o un desvío sobre el margen, en euros por cabeza.
///
/// Cada concepto se mide por unidad de cambio (1 punto de mortalidad, 100 g de
/// conversión, 1 PSY, 1 día no productivo) y da un rango porque la diapositiva
/// ofrece dos cifras según el escenario. No son importes en moneda local: son
/// euros de la fuente.
class PorcinoKpiImpact {
  const PorcinoKpiImpact({
    required this.label,
    required this.unit,
    required this.perUnitLow,
    required this.perUnitHigh,
    required this.basis,
  });

  final String label;
  final String unit;
  final double perUnitLow, perUnitHigh;
  final String basis;

  double impactLow(double units) => units * perUnitLow;
  double impactHigh(double units) => units * perUnitHigh;
}

/// Impactos publicados en la diapositiva de KPIs (€/cerdo y €/lechón).
const porcinoKpiImpacts = <PorcinoKpiImpact>[
  PorcinoKpiImpact(
    label: 'Mortalidad destete–engorde',
    unit: 'punto porcentual',
    perUnitLow: 0.44,
    perUnitHigh: 0.88,
    basis: 'Por 1 % de mortalidad en destete y engorde.',
  ),
  PorcinoKpiImpact(
    label: 'Conversión alimenticia',
    unit: '100 g',
    perUnitLow: 0.59,
    perUnitHigh: 3.84,
    basis: 'Por cada 100 g de conversión alimenticia.',
  ),
  PorcinoKpiImpact(
    label: 'Lechones destetados (PSY)',
    unit: 'lechón',
    perUnitLow: 1.4,
    perUnitHigh: 1.4,
    basis: 'Por 1 lechón destetado adicional por cerda al año.',
  ),
  PorcinoKpiImpact(
    label: 'Día no productivo (DNP)',
    unit: 'día',
    perUnitLow: 0.23,
    perUnitHigh: 0.23,
    basis: 'Por 1 día no productivo.',
  ),
];

/// Estima el impacto económico de un conjunto de cambios de KPI.
///
/// [changes] son unidades de cambio por concepto (por ejemplo, 1.5 puntos de
/// mortalidad o 200 g de conversión). Solo acepta las claves de
/// [porcinoKpiImpacts]; una clave desconocida o un valor negativo se rechazan.
class PorcinoEconomicImpact {
  PorcinoEconomicImpact({required this.changes}) {
    for (final entry in changes.entries) {
      if (!porcinoKpiImpacts.any((k) => k.label == entry.key)) {
        throw _invalid('Concepto desconocido: ${entry.key}.');
      }
      if (!entry.value.isFinite || entry.value < 0) {
        throw _invalid('${entry.key}: usa un número no negativo.');
      }
    }
  }

  /// Cambios por concepto, en las unidades de cada [PorcinoKpiImpact].
  final Map<String, double> changes;

  /// Total por cabeza, en el escenario bajo de la fuente.
  double get totalLowEur => _total((k) => k.perUnitLow);

  /// Total por cabeza, en el escenario alto de la fuente.
  double get totalHighEur => _total((k) => k.perUnitHigh);

  double _total(double Function(PorcinoKpiImpact) pick) {
    var sum = 0.0;
    for (final k in porcinoKpiImpacts) {
      final units = changes[k.label];
      if (units == null) continue;
      sum += units * pick(k);
    }
    return sum;
  }
}

/// Probabilidad de brote de PRRS descrita tras instalar filtros de aire.
const porcinoPrrsFilterReductionFactor = 8.0;

/// Distancias de referencia entre granjas (km) que aparecen en la diapositiva
/// pero que no fijan un umbral operativo; se muestran como contexto.
const porcinoDistanceReferences = <double>[8, 80];

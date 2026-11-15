/// Modelos productivos porcinos (Pork School, ago-2026): el «Modelo 2400» en
/// tres escenarios (promedio, Top 30 %, Top 10 %) y los KPIs históricos de la
/// década de 1960 y anteriores.
///
/// Fuente: `VetDosis_Modelos_Productivos_PorkSchool.csv`. Puro y sin estado.
/// Son valores de referencia de material de clase (no metas de rendimiento ni
/// límites operativos) y no tienen validación externa independiente.
library;

import 'porcino_reference.dart';

const porcinoProductiveModelsSource =
    'Modelos Productivos (Carlos Alberto Félix Rosas, Pork School ago-2026). '
    'Material de clase, sin validación externa.';

/// Un escenario del Modelo 2400. Los campos son los del CSV; los indicadores
/// derivados se calculan con los getters.
class PorcinoModel2400Scenario {
  const PorcinoModel2400Scenario({
    required this.name,
    required this.farrowingsPerWeek,
    required this.farrowingsPerSowPerYear,
    required this.fertility,
    required this.productiveSows,
    this.servicesPerWeek,
    required this.weanedPerLitter,
    required this.weanedPigsPerServedSowPerYear,
    required this.overproductionTargetPct,
  });

  final String name;

  /// Partos por semana.
  final double farrowingsPerWeek;

  /// Partos por hembra al año.
  final double farrowingsPerSowPerYear;

  /// Tasa de fertilidad (proporción 0–1).
  final double fertility;

  /// Vientres productivos del hato.
  final double productiveSows;

  /// Servicios por semana. El CSV solo lo publica para el escenario promedio.
  final double? servicesPerWeek;

  /// Lechones destetados por parto.
  final double weanedPerLitter;

  /// Lechones destetados por hembra servida al año (lo publica el CSV).
  final double weanedPigsPerServedSowPerYear;

  /// Objetivo de sobreproducción de lechones, en % (para tener margen de
  /// selección y cubrir mortalidad).
  final double overproductionTargetPct;

  /// Lechones destetados por hembra servida al año = destetados por parto ×
  /// partos por hembra al año. Reproduce el valor publicado.
  double get weanedPigsPerServedSowPerYearComputed =>
      weanedPerLitter * farrowingsPerSowPerYear;

  /// Partos por semana implícitos = servicios por semana × fertilidad. Null si
  /// el CSV no publica servicios para este escenario.
  double? get farrowingsPerWeekComputed {
    final services = servicesPerWeek;
    return services == null ? null : services * fertility;
  }

  /// Factor vientres ÷ partos por semana del escenario.
  double get factorSowsPerFarrowing =>
      farrowingsPerWeek == 0 ? 0 : productiveSows / farrowingsPerWeek;

  /// Lechones destetados por semana = partos por semana × destetados por parto.
  double get weanedPigsPerWeek => farrowingsPerWeek * weanedPerLitter;

  /// Lechones extra por semana según el objetivo de sobreproducción.
  double get surplusPigsPerWeek =>
      weanedPigsPerWeek * overproductionTargetPct / 100;
}

/// El Modelo 2400 en sus tres escenarios. [porcinoModel2400Sows],
/// [porcinoModel2400Crates], [porcinoModel2400Factor] y
/// [porcinoModel2400ReplacementPct] son fijos en los tres escenarios.
const porcinoModel2400Scenarios = <PorcinoModel2400Scenario>[
  PorcinoModel2400Scenario(
    name: 'Promedio',
    farrowingsPerWeek: 107,
    farrowingsPerSowPerYear: 2.3,
    fertility: 0.85,
    productiveSows: 2412,
    servicesPerWeek: 125,
    weanedPerLitter: 9.0,
    weanedPigsPerServedSowPerYear: 20.7,
    overproductionTargetPct: 10,
  ),
  PorcinoModel2400Scenario(
    name: 'Top 30 %',
    farrowingsPerWeek: 101,
    farrowingsPerSowPerYear: 2.35,
    fertility: 0.85,
    productiveSows: 2236,
    weanedPerLitter: 9.5,
    weanedPigsPerServedSowPerYear: 22.3,
    overproductionTargetPct: 5,
  ),
  PorcinoModel2400Scenario(
    name: 'Top 10 %',
    farrowingsPerWeek: 96,
    farrowingsPerSowPerYear: 2.4,
    fertility: 0.87,
    productiveSows: 2080,
    weanedPerLitter: 10.0,
    weanedPigsPerServedSowPerYear: 24.0,
    overproductionTargetPct: 0,
  ),
];

/// Parámetros del Modelo 2400 iguales en los tres escenarios.
const porcinoModel2400Sows = 2400;
const porcinoModel2400Crates = 384; // 8 salas × 48 jaulas de maternidad.
const porcinoModel2400ReplacementPct = 45;

/// Factor del «sistema simple»: parideras semanales × 25 = vientres
/// productivos (equivale a 52 ÷ 25 = 2.08 partos por hembra al año).
const porcinoModel2400Factor = 25;

/// Semanas de proceso de un cerdo de nacimiento a mercado (110 kg): 175 días.
const porcinoModel2400ProcessWeeks = 25;

/// Sistema de bandas 4-8-16: 3+1 maternidad, 7+1 destete, 15+1 engorda
/// (la semana «+1» es de limpieza y vacío).
const porcinoModel2400BandSystem = '4-8-16';

/// Un indicador histórico de la década de 1960 y anteriores, tal como lo cita
/// la clase. No son metas: son la referencia de hace más de medio siglo.
class PorcinoHistoricalKpi {
  const PorcinoHistoricalKpi(this.label, this.value, {this.note});
  final String label, value;
  final String? note;
}

const porcinoHistoricalKpis = <PorcinoHistoricalKpi>[
  PorcinoHistoricalKpi(
    'Destetados por camada al mes',
    '10',
    note: 'Historia 60s y antes.',
  ),
  PorcinoHistoricalKpi('Vendidos por vientre al mes', '1.5'),
  PorcinoHistoricalKpi('Kg vendidos por hembra al año', '1800'),
  PorcinoHistoricalKpi(
    'Conversión alimenticia',
    '3.5 : 1',
    note: 'Kg de alimento por kg de peso vivo.',
  ),
];

/// Los KPIs históricos como filas de tarjeta de referencia.
final porcinoHistoricalKpiRows = <PorcinoReferenceRow>[
  for (final kpi in porcinoHistoricalKpis)
    PorcinoReferenceRow(kpi.label, kpi.value, note: kpi.note),
];

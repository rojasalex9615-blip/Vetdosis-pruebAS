/// UPP de ejemplo (Rancho La Huamuchilera, Proyecto Semestral 2022): tablas
/// base de producción (fases, alimento, agua, espacio, costo) y de
/// contaminación (excreta, nitrógeno, fósforo, efluente y superficie agrícola).
///
/// Los datos del proyecto 2022 son **ilustrativos y sin confirmar** con el
/// productor; proteína y fósforo de la dieta son referencias típicas, no la
/// mezcla real de granos. Sirven para ordenar el cálculo, no como medición.
/// Puro y sin estado.
library;

FormatException _invalid(String message) => FormatException(message);

void _positive(double value, String label, {double max = 1e9}) {
  if (!value.isFinite || value <= 0 || value > max) {
    throw _invalid('$label: mayor que 0 y hasta ${max.toStringAsFixed(0)}.');
  }
}

void _count(int value, String label) {
  if (value < 0 || value > 1000000) {
    throw _invalid('$label: entero de 0 a 1 000 000.');
  }
}

/// Una fase productiva con sus datos de la hoja «Fases».
///
/// [retainedGainKgPerDay] solo se usa cuando la retención de N y P no sale de
/// la ganancia de la propia fase: en lactancia la cerda pierde peso y lo que se
/// retiene es la ganancia de la camada.
class PorcinoUppPhase {
  const PorcinoUppPhase({
    required this.name,
    required this.weightInKg,
    required this.weightOutKg,
    required this.days,
    required this.feedKgPerDay,
    required this.waterLPerDay,
    required this.spaceM2,
    required this.tempC,
    required this.crudeProteinPct,
    required this.phosphorusPct,
    required this.excretaPctLiveWeight,
    required this.feedPricePerKg,
    required this.gdpKgPerDay,
    this.retainedGainKgPerDay,
  });

  final String name;
  final double weightInKg, weightOutKg, feedKgPerDay, waterLPerDay, spaceM2;
  final double tempC, crudeProteinPct, phosphorusPct, excretaPctLiveWeight;
  final double feedPricePerKg, gdpKgPerDay;
  final int days;
  final double? retainedGainKgPerDay;

  double get weightMidKg => (weightInKg + weightOutKg) / 2;

  /// Ganancia que retiene N y P: la de la fase, o la de la camada en lactancia.
  double get retainedGain => retainedGainKgPerDay ?? gdpKgPerDay;

  /// Alimento ÷ ganancia diaria; 0 si la fase no gana peso.
  double get feedConversion => gdpKgPerDay == 0 ? 0 : feedKgPerDay / gdpKgPerDay;
}

/// Fases de la hoja «Fases». Precios en MXN de ejemplo.
const porcinoUppPhases = <PorcinoUppPhase>[
  PorcinoUppPhase(
    name: 'Gestación (cerda)',
    weightInKg: 200,
    weightOutKg: 240,
    days: 114,
    feedKgPerDay: 2,
    waterLPerDay: 15,
    spaceM2: 4,
    tempC: 18,
    crudeProteinPct: 13.5,
    phosphorusPct: 0.55,
    excretaPctLiveWeight: 2.7,
    feedPricePerKg: 7.5,
    gdpKgPerDay: 40 / 114,
  ),
  PorcinoUppPhase(
    name: 'Lactancia (cerda)',
    weightInKg: 240,
    weightOutKg: 225,
    days: 20,
    feedKgPerDay: 3.5,
    waterLPerDay: 25,
    spaceM2: 4,
    tempC: 22,
    crudeProteinPct: 17.5,
    phosphorusPct: 0.65,
    excretaPctLiveWeight: 6,
    feedPricePerKg: 9.5,
    gdpKgPerDay: -0.75,
    retainedGainKgPerDay: 2.25,
  ),
  PorcinoUppPhase(
    name: 'Lechón predestete',
    weightInKg: 1.5,
    weightOutKg: 6,
    days: 20,
    feedKgPerDay: 0.05,
    waterLPerDay: 0.3,
    spaceM2: 0,
    tempC: 30,
    crudeProteinPct: 20,
    phosphorusPct: 0.7,
    excretaPctLiveWeight: 10,
    feedPricePerKg: 18,
    gdpKgPerDay: 4.5 / 20,
  ),
  PorcinoUppPhase(
    name: 'Destete / Posdestete',
    weightInKg: 6,
    weightOutKg: 20,
    days: 35,
    feedKgPerDay: 0.6,
    waterLPerDay: 1.5,
    spaceM2: 0.15,
    tempC: 26,
    crudeProteinPct: 19,
    phosphorusPct: 0.65,
    excretaPctLiveWeight: 10.6,
    feedPricePerKg: 13,
    gdpKgPerDay: 0.4,
  ),
  PorcinoUppPhase(
    name: 'Desarrollo / Crecimiento',
    weightInKg: 20,
    weightOutKg: 55,
    days: 50,
    feedKgPerDay: 1.95,
    waterLPerDay: 4.5,
    spaceM2: 1,
    tempC: 20,
    crudeProteinPct: 16.5,
    phosphorusPct: 0.55,
    excretaPctLiveWeight: 6.3,
    feedPricePerKg: 8.5,
    gdpKgPerDay: 0.7,
  ),
  PorcinoUppPhase(
    name: 'Finalización / Engorde',
    weightInKg: 55,
    weightOutKg: 90,
    days: 50,
    feedKgPerDay: 2.25,
    waterLPerDay: 7,
    spaceM2: 1,
    tempC: 20,
    crudeProteinPct: 14.5,
    phosphorusPct: 0.45,
    excretaPctLiveWeight: 6.3,
    feedPricePerKg: 7.5,
    gdpKgPerDay: 0.7,
  ),
  PorcinoUppPhase(
    name: 'Sementales',
    weightInKg: 200,
    weightOutKg: 200,
    days: 365,
    feedKgPerDay: 2.5,
    waterLPerDay: 12,
    spaceM2: 1.2,
    tempC: 18,
    crudeProteinPct: 13.5,
    phosphorusPct: 0.55,
    excretaPctLiveWeight: 2.7,
    feedPricePerKg: 7.5,
    gdpKgPerDay: 0,
  ),
];

/// Supuestos globales de la hoja «Supuestos».
class PorcinoUppAssumptions {
  const PorcinoUppAssumptions({
    this.feedBagKg = 40,
    this.daysPerYear = 365,
    this.waterLossFraction = 0.1,
    this.washWaterLPerM2Day = 2,
    this.nLimitKgHaYear = 170,
    this.nRetentionFraction = 0.025,
    this.pRetentionFraction = 0.0055,
    this.proteinToNFactor = 6.25,
    this.pToP2O5 = 2.29,
  });

  final double feedBagKg, waterLossFraction, washWaterLPerM2Day;
  final int daysPerYear;
  final double nLimitKgHaYear, nRetentionFraction, pRetentionFraction;
  final double proteinToNFactor, pToP2O5;
}

/// Una fase con su número de animales (inventario).
class PorcinoUppLine {
  const PorcinoUppLine({required this.phase, required this.animals});
  final PorcinoUppPhase phase;
  final int animals;
}

/// Resultado de una fase: alimento, agua, espacio, costo y balance de N y P.
class PorcinoUppLineResult {
  const PorcinoUppLineResult({
    required this.line,
    required this.assumptions,
    required this.feedPerDayKg,
    required this.feedToCompletePhaseKg,
    required this.waterPerDayL,
    required this.areaM2,
    required this.feedCostPerDay,
    required this.feedCostToCompletePhase,
    required this.biomassKg,
    required this.excretaFreshKgDay,
    required this.nIngestedGDay,
    required this.nRetainedGDay,
    required this.nExcretedGDay,
    required this.pIngestedGDay,
    required this.pRetainedGDay,
    required this.pExcretedGDay,
    required this.effluentLDay,
  });

  final PorcinoUppLine line;
  final PorcinoUppAssumptions assumptions;
  final double feedPerDayKg, feedToCompletePhaseKg, waterPerDayL, areaM2;
  final double feedCostPerDay, feedCostToCompletePhase, biomassKg;
  final double excretaFreshKgDay;
  final double nIngestedGDay, nRetainedGDay, nExcretedGDay;
  final double pIngestedGDay, pRetainedGDay, pExcretedGDay;
  final double effluentLDay;

  PorcinoUppPhase get phase => line.phase;
  int get animals => line.animals;

  double get bagsPerDay => feedPerDayKg / assumptions.feedBagKg;

  double get nExcretedKgYear =>
      nExcretedGDay * animals * assumptions.daysPerYear / 1000;

  double get pExcretedKgYear =>
      pExcretedGDay * animals * assumptions.daysPerYear / 1000;
}

/// Balance de la UPP: producción (alimento, agua, espacio, costo) y
/// contaminación (excreta, N, P, efluente, superficie agrícola).
class PorcinoUppBalance {
  PorcinoUppBalance({
    required this.lines,
    this.assumptions = const PorcinoUppAssumptions(),
  }) {
    if (lines.isEmpty) throw _invalid('Agrega al menos una fase.');
    for (final line in lines) {
      _count(line.animals, 'Animales en ${line.phase.name}');
      _positive(line.phase.feedKgPerDay, 'Consumo de ${line.phase.name}');
    }
    _positive(assumptions.feedBagKg, 'Peso del bulto');
    if (assumptions.daysPerYear < 1 || assumptions.daysPerYear > 366) {
      throw _invalid('Días del año: entero de 1 a 366.');
    }
    _positive(assumptions.nLimitKgHaYear, 'Límite de N por hectárea');
    _positive(assumptions.proteinToNFactor, 'Factor de proteína a N');
    _positive(assumptions.pToP2O5, 'Factor P a P2O5');
  }

  final List<PorcinoUppLine> lines;
  final PorcinoUppAssumptions assumptions;

  List<PorcinoUppLineResult> get results => [
    for (final line in lines) _result(line),
  ];

  PorcinoUppLineResult _result(PorcinoUppLine line) {
    final p = line.phase;
    final a = line.animals;
    final feedPerDay = p.feedKgPerDay * a;
    final feedToComplete = feedPerDay * p.days;
    final waterPerDay = p.waterLPerDay * a;
    final area = p.spaceM2 * a;
    final biomass = p.weightMidKg * a;
    final excretaFresh = p.excretaPctLiveWeight / 100 * p.weightMidKg * a;

    final nIngested =
        p.feedKgPerDay * p.crudeProteinPct / 100 * 1000 / assumptions.proteinToNFactor;
    final nRetained = p.retainedGain * assumptions.nRetentionFraction * 1000;
    final pIngested = p.feedKgPerDay * p.phosphorusPct / 100 * 1000;
    final pRetained = p.retainedGain * assumptions.pRetentionFraction * 1000;

    final effluent =
        excretaFresh +
        waterPerDay * assumptions.waterLossFraction +
        assumptions.washWaterLPerM2Day * area;

    return PorcinoUppLineResult(
      line: line,
      assumptions: assumptions,
      feedPerDayKg: feedPerDay,
      feedToCompletePhaseKg: feedToComplete,
      waterPerDayL: waterPerDay,
      areaM2: area,
      feedCostPerDay: feedPerDay * p.feedPricePerKg,
      feedCostToCompletePhase: feedToComplete * p.feedPricePerKg,
      biomassKg: biomass,
      excretaFreshKgDay: excretaFresh,
      nIngestedGDay: nIngested,
      nRetainedGDay: nRetained,
      nExcretedGDay: _clamp0(nIngested - nRetained),
      pIngestedGDay: pIngested,
      pRetainedGDay: pRetained,
      pExcretedGDay: _clamp0(pIngested - pRetained),
      effluentLDay: effluent,
    );
  }

  static double _clamp0(double v) => v < 0 ? 0 : v;

  double get totalFeedPerDayKg => _sum((r) => r.feedPerDayKg);
  double get totalFeedToCompletePhaseKg =>
      _sum((r) => r.feedToCompletePhaseKg);
  double get totalBagsPerDay => _sum((r) => r.bagsPerDay);
  double get totalFeedCostPerDay => _sum((r) => r.feedCostPerDay);
  double get totalFeedCostToCompletePhase =>
      _sum((r) => r.feedCostToCompletePhase);
  double get totalWaterPerDayL => _sum((r) => r.waterPerDayL);
  double get totalAreaM2 => _sum((r) => r.areaM2);
  double get totalBiomassKg => _sum((r) => r.biomassKg);
  double get totalExcretaFreshKgDay => _sum((r) => r.excretaFreshKgDay);
  double get totalNExcretedKgYear => _sum((r) => r.nExcretedKgYear);
  double get totalPExcretedKgYear => _sum((r) => r.pExcretedKgYear);
  double get totalEffluentLDay => _sum((r) => r.effluentLDay);
  int get totalAnimals => lines.fold(0, (sum, l) => sum + l.animals);

  /// Superficie agrícola para absorber el N con el límite de aplicación.
  double get agriculturalAreaHa => totalNExcretedKgYear / assumptions.nLimitKgHaYear;

  double get pExcretedAsP2O5KgYear => totalPExcretedKgYear * assumptions.pToP2O5;

  double get effluentM3Year => totalEffluentLDay * assumptions.daysPerYear / 1000;

  /// N excretado por un cerdo de finalización en toda la fase (kg).
  double? get finishingPigNKgPhase {
    for (final r in results) {
      if (r.phase.name.startsWith('Finalización')) {
        return r.nExcretedGDay * r.phase.days / 1000;
      }
    }
    return null;
  }

  double _sum(double Function(PorcinoUppLineResult) pick) {
    var sum = 0.0;
    for (final r in results) {
      sum += pick(r);
    }
    return sum;
  }
}

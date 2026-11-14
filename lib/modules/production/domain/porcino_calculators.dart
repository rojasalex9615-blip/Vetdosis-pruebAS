/// Calculadoras porcinas sin base de datos: ventilación, capacidad inversa y
/// nitrógeno / huella hídrica gris. Puras y sin estado.
FormatException _invalid(String message) => FormatException(message);

int _ceil(double value) => (value - 1e-9).ceil();

// ---------------------------------------------------------------- Ventilación

enum VentClimate { cold, mild, hot }

extension VentClimateLabel on VentClimate {
  String get label => switch (this) {
    VentClimate.cold => 'Frío',
    VentClimate.mild => 'Templado',
    VentClimate.hot => 'Cálido',
  };
}

/// Tasa de ventilación por animal tal como la publica la tabla de origen.
/// [openEnded] = la tabla dice «>»: el valor es un mínimo, no un rango.
class VentRate {
  const VentRate(this.min, {double? max, this.openEnded = false})
    : max = max ?? min;
  final double min, max;
  final bool openEnded;
}

const cfmToM3h = 1.699011;

class VentStage {
  const VentStage({
    required this.name,
    required this.weightNote,
    required this.imperialCfm,
    this.metricM3h,
    this.metricWeightNote,
  });
  final String name, weightNote;

  /// Tabla «medidas imperiales» (CFM por animal).
  final Map<VentClimate, VentRate> imperialCfm;

  /// Tabla «sistema métrico decimal» (m³/h por animal); solo destete y engorda.
  final Map<VentClimate, VentRate>? metricM3h;
  final String? metricWeightNote;
}

const ventilationSource =
    'VentWorkshop, Pork School ago-2026 (Carlos Anadón), tablas de parámetros de diseño. Sin validación externa.';

const ventilationStages = <VentStage>[
  VentStage(
    name: 'Gestación',
    weightNote: '> 300 lb',
    imperialCfm: {
      VentClimate.cold: VentRate(15),
      VentClimate.mild: VentRate(80),
      VentClimate.hot: VentRate(300, openEnded: true),
    },
  ),
  VentStage(
    name: 'Maternidad',
    weightNote: '> 300 lb',
    imperialCfm: {
      VentClimate.cold: VentRate(20),
      VentClimate.mild: VentRate(150),
      VentClimate.hot: VentRate(750, openEnded: true),
    },
  ),
  VentStage(
    name: 'Destete',
    weightNote: '10–60 lb',
    imperialCfm: {
      VentClimate.cold: VentRate(5),
      VentClimate.mild: VentRate(15),
      VentClimate.hot: VentRate(70),
    },
    metricWeightNote: '5–35 kg',
    metricM3h: {
      VentClimate.cold: VentRate(8, max: 10),
      VentClimate.mild: VentRate(25, max: 30),
      VentClimate.hot: VentRate(70),
    },
  ),
  VentStage(
    name: 'Engorda',
    weightNote: '60–250 lb',
    imperialCfm: {
      VentClimate.cold: VentRate(30),
      VentClimate.mild: VentRate(60, max: 70),
      VentClimate.hot: VentRate(150, openEnded: true),
    },
    metricWeightNote: '30–120 kg',
    metricM3h: {
      VentClimate.cold: VentRate(15),
      VentClimate.mild: VentRate(70),
      VentClimate.hot: VentRate(200),
    },
  ),
  VentStage(
    name: 'Destete a finalización (WTF)',
    weightNote: '10–250 lb',
    imperialCfm: {
      VentClimate.cold: VentRate(5),
      VentClimate.mild: VentRate(10, max: 15),
      VentClimate.hot: VentRate(150, openEnded: true),
    },
  ),
];

enum VentTable { imperial, metric }

/// Caudal total de la sala = animales × tasa por animal.
class VentilationEstimate {
  VentilationEstimate({
    required this.stage,
    required this.climate,
    required this.animals,
    this.table = VentTable.imperial,
  }) {
    if (animals <= 0 || animals > 100000) {
      throw _invalid('Animales: entero entre 1 y 100000.');
    }
    if (table == VentTable.metric && stage.metricM3h == null) {
      throw _invalid('${stage.name} no tiene tabla métrica en el material.');
    }
  }
  final VentStage stage;
  final VentClimate climate;
  final int animals;
  final VentTable table;

  VentRate get _rate => table == VentTable.metric
      ? stage.metricM3h![climate]!
      : stage.imperialCfm[climate]!;
  double get _factor => table == VentTable.metric ? 1 : cfmToM3h;

  /// Por animal, ya convertido a m³/h.
  double get perAnimalMinM3h => _rate.min * _factor;
  double get perAnimalMaxM3h => _rate.max * _factor;
  double get totalMinM3h => perAnimalMinM3h * animals;
  double get totalMaxM3h => perAnimalMaxM3h * animals;
  double get totalMinCfm => totalMinM3h / cfmToM3h;
  double get totalMaxCfm => totalMaxM3h / cfmToM3h;

  /// «>» en la tabla: el total es un mínimo, no un rango.
  bool get isMinimumOnly => _rate.openEnded;
  bool get isRange => !_rate.openEnded && _rate.max != _rate.min;
}

// -------------------------------------------------------- Capacidad inversa

/// De la producción semanal (o de los espacios) a los vientres necesarios.
/// Ejemplo de clase: 518 cerdos/semana, 30 destetados/vientre/año → 898;
/// con 35 → 770 (la hoja de clase da 769 porque redondea el factor a 0.673).
class InverseCapacity {
  InverseCapacity({
    required this.pigsPerWeek,
    required this.weanedPerSowYear,
  }) {
    if (!pigsPerWeek.isFinite || pigsPerWeek <= 0 || pigsPerWeek > 100000) {
      throw _invalid('Cerdos por semana: mayor que 0 y hasta 100000.');
    }
    if (!weanedPerSowYear.isFinite ||
        weanedPerSowYear < 10 ||
        weanedPerSowYear > 50) {
      throw _invalid('Destetados por vientre al año: entre 10 y 50.');
    }
  }

  /// Espacios disponibles ÷ semanas de ciclo = cerdos por semana.
  /// Proyecto de clase: 150000 m² ÷ 1.2 = 125000 espacios ÷ 24 = 5208/semana.
  factory InverseCapacity.fromSpaces({
    required double totalM2,
    required double m2PerPig,
    required int cycleWeeks,
    required double weanedPerSowYear,
  }) {
    if (!totalM2.isFinite || totalM2 <= 0) {
      throw _invalid('Superficie: mayor que 0.');
    }
    if (!m2PerPig.isFinite || m2PerPig <= 0 || m2PerPig > 5) {
      throw _invalid('m² por cerdo: mayor que 0 y hasta 5.');
    }
    if (cycleWeeks < 1 || cycleWeeks > 60) {
      throw _invalid('Semanas de ciclo: de 1 a 60.');
    }
    return InverseCapacity(
      pigsPerWeek: totalM2 / m2PerPig / cycleWeeks,
      weanedPerSowYear: weanedPerSowYear,
    );
  }

  final double pigsPerWeek, weanedPerSowYear;

  /// Destetados por vientre por semana (30/52 = 0.577; 35/52 = 0.673).
  double get weeklyFactor => weanedPerSowYear / 52;
  int get sows => _ceil(pigsPerWeek / weeklyFactor);
}

// ------------------------------------------------- Nitrógeno / huella hídrica

/// Huella hídrica gris (HHGris = Carga ÷ (Cmax − Cnat)) y nivel de
/// contaminación del agua (NCA = HHGris ÷ recarga). Método del Dictamen
/// Diagnóstico Ambiental de la Actividad Porcícola en Yucatán (SEMARNAT, 2023,
/// p. 84). Las constantes por defecto son de Yucatán; hay que cambiarlas para
/// otra región.
class NitrogenFootprint {
  NitrogenFootprint({
    required this.pigs,
    required this.kgNPerPigYear,
    required this.cNaturalMgL,
    required this.cMaxMgL,
    this.areaKm2,
    this.unitRechargeM3Km2,
  }) {
    if (pigs <= 0 || pigs > 10000000) {
      throw _invalid('Cerdos: entero entre 1 y 10 000 000.');
    }
    if (!kgNPerPigYear.isFinite || kgNPerPigYear <= 0 || kgNPerPigYear > 100) {
      throw _invalid('Carga de N por cerdo: mayor que 0 y hasta 100 kg/año.');
    }
    if (!cNaturalMgL.isFinite || cNaturalMgL < 0) {
      throw _invalid('Concentración natural: no puede ser negativa.');
    }
    if (!cMaxMgL.isFinite || cMaxMgL <= cNaturalMgL) {
      throw _invalid('Cmax debe ser mayor que la concentración natural.');
    }
    final hasArea = areaKm2 != null;
    if (hasArea != (unitRechargeM3Km2 != null)) {
      throw _invalid('Para el NCA captura superficie y recarga unitaria.');
    }
    if (hasArea) {
      if (!areaKm2!.isFinite || areaKm2! <= 0) {
        throw _invalid('Superficie: mayor que 0.');
      }
      if (!unitRechargeM3Km2!.isFinite || unitRechargeM3Km2! <= 0) {
        throw _invalid('Recarga unitaria: mayor que 0.');
      }
    }
  }
  final int pigs;
  final double kgNPerPigYear, cNaturalMgL, cMaxMgL;
  final double? areaKm2, unitRechargeM3Km2;

  double get loadKgNYear => pigs * kgNPerPigYear;

  /// kg/año ÷ (mg/L = g/m³) = ×1000 g/kg → m³/año de agua para diluir.
  double get greyWaterM3Year => loadKgNYear * 1000 / (cMaxMgL - cNaturalMgL);

  double? get rechargeM3Year =>
      areaKm2 == null ? null : areaKm2! * unitRechargeM3Km2!;
  double? get nca =>
      rechargeM3Year == null ? null : greyWaterM3Year / rechargeM3Year!;

  /// «NCA > 1 = no sustentable; > 2 = crítico» (Dictamen, p. 84-85).
  String? get ncaReading {
    final v = nca;
    if (v == null) return null;
    if (v > 2) return 'Condiciones críticas para la sustentabilidad hídrica';
    if (v > 1) return 'Condición de no sustentabilidad';
    return 'Dentro del rango sustentable';
  }
}

// ---------------------------------------------------------------- Distancias

enum DistanceBand { veryClose, risk, intermediate, far }

/// Distancia a la granja porcina más cercana, contra los umbrales de la
/// presentación de bioseguridad (Jean Paul Cano, Pork School ago-2026).
DistanceBand classifyFarmDistance(double km) {
  if (!km.isFinite || km < 0 || km > 1000) {
    throw _invalid('Distancia: de 0 a 1000 km.');
  }
  if (km < 0.5) return DistanceBand.veryClose;
  if (km < 3) return DistanceBand.risk;
  if (km <= 10) return DistanceBand.intermediate;
  return DistanceBand.far;
}

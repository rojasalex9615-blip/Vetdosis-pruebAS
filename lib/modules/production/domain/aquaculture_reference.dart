/// Calculadoras de acuicultura (tilapia): siembra y biomasa máxima, ración
/// diaria, indicadores y costos del ciclo, y oxígeno / aireación.
///
/// Fuentes: rangos de El-Sayed (2013) vía Artemio Lab (densidad por sistema),
/// tabla SENA (mojarra roja, ración por talla y temperatura), 350 g de O₂ por
/// kg de alimento (Novair; Techma da 250–500 g) y el modelo de aireadores
/// (TOD, SOTR, OTR). Material de clase, sin validación externa independiente.
///
/// Puras y sin estado. No guardan registros ni confirman que sea adecuado
/// sembrar o alimentar.
library;

import 'dart:math' as math;

FormatException _invalid(String message) => FormatException(message);

int _ceil(double value) => (value - 1e-9).ceil();

// ------------------------------------------------------- Siembra y biomasa

/// Sistemas de cultivo con la densidad máxima publicada por la fuente.
/// [perVolume] = la densidad va por m³ (jaula y tanque); si no, por m².
class AquacultureSystem {
  const AquacultureSystem({
    required this.name,
    required this.minKg,
    required this.maxKg,
    required this.perVolume,
  });
  final String name, minKg, maxKg;
  final bool perVolume;
  String get range => '$minKg–$maxKg kg/${perVolume ? 'm³' : 'm²'}';
}

const aquacultureSystems = <AquacultureSystem>[
  AquacultureSystem(
    name: 'Estanque en tierra, sin aireación',
    minKg: '0.3',
    maxKg: '0.6',
    perVolume: false,
  ),
  AquacultureSystem(
    name: 'Estanque en tierra, con aireación',
    minKg: '1.5',
    maxKg: '2.0',
    perVolume: false,
  ),
  AquacultureSystem(
    name: 'Jaula flotante',
    minKg: '25',
    maxKg: '40',
    perVolume: true,
  ),
  AquacultureSystem(
    name: 'Tanque, recirculación o flujo continuo',
    minKg: '30',
    maxKg: '96',
    perVolume: true,
  ),
];

const aquacultureSeedSource =
    'El-Sayed (2013) vía Artemio Lab. Solo hay datos de tilapia.';

/// Siembra y biomasa máxima: biomasa = densidad × superficie (o volumen);
/// peces a cosechar = biomasa ÷ peso de cosecha; a sembrar = cosecha ÷
/// supervivencia. El nivel de intensidad elige el punto del rango publicado.
class SeedStockPlan {
  SeedStockPlan({
    required this.systemIndex,
    required this.areaM2,
    required this.averageDepthM,
    required this.harvestWeightG,
    required this.survivalPercent,
    required this.level,
    this.systems = aquacultureSystems,
  }) {
    if (systemIndex < 0 || systemIndex >= systems.length) {
      throw _invalid('Elige un sistema de cultivo de la lista.');
    }
    if (!areaM2.isFinite || areaM2 <= 0) {
      throw _invalid('Área del espejo: mayor que 0.');
    }
    if (!averageDepthM.isFinite || averageDepthM <= 0) {
      throw _invalid('Profundidad media: mayor que 0.');
    }
    if (!harvestWeightG.isFinite || harvestWeightG <= 0) {
      throw _invalid('Peso de cosecha: mayor que 0.');
    }
    if (!survivalPercent.isFinite ||
        survivalPercent <= 0 ||
        survivalPercent > 100) {
      throw _invalid('Supervivencia: mayor que 0 y hasta 100 %.');
    }
    if (level < 0 || level > 2) {
      throw _invalid('Nivel de intensidad: conservador, medio o máximo.');
    }
  }

  final int systemIndex, level;
  final double areaM2, averageDepthM, harvestWeightG, survivalPercent;

  /// Tabla de densidades publicadas para la especie elegida.
  final List<AquacultureSystem> systems;

  AquacultureSystem get system => systems[systemIndex];
  double get volumeM3 => areaM2 * averageDepthM;

  /// Base de la densidad: volumen si el sistema va por m³, área si va por m².
  double get densityBase => system.perVolume ? volumeM3 : areaM2;

  double _bound(String value) => double.parse(value);

  /// Densidad elegida dentro del rango (0 = mínimo, 1 = medio, 2 = máximo).
  double get densityKgPerUnit {
    final lo = _bound(system.minKg), hi = _bound(system.maxKg);
    return lo + (hi - lo) * const [0.0, 0.5, 1.0][level];
  }

  double get biomassKg => densityKgPerUnit * densityBase;
  double get harvestFish => biomassKg / (harvestWeightG / 1000);
  double get seedFish => harvestFish / (survivalPercent / 100);
  double get densityPerUnit => seedFish / densityBase;
}

// ------------------------------------------------------------ Ración diaria

/// Tasa diaria de alimento (% de biomasa) por peso promedio, de la tabla SENA
/// (mojarra roja). Null por encima de 500 g: la tabla no lo cubre.
double? senaDailyPercent(double averageGrams) {
  if (averageGrams <= 0) return null;
  if (averageGrams < 5) return 10;
  if (averageGrams < 20) return 8;
  if (averageGrams < 50) return 6;
  if (averageGrams < 100) return 4;
  if (averageGrams < 200) return 3.5;
  if (averageGrams < 300) return 3;
  if (averageGrams <= 500) return 2.5;
  return null;
}

/// Factor de temperatura de la tabla SENA (1 = 24–32 °C).
double senaTemperatureFactor(String band) => switch (band) {
  '24_32' => 1,
  '22_24' => 0.71,
  '20_22' => 0.54,
  '18_20' => 0.29,
  _ => throw _invalid('Banda de temperatura desconocida.'),
};

/// Ración diaria: biomasa = peso × número ÷ 1000; ración = biomasa × tasa ×
/// factor de temperatura. La tasa sale de la tabla por talla; se conserva el
/// aviso de que es una guía y que se ajusta con muestreos.
class DailyRationPlan {
  DailyRationPlan({
    required this.averageGrams,
    required this.fishCount,
    required this.temperatureFactor,
  }) {
    if (!averageGrams.isFinite || averageGrams <= 0) {
      throw _invalid('Peso promedio: mayor que 0.');
    }
    if (fishCount <= 0) throw _invalid('Número de peces: entero mayor que 0.');
    if (!temperatureFactor.isFinite || temperatureFactor <= 0) {
      throw _invalid('Factor de temperatura: mayor que 0.');
    }
    if (dailyPercent == null) {
      throw _invalid(
        'La tabla SENA solo cubre hasta 500 g; no se interpola por encima.',
      );
    }
  }

  final double averageGrams;
  final int fishCount;
  final double temperatureFactor;

  double get biomassKg => averageGrams * fishCount / 1000;
  double? get dailyPercent => senaDailyPercent(averageGrams);
  double get rationKg => biomassKg * (dailyPercent! / 100) * temperatureFactor;
}

// ------------------------------------------------- Indicadores y costos

/// Indicadores y costos del ciclo. Los cálculos siguen el orden de la fuente:
/// biomasas, ganancia, supervivencia, FCA, costos, ingresos y densidad.
class CycleIndicators {
  CycleIndicators({
    required this.initialFish,
    required this.finalFish,
    required this.initialWeightG,
    required this.finalWeightG,
    required this.feedKg,
    required this.feedPricePerKg,
    required this.laborCost,
    required this.operatingCost,
    required this.salePricePerKg,
    required this.pondVolumeM3,
  }) {
    if (initialFish <= 0 || finalFish <= 0) {
      throw _invalid('Peces iniciales y finales: enteros mayores que 0.');
    }
    if (finalFish > initialFish) {
      throw _invalid('Peces finales no puede superar a los iniciales.');
    }
    if (!initialWeightG.isFinite ||
        initialWeightG <= 0 ||
        !finalWeightG.isFinite ||
        finalWeightG <= 0) {
      throw _invalid('Pesos inicial y final: mayores que 0.');
    }
    if (!feedKg.isFinite || feedKg < 0) {
      throw _invalid('Alimento total: no puede ser negativo.');
    }
    if (!feedPricePerKg.isFinite || feedPricePerKg < 0) {
      throw _invalid('Precio del alimento: no puede ser negativo.');
    }
    if (!laborCost.isFinite ||
        laborCost < 0 ||
        !operatingCost.isFinite ||
        operatingCost < 0) {
      throw _invalid('Mano de obra y costos operativos: no negativos.');
    }
    if (!salePricePerKg.isFinite || salePricePerKg < 0) {
      throw _invalid('Precio de venta: no puede ser negativo.');
    }
    if (!pondVolumeM3.isFinite || pondVolumeM3 <= 0) {
      throw _invalid('Volumen del estanque: mayor que 0.');
    }
    if (biomassGainKg <= 0) {
      throw _invalid('La biomasa final debe superar a la inicial para el FCA.');
    }
  }

  final int initialFish, finalFish;
  final double initialWeightG, finalWeightG, feedKg, feedPricePerKg;
  final double laborCost, operatingCost, salePricePerKg, pondVolumeM3;

  double get initialBiomassKg => initialFish * initialWeightG / 1000;
  double get finalBiomassKg => finalFish * finalWeightG / 1000;
  double get biomassGainKg => finalBiomassKg - initialBiomassKg;
  double get survivalPercent => finalFish / initialFish * 100;
  double get mortalityPercent => 100 - survivalPercent;
  double get feedConversionRatio => feedKg / biomassGainKg;
  double get feedCost => feedKg * feedPricePerKg;
  double get totalCost => feedCost + laborCost + operatingCost;
  double get costPerKg => totalCost / biomassGainKg;
  double get income => finalBiomassKg * salePricePerKg;
  double get profit => income - totalCost;
  double get densityPerM3 => initialFish / pondVolumeM3;
}

// ------------------------------------------------------ Oxígeno y aireación

/// Oxígeno por kg de alimento (Novair 350 g; Techma 250–500 g).
const oxygenPerKgFeed = 0.35;

/// Eficiencia de transferencia de oxígeno por tipo de aireador.
double oxygenTransferEfficiency(String kind) => switch (kind) {
  'piedras_difusoras' => 0.15,
  'venturi' => 0.4,
  'nanoburbujas' => 0.77,
  'cono_speece' => 0.9,
  _ => throw _invalid('Tipo de aireador desconocido.'),
};

/// A. Demanda de oxígeno por alimento: kg O₂/día = alimento × 350 g ÷ 1000;
/// pico = demanda diaria ÷ 24 × factor de pico; generador = pico ÷ eficiencia.
class OxygenDemand {
  OxygenDemand({
    required this.feedKgPerDay,
    required this.peakFactor,
    required this.transferEfficiency,
    this.oxygenPerKg = oxygenPerKgFeed,
  }) {
    if (!feedKgPerDay.isFinite || feedKgPerDay <= 0) {
      throw _invalid('Alimento por día: mayor que 0.');
    }
    if (!peakFactor.isFinite || peakFactor < 1) {
      throw _invalid('Factor de pico: al menos 1.');
    }
    if (!transferEfficiency.isFinite ||
        transferEfficiency <= 0 ||
        transferEfficiency > 1) {
      throw _invalid('Eficiencia de transferencia: entre 0 y 1.');
    }
    if (!oxygenPerKg.isFinite || oxygenPerKg <= 0) {
      throw _invalid('O₂ por kg de alimento: mayor que 0.');
    }
  }

  final double feedKgPerDay, peakFactor, transferEfficiency, oxygenPerKg;

  double get oxygenKgPerDay => feedKgPerDay * oxygenPerKg;
  double get averageKgPerHour => oxygenKgPerDay / 24;
  double get peakKgPerHour => averageKgPerHour * peakFactor;
  double get generatorKgPerHour => peakKgPerHour / transferEfficiency;
  double get generatorNm3PerHour => generatorKgPerHour * 0.7;
}

/// B. Número de aireadores. El TOD (kg O₂/h) puede capturarse directo o
/// derivarse de (CO + RC + RF) × V. El OTR se corrige por temperatura con el
/// factor 1.024^(T1 − TF).
class AeratorPlan {
  AeratorPlan({
    required this.todKgPerHour,
    required this.sotrKgPerHour,
    required this.saturationMgL,
    required this.minimumMgL,
    required this.t1C,
    required this.tfC,
  }) {
    if (!todKgPerHour.isFinite || todKgPerHour <= 0) {
      throw _invalid('TOD: mayor que 0 kg O₂/h.');
    }
    if (!sotrKgPerHour.isFinite || sotrKgPerHour <= 0) {
      throw _invalid('SOTR: mayor que 0 kg O₂/h.');
    }
    if (!saturationMgL.isFinite || saturationMgL <= 0) {
      throw _invalid('Cs (saturación): mayor que 0.');
    }
    if (!minimumMgL.isFinite || minimumMgL < 0) {
      throw _invalid('C1 (mínimo permitido): no puede ser negativo.');
    }
    if (minimumMgL >= saturationMgL) {
      throw _invalid('C1 debe ser menor que Cs.');
    }
    if (!t1C.isFinite || !tfC.isFinite) {
      throw _invalid('T1 y TF deben ser números.');
    }
  }

  /// TOD desde los consumos por volumen: (CO + RC + RF) × V ÷ 1000.
  factory AeratorPlan.fromConsumption({
    required double coMgLh,
    required double rcMgLh,
    required double rfMgLh,
    required double volumeM3,
    required double sotrKgPerHour,
    required double saturationMgL,
    required double minimumMgL,
    required double t1C,
    required double tfC,
  }) {
    if (!volumeM3.isFinite || volumeM3 <= 0) {
      throw _invalid('Volumen: mayor que 0 m³.');
    }
    if (coMgLh < 0 || rcMgLh < 0 || rfMgLh < 0) {
      throw _invalid('CO, RC y RF no pueden ser negativos.');
    }
    final sum = coMgLh + rcMgLh + rfMgLh;
    if (sum <= 0) {
      throw _invalid('CO + RC + RF debe ser mayor que 0 para derivar el TOD.');
    }
    return AeratorPlan(
      todKgPerHour: sum * volumeM3 / 1000,
      sotrKgPerHour: sotrKgPerHour,
      saturationMgL: saturationMgL,
      minimumMgL: minimumMgL,
      t1C: t1C,
      tfC: tfC,
    );
  }

  final double todKgPerHour, sotrKgPerHour, saturationMgL, minimumMgL, t1C, tfC;

  /// OTR de referencia a las condiciones del tanque (kg O₂/h).
  double get otrKgPerHour =>
      sotrKgPerHour * (saturationMgL - minimumMgL) / saturationMgL;

  /// OTR corregido por temperatura.
  double get otrTemperatureKgPerHour =>
      otrKgPerHour * math.pow(1.024, t1C - tfC).toDouble();

  /// Aireadores calculados (se instala el entero superior).
  double get aerators => todKgPerHour / otrTemperatureKgPerHour;
  int get aeratorsToInstall => _ceil(aerators);
}

/// C. Horas de reserva de oxígeno: superávit = O₂ − mínimo; horas = superávit
/// ÷ pérdidas; hora en que se agota el oxígeno; y si alcanza hasta el amanecer.
class OxygenReserve {
  OxygenReserve({
    required this.currentMgL,
    required this.minimumMgL,
    required this.lossesMgLh,
    required this.readingHour,
    required this.dawnHour,
  }) {
    if (!currentMgL.isFinite || !minimumMgL.isFinite) {
      throw _invalid('O₂ y mínimo deben ser números.');
    }
    if (minimumMgL < 0) throw _invalid('El mínimo no puede ser negativo.');
    if (!lossesMgLh.isFinite || lossesMgLh <= 0) {
      throw _invalid('Pérdidas totales: mayor que 0 mg/L/h.');
    }
    if (readingHour < 0 || readingHour > 23) {
      throw _invalid('Hora de lectura: entre 0 y 23.');
    }
    if (dawnHour < 0 || dawnHour > 23) {
      throw _invalid('Hora del amanecer: entre 0 y 23.');
    }
  }

  final double currentMgL, minimumMgL, lossesMgLh;
  final int readingHour, dawnHour;

  double get surplusMgL => currentMgL - minimumMgL;
  double get reserveHours => surplusMgL / lossesMgLh;

  /// Hora del día en que se agota el oxígeno (0–23). Null si el superávit no
  /// es positivo (ya está por debajo del mínimo).
  int? get depletionHour {
    if (surplusMgL <= 0) return null;
    return (readingHour + reserveHours.floor()) % 24;
  }

  /// Horas desde la lectura hasta el amanecer, en el mismo día.
  int get hoursUntilDawn => ((dawnHour - readingHour) + 24) % 24;

  /// La reserva alcanza hasta el amanecer si cubre esas horas.
  bool get reachesDawn => reserveHours >= hoursUntilDawn;
}

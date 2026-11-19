/// Datos de acuicultura por especie de pez, tomados de
/// `docs/acuicultura-constantes-20261116.csv` y
/// `docs/acuicultura-cachama-plan-semanal-20261116.csv`.
///
/// Cada especie trae su propia tabla y su propia fuente. No se reutilizan
/// coeficientes de una especie para otra: donde la fuente no da el dato, la
/// calculadora no calcula.
///
/// Puras y sin estado. No guardan registros ni confirman que sea adecuado
/// sembrar o alimentar.
library;

import 'dart:math' as math;

import 'aquaculture_reference.dart';

FormatException _invalid(String message) => FormatException(message);

/// Especies de pez con datos en el repositorio.
enum FishSpecies {
  tilapia('Tilapia'),
  trucha('Trucha'),
  cachama('Cachama'),
  bagre('Bagre');

  const FishSpecies(this.label);
  final String label;

  /// Especie a partir del nombre de la actividad del catálogo.
  static FishSpecies? fromActivity(String activity) {
    for (final species in values) {
      if (species.label.toLowerCase() == activity.trim().toLowerCase()) {
        return species;
      }
    }
    return null;
  }
}

/// Calculadoras que la fuente respalda para cada especie.
///
/// Siembra y biomasa necesitan una densidad publicada; ración necesita una
/// tabla de tasa de alimentación. Donde falta, la calculadora avisa.
bool seedSupportedBy(FishSpecies species) => switch (species) {
  FishSpecies.tilapia || FishSpecies.trucha => true,
  FishSpecies.cachama || FishSpecies.bagre => false,
};

bool rationSupportedBy(FishSpecies species) => switch (species) {
  FishSpecies.tilapia || FishSpecies.trucha || FishSpecies.cachama => true,
  FishSpecies.bagre => false,
};

/// Por qué una calculadora no está disponible, con la fuente a la vista.
String seedUnavailableReason(FishSpecies species) => switch (species) {
  FishSpecies.cachama =>
    'El plan semanal de cachama trae consumo y conversión, pero no una '
        'densidad de siembra publicada. No se calcula siembra para cachama.',
  FishSpecies.bagre =>
    'De bagre solo hay la relación cloruro:nitrito. No hay densidad de '
        'siembra en la fuente.',
  _ => '',
};

String rationUnavailableReason(FishSpecies species) => switch (species) {
  FishSpecies.bagre =>
    'De bagre solo hay la relación cloruro:nitrito. No hay tabla de ración '
        'en la fuente.',
  _ => '',
};

// --------------------------------------------------------------- Trucha

/// Tallas de la tabla de Shelton, en peces por libra.
///
/// Menos peces por libra es un pez más grande: el orden va del más pequeño al
/// más grande, igual que las columnas del original.
const troutSizeClasses = <String>[
  '2500 o más peces/libra (alevín)',
  '2500 a 800 peces/libra',
  '800 a 300 peces/libra',
  '300 a 100 peces/libra',
  '100 a 30 peces/libra (dedino)',
];

/// Fila de la tabla de Shelton: tasa diaria (% del peso corporal) por talla.
class TroutRationRow {
  const TroutRationRow({
    required this.temperatureF,
    required this.label,
    required this.percentBySize,
    this.review,
  });
  final int temperatureF;
  final String label;

  /// Un null significa que la fuente imprime un valor no utilizable en esa
  /// talla; la calculadora no lo ofrece en vez de inventarlo.
  final List<double?> percentBySize;

  /// Aviso cuando la propia fuente tiene una errata probable.
  final String? review;
}

const troutRationRows = <TroutRationRow>[
  TroutRationRow(
    temperatureF: 55,
    label: '55 °F (12.8 °C)',
    percentBySize: [6.1, 5.2, 5.1, 4.2, 3.2],
  ),
  TroutRationRow(
    temperatureF: 60,
    label: '60 °F (15.6 °C)',
    percentBySize: [7.5, 6.3, 6.1, 5.1, 3.9],
  ),
  TroutRationRow(
    temperatureF: 65,
    label: '65 °F (18.3 °C)',
    percentBySize: [9.0, null, null, 6.1, 4.9],
    review:
        'La obra imprime 1.5 y 1.2 en las dos tallas intermedias: rompen la '
        'tendencia de la propia tabla (probable errata por 7.5 y 7.2). Esas '
        'dos tallas no se ofrecen hasta cotejar la fuente.',
  ),
];

const troutRationSource =
    'Shelton 1994, que cita a Leitritz y Lewis 1980. Temperaturas en °F, como '
    'la tabla original.';

const troutMaintenanceNote =
    'A 38 °F (3.3 °C) o menos la fuente da 0.5 a 1.8 % del peso al día según '
    'tamaño; es mantenimiento, no engorda, y no se interpola aquí.';

/// Ración diaria de trucha con la tabla de Shelton.
///
/// La tasa sale de la talla y la temperatura; la biomasa, del peso medio y el
/// número de peces.
class TroutRationPlan {
  TroutRationPlan({
    required this.rowIndex,
    required this.sizeIndex,
    required this.averageGrams,
    required this.fishCount,
  }) {
    if (rowIndex < 0 || rowIndex >= troutRationRows.length) {
      throw _invalid('Elige una temperatura de la tabla.');
    }
    if (sizeIndex < 0 || sizeIndex >= troutSizeClasses.length) {
      throw _invalid('Elige una talla de la tabla.');
    }
    if (!averageGrams.isFinite || averageGrams <= 0) {
      throw _invalid('Peso promedio: mayor que 0.');
    }
    if (fishCount <= 0) throw _invalid('Número de peces: entero mayor que 0.');
    if (dailyPercent == null) {
      throw _invalid(
        'La fuente no da una tasa utilizable para esa talla y temperatura.',
      );
    }
  }

  final int rowIndex, sizeIndex;
  final double averageGrams;
  final int fishCount;

  TroutRationRow get row => troutRationRows[rowIndex];
  double? get dailyPercent => row.percentBySize[sizeIndex];
  double get biomassKg => averageGrams * fishCount / 1000;
  double get rationKg => biomassKg * (dailyPercent! / 100);
}

/// Rangos de biomasa de trucha en kg/m³, tal como los publica cada fuente.
const troutDensityRanges = <AquacultureSystem>[
  AquacultureSystem(
    name: 'Jaula de 1 m³ dentro de raceway',
    minKg: '26',
    maxKg: '30',
    perVolume: true,
  ),
  AquacultureSystem(
    name: 'Jaula, fase de engorde',
    minKg: '25',
    maxKg: '30',
    perVolume: true,
  ),
  AquacultureSystem(
    name: 'Cualquier fase',
    minKg: '25',
    maxKg: '40',
    perVolume: true,
  ),
];

const troutDensitySource =
    'Chaves-Rojas y Vargas-Cordero 2016 (26–30 kg/m³ en jaulas de 1 m³; mejor '
    'crecimiento a 28), Guerrero 2006 y Perdomo et al. 2011, citados por los '
    'mismos autores.';

// -------------------------------------------------------------- Cachama

/// Una semana del plan de consumo de cachama (Cipa Acuavit).
class CachamaWeek {
  const CachamaWeek({
    required this.week,
    required this.gainPerDayG,
    required this.initialG,
    required this.finalG,
    required this.feedProduct,
    required this.consumptionGPerFishDay,
    required this.fcr,
  });
  final int week;
  final double gainPerDayG, initialG, finalG, consumptionGPerFishDay, fcr;
  final String feedProduct;
}

const cachamaWeeks = <CachamaWeek>[
  CachamaWeek(week: 1, gainPerDayG: 0.3, initialG: 0.5, finalG: 3, feedProduct: 'Mojarra iniciación 45 %', consumptionGPerFishDay: 0.27, fcr: 0.90),
  CachamaWeek(week: 2, gainPerDayG: 0.5, initialG: 2.6, finalG: 6, feedProduct: 'Mojarra prelevante 40 %', consumptionGPerFishDay: 0.45, fcr: 0.90),
  CachamaWeek(week: 3, gainPerDayG: 1, initialG: 6.1, finalG: 13, feedProduct: 'Mojarra prelevante 40 %', consumptionGPerFishDay: 0.9, fcr: 0.90),
  CachamaWeek(week: 4, gainPerDayG: 1.5, initialG: 13.1, finalG: 24, feedProduct: 'Mojarra prelevante 40 %', consumptionGPerFishDay: 1.35, fcr: 0.90),
  CachamaWeek(week: 5, gainPerDayG: 2, initialG: 23.6, finalG: 38, feedProduct: 'Mojarra 35 %', consumptionGPerFishDay: 2, fcr: 1.00),
  CachamaWeek(week: 6, gainPerDayG: 2.5, initialG: 37.6, finalG: 55, feedProduct: 'Mojarra 35 %', consumptionGPerFishDay: 2.5, fcr: 1.00),
  CachamaWeek(week: 7, gainPerDayG: 3.4, initialG: 55.1, finalG: 79, feedProduct: 'Mojarra 35 %', consumptionGPerFishDay: 3.4, fcr: 1.00),
  CachamaWeek(week: 8, gainPerDayG: 4, initialG: 78.9, finalG: 107, feedProduct: 'Mojarra 30 %', consumptionGPerFishDay: 4.4, fcr: 1.10),
  CachamaWeek(week: 9, gainPerDayG: 4.3, initialG: 106.9, finalG: 137, feedProduct: 'Mojarra 30 %', consumptionGPerFishDay: 4.73, fcr: 1.10),
  CachamaWeek(week: 10, gainPerDayG: 5, initialG: 137, finalG: 172, feedProduct: 'Mojarra 30 %', consumptionGPerFishDay: 5.5, fcr: 1.10),
  CachamaWeek(week: 11, gainPerDayG: 5.6, initialG: 172, finalG: 211, feedProduct: 'Mojarra 30 % o 24 % (límite no legible)', consumptionGPerFishDay: 6.16, fcr: 1.10),
  CachamaWeek(week: 12, gainPerDayG: 6, initialG: 211.2, finalG: 253, feedProduct: 'Mojarra 24 %', consumptionGPerFishDay: 7.2, fcr: 1.20),
  CachamaWeek(week: 13, gainPerDayG: 6.5, initialG: 253.2, finalG: 299, feedProduct: 'Mojarra 24 %', consumptionGPerFishDay: 7.8, fcr: 1.20),
  CachamaWeek(week: 14, gainPerDayG: 7, initialG: 298.7, finalG: 348, feedProduct: 'Mojarra 24 %', consumptionGPerFishDay: 8.4, fcr: 1.20),
  CachamaWeek(week: 15, gainPerDayG: 7.1, initialG: 347.7, finalG: 397, feedProduct: 'Mojarra 24 %', consumptionGPerFishDay: 8.52, fcr: 1.20),
  CachamaWeek(week: 16, gainPerDayG: 7.2, initialG: 397.4, finalG: 448, feedProduct: 'Mojarra 24 %', consumptionGPerFishDay: 8.64, fcr: 1.20),
  CachamaWeek(week: 17, gainPerDayG: 7.4, initialG: 447.8, finalG: 500, feedProduct: 'Mojarra 24 %', consumptionGPerFishDay: 8.88, fcr: 1.20),
  CachamaWeek(week: 18, gainPerDayG: 7.5, initialG: 499.6, finalG: 552, feedProduct: 'Mojarra 24 %', consumptionGPerFishDay: 9, fcr: 1.20),
  CachamaWeek(week: 19, gainPerDayG: 7.5, initialG: 552.1, finalG: 605, feedProduct: 'Mojarra 24 %', consumptionGPerFishDay: 9.15, fcr: 1.22),
  CachamaWeek(week: 20, gainPerDayG: 7.6, initialG: 604.6, finalG: 658, feedProduct: 'Mojarra 24 %', consumptionGPerFishDay: 9.272, fcr: 1.22),
];

const cachamaRationSource =
    'Cipa Acuavit, cálculo de consumo de cachama, 20 semanas. Verificado en '
    'captura. El producto de la semana 11 quedó ilegible en el límite.';

/// Consumo diario de cachama para una semana del plan.
class CachamaRationPlan {
  CachamaRationPlan({required this.weekIndex, required this.fishCount}) {
    if (weekIndex < 0 || weekIndex >= cachamaWeeks.length) {
      throw _invalid('Elige una semana del plan (1 a 20).');
    }
    if (fishCount <= 0) throw _invalid('Número de peces: entero mayor que 0.');
  }

  final int weekIndex;
  final int fishCount;

  CachamaWeek get week => cachamaWeeks[weekIndex];
  double get biomassKg => week.finalG * fishCount / 1000;
  double get feedKgPerDay => week.consumptionGPerFishDay * fishCount / 1000;
  double get feedKgPerWeek => feedKgPerDay * 7;
  double get projectedGainGPerWeek => week.gainPerDayG * 7;
}

// ---------------------------------------------------------------- Bagre

/// Relación cloruro:nitrito mínima publicada para bagre.
const bagreNitriteRatio = 10.0;

/// Cloruro de seguro para bagre, en mg/L.
const bagreSafeChlorideMgL = 100.0;

const bagreNitriteSource =
    'Constantes de nitrito para bagre del archivo de acuicultura: relación '
    'Cl:NO₂-N mínima de 10 y cloruro de seguro de 100 ppm.';

/// Cloruro de mantenimiento sugerido según la especie, si la fuente lo da.
double? maintenanceChlorideFor(FishSpecies species) => switch (species) {
  FishSpecies.bagre => bagreSafeChlorideMgL,
  FishSpecies.tilapia => 150,
  _ => null,
};

/// Biomasa máxima por m³ de cada especie cuando la fuente la publica, para
/// comparar en el resumen sin inventar equivalencias.
double? publishedDensityKgPerM3(FishSpecies species) => switch (species) {
  FishSpecies.trucha => 40,
  _ => null,
};

/// Redondeo seguro para presentar, sin notación científica.
double safeRound(double value, [int decimals = 2]) {
  if (!value.isFinite) return 0;
  final factor = math.pow(10, decimals);
  return (value * factor).round() / factor;
}

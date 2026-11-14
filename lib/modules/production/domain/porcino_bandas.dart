/// Calculadora de flujo de producción porcino por bandas.
///
/// Reproduce las fórmulas de la hoja de clase `Flujo_produccion_bandas.xlsx`
/// (550 vientres, banda de 14 días). Puro y sin estado: no guarda registros ni
/// consulta Supabase. Los valores son de referencia de clase; la UPP debe
/// sustituirlos por los suyos.
library;

FormatException _invalid(String message) => FormatException(message);

/// Flujo por bandas: de vientres a partos, lechones, jaulas y reemplazos.
///
/// Con 550 vientres, banda de 14 días, 114 de gestación, 28 de lactancia y 7
/// días abiertos: ciclo 149 días, 10.64 bandas, 43.93 partos y 549.08 LNV por
/// banda (ejemplo de la diapositiva).
class PorcinoBandFlow {
  PorcinoBandFlow({
    required this.sows,
    this.gestationDays = 114,
    this.lactationDays = 28,
    this.openDays = 7,
    this.bandIntervalDays = 14,
    this.infertility = 0.15,
    this.bornAlivePerLitter = 12.5,
    this.pigletMortality = 0.10,
    this.nursingBands = 2,
    this.washBands = 1,
    this.annualReplacement = 0.45,
    this.monthsPerYear = 12,
  }) {
    if (sows <= 0 || sows > 1000000) {
      throw _invalid('Vientres: entero entre 1 y 1000000.');
    }
    for (final (value, label) in [
      (gestationDays, 'Días de gestación'),
      (lactationDays, 'Días de lactancia'),
      (openDays, 'Días abiertos'),
      (bandIntervalDays, 'Intervalo entre bandas'),
    ]) {
      if (value < 0 || value > 400) {
        throw _invalid('$label: entero entre 0 y 400.');
      }
    }
    if (bandIntervalDays <= 0) {
      throw _invalid('Intervalo entre bandas: mayor que 0.');
    }
    for (final (value, label) in [
      (infertility, '% de infertilidad'),
      (pigletMortality, '% mortalidad de lechones'),
      (annualReplacement, '% de reemplazo anual'),
    ]) {
      if (!value.isFinite || value < 0 || value >= 1) {
        throw _invalid('$label: fracción de 0 a 1 (sin incluir 1).');
      }
    }
    if (!bornAlivePerLitter.isFinite ||
        bornAlivePerLitter <= 0 ||
        bornAlivePerLitter > 30) {
      throw _invalid('Lechones nacidos vivos: mayor que 0 y hasta 30.');
    }
    if (nursingBands < 1 || nursingBands > 20) {
      throw _invalid('Bandas de lactancia: entero de 1 a 20.');
    }
    if (washBands < 0 || washBands > 20) {
      throw _invalid('Bandas de lavado: entero de 0 a 20.');
    }
    if (monthsPerYear < 1 || monthsPerYear > 12) {
      throw _invalid('Meses del año: entero de 1 a 12.');
    }
  }

  final int sows;
  final int gestationDays,
      lactationDays,
      openDays,
      bandIntervalDays,
      nursingBands,
      washBands,
      monthsPerYear;
  final double infertility,
      bornAlivePerLitter,
      pigletMortality,
      annualReplacement;

  /// Días de gestación + lactancia + días abiertos.
  int get cycleDays => gestationDays + lactationDays + openDays;

  /// Ciclo ÷ intervalo entre bandas.
  double get cycleBands => cycleDays / bandIntervalDays;

  /// Vientres ÷ bandas del ciclo.
  double get servicesPerBand => sows / cycleBands;

  /// Servicios por banda menos el % de infertilidad.
  double get farrowingsPerBand => servicesPerBand * (1 - infertility);

  /// Partos por banda × LNV promedio.
  double get bornAlivePerBand => farrowingsPerBand * bornAlivePerLitter;

  /// LNV por banda menos el % de mortalidad de lechones.
  double get weanedPerBand => bornAlivePerBand * (1 - pigletMortality);

  /// Partos por banda × (bandas de lactancia + bandas de lavado).
  double get nursingCrates => farrowingsPerBand * (nursingBands + washBands);

  /// % de reemplazo anual aplicado a los vientres.
  double get annualReplacements => sows * annualReplacement;

  /// Reemplazos anuales ÷ meses del año.
  double get replacementsPerMonth => annualReplacements / monthsPerYear;

  /// Lechones destetados por semana (base del inventario por etapa).
  double get weanedPerWeek => weanedPerBand / (bandIntervalDays / 7);
}

/// Una etapa del inventario: duración, mortalidad y población resultante.
class PorcinoStage {
  const PorcinoStage({
    required this.name,
    required this.weeks,
    required this.mortality,
    required this.initialPerWeek,
  });

  final String name;
  final int weeks;
  final double mortality;
  final double initialPerWeek;

  /// Población final por semana = inicial × (1 − mortalidad).
  double get finalPerWeek => initialPerWeek * (1 - mortality);

  /// Población total de la etapa = semanas × población final por semana.
  double get total => weeks * finalPerWeek;
}

/// Inventario por etapa encadenado desde los lechones destetados por semana.
///
/// Cada etapa hereda la población final de la anterior; el total es la suma de
/// las poblaciones totales. Mortalidades por defecto de la diapositiva:
/// pre-iniciación 3 %, iniciación 1 %, crecimiento 0.5 %, finalización 0.5 %.
class PorcinoStageInventory {
  PorcinoStageInventory({
    required this.weanedPerWeek,
    List<PorcinoStageSpec>? specs,
  }) : specs = specs ?? defaultStages {
    if (!weanedPerWeek.isFinite || weanedPerWeek < 0) {
      throw _invalid('Lechones destetados por semana: número no negativo.');
    }
  }

  final double weanedPerWeek;
  final List<PorcinoStageSpec> specs;

  static const defaultStages = <PorcinoStageSpec>[
    PorcinoStageSpec('Pre-iniciación', weeks: 3, mortality: 0.03),
    PorcinoStageSpec('Iniciación', weeks: 3, mortality: 0.01),
    PorcinoStageSpec('Crecimiento y desarrollo', weeks: 8, mortality: 0.005),
    PorcinoStageSpec('Finalización', weeks: 4, mortality: 0.005),
  ];

  /// Etapas resueltas, encadenando la población final de una en la siguiente.
  List<PorcinoStage> get stages {
    final result = <PorcinoStage>[];
    var incoming = weanedPerWeek;
    for (final spec in specs) {
      final stage = PorcinoStage(
        name: spec.name,
        weeks: spec.weeks,
        mortality: spec.mortality,
        initialPerWeek: incoming,
      );
      result.add(stage);
      incoming = stage.finalPerWeek;
    }
    return result;
  }

  /// Suma de las poblaciones totales de todas las etapas.
  double get total {
    var sum = 0.0;
    for (final stage in stages) {
      sum += stage.total;
    }
    return sum;
  }
}

/// Especificación de una etapa antes de encadenarla.
class PorcinoStageSpec {
  const PorcinoStageSpec(this.name, {required this.weeks, required this.mortality});
  final String name;
  final int weeks;
  final double mortality;
}

/// Ganancia diaria de peso y conversión alimenticia de una etapa.
///
/// Con 15–30 kg en 23 días y 0.9 kg/día: GDP 0.65 kg/día, consumo total 20.7 kg
/// y conversión 1.38 (ejemplo del pizarrón).
class PorcinoStagePerformance {
  PorcinoStagePerformance({
    required this.startKg,
    required this.endKg,
    required this.days,
    required this.dailyFeedKg,
  }) {
    if (!startKg.isFinite || startKg <= 0 || startKg > 1000) {
      throw _invalid('Peso inicial: mayor que 0 y hasta 1000 kg.');
    }
    if (!endKg.isFinite || endKg <= 0 || endKg > 1000) {
      throw _invalid('Peso final: mayor que 0 y hasta 1000 kg.');
    }
    if (endKg <= startKg) {
      throw _invalid('Peso final: debe superar al peso inicial.');
    }
    if (days <= 0 || days > 3650) {
      throw _invalid('Días de la etapa: entero entre 1 y 3650.');
    }
    if (!dailyFeedKg.isFinite || dailyFeedKg < 0 || dailyFeedKg > 100) {
      throw _invalid('Consumo diario: número de 0 a 100 kg por animal.');
    }
  }

  final double startKg, endKg, dailyFeedKg;
  final int days;

  /// (Peso final − inicial) ÷ días.
  double get dailyGain => (endKg - startKg) / days;

  /// (Peso inicial + final) ÷ 2.
  double get averageKg => (startKg + endKg) / 2;

  /// Consumo diario × días.
  double get totalFeed => dailyFeedKg * days;

  /// Consumo diario ÷ GDP; 0 si la ganancia es nula.
  double get feedConversion => dailyGain == 0 ? 0 : dailyFeedKg / dailyGain;
}

/// Rendimiento de transformación = producto final ÷ materia prima × 100.
class PorcinoYield {
  PorcinoYield({required this.inputKg, required this.outputKg}) {
    if (!inputKg.isFinite || inputKg <= 0 || inputKg > 1000000) {
      throw _invalid('Materia prima: mayor que 0 y hasta 1000000 kg.');
    }
    if (!outputKg.isFinite || outputKg < 0 || outputKg > 1000000) {
      throw _invalid('Producto final: número de 0 a 1000000 kg.');
    }
  }

  final double inputKg, outputKg;

  /// Producto final ÷ materia prima × 100.
  double get percent => outputKg / inputKg * 100;
}

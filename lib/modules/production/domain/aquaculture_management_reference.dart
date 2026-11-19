/// Calculadoras de manejo de acuicultura que complementan
/// `aquaculture_reference.dart`: conversión alimenticia y costo, recambio de
/// agua, sal contra el nitrito y alimento medicado.
///
/// Especificación de fórmulas y constantes: Claude (2026-11-16), a partir de las
/// 7 calculadoras de referencia de Artemio Lab. Fuentes primarias citadas en
/// cada bloque. Puras y sin estado; no guardan registros ni recomiendan
/// productos ni dosis clínicas.
library;

import 'dart:math' as math;

FormatException _invalid(String message) => FormatException(message);

// ------------------------------------------------ Conversión y costo (FCA)

/// Conversión alimenticia y costo. El FCA aparente usa solo la biomasa
/// producida; el FCA con mortalidad añade la biomasa de los peces muertos
/// (estimada por conteo si no se registró, marcada como supuesto).
class FeedConversionPlan {
  FeedConversionPlan({
    required this.feedKg,
    required this.initialBiomassKg,
    required this.finalBiomassKg,
    required this.withdrawnBiomassKg,
    required this.deadFish,
    required this.initialWeightG,
    required this.finalWeightG,
    required this.feedPricePerKg,
    required this.salePricePerKg,
    required this.days,
  }) {
    if (!feedKg.isFinite || feedKg < 0) {
      throw _invalid('Alimento consumido: no puede ser negativo.');
    }
    if (!initialBiomassKg.isFinite ||
        initialBiomassKg < 0 ||
        !finalBiomassKg.isFinite ||
        finalBiomassKg < 0) {
      throw _invalid('Biomasas inicial y final: no negativas.');
    }
    if (!withdrawnBiomassKg.isFinite || withdrawnBiomassKg < 0) {
      throw _invalid('Biomasa retirada: no puede ser negativa.');
    }
    if (deadFish < 0) {
      throw _invalid('Peces muertos: no puede ser negativo.');
    }
    if (!initialWeightG.isFinite ||
        initialWeightG <= 0 ||
        !finalWeightG.isFinite ||
        finalWeightG <= 0) {
      throw _invalid('Pesos inicial y final: mayores que 0.');
    }
    if (!feedPricePerKg.isFinite || feedPricePerKg < 0) {
      throw _invalid('Precio del alimento: no puede ser negativo.');
    }
    if (!salePricePerKg.isFinite || salePricePerKg < 0) {
      throw _invalid('Precio de venta: no puede ser negativo.');
    }
    if (!days.isFinite || days <= 0) {
      throw _invalid('Días del ciclo: mayor que 0.');
    }
    if (producedBiomassKg <= 0) {
      throw _invalid('La biomasa producida debe ser mayor que 0 para el FCA.');
    }
  }

  final double feedKg, initialBiomassKg, finalBiomassKg, withdrawnBiomassKg;
  final int deadFish;
  final double initialWeightG, finalWeightG, feedPricePerKg, salePricePerKg;
  final double days;

  /// Biomasa producida: final + retirada − inicial.
  double get producedBiomassKg =>
      finalBiomassKg + withdrawnBiomassKg - initialBiomassKg;

  /// FCA aparente = alimento ÷ biomasa producida.
  double get apparentFcr => feedKg / producedBiomassKg;

  /// Biomasa de los peces muertos. Si no se registró, se estima por el conteo
  /// y el peso medio (supuesto, no dato medido).
  double get deadBiomassKg =>
      deadFish * (initialWeightG + finalWeightG) / 2 / 1000;

  /// FCA con mortalidad: suma la biomasa de los muertos al denominador.
  double get fcrWithMortality =>
      feedKg / (producedBiomassKg + deadBiomassKg);

  /// Costo de alimento por kg producido = FCA aparente × precio del alimento.
  double get feedCostPerKg => apparentFcr * feedPricePerKg;

  /// Alimento consumido por día.
  double get feedPerDayKg => feedKg / days;

  /// Ganancia diaria de peso (g/día).
  double get dailyWeightGainG => (finalWeightG - initialWeightG) / days;

  /// Costo del alimento como fracción del precio de venta. Null si no hay
  /// precio de venta.
  double? get feedShareOfSalePrice =>
      salePricePerKg > 0 ? feedCostPerKg / salePricePerKg : null;

  /// Alimento que se gastaría con un FCA objetivo.
  double feedForTargetFcr(double targetFcr) {
    if (!targetFcr.isFinite || targetFcr <= 0) {
      throw _invalid('FCA objetivo: mayor que 0.');
    }
    return targetFcr * producedBiomassKg;
  }

  /// Ahorro de alimento (en dinero) al bajar al FCA objetivo.
  double savingsForTargetFcr(double targetFcr) =>
      (feedKg - feedForTargetFcr(targetFcr)) * feedPricePerKg;
}

// ------------------------------------------------------ Calidad del agua

/// Fracción de amonio no ionizado (NH₃) respecto al nitrógeno amoniacal total,
/// según Emerson et al. 1975. Depende de pH y temperatura.
double unionizedAmmoniaFraction(double ph, double temperatureC) {
  if (!ph.isFinite || ph < 0 || ph > 14) {
    throw _invalid('pH: entre 0 y 14.');
  }
  if (!temperatureC.isFinite || temperatureC <= 0 || temperatureC >= 100) {
    throw _invalid('Temperatura: mayor que 0 y menor que 100 °C.');
  }
  final pka = 0.09018 + 2729.92 / (temperatureC + 273.15);
  return 1 / (1 + math.pow(10, pka - ph));
}

/// Nitrógeno amoniacal total (TAN) a partir del NH₃-N no ionizado deseado.
double totalAmmoniaNitrogen(double unionizedNh3N, double ph, double tempC) {
  if (!unionizedNh3N.isFinite || unionizedNh3N < 0) {
    throw _invalid('NH₃-N no ionizado: no puede ser negativo.');
  }
  return unionizedNh3N / unionizedAmmoniaFraction(ph, tempC);
}

/// Recambio de agua por dilución. La fracción por parámetro es
/// `(actual − deseado) ÷ (actual − agua nueva)`; el recambio necesario es el
/// máximo entre amonio, nitrito y nitrato. Si supera el máximo por recambio,
/// se hacen varios recambios sucesivos.
class WaterExchangePlan {
  WaterExchangePlan({
    required this.volumeM3,
    required this.currentAmmoniaMgL,
    required this.desiredAmmoniaMgL,
    required this.currentNitriteMgL,
    required this.desiredNitriteMgL,
    required this.currentNitrateMgL,
    required this.desiredNitrateMgL,
    this.sourceAmmoniaMgL = 0,
    this.sourceNitriteMgL = 0,
    this.sourceNitrateMgL = 0,
    this.maxFractionPerExchange = 0.30,
  }) {
    if (!volumeM3.isFinite || volumeM3 <= 0) {
      throw _invalid('Volumen: mayor que 0.');
    }
    for (final entry in {
      'Amonio (TAN)': [currentAmmoniaMgL, desiredAmmoniaMgL, sourceAmmoniaMgL],
      'Nitrito (NO₂-N)': [currentNitriteMgL, desiredNitriteMgL, sourceNitriteMgL],
      'Nitrato (NO₃-N)': [currentNitrateMgL, desiredNitrateMgL, sourceNitrateMgL],
    }.entries) {
      if (entry.value.any((v) => !v.isFinite || v < 0)) {
        throw _invalid('${entry.key}: concentraciones no negativas.');
      }
    }
    if (!maxFractionPerExchange.isFinite ||
        maxFractionPerExchange <= 0 ||
        maxFractionPerExchange >= 1) {
      throw _invalid('Máximo por recambio: mayor que 0 y menor que 1.');
    }
  }

  final double volumeM3;
  final double currentAmmoniaMgL, desiredAmmoniaMgL;
  final double currentNitriteMgL, desiredNitriteMgL;
  final double currentNitrateMgL, desiredNitrateMgL;
  final double sourceAmmoniaMgL, sourceNitriteMgL, sourceNitrateMgL;
  final double maxFractionPerExchange;

  static double fractionFor(double current, double desired, double source) {
    if (current <= desired) return 0;
    if (current <= source) return 1;
    return (current - desired) / (current - source);
  }

  double get ammoniaFraction =>
      fractionFor(currentAmmoniaMgL, desiredAmmoniaMgL, sourceAmmoniaMgL);
  double get nitriteFraction =>
      fractionFor(currentNitriteMgL, desiredNitriteMgL, sourceNitriteMgL);
  double get nitrateFraction =>
      fractionFor(currentNitrateMgL, desiredNitrateMgL, sourceNitrateMgL);

  /// Fracción del recambio: el parámetro que más lo exige.
  double get requiredFraction =>
      [ammoniaFraction, nitriteFraction, nitrateFraction]
          .reduce(math.max);

  /// Litros a recambiar en un solo recambio.
  double get liters => requiredFraction * volumeM3 * 1000;

  /// Parámetro que exige el recambio, con su valor actual, deseado y de agua
  /// nueva. Si hay empate, se toma el primero (amonio, nitrito, nitrato).
  ({double current, double desired, double source}) get _worst {
    final fractions = [ammoniaFraction, nitriteFraction, nitrateFraction];
    final index = fractions.indexOf(requiredFraction);
    return switch (index) {
      0 => (
          current: currentAmmoniaMgL,
          desired: desiredAmmoniaMgL,
          source: sourceAmmoniaMgL,
        ),
      1 => (
          current: currentNitriteMgL,
          desired: desiredNitriteMgL,
          source: sourceNitriteMgL,
        ),
      _ => (
          current: currentNitrateMgL,
          desired: desiredNitrateMgL,
          source: sourceNitrateMgL,
        ),
    };
  }

  /// Recambios sucesivos necesarios si un solo recambio no alcanza. Sin agua
  /// nueva, n = ⌈ln(deseado/actual) ÷ ln(1 − máximo)⌉; con agua nueva que ya
  /// trae el parámetro, se busca el menor n que cumpla
  /// C·(1−f)ⁿ + S·(1−(1−f)ⁿ) ≤ deseado.
  int get exchanges {
    if (requiredFraction <= maxFractionPerExchange) return 1;
    final worst = _worst;
    if (worst.source > 0) {
      final f = maxFractionPerExchange;
      var value = worst.current;
      for (var n = 1; n <= 100; n++) {
        value = value * (1 - f) + worst.source * f;
        if (value <= worst.desired) return n;
      }
      return 100;
    }
    return (math.log(worst.desired / worst.current) /
            math.log(1 - maxFractionPerExchange))
        .ceil();
  }
}

// ------------------------------------------------- Sal contra el nitrito

/// Corrección de cloruro contra la toxicidad del nitrito. La sal común
/// (NaCl) es 60,66 % cloruro, así que 1 mg/L de Cl exige 1,65 g de NaCl puro
/// por m³.
class NitriteSaltPlan {
  NitriteSaltPlan({
    required this.volumeM3,
    required this.nitriteNitrogenMgL,
    required this.currentChlorideMgL,
    this.ratio = 20,
    this.maintenanceChlorideMgL = 0,
    this.purityPercent = 100,
  }) {
    if (!volumeM3.isFinite || volumeM3 <= 0) {
      throw _invalid('Volumen: mayor que 0.');
    }
    if (!nitriteNitrogenMgL.isFinite || nitriteNitrogenMgL < 0) {
      throw _invalid('Nitrito (NO₂-N): no puede ser negativo.');
    }
    if (!currentChlorideMgL.isFinite || currentChlorideMgL < 0) {
      throw _invalid('Cloruro actual: no puede ser negativo.');
    }
    if (!ratio.isFinite || ratio <= 0) {
      throw _invalid('Relación Cl:NO₂-N: mayor que 0.');
    }
    if (!maintenanceChlorideMgL.isFinite || maintenanceChlorideMgL < 0) {
      throw _invalid('Cloruro de mantenimiento: no puede ser negativo.');
    }
    if (!purityPercent.isFinite || purityPercent <= 0 || purityPercent > 100) {
      throw _invalid('Pureza de la sal: mayor que 0 y hasta 100 %.');
    }
  }

  /// 1 ÷ 0,6066 = 1,65 g de NaCl puro por m³ por cada mg/L de cloruro.
  static const saltPerChlorideGramPerM3 = 1.65;

  final double volumeM3, nitriteNitrogenMgL, currentChlorideMgL;
  final double ratio, maintenanceChlorideMgL, purityPercent;

  /// Cloruro objetivo = máximo entre la relación y el mantenimiento.
  double get targetChlorideMgL =>
      math.max(ratio * nitriteNitrogenMgL, maintenanceChlorideMgL);

  /// Cloruro que falta añadir.
  double get chlorideToAddMgL =>
      math.max(0, targetChlorideMgL - currentChlorideMgL);

  /// Sal pura por m³.
  double get pureSaltGramPerM3 =>
      chlorideToAddMgL * saltPerChlorideGramPerM3;

  /// Sal comercial por m³ (corregida por pureza).
  double get saltGramPerM3 => pureSaltGramPerM3 / (purityPercent / 100);

  /// Sal comercial total del volumen.
  double get saltKg => saltGramPerM3 * volumeM3 / 1000;

  /// Salinidad añadida (g/L de NaCl puro).
  double get addedSalinityGramPerL =>
      pureSaltGramPerM3 / 1000;

  /// Relación cloruro : nitrito actual (alerta si baja de 10).
  double? get currentRatio =>
      nitriteNitrogenMgL > 0 ? currentChlorideMgL / nitriteNitrogenMgL : null;

  bool get belowMinimumRatio =>
      nitriteNitrogenMgL > 0 && currentChlorideMgL / nitriteNitrogenMgL < 10;
}

// ------------------------------------------------ Alimento medicado

enum MedicatedDoseBasis {
  /// Dosis por kg de pez y día (mg de activo / kg de pez / día).
  perFishPerDay,

  /// Dosis por kg de alimento (mg de activo / kg de alimento).
  perKgFeed,
}

/// Aritmética de alimento medicado o suplementado. No recomienda productos ni
/// dosis: solo convierte lo que el profesional ya decidió.
class MedicatedFeedPlan {
  MedicatedFeedPlan({
    required this.biomassKg,
    required this.dailyFeedKg,
    required this.doseBasis,
    required this.doseValue,
    required this.productConcentration,
    required this.treatmentDays,
  }) {
    if (!biomassKg.isFinite || biomassKg <= 0) {
      throw _invalid('Biomasa: mayor que 0.');
    }
    if (!dailyFeedKg.isFinite || dailyFeedKg <= 0) {
      throw _invalid('Alimento por día: mayor que 0.');
    }
    if (!doseValue.isFinite || doseValue < 0) {
      throw _invalid('Dosis: no puede ser negativa.');
    }
    if (!productConcentration.isFinite || productConcentration <= 0) {
      throw _invalid('Concentración del producto: mayor que 0.');
    }
    if (!treatmentDays.isFinite || treatmentDays <= 0) {
      throw _invalid('Días de tratamiento: mayor que 0.');
    }
  }

  final double biomassKg, dailyFeedKg, doseValue, productConcentration;
  final MedicatedDoseBasis doseBasis;
  final double treatmentDays;

  /// Activo por día (g). Por pez: mg/kg/día × biomasa ÷ 1000. Por alimento:
  /// mg/kg de alimento × kg de alimento ÷ 1000.
  double get activeGramsPerDay => doseBasis == MedicatedDoseBasis.perFishPerDay
      ? doseValue * biomassKg / 1000
      : doseValue * dailyFeedKg / 1000;

  /// Producto por día (g) según su concentración (g de activo / g de producto).
  double get productGramsPerDay => activeGramsPerDay / productConcentration;

  /// Producto por kg de alimento.
  double get productPerKgFeed => productGramsPerDay / dailyFeedKg;

  /// Producto para el lote: todo el tratamiento si no se indica una cantidad.
  double get batchGrams => productPerKgFeed * dailyFeedKg * treatmentDays;

  /// Inclusión (% p/p) del producto en el alimento.
  double get inclusionPercent => productPerKgFeed / 10;

  /// Dosis real si los peces comen menos de lo ofrecido.
  double realDoseAtConsumption(double consumptionFraction) {
    if (!consumptionFraction.isFinite ||
        consumptionFraction < 0 ||
        consumptionFraction > 1) {
      throw _invalid('Consumo: entre 0 y 1.');
    }
    return doseValue * consumptionFraction;
  }

  /// Concentración del producto a partir de un porcentaje p/p.
  static double concentrationFromPercent(double percent) => percent / 100;
}

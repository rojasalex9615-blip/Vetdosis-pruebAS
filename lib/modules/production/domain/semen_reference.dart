/// Evaluación seminal por especie: cerdo, perro y caballo.
///
/// Extiende el módulo porcino (`porcino_semen.dart`) con la dimensión de
/// especie del prototipo «Evaluación seminal por especie»: el perro evalúa el
/// eyaculado (Tittarelli, cap. 12, fracción espermática; el capítulo no da
/// dosis) y el caballo reparte el eyaculado en dosis de progresivos
/// (Egyptien et al. 2023: 300–500 ×10⁶ progresivos por dosis; el número de
/// dosis es un cálculo derivado).
///
/// Reutiliza las piezas genéricas ya versionadas: [SemenChamber],
/// [SemenConcentration] y [SemenInsemination]. Cálculo de sesión, sin base de
/// datos. Umbrales editables; por defecto son los del material de clase.
library;

FormatException _invalid(String message) => FormatException(message);

/// Un tipo de dosis: etiqueta y espermatozoides por dosis, en ×10⁹.
///
/// En el caballo la cifra son progresivos (0.3–0.5 ×10⁹); en el cerdo,
/// espermatozoides totales (2–3 ×10⁹).
class SemenDoseType {
  const SemenDoseType(this.label, this.spermPerDoseBillion, {this.volumeRange});
  final String label;
  final double spermPerDoseBillion;

  /// Rango orientativo del volumen por dosis, en ml (solo el cerdo).
  final ({double min, double max})? volumeRange;
}

/// Umbrales de calidad editables, por especie.
class SemenThresholds {
  const SemenThresholds({
    required this.motilityMin,
    this.morphologyMin,
    this.progressiveMin,
    this.vslMin,
    this.strMin,
    required this.volumeMinMl,
    required this.totalSpermMinBillion,
  });
  final double motilityMin;
  final double? morphologyMin;
  final double? progressiveMin;
  final double? vslMin;
  final double? strMin;
  final double volumeMinMl;
  final double totalSpermMinBillion;

  void validate() {
    for (final (value, label) in [
      (motilityMin, 'Motilidad mínima'),
      (morphologyMin, 'Morfología mínima'),
      (progressiveMin, 'Progresiva mínima'),
      (strMin, 'STR mínimo'),
    ]) {
      if (value != null && (!value.isFinite || value < 0 || value > 100)) {
        throw _invalid('$label: entre 0 y 100 %.');
      }
    }
    if (vslMin != null && (!vslMin!.isFinite || vslMin! < 0 || vslMin! > 500)) {
      throw _invalid('VSL mínimo: entre 0 y 500 µm/s.');
    }
    if (!volumeMinMl.isFinite || volumeMinMl < 0 || volumeMinMl > 1000) {
      throw _invalid('Volumen mínimo: entre 0 y 1000 ml.');
    }
    if (!totalSpermMinBillion.isFinite || totalSpermMinBillion < 0) {
      throw _invalid('Total mínimo: no puede ser negativo.');
    }
  }
}

/// Perfil de evaluación por especie: qué campos aplican, umbrales por defecto,
/// tipos de dosis y si el volumen por dosis se captura.
class SemenSpeciesProfile {
  const SemenSpeciesProfile({
    required this.id,
    required this.label,
    required this.source,
    required this.volumeLabel,
    required this.motilityLabel,
    required this.showMorphology,
    required this.showProgressive,
    required this.morphologyInCount,
    required this.progressiveInCount,
    required this.showKinetics,
    required this.showDoseVolume,
    required this.showDiluent,
    required this.assessesDoses,
    required this.doseTypes,
    required this.thresholds,
    required this.exampleVolumeMl,
    required this.exampleConcentration,
    required this.exampleMotility,
    this.exampleMorphology,
    this.exampleProgressive,
    this.exampleVsl,
    this.exampleStr,
    this.exampleDoseVolumeMl,
    this.exampleDoseTypeIndex,
  });
  final String id, label, source, volumeLabel, motilityLabel;
  final bool showMorphology, showProgressive, showKinetics;

  /// Si la morfología o la progresiva multiplican el recuento de espermatozoides
  /// útiles. En el prototipo el cerdo usa motilidad × morfología y el caballo
  /// usa la progresiva; el perro solo muestra el total.
  final bool morphologyInCount, progressiveInCount;
  final bool showDoseVolume, showDiluent;

  /// El cerdo y el caballo reparten en dosis; el perro solo evalúa el eyaculado.
  final bool assessesDoses;
  final List<SemenDoseType> doseTypes;
  final SemenThresholds thresholds;

  final double exampleVolumeMl, exampleConcentration, exampleMotility;
  final double? exampleMorphology, exampleProgressive, exampleVsl, exampleStr;
  final double? exampleDoseVolumeMl;
  final int? exampleDoseTypeIndex;
}

/// Perfiles por especie, con los valores de ejemplo del prototipo.
const semenSpeciesProfiles = <SemenSpeciesProfile>[
  SemenSpeciesProfile(
    id: 'cerdo',
    label: 'Cerdo',
    source: 'Práctica con iSPERM y Rodríguez-Martínez (verraco).',
    volumeLabel: 'Volumen del eyaculado (ml)',
    motilityLabel: 'Motilidad total (%)',
    showMorphology: true,
    showProgressive: true,
    morphologyInCount: true,
    progressiveInCount: false,
    showKinetics: true,
    showDoseVolume: true,
    showDiluent: true,
    assessesDoses: true,
    doseTypes: [
      SemenDoseType(
        'Cervical (3 × 10⁹)',
        3,
        volumeRange: (min: 80, max: 100),
      ),
      SemenDoseType(
        'Poscervical (2 × 10⁹)',
        2,
        volumeRange: (min: 60, max: 80),
      ),
    ],
    thresholds: SemenThresholds(
      motilityMin: 85,
      progressiveMin: 70,
      vslMin: 30,
      strMin: 70,
      morphologyMin: 85,
      volumeMinMl: 50,
      totalSpermMinBillion: 10,
    ),
    exampleVolumeMl: 200,
    exampleConcentration: 380,
    exampleMotility: 90,
    exampleMorphology: 88,
    exampleProgressive: 75,
    exampleVsl: 35,
    exampleStr: 75,
    exampleDoseVolumeMl: 80,
    exampleDoseTypeIndex: 1,
  ),
  SemenSpeciesProfile(
    id: 'perro',
    label: 'Perro',
    source:
        'Tittarelli, cap. 12 (fracción espermática). El capítulo no da dosis '
        'por inseminación, por eso aquí solo se evalúa el eyaculado.',
    volumeLabel: 'Volumen de la fracción espermática (ml)',
    motilityLabel: 'Motilidad progresiva (%)',
    showMorphology: true,
    showProgressive: false,
    morphologyInCount: false,
    progressiveInCount: false,
    showKinetics: false,
    showDoseVolume: false,
    showDiluent: false,
    assessesDoses: false,
    doseTypes: [],
    thresholds: SemenThresholds(
      motilityMin: 70,
      morphologyMin: 70,
      volumeMinMl: 0.5,
      totalSpermMinBillion: 0.2,
    ),
    exampleVolumeMl: 3,
    exampleConcentration: 80,
    exampleMotility: 80,
    exampleMorphology: 80,
  ),
  SemenSpeciesProfile(
    id: 'caballo',
    label: 'Caballo',
    source:
        'Egyptien et al. 2023. El artículo da el criterio (300–500 ×10⁶ '
        'progresivos por dosis), el número de dosis es un cálculo derivado.',
    volumeLabel: 'Volumen (ml)',
    motilityLabel: 'Motilidad total (%)',
    showMorphology: false,
    showProgressive: true,
    morphologyInCount: false,
    progressiveInCount: true,
    showKinetics: false,
    showDoseVolume: false,
    showDiluent: false,
    assessesDoses: true,
    doseTypes: [
      SemenDoseType('300 × 10⁶ progresivos', 0.3),
      SemenDoseType('400 × 10⁶ progresivos', 0.4),
      SemenDoseType('500 × 10⁶ progresivos', 0.5),
    ],
    thresholds: SemenThresholds(
      motilityMin: 70,
      progressiveMin: 50,
      volumeMinMl: 0,
      totalSpermMinBillion: 4,
    ),
    exampleVolumeMl: 50,
    exampleConcentration: 200,
    exampleMotility: 75,
    exampleProgressive: 60,
    exampleDoseTypeIndex: 2,
  ),
];

SemenSpeciesProfile semenSpeciesProfile(String id) =>
    semenSpeciesProfiles.firstWhere(
      (p) => p.id == id,
      orElse: () => throw _invalid('Especie seminal desconocida: $id.'),
    );

/// Evaluación y reparto seminal de un eyaculado, según la especie.
///
/// Espermatozoides útiles:
/// - cerdo: volumen × concentración × motilidad × morfología, menos pérdidas.
/// - caballo: volumen × concentración × progresiva, menos pérdidas.
///
/// Las dosis se redondean hacia abajo: una fracción no completa una dosis.
class SemenEvaluation {
  SemenEvaluation({
    required this.profile,
    required this.volumeMl,
    required this.concentrationMillionsPerMl,
    required this.motilityPercent,
    this.morphologyPercent,
    this.progressivePercent,
    this.spermPerDoseBillion,
    this.doseVolumeMl,
    this.doseVolumeRange,
    this.lossPercent = 0,
    this.shelfLifeDays,
    this.collectedOn,
    SemenThresholds? thresholds,
  }) : thresholds = thresholds ?? profile.thresholds {
    if (!volumeMl.isFinite || volumeMl <= 0 || volumeMl > 1000) {
      throw _invalid('$volumeLabel: mayor que 0 y hasta 1000 ml.');
    }
    if (!concentrationMillionsPerMl.isFinite ||
        concentrationMillionsPerMl <= 0 ||
        concentrationMillionsPerMl > 5000) {
      throw _invalid('Concentración: mayor que 0 y hasta 5000 ×10⁶/ml.');
    }
    _percent(motilityPercent, motilityLabel);
    if (profile.showMorphology) {
      if (morphologyPercent == null) {
        throw _invalid('Morfología normal: hace falta para esta especie.');
      }
      _percent(morphologyPercent!, 'Morfología normal');
    }
    if (profile.showProgressive) {
      if (progressivePercent == null) {
        throw _invalid('Motilidad progresiva: hace falta para esta especie.');
      }
      _percent(progressivePercent!, 'Motilidad progresiva');
    }
    if (!lossPercent.isFinite || lossPercent < 0 || lossPercent >= 100) {
      throw _invalid('Margen de pérdida: de 0 a menos de 100 %.');
    }
    this.thresholds.validate();
    if (profile.assessesDoses) {
      final perDose = spermPerDoseBillion;
      if (perDose == null || !perDose.isFinite || perDose <= 0) {
        throw _invalid('Espermas por dosis: mayor que 0.');
      }
      if (profile.showDoseVolume) {
        if (doseVolumeMl == null ||
            !doseVolumeMl!.isFinite ||
            doseVolumeMl! <= 0 ||
            doseVolumeMl! > 200) {
          throw _invalid('Volumen por dosis: mayor que 0 y hasta 200 ml.');
        }
      }
      if (profile.showDiluent && (shelfLifeDays == null || collectedOn == null)) {
        throw _invalid('Diluyente y fecha de colecta: hacen falta para el CAD.');
      }
    }
  }

  static void _percent(double value, String label) {
    if (!value.isFinite || value < 0 || value > 100) {
      throw _invalid('$label: entre 0 y 100 %.');
    }
  }

  final SemenSpeciesProfile profile;
  final double volumeMl, concentrationMillionsPerMl, motilityPercent;
  final double? morphologyPercent, progressivePercent;
  final double? spermPerDoseBillion, doseVolumeMl;

  /// Rango orientativo del volumen por dosis del tipo elegido, si se conoce.
  final ({double min, double max})? doseVolumeRange;
  final double lossPercent;
  final int? shelfLifeDays;
  final DateTime? collectedOn;

  /// Umbrales efectivos: los del perfil salvo que se pasen editados.
  final SemenThresholds thresholds;

  String get volumeLabel => profile.volumeLabel;
  String get motilityLabel => profile.motilityLabel;

  double get _retained => 1 - lossPercent / 100;

  /// Espermatozoides totales del eyaculado (sin descontar calidad), ×10⁹.
  double get totalSpermBillion =>
      volumeMl * concentrationMillionsPerMl * 1e6 / 1e9;

  /// Espermatozoides útiles del eyaculado (unidades absolutas).
  double get usableSperm {
    var sperm = volumeMl * concentrationMillionsPerMl * 1e6;
    if (profile.morphologyInCount) {
      sperm *= (morphologyPercent ?? 0) / 100;
    }
    sperm *= motilityPercent / 100;
    if (profile.progressiveInCount) {
      sperm *= (progressivePercent ?? 0) / 100;
    }
    return sperm * _retained;
  }

  double get usableSpermBillion => usableSperm / 1e9;

  /// Dosis completas. Null si la especie no reparte en dosis (perro).
  int? get doses {
    if (!profile.assessesDoses) return null;
    final perDose = spermPerDoseBillion! * 1e9;
    final n = usableSperm / perDose;
    return n.isFinite && n > 0 ? n.floor() : 0;
  }

  /// Volumen final repartido, en ml (solo si se captura el volumen por dosis).
  double? get finalVolumeMl =>
      profile.showDoseVolume ? (doses ?? 0) * doseVolumeMl! : null;

  /// Diluyente a preparar para completar las dosis, en ml.
  double? get diluentToAddMl {
    final vf = finalVolumeMl;
    if (vf == null) return null;
    final extra = vf - volumeMl;
    return extra > 0 ? extra : 0;
  }

  /// Espermatozoides que sobran sin completar otra dosis, ×10⁹.
  double? get leftoverSpermBillion {
    if (!profile.assessesDoses) return null;
    return (usableSperm - (doses ?? 0) * spermPerDoseBillion! * 1e9) / 1e9;
  }

  /// Fecha mínima de uso (mínimo del rango del diluyente). Null si no aplica.
  DateTime? get useBefore {
    final days = shelfLifeDays;
    final collected = collectedOn;
    if (days == null || collected == null) return null;
    return DateTime(
      collected.year,
      collected.month,
      collected.day,
    ).add(Duration(days: days));
  }

  /// El volumen final no cubre ni el eyaculado: algo no cuadra.
  bool get volumeShortfall {
    final vf = finalVolumeMl;
    return vf != null && vf < volumeMl;
  }

  /// Avisos del reparto, en el orden del prototipo. Lista vacía si todo cuadra.
  List<String> get alerts {
    final list = <String>[];
    if (volumeShortfall) {
      list.add(
        'El volumen final es menor al eyaculado: revisa el volumen por dosis.',
      );
    }
    final range = doseVolumeRange;
    if (range != null &&
        doseVolumeMl != null &&
        (doseVolumeMl! < range.min || doseVolumeMl! > range.max)) {
      list.add(
        'Volumen por dosis fuera del rango de ${_num(range.min)}–'
        '${_num(range.max)} ml.',
      );
    }
    if (volumeMl < thresholds.volumeMinMl) {
      list.add(
        'Volumen menor a ${_num(thresholds.volumeMinMl)} ml: posible colecta '
        'incompleta, repetir.',
      );
    }
    if (totalSpermBillion < thresholds.totalSpermMinBillion) {
      list.add(
        'Menos de ${_num(thresholds.totalSpermMinBillion)} × 10⁹ '
        'espermatozoides en el eyaculado.',
      );
    }
    return list;
  }

  /// Criterios de calidad por debajo del umbral.
  List<String> get qualityFailures {
    final t = thresholds;
    final list = <String>[];
    if (motilityPercent < t.motilityMin) {
      list.add('motilidad <${_num(t.motilityMin)} %');
    }
    if (t.progressiveMin != null &&
        (progressivePercent ?? 0) < t.progressiveMin!) {
      list.add('progresiva <${_num(t.progressiveMin!)} %');
    }
    if (t.morphologyMin != null &&
        (morphologyPercent ?? 0) < t.morphologyMin!) {
      list.add('morfología normal <${_num(t.morphologyMin!)} %');
    }
    return list;
  }

  bool get isApt => qualityFailures.isEmpty;

  String get verdict => isApt
      ? 'Cumple los mínimos de calidad.'
      : 'No cumple: ${qualityFailures.join(', ')}.';
}

/// Formatea un número sin decimales sobrantes (85 → «85», 70.5 → «70.5»).
String _num(double value) {
  final fixed = value.toStringAsFixed(1);
  return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
}

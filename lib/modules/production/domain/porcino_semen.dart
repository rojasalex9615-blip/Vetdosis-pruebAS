/// Dosis seminales porcinas: del eyaculado a las dosis de inseminación.
///
/// Cálculo de sesión, sin base de datos. Réplica del prototipo «Dosis seminales
/// porcinas» de la hoja de clase. La dilución y el área de conteo quedan por
/// confirmar con el material del curso: la app no las da por buenas.
library;

FormatException _invalid(String message) => FormatException(message);

/// Cámara de conteo y su factor: células contadas × factor = células/ml antes
/// de la dilución. En una cámara de Neubauer, 5 cuadros medianos ocupan 0.02 µl
/// (1 ÷ 0.02 µl = 50 000 por ml) y un cuadro grande de 1 mm² ocupa 0.1 µl
/// (10 000 por ml).
enum SemenChamber {
  smallSquares('5 cuadros medianos (4 esquinas + centro)', 50000),
  largeSquare('1 cuadro grande de 1 mm²', 10000);

  const SemenChamber(this.label, this.factor);
  final String label;
  final double factor;
}

/// Concentración espermática en ×10⁶/ml, por conteo en cámara o capturada.
class SemenConcentration {
  SemenConcentration.fromCount({
    required int cells,
    required double dilution,
    required SemenChamber chamber,
  }) : millionsPerMl = cells * dilution * chamber.factor / 1e6 {
    if (cells <= 0 || cells > 100000) {
      throw _invalid('Células contadas: entero entre 1 y 100000.');
    }
    if (!dilution.isFinite || dilution < 1 || dilution > 10000) {
      throw _invalid('Factor de dilución: entre 1 y 10000.');
    }
  }

  SemenConcentration.direct(double value) : millionsPerMl = value {
    if (!value.isFinite || value <= 0 || value > 5000) {
      throw _invalid('Concentración: mayor que 0 y hasta 5000 ×10⁶/ml.');
    }
  }

  /// En millones por mililitro (×10⁶/ml).
  final double millionsPerMl;
}

/// Vía de inseminación: dosis de referencia (×10⁹) y rango orientativo del
/// volumen por dosis, en ml.
enum SemenInsemination {
  cervical('Cervical', 3, 80, 100),
  postCervical('Poscervical', 2, 60, 80);

  const SemenInsemination(
    this.label,
    this.spermPerDoseBillion,
    this.doseVolumeMinMl,
    this.doseVolumeMaxMl,
  );
  final String label;
  final double spermPerDoseBillion, doseVolumeMinMl, doseVolumeMaxMl;

  ({double min, double max}) get doseVolumeRange =>
      (min: doseVolumeMinMl, max: doseVolumeMaxMl);
}

/// Umbrales de calidad editables. Por defecto son los criterios de la práctica
/// con analizador (iSPERM); con microscopio y evaluación subjetiva otras
/// fuentes aceptan mínimos distintos. No son un contrato del servidor.
class SemenQualityThresholds {
  const SemenQualityThresholds({
    this.motilityTotalMin = 85,
    this.progressiveMin = 70,
    this.vslMin = 30,
    this.strMin = 70,
    this.volumeMinMl = 50,
  });

  final double motilityTotalMin, progressiveMin, vslMin, strMin, volumeMinMl;
}

void _checkThresholds(SemenQualityThresholds t) {
  for (final (value, label) in [
    (t.motilityTotalMin, 'Motilidad total mínima'),
    (t.progressiveMin, 'Progresiva mínima'),
    (t.strMin, 'STR mínimo'),
  ]) {
    if (!value.isFinite || value < 0 || value > 100) {
      throw _invalid('$label: entre 0 y 100 %.');
    }
  }
  if (!t.vslMin.isFinite || t.vslMin < 0 || t.vslMin > 500) {
    throw _invalid('VSL mínimo: entre 0 y 500 µm/s.');
  }
  if (!t.volumeMinMl.isFinite || t.volumeMinMl < 0 || t.volumeMinMl > 1000) {
    throw _invalid('Volumen mínimo del eyaculado: entre 0 y 1000 ml.');
  }
}

/// Aptitud del eyaculado para inseminar, contra los umbrales elegidos.
class SemenQualityAssessment {
  SemenQualityAssessment({
    required this.motilityPercent,
    required this.progressivePercent,
    required this.strPercent,
    required this.vslMicronsPerSecond,
    this.thresholds = const SemenQualityThresholds(),
  }) {
    for (final (value, label) in [
      (motilityPercent, 'Motilidad'),
      (progressivePercent, 'Motilidad progresiva'),
      (strPercent, 'STR'),
    ]) {
      if (!value.isFinite || value < 0 || value > 100) {
        throw _invalid('$label: entre 0 y 100 %.');
      }
    }
    if (!vslMicronsPerSecond.isFinite ||
        vslMicronsPerSecond < 0 ||
        vslMicronsPerSecond > 500) {
      throw _invalid('VSL: entre 0 y 500 µm/s.');
    }
    _checkThresholds(thresholds);
  }

  final double motilityPercent, progressivePercent, strPercent;
  final double vslMicronsPerSecond;
  final SemenQualityThresholds thresholds;

  /// Criterios por debajo del umbral, con su valor exigido.
  List<String> get failures {
    final list = <String>[];
    if (motilityPercent < thresholds.motilityTotalMin) {
      list.add('motilidad total <${_num(thresholds.motilityTotalMin)} %');
    }
    if (progressivePercent < thresholds.progressiveMin) {
      list.add('progresiva <${_num(thresholds.progressiveMin)} %');
    }
    if (vslMicronsPerSecond < thresholds.vslMin) {
      list.add('VSL <${_num(thresholds.vslMin)} µm/s');
    }
    if (strPercent < thresholds.strMin) {
      list.add('STR <${_num(thresholds.strMin)} %');
    }
    return list;
  }

  bool get isApt => failures.isEmpty;

  String get verdict => isApt
      ? 'Cumple los mínimos de calidad.'
      : 'No apto para inseminar: ${failures.join(', ')}.';
}

/// Vida útil del diluyente, en días desde la colecta.
enum SemenDiluent {
  short('Corta duración (3–4 días)', 3),
  medium('Media duración (7–10 días)', 7),
  long('Larga duración (14 días)', 14);

  const SemenDiluent(this.label, this.days);
  final String label;
  final int days;
}

const semenSource =
    'Prototipo «Dosis seminales porcinas» de la hoja de clase. La dilución '
    'cambia según el método (1:200 o 1:100): confírmala con tu material del '
    'curso; sin validación externa.';

/// Atajo del conteo: con dilución 1:200 y 5 cuadros medianos, células
/// contadas × 10 = millones/ml. La dilución depende del protocolo.
const semenCountShortcut =
    'Atajo con 1:200 y 5 cuadros medianos: células contadas × 10 = millones/ml. '
    'La dilución cambia según el método (ej. 1:100 en otros protocolos): '
    'confírmala con tu profe.';

const semenProtocol = [
  'Preparar el diluyente y atemperarlo.',
  'Mezclar semen y diluyente a temperatura ambiente (30 min a 1 h).',
  'Repartir en botes o bolsas del volumen por dosis.',
  'Media hora a temperatura ambiente y luego a 17 °C.',
  'Rotar las dosis de forma periódica (el esperma se asienta).',
  'Antes de inseminar, mover lento y atemperar.',
  'Inseminar al detectar el celo, de nuevo a las 12 h y a las 24 h.',
];

/// Reparto de un eyaculado en dosis de inseminación.
///
/// Espermas útiles = volumen × concentración × motilidad × morfología, menos el
/// margen de pérdida. Las dosis se redondean hacia abajo: una fracción no
/// completa una dosis.
class SemenDosePlan {
  SemenDosePlan({
    required this.volumeMl,
    required this.concentrationMillionsPerMl,
    required this.motilityPercent,
    required this.morphologyPercent,
    required this.spermPerDoseBillion,
    required this.doseVolumeMl,
    required this.lossPercent,
    required this.shelfLifeDays,
    required this.collectedOn,
    this.doseVolumeRange,
    this.thresholds = const SemenQualityThresholds(),
  }) {
    if (!volumeMl.isFinite || volumeMl <= 0 || volumeMl > 1000) {
      throw _invalid('Volumen del eyaculado: mayor que 0 y hasta 1000 ml.');
    }
    if (!concentrationMillionsPerMl.isFinite ||
        concentrationMillionsPerMl <= 0 ||
        concentrationMillionsPerMl > 5000) {
      throw _invalid('Concentración: mayor que 0 y hasta 5000 ×10⁶/ml.');
    }
    for (final (value, label) in [
      (motilityPercent, 'Motilidad'),
      (morphologyPercent, 'Morfología'),
    ]) {
      if (!value.isFinite || value < 0 || value > 100) {
        throw _invalid('$label: entre 0 y 100 %.');
      }
    }
    if (!spermPerDoseBillion.isFinite ||
        spermPerDoseBillion <= 0 ||
        spermPerDoseBillion > 10) {
      throw _invalid('Espermas por dosis: mayor que 0 y hasta 10 ×10⁹.');
    }
    if (!doseVolumeMl.isFinite || doseVolumeMl <= 0 || doseVolumeMl > 200) {
      throw _invalid('Volumen por dosis: mayor que 0 y hasta 200 ml.');
    }
    if (!lossPercent.isFinite || lossPercent < 0 || lossPercent >= 100) {
      throw _invalid('Margen de pérdida: de 0 a menos de 100 %.');
    }
    if (shelfLifeDays < 1 || shelfLifeDays > 60) {
      throw _invalid('Vida del diluyente: de 1 a 60 días.');
    }
    _checkThresholds(thresholds);
  }

  final double volumeMl, concentrationMillionsPerMl;
  final double motilityPercent, morphologyPercent;
  final double spermPerDoseBillion, doseVolumeMl, lossPercent;
  final int shelfLifeDays;
  final DateTime collectedOn;

  /// Rango orientativo del volumen por dosis para la vía elegida, si se conoce.
  final ({double min, double max})? doseVolumeRange;
  final SemenQualityThresholds thresholds;

  double get _motileFraction => motilityPercent / 100;
  double get _normalFraction => morphologyPercent / 100;
  double get _retainedFraction => 1 - lossPercent / 100;

  /// Espermatozoides útiles del eyaculado (unidades absolutas).
  double get usableSperm =>
      volumeMl *
      concentrationMillionsPerMl *
      1e6 *
      _motileFraction *
      _normalFraction *
      _retainedFraction;

  /// Dosis completas que se pueden preparar.
  int get doses {
    final perDose = spermPerDoseBillion * 1e9;
    final n = usableSperm / perDose;
    return n.isFinite && n > 0 ? n.floor() : 0;
  }

  /// Espermatozoides útiles totales, en ×10⁹.
  double get usableSpermBillion => usableSperm / 1e9;

  /// Volumen final de semen diluido ya repartido, en ml.
  double get finalVolumeMl => doses * doseVolumeMl;

  /// Diluyente a preparar para completar el volumen de las dosis, en ml.
  double get diluentToAddMl {
    final extra = finalVolumeMl - volumeMl;
    return extra > 0 ? extra : 0;
  }

  /// Espermatozoides que sobran sin completar otra dosis, en ×10⁹.
  double get leftoverSpermBillion =>
      (usableSperm - doses * spermPerDoseBillion * 1e9) / 1e9;

  /// Fecha mínima de uso, como el mínimo del rango del diluyente.
  DateTime get useBefore {
    final base = DateTime(
      collectedOn.year,
      collectedOn.month,
      collectedOn.day,
    );
    return base.add(Duration(days: shelfLifeDays));
  }

  /// El volumen final no cubre ni el eyaculado: algo no cuadra.
  bool get volumeShortfall => finalVolumeMl < volumeMl;

  /// Espermatozoides totales del eyaculado (sin descontar calidad), ×10⁹.
  double get totalSpermBillion =>
      volumeMl * concentrationMillionsPerMl * 1e6 / 1e9;

  /// Avisos del reparto, en el orden del prototipo. Lista vacía si todo cuadra.
  List<String> get alerts {
    final list = <String>[];
    if (volumeShortfall) {
      list.add(
        'El volumen final es menor al eyaculado: revisa el volumen por dosis.',
      );
    }
    if (volumeMl < thresholds.volumeMinMl) {
      list.add(
        'Eyaculado <${_num(thresholds.volumeMinMl)} ml: posible colecta '
        'incompleta, repetir.',
      );
    }
    if (totalSpermBillion < 10) {
      list.add(
        'Menos de 10 × 10⁹ espermatozoides totales en el eyaculado.',
      );
    }
    final range = doseVolumeRange;
    if (range != null &&
        (doseVolumeMl < range.min || doseVolumeMl > range.max)) {
      list.add(
        'Volumen por dosis fuera del rango de ${_num(range.min)}–'
        '${_num(range.max)} ml.',
      );
    }
    return list;
  }
}

/// Formatea un número sin decimales sobrantes (85 → «85», 70.5 → «70.5»).
String _num(double value) {
  final fixed = value.toStringAsFixed(1);
  return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
}

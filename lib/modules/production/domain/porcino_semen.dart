/// Dosis seminales porcinas: del eyaculado a las dosis de inseminación.
///
/// Cálculo de sesión, sin base de datos. Réplica del prototipo «Dosis seminales
/// porcinas» de la hoja de clase. La dilución y el área de conteo quedan por
/// confirmar con el material del curso: la app no las da por buenas.
library;

FormatException _invalid(String message) => FormatException(message);

/// Cámara de conteo y su factor: células contadas × factor = células/ml antes
/// de la dilución. En una cámara de Neubauer, 5 cuadros pequeños ocupan 0.02 µl
/// (1 ÷ 0.02 µl = 50 000 por ml) y un cuadro grande de 1 mm² ocupa 0.1 µl
/// (10 000 por ml).
enum SemenChamber {
  smallSquares('5 cuadros pequeños (esquinas + centro)', 50000),
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

/// Vía de inseminación con su dosis de referencia en ×10⁹ espermatozoides.
enum SemenInsemination {
  cervical('Cervical', 3),
  postCervical('Poscervical', 2);

  const SemenInsemination(this.label, this.spermPerDoseBillion);
  final String label;
  final double spermPerDoseBillion;
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
    'Prototipo «Dosis seminales porcinas» de la hoja de clase. Dilución y área de conteo por confirmar con el material del curso; sin validación externa.';

const semenProtocol = [
  'Preparar el diluyente y atemperarlo.',
  'Mezclar semen y diluyente a temperatura ambiente (30 min a 1 h).',
  'Repartir en botes o bolsas del volumen por dosis.',
  'Media hora a temperatura ambiente y luego a 17 °C.',
  'Rotar las dosis de forma periódica (el esperma se asienta).',
  'Antes de inseminar, mover lento y atemperar.',
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
  }

  final double volumeMl, concentrationMillionsPerMl;
  final double motilityPercent, morphologyPercent;
  final double spermPerDoseBillion, doseVolumeMl, lossPercent;
  final int shelfLifeDays;
  final DateTime collectedOn;

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
}

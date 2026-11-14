import 'dart:math';

import 'package:flutter/foundation.dart';

import '../domain/lab_repository.dart';
import '../domain/lab_result.dart';

String newLabOperationId() {
  final r = Random.secure();
  return List.generate(
    24,
    (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

/// Lo que la pantalla necesita saber de un resultado: su valor y lo que dice
/// CADA fuente, sin resumir.
class LabResultView {
  const LabResultView({
    required this.stored,
    required this.readings,
    required this.agreed,
  });

  final LabStoredResult stored;

  /// Una lectura por fuente que aplica, cada una con el rango que la produjo.
  final List<LabReading> readings;

  /// La lectura unica, solo si todas las fuentes coinciden. Nulo cuando no,
  /// que es la señal de que la pantalla debe mostrarlas todas y dejar que el
  /// profesional elija.
  final LabFlag? agreed;

  bool get disputed => agreed == null && readings.any((r) => r.judged);
  bool get unjudged => !readings.any((r) => r.judged);
}

class LabViewModel extends ChangeNotifier {
  LabViewModel(this.repository, this.clinicId, this.patientId);

  final LabRepository repository;
  final String clinicId, patientId;

  LabWorkspace? workspace;
  bool busy = false;
  String? error;

  /// Los analitos que la biblioteca conoce para la especie del paciente.
  /// Vacio no es un fallo: significa que para esa especie no hay referencias
  /// importadas, y la captura sigue aceptando el nombre a mano.
  List<LabAnalyte> catalog = const [];

  Future<void> load() async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      workspace = await repository.workspace(clinicId, patientId);
    } catch (e) {
      error = '$e';
    }
    // El catalogo es una ayuda de captura: si falla, no se cae la pantalla
    // ni se pierde el expediente que ya se leyo.
    try {
      catalog = await repository.analyteCatalog(clinicId, patientId);
    } catch (_) {
      catalog = const [];
    }
    busy = false;
    notifyListeners();
  }

  /// Arma la lectura de un resultado contra sus referencias. El juicio vive
  /// en el dominio, no aqui ni en el servidor: una sola regla, un solo sitio.
  LabResultView view(LabStoredPanel panel, LabStoredResult stored) {
    final rangos = [
      for (final r in stored.ranges) r.toRange(stored.analyteKey, panel.species),
    ];
    // El valor llega como texto exacto del servidor; parseValue rechaza la
    // coma, asi que aqui se usa double.parse directamente sobre ese texto.
    final resultado = LabResult(
      analyteKey: stored.analyteKey,
      value: double.parse(stored.value),
      unit: stored.unit,
    );
    return LabResultView(
      stored: stored,
      readings: resultado.readings(panel.species, rangos),
      agreed: resultado.agreedFlag(panel.species, rangos),
    );
  }

  /// Valida y guarda una toma. Devuelve el mensaje de error, o nulo si se
  /// guardo.
  Future<String?> record({
    required DateTime collectedAt,
    required String origin,
    required String labName,
    required String notes,
    required List<({String analyte, String value, String unit})> rows,
  }) async {
    final limpias = [
      for (final r in rows)
        if (r.analyte.trim().isNotEmpty ||
            r.value.trim().isNotEmpty ||
            r.unit.trim().isNotEmpty)
          r,
    ];
    if (limpias.isEmpty) return 'Agrega al menos un resultado.';
    if (collectedAt.isAfter(DateTime.now())) {
      return 'La toma no puede ser en el futuro.';
    }
    final vistos = <String>{};
    final draft = <LabDraftResult>[];
    for (final r in limpias) {
      if (r.analyte.trim().isEmpty) return 'Falta el nombre de un analito.';
      if (r.unit.trim().isEmpty) {
        return 'Falta la unidad de ${r.analyte.trim()}.';
      }
      if (!vistos.add(r.analyte.trim().toLowerCase())) {
        return 'El analito ${r.analyte.trim()} esta repetido en la misma toma.';
      }
      try {
        // La misma regla que el servidor: punto decimal, nunca coma.
        LabResult.parseValue(r.value);
      } on FormatException catch (e) {
        return '${r.analyte.trim()}: ${e.message}';
      }
      draft.add(
        LabDraftResult(
          analyteKey: r.analyte.trim(),
          value: r.value.trim(),
          unit: r.unit.trim(),
        ),
      );
    }
    busy = true;
    notifyListeners();
    try {
      await repository.recordPanel(
        clinicId,
        patientId,
        collectedAt: collectedAt,
        origin: origin,
        labName: origin == 'laboratorio_externo' ? labName.trim() : '',
        notes: notes.trim(),
        results: draft,
        operationId: newLabOperationId(),
      );
    } catch (e) {
      busy = false;
      notifyListeners();
      return '$e';
    }
    await load();
    return null;
  }

  /// Corrige un resultado. Devuelve el mensaje de error, o nulo si se
  /// guardo. No edita nada: el original se conserva y la version nueva lo
  /// apunta, con su motivo.
  Future<String?> correct(
    String resultId, {
    required String value,
    required String unit,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) return 'Di por qué se corrige.';
    if (unit.trim().isEmpty) return 'Falta la unidad.';
    try {
      // La misma regla que el servidor y que la captura.
      LabResult.parseValue(value);
    } on FormatException catch (e) {
      return e.message;
    }
    busy = true;
    notifyListeners();
    try {
      await repository.correctResult(
        clinicId,
        resultId,
        value: value.trim(),
        unit: unit.trim(),
        reason: reason.trim(),
        operationId: newLabOperationId(),
      );
    } catch (e) {
      busy = false;
      notifyListeners();
      return '$e';
    }
    await load();
    return null;
  }
}

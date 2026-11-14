import 'lab_result.dart';

/// Un rango de referencia tal como llega del servidor, con su procedencia.
class LabRangeRef {
  const LabRangeRef({
    required this.low,
    required this.high,
    required this.unit,
    required this.source,
    required this.verified,
  });

  factory LabRangeRef.read(Map<String, dynamic> row) => LabRangeRef(
    low: double.parse('${row['low']}'),
    high: double.parse('${row['high']}'),
    unit: '${row['unit']}',
    source: '${row['source']}',
    verified: row['verified'] == true,
  );

  final double low, high;
  final String unit, source;

  /// Falso mientras un MVZ no lo haya revisado. La pantalla lo dice.
  final bool verified;

  LabReferenceRange toRange(String analyteKey, String species) =>
      LabReferenceRange(
        analyteKey: analyteKey,
        species: species,
        unit: unit,
        low: low,
        high: high,
        source: source,
      );
}

/// Un resultado guardado, con todas las referencias que le aplican.
class LabStoredResult {
  const LabStoredResult({
    required this.id,
    required this.analyteKey,
    required this.value,
    required this.unit,
    required this.ranges,
    this.replacesId,
    this.correctionReason,
  });

  factory LabStoredResult.read(Map<String, dynamic> row) => LabStoredResult(
    id: '${row['id']}',
    analyteKey: '${row['analyte_key']}',
    // Llega como texto a proposito: numeric exacto de Postgres, sin pasar
    // por un flotante en el camino.
    value: '${row['value']}',
    unit: '${row['unit']}',
    replacesId: row['replaces_id'] as String?,
    correctionReason: row['correction_reason'] as String?,
    ranges: [
      for (final r in (row['ranges'] as List? ?? const []))
        LabRangeRef.read(Map<String, dynamic>.from(r as Map)),
    ],
  );

  final String id, analyteKey, value, unit;
  final List<LabRangeRef> ranges;
  final String? replacesId, correctionReason;

  bool get isCorrection => replacesId != null;
}

/// Una toma de muestra con sus resultados.
class LabStoredPanel {
  const LabStoredPanel({
    required this.id,
    required this.patientName,
    required this.species,
    required this.collectedAt,
    required this.origin,
    required this.labName,
    required this.notes,
    required this.results,
  });

  factory LabStoredPanel.read(Map<String, dynamic> row) => LabStoredPanel(
    id: '${row['id']}',
    patientName: '${row['patient_name'] ?? ''}',
    species: '${row['species']}',
    collectedAt: DateTime.parse('${row['collected_at']}').toLocal(),
    origin: '${row['origin']}',
    labName: '${row['lab_name'] ?? ''}',
    notes: '${row['notes'] ?? ''}',
    results: [
      for (final r in (row['results'] as List? ?? const []))
        LabStoredResult.read(Map<String, dynamic>.from(r as Map)),
    ],
  );

  final String id, patientName, species, origin, labName, notes;
  final DateTime collectedAt;
  final List<LabStoredResult> results;

  /// Los resultados vigentes: los que nadie ha corregido.
  ///
  /// Una correccion no borra ni edita el original, agrega una version nueva
  /// que lo apunta. Lo que se muestra arriba es la version vigente; el
  /// original sigue en [results] y la pantalla puede enseñarlo.
  List<LabStoredResult> get current {
    final reemplazados = {
      for (final r in results)
        if (r.replacesId != null) r.replacesId!,
    };
    return [
      for (final r in results)
        if (!reemplazados.contains(r.id)) r,
    ];
  }

  String get originLabel => switch (origin) {
    'laboratorio_externo' => 'Laboratorio externo',
    'equipo_propio' => 'Equipo propio',
    _ => origin,
  };
}

class LabWorkspace {
  const LabWorkspace({required this.canRecord, required this.panels});

  factory LabWorkspace.read(Map<String, dynamic> row) => LabWorkspace(
    canRecord: row['can_record'] == true,
    panels: [
      for (final p in (row['panels'] as List? ?? const []))
        LabStoredPanel.read(Map<String, dynamic>.from(p as Map)),
    ],
  );

  /// Si el servidor dice que esta cuenta no puede capturar, la pantalla no
  /// ofrece el formulario en vez de ofrecerlo y fallar al guardar.
  final bool canRecord;
  final List<LabStoredPanel> panels;
}

/// Un resultado por capturar, antes de enviarlo.
class LabDraftResult {
  const LabDraftResult({
    required this.analyteKey,
    required this.value,
    required this.unit,
  });
  final String analyteKey, value, unit;

  Map<String, dynamic> toJson() => {
    'analyte_key': analyteKey,
    'value': value,
    'unit': unit,
  };
}

/// Un analito que la biblioteca de referencias conoce para la especie del
/// paciente, con la unidad en que publica el rango.
///
/// Existe para que la captura ofrezca EL NOMBRE que va a resolver un rango.
/// Teclear el analito libre funciona, pero una letra de mas deja el
/// resultado sin referencia y eso no se ve al guardar.
class LabAnalyte {
  const LabAnalyte({
    required this.analyteKey,
    required this.unit,
    required this.sources,
  });

  factory LabAnalyte.read(Map<String, dynamic> row) => LabAnalyte(
    analyteKey: '${row['analyte_key']}',
    unit: '${row['unit']}',
    sources: (row['sources'] as num?)?.toInt() ?? 0,
  );

  final String analyteKey, unit;

  /// Cuantas fuentes publican un rango para este analito y unidad. Dos o mas
  /// es el caso en que las fuentes pueden no coincidir.
  final int sources;

  String get label => sources > 1
      ? '$analyteKey · $unit · $sources fuentes'
      : '$analyteKey · $unit';
}

abstract interface class LabRepository {
  Future<LabWorkspace> workspace(String clinicId, String patientId);

  /// Los analitos que la biblioteca conoce para la especie de ESTE paciente.
  /// La especie la lee el servidor del expediente, no la manda el cliente.
  Future<List<LabAnalyte>> analyteCatalog(String clinicId, String patientId);

  /// Devuelve el id de la toma. Es idempotente por [operationId]: repetir la
  /// llamada con el mismo contenido devuelve la misma toma en vez de crear
  /// otra.
  Future<String> recordPanel(
    String clinicId,
    String patientId, {
    required DateTime collectedAt,
    required String origin,
    required String labName,
    required String notes,
    required List<LabDraftResult> results,
    required String operationId,
  });

  /// Corrige un resultado. No lo edita ni lo borra: guarda una version nueva
  /// que apunta a la anterior y exige decir por que. El servidor solo deja
  /// corregir lo propio, y una sola vez por resultado.
  Future<String> correctResult(
    String clinicId,
    String resultId, {
    required String value,
    required String unit,
    required String reason,
    required String operationId,
  });
}

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/dose_record.dart';
import 'local_dose_record_store.dart';

/// Cálculos guardados en la ficha del paciente, en la base de la clínica.
///
/// La tabla no se toca directo: todo pasa por dos RPC que validan la carga en
/// el servidor y responden al recibo idempotente por operación.
class SupabaseDoseRecordStore implements DoseRecordStore {
  SupabaseDoseRecordStore(this.client, {required this.clinicId});

  final SupabaseClient client;
  final String clinicId;

  @override
  Future<DoseRecord> save(DoseRecord record) async {
    final patientId = record.patientId;
    if (patientId == null || record.clinicId != clinicId) {
      throw StateError(
        'El cálculo no está ligado a un paciente de esta clínica.',
      );
    }
    await client.rpc(
      'record_vet_dose_calculation',
      params: {
        'p_clinic_id': clinicId,
        'p_patient_id': patientId,
        'p_calculation': doseCalculationPayload(record),
        'p_operation_id': record.id,
      },
    );
    return record.marcarSincronizado(DateTime.now().toUtc());
  }

  @override
  Future<List<DoseRecord>> forPatient(
    String patientId, {
    int limit = 50,
  }) async {
    final rows = await client.rpc(
      'vet_dose_calculations_for_patient',
      params: {
        'p_clinic_id': clinicId,
        'p_patient_id': patientId,
        'p_limit': limit,
      },
    );
    return [for (final row in asDoseRows(rows)) doseRecordFromRow(row)];
  }

  @override
  Future<List<DoseRecord>> recent({int limit = 50}) async => const [];
}

/// La carga que valida `record_vet_dose_calculation`: texto tal como se mostró,
/// con la coma decimal del original. El servidor la normaliza.
Map<String, dynamic> doseCalculationPayload(DoseRecord record) => {
  'principio': record.principio,
  'pauta_id': record.pautaId,
  'indicacion': record.indicacion,
  'especie': record.especie,
  'via': record.via,
  'intervalo': record.intervalo,
  'dosis_literal': record.dosisLiteral,
  'cita': record.cita,
  'peso_kg': record.pesoKg.replaceAll(',', '.'),
  if (record.concentracionMgMl != null)
    'concentracion_mg_ml': record.concentracionMgMl!.replaceAll(',', '.'),
  'resultado_mg': record.resultadoMg,
  if (record.resultadoMl != null) 'resultado_ml': record.resultadoMl,
};

/// PostgREST devuelve `setof` como lista de objetos; si algún día devuelve uno
/// solo, se acepta igual y no se rompe la pantalla.
List<Map<String, dynamic>> asDoseRows(Object? raw) => switch (raw) {
  final List<dynamic> rows => [
    for (final row in rows)
      if (row is Map) Map<String, dynamic>.from(row),
  ],
  final Map row => [Map<String, dynamic>.from(row)],
  _ => const [],
};

/// Una fila de `vet_dose_calculations` vista como el registro de la app.
///
/// El peso y la concentración viajan como número en la base y como texto con
/// coma en la pantalla: aquí se vuelven texto para que el registro diga lo
/// mismo que dijo el cálculo.
DoseRecord doseRecordFromRow(Map<String, dynamic> row) {
  final createdAt = DateTime.tryParse('${row['created_at']}') ?? DateTime.now();
  return DoseRecord(
    id: '${row['id']}',
    createdAt: createdAt,
    principio: '${row['principio'] ?? ''}',
    pautaId: '${row['pauta_id'] ?? ''}',
    indicacion: '${row['indicacion'] ?? ''}',
    especie: '${row['especie'] ?? ''}',
    via: '${row['via'] ?? ''}',
    intervalo: '${row['intervalo'] ?? ''}',
    dosisLiteral: '${row['dosis_literal'] ?? ''}',
    cita: '${row['cita'] ?? ''}',
    pesoKg: _numeroTexto(row['peso_kg']),
    resultadoMg: '${row['resultado_mg'] ?? ''}',
    concentracionMgMl: row['concentracion_mg_ml'] == null
        ? null
        : _numeroTexto(row['concentracion_mg_ml']),
    resultadoMl: row['resultado_ml'] == null ? null : '${row['resultado_ml']}',
    clinicId: row['clinic_id'] == null ? null : '${row['clinic_id']}',
    patientId: row['patient_id'] == null ? null : '${row['patient_id']}',
    actorId: row['created_by'] == null ? null : '${row['created_by']}',
    syncedAt: createdAt,
  );
}

String _numeroTexto(Object? value) {
  if (value == null) return '';
  if (value is String) return value.replaceAll('.', ',');
  if (value is num) {
    final texto = value is int ? '$value' : value.toString();
    return texto.replaceAll('.', ',');
  }
  return '$value';
}

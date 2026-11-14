import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/lab_repository.dart';

/// Llama a las funciones de 15M_lab_results.sql. Nada de acceso directo a
/// tablas: esas estan en `private` y revocadas, justamente para que toda
/// lectura y escritura pase por una funcion que comprueba permisos.
class SupabaseLabRepository implements LabRepository {
  SupabaseLabRepository(this.client);
  final SupabaseClient client;

  @override
  Future<LabWorkspace> workspace(String clinicId, String patientId) async =>
      LabWorkspace.read(
        Map<String, dynamic>.from(
          await client.rpc(
                'lab_workspace',
                params: {'p_clinic': clinicId, 'p_patient': patientId},
              )
              as Map,
        ),
      );

  @override
  Future<List<LabAnalyte>> analyteCatalog(
    String clinicId,
    String patientId,
  ) async {
    final data = Map<String, dynamic>.from(
      await client.rpc(
            'lab_analyte_catalog',
            params: {'p_clinic': clinicId, 'p_patient': patientId},
          )
          as Map,
    );
    return [
      for (final r in (data['items'] as List? ?? const []))
        LabAnalyte.read(Map<String, dynamic>.from(r as Map)),
    ];
  }

  @override
  Future<String> recordPanel(
    String clinicId,
    String patientId, {
    required DateTime collectedAt,
    required String origin,
    required String labName,
    required String notes,
    required List<LabDraftResult> results,
    required String operationId,
  }) async =>
      '${await client.rpc(
        'lab_panel_record',
        params: {
          'p_clinic': clinicId,
          'p_patient': patientId,
          'p_data': {
            // El servidor exige la confirmacion explicita: no guarda un
            // expediente por un toque accidental.
            'confirmed': true,
            'collected_at': collectedAt.toUtc().toIso8601String(),
            'origin': origin,
            'lab_name': labName,
            'notes': notes,
            'results': [for (final r in results) r.toJson()],
          },
          'p_operation': operationId,
        },
      )}';

  @override
  Future<String> correctResult(
    String clinicId,
    String resultId, {
    required String value,
    required String unit,
    required String reason,
    required String operationId,
  }) async =>
      '${await client.rpc(
        'lab_result_correct',
        params: {
          'p_clinic': clinicId,
          'p_result': resultId,
          'p_data': {
            'confirmed': true,
            'value': value,
            'unit': unit,
            'correction_reason': reason,
          },
          'p_operation': operationId,
        },
      )}';
}

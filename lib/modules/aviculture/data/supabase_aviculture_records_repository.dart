import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/aviculture_records.dart';
import '../domain/aviculture_records_repository.dart';

/// Cliente del módulo M15. Solo invoca RPC; las tablas avícolas no conceden
/// privilegios directos a `authenticated`.
class SupabaseAvicultureRecordsRepository
    implements AvicultureRecordsRepository {
  const SupabaseAvicultureRecordsRepository(this.client);

  final SupabaseClient client;

  @override
  Future<AviWorkspace> workspace(String clinicId) async {
    final data = await client.rpc(
      'avi_workspace',
      params: {'p_clinic': clinicId},
    );
    if (data is! Map) {
      throw const FormatException('Respuesta avícola inválida.');
    }
    return AviWorkspace.read(Map<String, dynamic>.from(data));
  }

  Future<String> _save(
    String rpc,
    String clinicId,
    Map<String, dynamic> data, {
    String? id,
    int? version,
    required String operation,
  }) async {
    final result = await client.rpc(
      rpc,
      params: {
        'p_clinic': clinicId,
        'p_id': id,
        'p_version': version,
        'p_data': data,
        'p_operation': operation,
      },
    );
    if (result is! String) {
      throw const FormatException('Respuesta avícola inválida.');
    }
    return result;
  }

  @override
  Future<String> saveHouse(
    String clinicId,
    Map<String, dynamic> data, {
    String? id,
    int? version,
    required String operation,
  }) => _save(
    'avi_house_save',
    clinicId,
    data,
    id: id,
    version: version,
    operation: operation,
  );

  @override
  Future<String> saveFlock(
    String clinicId,
    Map<String, dynamic> data, {
    String? id,
    int? version,
    required String operation,
  }) => _save(
    'avi_flock_save',
    clinicId,
    data,
    id: id,
    version: version,
    operation: operation,
  );

  @override
  Future<String> saveRecord(
    String clinicId,
    Map<String, dynamic> data, {
    String? id,
    int? version,
    required String operation,
  }) => _save(
    'avi_production_save',
    clinicId,
    data,
    id: id,
    version: version,
    operation: operation,
  );

  @override
  Future<String> saveEvent(
    String clinicId,
    Map<String, dynamic> data, {
    String? id,
    int? version,
    required String operation,
  }) => _save(
    'avi_event_save',
    clinicId,
    data,
    id: id,
    version: version,
    operation: operation,
  );
}

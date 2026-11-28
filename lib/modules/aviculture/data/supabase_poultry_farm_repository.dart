import '../domain/poultry_schedule.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/poultry_farm.dart';
import 'supabase_aviculture_records_repository.dart';

class SupabasePoultryFarmRepository
    implements PoultryFarmRepository, PoultryScheduleRepository {
  const SupabasePoultryFarmRepository(this.client);
  final SupabaseClient client;
  @override
  Future<PoultryFarmWorkspace> load(String clinicId) async {
    final value = await client.rpc(
      'avi_farms_workspace',
      params: {'p_clinic': clinicId},
    );
    if (value is! Map) {
      throw const FormatException('Respuesta avícola incompleta.');
    }
    return PoultryFarmWorkspace.read(
      Map<String, dynamic>.from(value),
      clinicId,
    );
  }

  Future<String> _save(String rpc, Map<String, dynamic> params) async {
    final result = await client.rpc(rpc, params: params);
    if (result is! String) {
      throw const FormatException('El servidor no confirmó el guardado.');
    }
    return result;
  }

  @override
  Future<String> saveFarm(
    String clinicId,
    Map<String, dynamic> data, {
    String? id,
    int? version,
    required String operation,
  }) => _save('avi_farm_save', {
    'p_clinic': clinicId,
    'p_id': id,
    'p_version': version,
    'p_data': data,
    'p_operation': operation,
  });
  @override
  Future<String> saveHouse(
    String clinicId,
    String farmId,
    Map<String, dynamic> data, {
    String? id,
    int? version,
    required String operation,
  }) => _save('avi_farm_house_save', {
    'p_clinic': clinicId,
    'p_farm': farmId,
    'p_id': id,
    'p_version': version,
    'p_data': data,
    'p_operation': operation,
  });
  @override
  Future<String> saveFlock(
    String clinicId,
    Map<String, dynamic> data, {
    required String operation,
  }) => SupabaseAvicultureRecordsRepository(
    client,
  ).saveFlock(clinicId, data, operation: operation);
  @override
  Future<String> saveHealth(
    String clinicId,
    Map<String, dynamic> data, {
    required String operation,
  }) => _save('avi_health_event_save', {
    'p_clinic': clinicId,
    'p_data': data,
    'p_operation': operation,
  });
  @override
  Future<Map<String, dynamic>> calendar(String clinic) async {
    final data = await client.rpc(
      'avi_calendar_workspace',
      params: {'p_clinic': clinic},
    );
    if (data is! Map) throw const FormatException('Calendario incompleto.');
    return Map<String, dynamic>.from(data);
  }

  @override
  Future<String> saveScheduled(
    String clinic,
    Map<String, dynamic> data, {
    String? id,
    int? version,
    required String operation,
  }) => _save('avi_calendar_save', {
    'p_clinic': clinic,
    'p_id': id,
    'p_version': version,
    'p_data': data,
    'p_operation': operation,
  });
}

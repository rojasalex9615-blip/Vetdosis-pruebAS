import 'aviculture_records.dart';

/// Contrato del módulo de postura. Cada escritura exige `operation`, el
/// identificador idempotente de 48 caracteres hexadecimales que el servidor
/// usa para no duplicar registros al reintentar.
abstract interface class AvicultureRecordsRepository {
  Future<AviWorkspace> workspace(String clinicId);

  Future<String> saveHouse(
    String clinicId,
    Map<String, dynamic> data, {
    String? id,
    int? version,
    required String operation,
  });

  Future<String> saveFlock(
    String clinicId,
    Map<String, dynamic> data, {
    String? id,
    int? version,
    required String operation,
  });

  Future<String> saveRecord(
    String clinicId,
    Map<String, dynamic> data, {
    String? id,
    int? version,
    required String operation,
  });

  Future<String> saveEvent(
    String clinicId,
    Map<String, dynamic> data, {
    String? id,
    int? version,
    required String operation,
  });
}

import 'package:sembast/sembast.dart';

import '../domain/dose_record.dart';

/// Dónde se guardan los cálculos hechos a un paciente.
///
/// La interfaz existe para que la pantalla no sepa si el destino es el
/// dispositivo o la base de la clínica.
abstract interface class DoseRecordStore {
  /// Devuelve el registro tal como quedó guardado: con marca de sincronización
  /// si llegó a la nube, sin ella si solo vive en el dispositivo.
  Future<DoseRecord> save(DoseRecord record);
  Future<List<DoseRecord>> forPatient(String patientId, {int limit = 50});
  Future<List<DoseRecord>> recent({int limit = 50});
}

/// Almacén local, en la misma base sin conexión que el resto de la app.
///
/// Los cálculos son append-only: se guardan con su cita y no se reescriben.
/// Quedan en el dispositivo y siguen el camino de sincronización pendiente.
class LocalDoseRecordStore implements DoseRecordStore {
  LocalDoseRecordStore(this.database);

  final Database database;
  final _records = stringMapStoreFactory.store('dose-records-v1');

  @override
  Future<DoseRecord> save(DoseRecord record) async {
    await _records.record(record.id).put(database, record.toJson());
    return record;
  }

  @override
  Future<List<DoseRecord>> forPatient(String patientId, {int limit = 50}) =>
      _read(Filter.equals('patient_id', patientId), limit);

  @override
  Future<List<DoseRecord>> recent({int limit = 50}) => _read(null, limit);

  /// Los que nunca llegaron a la nube y ya tienen paciente: solo esos se pueden
  /// reenviar. Un cálculo sin paciente no tiene ficha donde vivir.
  Future<List<DoseRecord>> pendientes({int limit = 50}) async {
    final rows = await _records.find(
      database,
      finder: Finder(sortOrders: [SortOrder('created_at')], limit: 200),
    );
    final pending = <DoseRecord>[];
    for (final row in rows) {
      final record = DoseRecord.fromJson(row.value);
      if (record.syncedAt == null && record.patientId != null) {
        pending.add(record);
        if (pending.length == limit) break;
      }
    }
    return pending;
  }

  Future<List<DoseRecord>> _read(Filter? filtro, int limit) async {
    final rows = await _records.find(
      database,
      finder: Finder(
        filter: filtro,
        sortOrders: [SortOrder('created_at', false)],
        limit: limit,
      ),
    );
    return [for (final row in rows) DoseRecord.fromJson(row.value)];
  }
}

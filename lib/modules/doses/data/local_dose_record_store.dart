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

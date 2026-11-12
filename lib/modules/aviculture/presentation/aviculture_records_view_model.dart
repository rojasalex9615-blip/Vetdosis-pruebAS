import 'package:flutter/foundation.dart';
import '../domain/aviculture_records.dart';
import '../domain/aviculture_records_repository.dart';
import '../../patients/presentation/patient_view_model.dart'
    show newOperationId;

/// Mensajes de error del servidor avícola en lenguaje de la clínica.
String avicultureError(Object error) {
  final text = error.toString();
  for (final entry in _aviMessages.entries) {
    if (text.contains(entry.key)) return entry.value;
  }
  if (text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Failed host lookup')) {
    return 'Sin conexión con el servidor. Revisa tu red e inténtalo de nuevo.';
  }
  return 'No se pudo completar la operación. Revisa los datos o tu acceso.';
}

const _aviMessages = <String, String>{
  'access_denied': 'No tienes acceso a este espacio de trabajo.',
  'write_role_required':
      'Tu rol permite consultar, pero no registrar datos avícolas.',
  'lead_role_required':
      'Solo administración o MVZ pueden crear, editar o cerrar parvadas.',
  'version_conflict':
      'Otra persona cambió este registro. Actualiza la pantalla y vuelve a intentarlo.',
  'record_exists': 'Ya existe un registro de esa parvada para esa fecha.',
  'mortality_exceeds_birds':
      'La mortalidad indicada supera las aves vivas de la parvada.',
  'flock_closed': 'La parvada está cerrada y no admite más registros.',
  'flock_has_records':
      'No puedes cambiar las aves iniciales: la parvada ya tiene registros.',
  'flock_code_exists': 'Ese código de parvada ya está en uso.',
  'house_not_available': 'La caseta no existe o está archivada.',
  'invalid_date': 'Revisa la fecha: no puede ser futura ni anterior al inicio.',
  'invalid_data': 'Revisa los campos: hay un valor fuera de rango o vacío.',
  'invalid_system': 'Elige piso o jaula/batería.',
  'invalid_kind': 'Elige un tipo de evento válido.',
  'not_found': 'El registro ya no existe. Actualiza la pantalla.',
  'explicit_permission_required':
      'Falta un permiso vigente para esta acción. Consulta con administración.',
};

class AvicultureRecordsViewModel extends ChangeNotifier {
  AvicultureRecordsViewModel({
    required this.clinicId,
    required this.repository,
  });

  final String clinicId;
  final AvicultureRecordsRepository repository;

  AviWorkspace? workspace;
  bool loading = false;
  bool busy = false;
  String error = '';
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (loading || busy) return;
    loading = true;
    error = '';
    _notify();
    try {
      workspace = await repository.workspace(clinicId);
    } catch (e) {
      error = avicultureError(e);
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<bool> _write(
    Future<String> Function(String operation) call,
  ) async {
    if (busy) return false;
    busy = true;
    error = '';
    _notify();
    try {
      await call(newOperationId());
      workspace = await repository.workspace(clinicId);
      return true;
    } catch (e) {
      error = avicultureError(e);
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<bool> saveHouse({
    String? id,
    int? version,
    required String name,
    required String system,
    required int capacity,
    String notes = '',
    bool archived = false,
  }) => _write(
    (operation) => repository.saveHouse(
      clinicId,
      {
        'name': name,
        'system': system,
        'capacity': capacity,
        'notes': notes,
        'archived': archived,
      },
      id: id,
      version: version,
      operation: operation,
    ),
  );

  Future<bool> createFlock({
    required String code,
    String? houseId,
    String geneticLine = '',
    required DateTime startDate,
    required int initialBirds,
    String notes = '',
  }) => _write(
    (operation) => repository.saveFlock(
      clinicId,
      {
        'code': code,
        'house_id': houseId,
        'genetic_line': geneticLine,
        'start_date': aviDate(startDate),
        'initial_birds': initialBirds,
        'notes': notes,
        'status': 'activa',
      },
      operation: operation,
    ),
  );

  Future<bool> closeFlock(AviFlock flock) => _write(
    (operation) => repository.saveFlock(
      clinicId,
      {
        'code': flock.code,
        'house_id': flock.houseId,
        'genetic_line': flock.geneticLine,
        'start_date': aviDate(flock.startDate),
        'initial_birds': flock.initialBirds,
        'status': 'cerrada',
      },
      id: flock.id,
      version: flock.version,
      operation: operation,
    ),
  );

  Future<bool> saveRecord({
    String? id,
    int? version,
    required String flockId,
    required DateTime date,
    int eggs = 0,
    int discarded = 0,
    int mortality = 0,
    double feedKg = 0,
    double? avgWeightG,
    double? waterL,
    String notes = '',
  }) => _write(
    (operation) => repository.saveRecord(
      clinicId,
      {
        'flock_id': flockId,
        'date': aviDate(date),
        'eggs': eggs,
        'eggs_discarded': discarded,
        'mortality': mortality,
        'feed_kg': feedKg.toStringAsFixed(3),
        'avg_weight_g': avgWeightG?.toStringAsFixed(1),
        'water_l': waterL?.toStringAsFixed(1),
        'notes': notes,
      },
      id: id,
      version: version,
      operation: operation,
    ),
  );

  Future<bool> saveEvent({
    required String flockId,
    required DateTime date,
    required String kind,
    required String title,
    String details = '',
    DateTime? withdrawalUntil,
  }) => _write(
    (operation) => repository.saveEvent(
      clinicId,
      {
        'flock_id': flockId,
        'date': aviDate(date),
        'kind': kind,
        'title': title,
        'details': details,
        'withdrawal_until': withdrawalUntil == null
            ? null
            : aviDate(withdrawalUntil),
      },
      operation: operation,
    ),
  );
}

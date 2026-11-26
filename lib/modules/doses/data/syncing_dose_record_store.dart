import 'package:supabase_flutter/supabase_flutter.dart';

import '../../offline/data/local_database.dart';
import '../domain/dose_record.dart';
import 'local_dose_record_store.dart';
import 'supabase_dose_record_store.dart';

/// Guarda en el dispositivo primero y, si hay sesión y paciente, también en la
/// ficha de la clínica.
///
/// El orden no es negociable: lo local primero, porque perder el cálculo es
/// peor que no haberlo enviado. Si el envío falla, el registro queda pendiente
/// y se reintenta la próxima vez que se abra la pantalla.
class SyncingDoseRecordStore implements DoseRecordStore {
  SyncingDoseRecordStore({required this.local, this.remote});

  final LocalDoseRecordStore local;
  final DoseRecordStore? remote;

  @override
  Future<DoseRecord> save(DoseRecord record) async {
    await local.save(record);
    final destino = remote;
    if (destino == null || record.patientId == null) return record;
    try {
      final enviado = await destino.save(record);
      await local.save(enviado);
      return enviado;
    } catch (_) {
      return record;
    }
  }

  /// Lo compartido manda; si la nube no contesta, se lee lo del dispositivo.
  @override
  Future<List<DoseRecord>> forPatient(
    String patientId, {
    int limit = 50,
  }) async {
    final destino = remote;
    if (destino != null) {
      try {
        final remotos = await destino.forPatient(patientId, limit: limit);
        if (remotos.isNotEmpty) return remotos;
      } catch (_) {}
    }
    return local.forPatient(patientId, limit: limit);
  }

  @override
  Future<List<DoseRecord>> recent({int limit = 50}) =>
      local.recent(limit: limit);

  /// Reenvía lo que quedó pendiente. Devuelve cuántos llegaron.
  Future<int> reintentarPendientes({int limit = 20}) async {
    final destino = remote;
    if (destino == null) return 0;
    var enviados = 0;
    for (final record in await local.pendientes(limit: limit)) {
      try {
        final enviado = await destino.save(record);
        await local.save(enviado);
        enviados++;
      } catch (_) {
        return enviados;
      }
    }
    return enviados;
  }
}

/// Abre el almacén de cálculos con lo que haya disponible en este dispositivo.
///
/// [remote] se inyecta en las pruebas. Sin él se usa Supabase solo si la app
/// está inicializada, hay sesión y se conoce la clínica; si no, el almacén
/// queda local y la pantalla lo dice al guardar.
Future<SyncingDoseRecordStore> abrirDoseRecordStore({
  String? clinicId,
  DoseRecordStore? remote,
}) async {
  final local = LocalDoseRecordStore(await openOfflineDatabase());
  return SyncingDoseRecordStore(
    local: local,
    remote: remote ?? _supabaseOrNull(clinicId),
  );
}

DoseRecordStore? _supabaseOrNull(String? clinicId) {
  if (clinicId == null) return null;
  try {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) return null;
    return SupabaseDoseRecordStore(client, clinicId: clinicId);
  } catch (_) {
    return null;
  }
}

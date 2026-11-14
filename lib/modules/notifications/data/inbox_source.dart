import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/domain/auth_repository.dart';
import '../../auth/domain/staff_labels.dart';
import '../../operations/domain/operations_repository.dart';
import '../domain/inbox.dart';

/// De donde salen las notificaciones de la campana.
abstract interface class InboxSource {
  Future<List<InboxItem>> load(String clinicId, String userId);
}

/// Arma el buzon con las RPC que ya usan Equipo y Turnos.
///
/// Cada fuente falla por separado: si la persona no tiene el modulo de turnos
/// o el servidor rechaza uno, se muestra lo del otro. Solo si fallan todas se
/// propaga el error, para que el menu diga que no pudo consultar en lugar de
/// fingir que no hay nada.
class TeamInboxSource implements InboxSource {
  const TeamInboxSource({this.operations, this.duty, DateTime Function()? now})
    : _now = now;

  final OperationsRepository? operations;
  final TeamDutyRepository? duty;
  final DateTime Function()? _now;

  @override
  Future<List<InboxItem>> load(String clinicId, String userId) async {
    Map<String, dynamic>? ops;
    Map<String, dynamic>? shifts;
    Object? failure;
    if (operations != null) {
      try {
        ops = await operations!.dashboard(clinicId);
      } catch (e) {
        failure = e;
      }
    }
    if (duty != null) {
      try {
        shifts = await duty!.dutyWorkspace(clinicId);
      } catch (e) {
        failure ??= e;
      }
    }
    if (ops == null && shifts == null && failure != null) throw failure;

    final people = [
      for (final p in ops?['people'] as List? ?? const [])
        if (p is Map) Map<String, dynamic>.from(p),
    ];
    final roles = {
      for (final m in ops?['members'] as List? ?? const [])
        if (m is Map && m['user_id'] is String)
          m['user_id'] as String: m['role'] as String?,
    };
    String name(String id) => staffLabel(id, people, role: roles[id]);

    return buildInbox(
      userId: userId,
      now: (_now ?? DateTime.now)(),
      ops: ops,
      duty: shifts,
      name: name,
    );
  }
}

/// Recuerda hasta donde vio la persona su buzon, por cuenta y clinica.
abstract interface class InboxSeenStore {
  Future<DateTime?> read(String clinicId, String userId);
  Future<void> write(String clinicId, String userId, DateTime seen);
}

/// Marca de visto guardada en el telefono.
///
/// Es local a proposito: leer una notificacion no cambia nada en el servidor
/// ni avisa a quien la mando. Si se cambia de telefono, lo de la ultima
/// semana vuelve a aparecer como nuevo, que es el fallo menos dañino.
class PrefsInboxSeenStore implements InboxSeenStore {
  const PrefsInboxSeenStore();

  String _key(String clinicId, String userId) =>
      'inbox-seen-v1:$userId:$clinicId';

  @override
  Future<DateTime?> read(String clinicId, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_key(clinicId, userId));
    return millis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  @override
  Future<void> write(String clinicId, String userId, DateTime seen) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _key(clinicId, userId),
      seen.toUtc().millisecondsSinceEpoch,
    );
  }
}

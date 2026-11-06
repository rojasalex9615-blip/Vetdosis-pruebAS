import 'dart:convert';

import 'package:sembast/sembast.dart';

import '../domain/app_notification.dart';
import '../domain/notification_repository.dart';

/// Notificaciones guardadas en el teléfono.
///
/// Es el almacén que permite que notas y recordatorios funcionen sin conexión
/// y sin depender todavía de Supabase. Cuando existan las tablas remotas, este
/// almacén sigue sirviendo de caché: el contrato es el mismo.
///
/// La clave incluye la cuenta, y además cada fila guarda su `userId` y se
/// comprueba al leer. Es redundante a propósito: si alguna vez dos cuentas
/// comparten el archivo local, una no puede acabar viendo los avisos de la
/// otra por un fallo de clave.
class LocalNotificationStore implements NotificationRepository {
  LocalNotificationStore(this.database);

  final Database database;
  final _store = stringMapStoreFactory.store('notifications-v1');

  String _key(String userId, String id) => jsonEncode([userId, id]);

  @override
  Future<List<AppNotification>> list(String userId, {String? clinicId}) async {
    final rows = await _store.find(
      database,
      finder: Finder(filter: Filter.equals('userId', userId)),
    );
    final items = <AppNotification>[];
    for (final row in rows) {
      final notification = AppNotification.fromRow(row.value, userId);
      if (notification == null) continue;
      // Las personales (sin clínica) se ven siempre; las de una clínica, solo
      // dentro de ella.
      final suya =
          notification.clinicId == null || notification.clinicId == clinicId;
      if (!suya) continue;
      items.add(notification);
    }
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  @override
  Future<void> add(String userId, AppNotification notification) =>
      _store
          .record(_key(userId, notification.id))
          .put(database, notification.toRow(userId));

  @override
  Future<void> markRead(String userId, String id, DateTime at) async {
    final record = _store.record(_key(userId, id));
    final row = await record.get(database);
    if (row == null) return;
    final notification = AppNotification.fromRow(row, userId);
    // Una fila de otra cuenta no se toca ni para marcarla leída.
    if (notification == null) return;
    if (!notification.unread) return;
    await record.put(database, notification.copyWith(readAt: at).toRow(userId));
  }

  @override
  Future<void> markAllRead(String userId, List<String> ids, DateTime at) async {
    for (final id in ids) {
      await markRead(userId, id, at);
    }
  }

  @override
  Future<void> remove(String userId, String id) async {
    final record = _store.record(_key(userId, id));
    final row = await record.get(database);
    if (row == null) return;
    if (AppNotification.fromRow(row, userId) == null) return;
    await record.delete(database);
  }
}

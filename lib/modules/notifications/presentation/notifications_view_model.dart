import 'package:flutter/foundation.dart';

import '../domain/app_notification.dart';
import '../domain/notification_repository.dart';

/// Estado de la bandeja de notificaciones personales.
class NotificationsViewModel extends ChangeNotifier {
  NotificationsViewModel({
    required this.repository,
    required this.userId,
    this.clinicId,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final NotificationRepository repository;
  final String userId;
  final String? clinicId;
  final DateTime Function() now;

  List<AppNotification> _items = const [];
  bool _busy = false;
  String? _error;
  bool _disposed = false;

  /// Identifica la carga en curso. Si llega el resultado de una anterior se
  /// descarta: al cambiar de clínica no debe repoblarse con la lista vieja.
  int _carga = 0;

  List<AppNotification> get items => _items;
  bool get busy => _busy;
  String? get error => _error;
  int get unreadCount => _items.where((item) => item.unread).length;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _emit() {
    if (_disposed) return;
    notifyListeners();
  }

  Future<void> load() async {
    final carga = ++_carga;
    _busy = true;
    _error = null;
    _emit();
    try {
      final items = await repository.list(userId, clinicId: clinicId);
      if (_disposed || carga != _carga) return;
      _items = items;
    } catch (_) {
      if (_disposed || carga != _carga) return;
      // No se muestra el detalle del fallo: puede traer datos de la cuenta.
      _error = 'No se pudieron consultar tus notificaciones.';
      _items = const [];
    } finally {
      if (!_disposed && carga == _carga) {
        _busy = false;
        _emit();
      }
    }
  }

  Future<void> markRead(String id) async {
    await repository.markRead(userId, id, now().toUtc());
    await load();
  }

  /// Marca como leídas solo las que están a la vista, no todo lo guardado.
  Future<void> markVisibleRead() async {
    final ids = _items
        .where((item) => item.unread)
        .map((item) => item.id)
        .toList();
    if (ids.isEmpty) return;
    await repository.markAllRead(userId, ids, now().toUtc());
    await load();
  }

  Future<void> remove(String id) async {
    await repository.remove(userId, id);
    await load();
  }
}

import 'package:flutter/material.dart';

import '../domain/notification_repository.dart';
import 'notification_bell.dart';
import 'notifications_screen.dart';
import 'notifications_view_model.dart';

/// Campana de la cabecera con su propio estado.
///
/// El contenedor de la app no tiene estado donde guardar el modelo, así que lo
/// lleva aquí: se crea al montarse y se rehace cuando cambia la cuenta o la
/// clínica, para que el contador no arrastre el de otro espacio.
class NotificationBellButton extends StatefulWidget {
  const NotificationBellButton({
    super.key,
    required this.repository,
    required this.userId,
    this.clinicId,
    this.refreshKey,
    this.onOpen,
  });

  final NotificationRepository repository;
  final String userId;
  final String? clinicId;

  /// Al cambiar, vuelve a contar. Se usa con el nombre de la pantalla actual:
  /// al volver de la bandeja, el número de la campana queda al día.
  final String? refreshKey;

  final VoidCallback? onOpen;

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  late NotificationsViewModel _model = _crear();

  NotificationsViewModel _crear() => NotificationsViewModel(
    repository: widget.repository,
    userId: widget.userId,
    clinicId: widget.clinicId,
  )..load();

  @override
  void didUpdateWidget(NotificationBellButton old) {
    super.didUpdateWidget(old);
    final cambioDeAmbito =
        old.userId != widget.userId ||
        old.clinicId != widget.clinicId ||
        old.repository != widget.repository;
    if (cambioDeAmbito) {
      _model.dispose();
      _model = _crear();
    } else if (old.refreshKey != widget.refreshKey) {
      _model.load();
    }
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _model,
    builder: (context, _) =>
        NotificationBell(unread: _model.unreadCount, onPressed: widget.onOpen),
  );
}

/// Bandeja de notificaciones con su propio modelo, lista para incrustarse.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    required this.repository,
    required this.userId,
    this.clinicId,
    this.onOpenRoute,
  });

  final NotificationRepository repository;
  final String userId;
  final String? clinicId;
  final ValueChanged<String>? onOpenRoute;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final NotificationsViewModel _model = NotificationsViewModel(
    repository: widget.repository,
    userId: widget.userId,
    clinicId: widget.clinicId,
  );

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationsScreen(model: _model, onOpenRoute: widget.onOpenRoute);
}

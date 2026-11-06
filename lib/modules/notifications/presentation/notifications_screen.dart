import 'package:flutter/material.dart';

import '../domain/app_notification.dart';
import 'notifications_view_model.dart';

/// Bandeja de notificaciones personales.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.model,
    this.onOpenRoute,
  });

  final NotificationsViewModel model;

  /// Qué hacer al tocar una notificación que lleva a una pantalla. Lo decide
  /// quien monta esta pantalla: aquí no se conoce la navegación de la app.
  final ValueChanged<String>? onOpenRoute;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    widget.model.load();
  }

  String _cuando(DateTime utc) {
    final local = utc.toLocal();
    final diferencia = DateTime.now().difference(local);
    if (diferencia.inMinutes < 1) return 'ahora';
    if (diferencia.inMinutes < 60) return 'hace ${diferencia.inMinutes} min';
    if (diferencia.inHours < 24) return 'hace ${diferencia.inHours} h';
    if (diferencia.inDays < 7) return 'hace ${diferencia.inDays} d';
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    return '$dd/$mm/${local.year}';
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.model,
    builder: (context, _) {
      final model = widget.model;
      if (model.busy && model.items.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ),
        );
      }
      if (model.error != null) {
        return _Aviso(
          icon: Icons.error_outline,
          title: model.error!,
          detail: 'Vuelve a intentarlo cuando tengas conexión.',
          action: FilledButton(
            onPressed: model.load,
            child: const Text('Reintentar'),
          ),
        );
      }
      if (model.items.isEmpty) {
        return const _Aviso(
          icon: Icons.notifications_none_rounded,
          title: 'No tienes notificaciones',
          detail:
              'Aquí aparecerán los mensajes de tu clínica, los anuncios, las '
              'respuestas de IA y tus notas y recordatorios.',
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (model.unreadCount > 0)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: model.markVisibleRead,
                icon: const Icon(Icons.done_all),
                label: const Text('Marcar como leídas'),
              ),
            ),
          for (final item in model.items)
            _Fila(
              item: item,
              cuando: _cuando(item.createdAt),
              onTap: () {
                if (item.unread) model.markRead(item.id);
                final route = item.route;
                if (route != null) widget.onOpenRoute?.call(route);
              },
              onRemove: () => model.remove(item.id),
            ),
        ],
      );
    },
  );
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.item,
    required this.cuando,
    required this.onTap,
    required this.onRemove,
  });

  final AppNotification item;
  final String cuando;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final color = item.kind.color;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        onTap: onTap,
        // La barra de color repite el tipo que ya dice el icono y la etiqueta,
        // para no depender solo del color.
        leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: dark ? .18 : .12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(item.kind.icon, color: color, size: 22),
        ),
        title: Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: item.unread ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.body.isNotEmpty)
              Text(item.body, maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(
              '${item.kind.label} · $cuando',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        trailing: IconButton(
          tooltip: 'Quitar de la bandeja',
          onPressed: onRemove,
          icon: const Icon(Icons.close),
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({
    required this.icon,
    required this.title,
    required this.detail,
    this.action,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
    child: Column(
      children: [
        Icon(icon, size: 40, color: Theme.of(context).hintColor),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(detail, textAlign: TextAlign.center),
        if (action != null) ...[const SizedBox(height: 18), action!],
      ],
    ),
  );
}

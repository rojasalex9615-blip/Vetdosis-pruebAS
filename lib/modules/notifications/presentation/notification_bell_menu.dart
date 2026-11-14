import 'dart:async';

import 'package:flutter/material.dart';

import '../../../vet_ui/vet_icons.dart';
import '../data/inbox_source.dart';
import '../domain/inbox.dart';

/// Campana de la barra: despliega las notificaciones recientes y marca con un
/// numero las que llegaron desde la ultima vez que se abrio.
///
/// Abrir el menu da por vistas las que se muestran; los puntos de «nuevo» se
/// conservan mientras el menu sigue abierto, para que se distinga que llego.
class NotificationBellMenu extends StatefulWidget {
  const NotificationBellMenu({
    super.key,
    required this.source,
    required this.seenStore,
    required this.clinicId,
    required this.userId,
    required this.onOpenItem,
    this.onOpenAll,
    this.refreshKey,
    this.iconBuilder,
    this.pollEvery = const Duration(minutes: 2),
    this.now = DateTime.now,
  });

  final InboxSource source;
  final InboxSeenStore seenStore;
  final String clinicId;
  final String userId;
  final ValueChanged<InboxItem> onOpenItem;

  /// Lleva a la pantalla completa de avisos del equipo.
  final VoidCallback? onOpenAll;

  /// Al cambiar (la pantalla actual) se vuelve a consultar, para que al
  /// volver de leer un mensaje el contador ya este al dia.
  final Object? refreshKey;

  /// Pinta el icono base; la barra Neu lo mete en su placa.
  final Widget Function(BuildContext context, bool unread)? iconBuilder;

  final Duration pollEvery;
  final DateTime Function() now;

  @override
  State<NotificationBellMenu> createState() => _NotificationBellMenuState();
}

class _NotificationBellMenuState extends State<NotificationBellMenu> {
  final _menu = MenuController();
  List<InboxItem> items = const [];
  DateTime? seen;

  /// La marca de visto anterior a abrir el menu: decide los puntos de nuevo
  /// que se ven dentro mientras esta abierto.
  DateTime? shownSeen;
  bool busy = false;
  String? error;
  int _generation = 0;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _poll?.cancel();
    load();
    _poll = Timer.periodic(widget.pollEvery, (_) {
      if (!busy) load();
    });
  }

  @override
  void didUpdateWidget(NotificationBellMenu old) {
    super.didUpdateWidget(old);
    final scope =
        old.clinicId != widget.clinicId ||
        old.userId != widget.userId ||
        old.source != widget.source;
    if (scope) {
      // Otra cuenta u otra clinica: nada de lo mostrado le corresponde.
      items = const [];
      seen = null;
      shownSeen = null;
      _start();
    } else if (old.refreshKey != widget.refreshKey) {
      load();
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    final generation = ++_generation;
    // Sin setState: load() tambien corre desde initState. El indicador se
    // pinta en cuanto llega la respuesta o en el siguiente cuadro.
    busy = true;
    error = null;
    try {
      final stored = await widget.seenStore.read(
        widget.clinicId,
        widget.userId,
      );
      final next = await widget.source.load(widget.clinicId, widget.userId);
      if (!mounted || generation != _generation) return;
      setState(() {
        items = next;
        // Primera vez en este telefono: solo la ultima semana cuenta como
        // nueva, para no estrenar la campana con treinta pendientes.
        seen =
            stored ??
            widget.now().toUtc().subtract(const Duration(days: 7));
      });
      if (_menu.isOpen) await _markSeen();
    } catch (_) {
      if (!mounted || generation != _generation) return;
      // Sin detalle: el error del servidor puede traer datos de la cuenta.
      setState(() => error = 'No se pudieron consultar tus notificaciones.');
    } finally {
      if (mounted && generation == _generation) setState(() => busy = false);
    }
  }

  /// Da por vistas las que hay. Se guarda la hora de la mas reciente, no la
  /// del telefono: un reloj adelantado no debe ocultar lo que llegue despues.
  Future<void> _markSeen() async {
    if (items.isEmpty) return;
    final newest = items.first.createdAt;
    if (seen != null && !newest.isAfter(seen!)) return;
    setState(() => seen = newest);
    try {
      await widget.seenStore.write(widget.clinicId, widget.userId, newest);
    } catch (_) {
      // Si no se pudo guardar, la proxima vez vuelven a salir como nuevas.
    }
  }

  int get unread => inboxUnread(items, seen);

  void _toggle() {
    if (_menu.isOpen) {
      _menu.close();
      return;
    }
    shownSeen = seen;
    _menu.open();
    _markSeen();
    if (!busy) load();
  }

  Widget _tile(BuildContext context, InboxItem item) {
    final fresh = isInboxUnread(item, shownSeen);
    final scheme = Theme.of(context).colorScheme;
    return MenuItemButton(
      onPressed: () => widget.onOpenItem(item),
      style: MenuItemButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      leadingIcon: CircleAvatar(
        radius: 18,
        backgroundColor: scheme.primaryContainer,
        child: Icon(item.kind.icon, size: 18, color: scheme.onPrimaryContainer),
      ),
      trailingIcon: fresh
          ? Semantics(
              label: 'Nueva',
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
      child: SizedBox(
        width: 230,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: fresh ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (item.body.isNotEmpty)
              Text(
                item.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            Text(
              '${item.kind.label} · ${inboxAge(item.createdAt, widget.now().toUtc())}',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = unread;
    final label = count > 99 ? '99+' : '$count';
    return MenuAnchor(
      controller: _menu,
      // El menu se recoloca solo para no salirse de la pantalla.
      alignmentOffset: const Offset(0, 4),
      style: const MenuStyle(
        maximumSize: WidgetStatePropertyAll(Size(340, 520)),
      ),
      menuChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SizedBox(
            width: 290,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Notificaciones',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (busy)
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
        ),
        if (error != null)
          MenuItemButton(
            leadingIcon: const Icon(VetIcons.refresh),
            onPressed: () {
              setState(() {});
              load();
            },
            closeOnActivate: false,
            child: SizedBox(width: 230, child: Text('$error Reintentar')),
          )
        else if (items.isEmpty && !busy)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SizedBox(
              width: 290,
              child: Text(
                'No tienes notificaciones recientes. Aquí aparecen anuncios, mensajes, tareas y cambios en tu horario.',
              ),
            ),
          ),
        for (final item in items) _tile(context, item),
        if (widget.onOpenAll != null) ...[
          const Divider(height: 1),
          MenuItemButton(
            leadingIcon: const Icon(VetIcons.megaphone),
            onPressed: widget.onOpenAll,
            child: const Text('Ver todos los anuncios y avisos'),
          ),
        ],
      ],
      builder: (context, controller, _) => IconButton(
        tooltip: count == 0
            ? 'Notificaciones, ninguna nueva'
            : 'Notificaciones, $count nuevas',
        onPressed: _toggle,
        icon: Badge(
          isLabelVisible: count > 0,
          label: ExcludeSemantics(child: Text(label)),
          offset: const Offset(6, -6),
          child:
              widget.iconBuilder?.call(context, count > 0) ??
              const Icon(VetIcons.bell),
        ),
      ),
    );
  }
}

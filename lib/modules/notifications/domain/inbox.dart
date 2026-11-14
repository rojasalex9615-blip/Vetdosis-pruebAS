import 'package:flutter/widgets.dart';

import '../../../vet_ui/vet_icons.dart';

/// Tipo de notificacion personal que muestra la campana.
///
/// Solo entra lo que va dirigido a la persona o a su equipo: anuncios,
/// mensajes, tareas que alguien le asigno y cambios que otra persona hizo a
/// sus turnos. No entran avisos clinicos ni telemetria de la app.
enum InboxKind {
  announcement('Anuncio del equipo', VetIcons.megaphone),
  groupMessage('Mensaje al grupo', VetIcons.chats),
  mention('Te mencionaron', VetIcons.userPaw),
  privateMessage('Mensaje personal', VetIcons.chat),
  task('Tarea asignada', VetIcons.clipboardList),
  duty('Cambio en tu horario', VetIcons.calendarClock),
  dutyCancelled('Turno o falta cancelada', VetIcons.calendar);

  const InboxKind(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Una notificacion ya armada para pintarse.
@immutable
class InboxItem {
  const InboxItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.route,
  });

  /// Unico dentro del buzon: tipo de origen mas el id de la fila.
  final String id;
  final InboxKind kind;
  final String title;
  final String body;

  /// En UTC; la hora local se calcula al pintar.
  final DateTime createdAt;

  /// Pantalla de la app que lo amplia, o null si lo abre el contenedor
  /// (los turnos tienen su propia pantalla, fuera de la navegacion).
  final String? route;
}

/// Pantalla a la que lleva cada tipo.
String? inboxRoute(InboxKind kind) => switch (kind) {
  InboxKind.announcement => 'Anuncios y avisos',
  InboxKind.groupMessage ||
  InboxKind.mention ||
  InboxKind.privateMessage => 'Equipo y avisos',
  InboxKind.task => 'Pendientes del equipo',
  InboxKind.duty || InboxKind.dutyCancelled => null,
};

/// Cuantas notificaciones como maximo guarda el menu.
const inboxLimit = 30;

/// Antiguedad maxima de lo que se muestra. Lo anterior ya esta en sus
/// pantallas y solo haria la lista mas larga.
const inboxWindow = Duration(days: 30);

DateTime? _time(Object? raw) =>
    raw is String ? DateTime.tryParse(raw)?.toUtc() : null;

String _short(Object? raw, [int max = 140]) {
  final text = '${raw ?? ''}'.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text.length <= max ? text : '${text.substring(0, max - 1)}…';
}

String _two(int n) => n.toString().padLeft(2, '0');

/// Fecha y hora local corta: «12/11 08:30».
String inboxClock(DateTime at) {
  final l = at.toLocal();
  return '${_two(l.day)}/${_two(l.month)} ${_two(l.hour)}:${_two(l.minute)}';
}

/// «hace 5 min», «hace 3 h», o la fecha si ya pasaron dias.
String inboxAge(DateTime at, DateTime now) {
  final d = now.difference(at);
  if (d.inMinutes < 1) return 'ahora';
  if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
  if (d.inHours < 24) return 'hace ${d.inHours} h';
  if (d.inDays < 7) return 'hace ${d.inDays} d';
  return inboxClock(at);
}

/// Arma el buzon de [userId] con lo que ya devuelven las RPC del equipo.
///
/// [ops] es la respuesta de `ops_dashboard` y [duty] la de
/// `team_duty_workspace`; cualquiera puede faltar si la persona no tiene ese
/// modulo o no hubo conexion. Lo que hizo la propia persona no se le
/// notifica. [name] traduce un id de integrante a su nombre visible.
List<InboxItem> buildInbox({
  required String userId,
  required DateTime now,
  Map<String, dynamic>? ops,
  Map<String, dynamic>? duty,
  String Function(String id)? name,
}) {
  String who(Object? id) => id is String
      ? (name?.call(id) ?? 'Alguien del equipo')
      : 'Alguien del equipo';
  List<Map<String, dynamic>> rows(Map<String, dynamic>? source, String key) {
    final raw = source?[key];
    if (raw is! List) return const [];
    return [
      for (final row in raw)
        if (row is Map) Map<String, dynamic>.from(row),
    ];
  }

  final since = now.toUtc().subtract(inboxWindow);
  final items = <InboxItem>[];
  void add(InboxItem item) {
    if (item.createdAt.isBefore(since)) return;
    items.add(item);
  }

  for (final m in rows(ops, 'messages')) {
    final at = _time(m['created_at']);
    if (at == null || m['id'] == null || m['author_id'] == userId) continue;
    final mentions = m['mentioned_user_ids'];
    final mentioned = mentions is List && mentions.contains(userId);
    final kind = m['category'] == 'aviso'
        ? InboxKind.announcement
        : mentioned
        ? InboxKind.mention
        : InboxKind.groupMessage;
    final urgent = m['category'] == 'urgente';
    add(
      InboxItem(
        id: 'message:${m['id']}',
        kind: kind,
        title: kind == InboxKind.announcement
            ? 'Anuncio de ${who(m['author_id'])}'
            : mentioned
            ? '${who(m['author_id'])} te mencionó'
            : '${urgent ? 'Urgente · ' : ''}${who(m['author_id'])} escribió al grupo',
        body: _short(m['body']),
        createdAt: at,
        route: inboxRoute(kind),
      ),
    );
  }

  for (final m in rows(ops, 'private_messages')) {
    final at = _time(m['created_at']);
    if (at == null || m['id'] == null || m['recipient_id'] != userId) continue;
    add(
      InboxItem(
        id: 'private:${m['id']}',
        kind: InboxKind.privateMessage,
        title: 'Mensaje de ${who(m['author_id'])}',
        body: _short(m['body']),
        createdAt: at,
        route: inboxRoute(InboxKind.privateMessage),
      ),
    );
  }

  for (final t in rows(ops, 'tasks')) {
    final at = _time(t['created_at']);
    if (at == null || t['id'] == null || t['created_by'] == userId) continue;
    if (t['completed_at'] != null) continue;
    final mentions = t['mentioned_user_ids'];
    final mine =
        t['assigned_to'] == userId ||
        (mentions is List && mentions.contains(userId));
    if (!mine) continue;
    final details = [
      if ('${t['area'] ?? ''}'.trim().isNotEmpty) 'Área: ${t['area']}',
      if (t['scheduled_on'] != null) 'Para el ${t['scheduled_on']}',
      if (t['priority'] == 'urgente') 'Prioridad urgente',
    ].join(' · ');
    add(
      InboxItem(
        id: 'task:${t['id']}',
        kind: InboxKind.task,
        title: '${who(t['created_by'])} te asignó: ${_short(t['title'], 80)}',
        body: details,
        createdAt: at,
        route: inboxRoute(InboxKind.task),
      ),
    );
  }

  for (final e in rows(duty, 'entries')) {
    final mine = e['user_id'] == userId;
    final covering = e['cover_id'] == userId;
    if (!mine && !covering) continue;
    final starts = _time(e['starts_at']);
    final ends = _time(e['ends_at']);
    final when = starts == null || ends == null
        ? ''
        : '${inboxClock(starts)} → ${inboxClock(ends)}';
    final what = e['kind'] == 'shift' ? 'turno' : 'falta';
    final created = _time(e['created_at']);
    if (created != null && e['id'] != null && e['created_by'] != userId) {
      add(
        InboxItem(
          id: 'duty:${e['id']}',
          kind: InboxKind.duty,
          title: covering
              ? '${who(e['created_by'])} te asignó una cobertura'
              : '${who(e['created_by'])} registró tu $what',
          body: [
            when,
            if (covering) 'Cubres a ${who(e['user_id'])}',
          ].where((s) => s.isNotEmpty).join(' · '),
          createdAt: created,
        ),
      );
    }
    final cancelled = _time(e['cancelled_at']);
    if (e['cancelled'] == true &&
        cancelled != null &&
        e['cancelled_by'] != userId) {
      add(
        InboxItem(
          id: 'duty-cancel:${e['id']}',
          kind: InboxKind.dutyCancelled,
          title: '${who(e['cancelled_by'])} canceló ${covering ? 'tu cobertura' : 'tu $what'}',
          body: [
            when,
            if (e['cancel_reason'] is String) _short(e['cancel_reason'], 80),
          ].where((s) => s.isNotEmpty).join(' · '),
          createdAt: cancelled,
        ),
      );
    }
  }

  items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return items.length > inboxLimit ? items.sublist(0, inboxLimit) : items;
}

/// Cuantas son posteriores a la ultima vez que se abrio la campana.
int inboxUnread(List<InboxItem> items, DateTime? seen) =>
    items.where((i) => isInboxUnread(i, seen)).length;

bool isInboxUnread(InboxItem item, DateTime? seen) =>
    seen == null || item.createdAt.isAfter(seen);

import 'package:flutter/material.dart';

import '../../../vet_ui/vet_theme.dart';

/// Tipo de notificación personal.
///
/// Son avisos dirigidos a la persona, no telemetría del funcionamiento de la
/// app: lo que esperaría encontrar al abrir la campana. Cada tipo lleva su
/// color de la paleta de marca para reconocerlo de un vistazo, igual que los
/// módulos del Inicio y las calculadoras.
enum NotificationKind {
  /// Mensaje de la clínica dirigido a esta persona.
  clinicMessage('Mensaje de la clínica', Icons.forum_outlined, VetColors.cyan),

  /// Anuncio o aviso publicado para el equipo.
  announcement('Anuncio', Icons.campaign_outlined, VetColors.violet),

  /// Respuesta o plan generado por el asistente de IA.
  aiPlan('Respuesta de IA', Icons.auto_awesome, VetColors.lilac),

  /// Nota personal que alguien se deja a sí mismo.
  note('Nota', Icons.sticky_note_2_outlined, VetColors.turquoise),

  /// Recordatorio con fecha, puesto por la propia persona.
  reminder('Recordatorio', Icons.alarm, VetColors.purple);

  const NotificationKind(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  /// Lee el tipo guardado. Un valor desconocido no se adivina: se descarta,
  /// para no mostrar como «nota» algo que era un aviso clínico.
  static NotificationKind? parse(String? stored) {
    for (final kind in NotificationKind.values) {
      if (kind.name == stored) return kind;
    }
    return null;
  }
}

/// Una notificación personal, tal como se guarda y se muestra.
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.createdAt,
    this.body = '',
    this.readAt,
    this.route,
    this.clinicId,
  });

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;

  /// Siempre en UTC: la hora de presentación se calcula al pintar, para que un
  /// cambio de zona horaria del teléfono no reordene el historial.
  final DateTime createdAt;
  final DateTime? readAt;

  /// Pantalla a la que lleva al tocarla, si la hay. Es el nombre de ruta que
  /// entiende la navegación de la app, no una URL.
  final String? route;

  /// Clínica a la que pertenece, o null si es puramente personal. Sirve para
  /// no mezclar avisos de una clínica con los de otra al cambiar de espacio.
  final String? clinicId;

  bool get unread => readAt == null;

  AppNotification copyWith({DateTime? readAt}) => AppNotification(
    id: id,
    kind: kind,
    title: title,
    body: body,
    createdAt: createdAt,
    readAt: readAt ?? this.readAt,
    route: route,
    clinicId: clinicId,
  );

  Map<String, Object?> toRow(String userId) => {
    'userId': userId,
    'id': id,
    'kind': kind.name,
    'title': title,
    'body': body,
    'createdAt': createdAt.toUtc().millisecondsSinceEpoch,
    'readAt': readAt?.toUtc().millisecondsSinceEpoch,
    'route': route,
    'clinicId': clinicId,
  };

  /// Reconstruye una notificación guardada.
  ///
  /// Devuelve null si la fila no corresponde a esta persona o si le falta algo
  /// esencial. Falla cerrada a propósito: es preferible no mostrar un aviso
  /// que mostrarle a alguien el de otra cuenta.
  static AppNotification? fromRow(Map<String, Object?> row, String userId) {
    if (row['userId'] != userId) return null;
    final id = row['id'];
    final title = row['title'];
    final created = row['createdAt'];
    final kind = NotificationKind.parse(row['kind'] as String?);
    if (id is! String || id.isEmpty) return null;
    if (title is! String || title.isEmpty) return null;
    if (created is! int) return null;
    if (kind == null) return null;
    final read = row['readAt'];
    return AppNotification(
      id: id,
      kind: kind,
      title: title,
      body: row['body'] is String ? row['body'] as String : '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(created, isUtc: true),
      readAt: read is int
          ? DateTime.fromMillisecondsSinceEpoch(read, isUtc: true)
          : null,
      route: row['route'] is String ? row['route'] as String : null,
      clinicId: row['clinicId'] is String ? row['clinicId'] as String : null,
    );
  }
}

/// Mensaje interno del equipo. [recipientId] nulo significa todo el equipo.
class TeamMessage {
  const TeamMessage({
    required this.id,
    required this.clinicId,
    required this.senderId,
    this.recipientId,
    this.senderName = '',
    this.senderPhoto,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String clinicId;
  final String senderId;
  final String? recipientId;
  final String senderName;
  final String? senderPhoto;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get broadcast => recipientId == null;
  bool get unread => readAt == null;

  factory TeamMessage.fromJson(Map<String, dynamic> data) {
    String text(String key) {
      final value = data[key];
      return value is String ? value : '';
    }

    return TeamMessage(
      id: text('id'),
      clinicId: text('clinic_id'),
      senderId: text('sender_id'),
      recipientId: data['recipient_id'] is String
          ? data['recipient_id'] as String
          : null,
      senderName: text('sender_name'),
      senderPhoto: data['sender_photo'] is String
          ? data['sender_photo'] as String
          : null,
      body: text('body'),
      createdAt:
          DateTime.tryParse(text('created_at'))?.toLocal() ?? DateTime.now(),
      readAt: data['read_at'] is String
          ? DateTime.tryParse(data['read_at'] as String)?.toLocal()
          : null,
    );
  }
}

abstract interface class TeamMessageRepository {
  /// Envía a los destinatarios indicados; vacío equivale a todo el equipo.
  /// Devuelve cuántos mensajes se crearon.
  Future<int> send(String clinicId, List<String> recipients, String body);

  /// Recibidos por el usuario actual (directos o a todo el equipo).
  Future<List<TeamMessage>> inbox(String clinicId);

  Future<void> markRead(String messageId);
}

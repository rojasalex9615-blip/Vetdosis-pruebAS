import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/auth/domain/team_message.dart';

void main() {
  test('un mensaje al equipo no tiene destinatario y llega sin leer', () {
    final m = TeamMessage.fromJson({
      'id': 'm1',
      'clinic_id': 'c1',
      'sender_id': 'u1',
      'recipient_id': null,
      'sender_name': 'Ana',
      'body': 'Hola',
      'created_at': '2026-11-21T10:00:00Z',
    });
    expect(m.broadcast, isTrue);
    expect(m.unread, isTrue);
    expect(m.senderName, 'Ana');
    expect(m.body, 'Hola');
  });

  test('un mensaje leído con destinatario directo', () {
    final m = TeamMessage.fromJson({
      'id': 'm2',
      'clinic_id': 'c1',
      'sender_id': 'u1',
      'recipient_id': 'u2',
      'body': 'Solo para ti',
      'created_at': '2026-11-21T10:00:00Z',
      'read_at': '2026-11-21T11:00:00Z',
    });
    expect(m.broadcast, isFalse);
    expect(m.unread, isFalse);
  });
}

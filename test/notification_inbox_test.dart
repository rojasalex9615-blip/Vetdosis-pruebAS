import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/notifications/data/inbox_source.dart';
import 'package:vetdosis_pro/modules/notifications/domain/inbox.dart';
import 'package:vetdosis_pro/modules/notifications/presentation/notification_bell_menu.dart';

const me = 'user-me';
const admin = 'user-admin';
final now = DateTime.utc(2026, 11, 12, 15);
String ago(Duration d) => now.subtract(d).toIso8601String();

Map<String, dynamic> ops() => {
  'messages': [
    {
      'id': 'm1',
      'category': 'aviso',
      'body': 'Junta de equipo el viernes',
      'author_id': admin,
      'created_at': ago(const Duration(hours: 1)),
    },
    {
      'id': 'm2',
      'category': 'general',
      'body': 'Revisen el rol de limpieza',
      'author_id': admin,
      'mentioned_user_ids': [me],
      'created_at': ago(const Duration(hours: 2)),
    },
    // Lo que escribe la propia persona no se le notifica.
    {
      'id': 'm3',
      'category': 'general',
      'body': 'Yo mismo',
      'author_id': me,
      'created_at': ago(const Duration(minutes: 5)),
    },
    // Demasiado antiguo para el menu.
    {
      'id': 'm4',
      'category': 'aviso',
      'body': 'Viejo',
      'author_id': admin,
      'created_at': ago(const Duration(days: 40)),
    },
  ],
  'private_messages': [
    {
      'id': 'p1',
      'author_id': admin,
      'recipient_id': me,
      'body': '¿Puedes cubrir el sábado?',
      'created_at': ago(const Duration(minutes: 30)),
    },
    {
      'id': 'p2',
      'author_id': me,
      'recipient_id': admin,
      'body': 'Enviado por mí',
      'created_at': ago(const Duration(minutes: 20)),
    },
  ],
  'tasks': [
    {
      'id': 't1',
      'title': 'Limpieza de quirófano',
      'area': 'Quirófano',
      'assigned_to': me,
      'created_by': admin,
      'priority': 'urgente',
      'created_at': ago(const Duration(hours: 3)),
    },
    {
      'id': 't2',
      'title': 'Tarea de otra persona',
      'assigned_to': 'user-otro',
      'created_by': admin,
      'priority': 'baja',
      'created_at': ago(const Duration(hours: 3)),
    },
    {
      'id': 't3',
      'title': 'Ya hecha',
      'assigned_to': me,
      'created_by': admin,
      'priority': 'baja',
      'completed_at': ago(const Duration(hours: 1)),
      'created_at': ago(const Duration(hours: 4)),
    },
  ],
};

Map<String, dynamic> duty() => {
  'entries': [
    {
      'id': 'd1',
      'user_id': me,
      'kind': 'shift',
      'starts_at': '2026-11-14T14:00:00Z',
      'ends_at': '2026-11-14T22:00:00Z',
      'created_by': admin,
      'created_at': ago(const Duration(hours: 5)),
      'cancelled': true,
      'cancelled_by': admin,
      'cancel_reason': 'Cambio de rol',
      'cancelled_at': ago(const Duration(minutes: 10)),
    },
    {
      'id': 'd2',
      'user_id': 'user-otro',
      'cover_id': me,
      'kind': 'absence',
      'starts_at': '2026-11-15T14:00:00Z',
      'ends_at': '2026-11-15T22:00:00Z',
      'created_by': admin,
      'created_at': ago(const Duration(hours: 6)),
    },
  ],
};

class FakeSource implements InboxSource {
  FakeSource(this.items);
  List<InboxItem> items;
  int calls = 0;
  @override
  Future<List<InboxItem>> load(String clinicId, String userId) async {
    calls++;
    return items;
  }
}

class MemorySeen implements InboxSeenStore {
  DateTime? value;
  @override
  Future<DateTime?> read(String clinicId, String userId) async => value;
  @override
  Future<void> write(String clinicId, String userId, DateTime seen) async =>
      value = seen;
}

void main() {
  test('El buzón reúne lo dirigido a la persona y omite lo propio', () {
    final items = buildInbox(
      userId: me,
      now: now,
      ops: ops(),
      duty: duty(),
      name: (id) => id == admin ? 'Dra. Admin' : 'Otra persona',
    );
    expect(items.map((i) => i.id), [
      'duty-cancel:d1',
      'private:p1',
      'message:m1',
      'message:m2',
      'task:t1',
      'duty:d1',
      'duty:d2',
    ]);
    final kinds = {for (final i in items) i.id: i.kind};
    expect(kinds['message:m1'], InboxKind.announcement);
    expect(kinds['message:m2'], InboxKind.mention);
    expect(kinds['private:p1'], InboxKind.privateMessage);
    expect(kinds['task:t1'], InboxKind.task);
    expect(kinds['duty:d2'], InboxKind.duty);
    final task = items.firstWhere((i) => i.id == 'task:t1');
    expect(task.title, contains('Limpieza de quirófano'));
    expect(task.body, contains('Quirófano'));
    expect(task.route, 'Pendientes del equipo');
    final cover = items.firstWhere((i) => i.id == 'duty:d2');
    expect(cover.title, contains('cobertura'));
    expect(cover.body, contains('Otra persona'));
    expect(cover.route, isNull);
  });

  test('Sin datos de un módulo el buzón queda vacío, no falla', () {
    expect(buildInbox(userId: me, now: now), isEmpty);
    expect(
      buildInbox(userId: me, now: now, ops: {'messages': 'roto'}),
      isEmpty,
    );
  });

  test('Cuenta como nuevo solo lo posterior a la marca de visto', () {
    final items = buildInbox(userId: me, now: now, ops: ops());
    final seen = now.subtract(const Duration(minutes: 90));
    expect(inboxUnread(items, seen), 2);
    expect(inboxUnread(items, null), items.length);
  });

  testWidgets('La campana marca las nuevas y abre un menú que las da por vistas', (
    tester,
  ) async {
    final source = FakeSource(buildInbox(userId: me, now: now, ops: ops()));
    final seen = MemorySeen()..value = now.subtract(const Duration(minutes: 90));
    InboxItem? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              NotificationBellMenu(
                source: source,
                seenStore: seen,
                clinicId: 'clinic',
                userId: me,
                now: () => now,
                onOpenItem: (item) => opened = item,
                onOpenAll: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
    expect(find.byTooltip('Notificaciones, 2 nuevas'), findsOneWidget);

    await tester.tap(find.byTooltip('Notificaciones, 2 nuevas'));
    await tester.pumpAndSettle();
    expect(find.text('Notificaciones'), findsOneWidget);
    expect(find.textContaining('Junta de equipo'), findsOneWidget);
    expect(find.textContaining('te asignó: Limpieza'), findsOneWidget);
    expect(find.text('Ver todos los anuncios y avisos'), findsOneWidget);
    // Abrirlo guarda como visto lo más reciente.
    expect(seen.value, source.items.first.createdAt);

    await tester.tap(find.textContaining('te asignó: Limpieza'));
    await tester.pumpAndSettle();
    expect(opened?.id, 'task:t1');
    expect(find.byTooltip('Notificaciones, ninguna nueva'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Sin notificaciones no se pinta marcador', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              NotificationBellMenu(
                source: FakeSource(const []),
                seenStore: MemorySeen(),
                clinicId: 'clinic',
                userId: me,
                now: () => now,
                onOpenItem: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Notificaciones, ninguna nueva'), findsOneWidget);
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(find.textContaining('No tienes notificaciones recientes'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

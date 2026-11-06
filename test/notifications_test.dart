import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:vetdosis_pro/modules/notifications/data/local_notification_store.dart';
import 'package:vetdosis_pro/modules/notifications/domain/app_notification.dart';
import 'package:vetdosis_pro/modules/notifications/domain/notification_repository.dart';
import 'package:vetdosis_pro/modules/notifications/presentation/notification_bell.dart';
import 'package:vetdosis_pro/modules/notifications/presentation/notifications_screen.dart';
import 'package:vetdosis_pro/modules/notifications/presentation/notifications_view_model.dart';

var _secuencia = 0;

/// Una base por prueba: la de memoria devuelve la misma instancia si se repite
/// el nombre, y los avisos de una prueba se colarian en la siguiente.
Future<Database> _db() =>
    databaseFactoryMemory.openDatabase('notificaciones-${_secuencia++}.db');

AppNotification _aviso(
  String id, {
  NotificationKind kind = NotificationKind.note,
  String? clinicId,
  DateTime? createdAt,
  DateTime? readAt,
  String? route,
}) => AppNotification(
  id: id,
  kind: kind,
  title: 'Aviso $id',
  body: 'Detalle $id',
  createdAt: createdAt ?? DateTime.utc(2026, 11, 6, 8),
  readAt: readAt,
  route: route,
  clinicId: clinicId,
);

/// Repositorio que tarda lo que se le diga, para probar resultados tardíos.
class _RepoLento implements NotificationRepository {
  _RepoLento(this.porClinica);
  final Map<String?, List<AppNotification>> porClinica;
  final pendientes = <Completer<List<AppNotification>>>[];

  @override
  Future<List<AppNotification>> list(String userId, {String? clinicId}) {
    final completer = Completer<List<AppNotification>>();
    pendientes.add(completer);
    return completer.future;
  }

  @override
  Future<void> add(String userId, AppNotification notification) async {}
  @override
  Future<void> markRead(String userId, String id, DateTime at) async {}
  @override
  Future<void> markAllRead(String u, List<String> ids, DateTime at) async {}
  @override
  Future<void> remove(String userId, String id) async {}
}

void main() {
  group('Almacén local', () {
    test('Una cuenta no ve las notificaciones de otra', () async {
      final store = LocalNotificationStore(await _db());
      await store.add('ana', _aviso('a1'));
      await store.add('beto', _aviso('b1'));
      expect((await store.list('ana')).map((e) => e.id), ['a1']);
      expect((await store.list('beto')).map((e) => e.id), ['b1']);
    });

    test('Una fila con cuenta ajena se descarta, no se muestra', () async {
      final db = await _db();
      final store = LocalNotificationStore(db);
      await store.add('ana', _aviso('a1'));
      // Se altera el dueño de la fila por debajo del repositorio.
      final rows = await stringMapStoreFactory
          .store('notifications-v1')
          .find(db);
      await stringMapStoreFactory
          .store('notifications-v1')
          .record(rows.first.key)
          .put(db, {...rows.first.value, 'userId': 'beto'});
      expect(await store.list('ana'), isEmpty);
    });

    test('Las de una clínica no se ven desde otra; las personales sí', () async {
      final store = LocalNotificationStore(await _db());
      await store.add('ana', _aviso('personal'));
      await store.add('ana', _aviso('c1', clinicId: 'clinica-1'));
      await store.add('ana', _aviso('c2', clinicId: 'clinica-2'));
      final enUno = await store.list('ana', clinicId: 'clinica-1');
      expect(enUno.map((e) => e.id), containsAll(['personal', 'c1']));
      expect(enUno.map((e) => e.id), isNot(contains('c2')));
    });

    test('Ordena de la más reciente a la más antigua', () async {
      final store = LocalNotificationStore(await _db());
      await store.add(
        'ana',
        _aviso('vieja', createdAt: DateTime.utc(2026, 1, 1)),
      );
      await store.add(
        'ana',
        _aviso('nueva', createdAt: DateTime.utc(2026, 11, 6)),
      );
      expect((await store.list('ana')).map((e) => e.id), ['nueva', 'vieja']);
    });

    test('Marcar leída conserva la hora original de lectura', () async {
      final store = LocalNotificationStore(await _db());
      await store.add('ana', _aviso('a1'));
      final primera = DateTime.utc(2026, 11, 6, 9);
      await store.markRead('ana', 'a1', primera);
      await store.markRead('ana', 'a1', DateTime.utc(2026, 11, 6, 10));
      expect((await store.list('ana')).single.readAt, primera);
    });

    test('Otra cuenta no puede marcar ni borrar lo que no es suyo', () async {
      final store = LocalNotificationStore(await _db());
      await store.add('ana', _aviso('a1'));
      await store.markRead('beto', 'a1', DateTime.utc(2026, 11, 6, 9));
      await store.remove('beto', 'a1');
      final suyas = await store.list('ana');
      expect(suyas.single.unread, isTrue);
      expect(suyas, hasLength(1));
    });

    test('Un tipo desconocido se descarta en vez de adivinarse', () async {
      final db = await _db();
      final store = LocalNotificationStore(db);
      await store.add('ana', _aviso('a1'));
      final rows = await stringMapStoreFactory
          .store('notifications-v1')
          .find(db);
      await stringMapStoreFactory
          .store('notifications-v1')
          .record(rows.first.key)
          .put(db, {...rows.first.value, 'kind': 'inventado'});
      expect(await store.list('ana'), isEmpty);
    });
  });

  group('Modelo de la bandeja', () {
    test('Cuenta solo las no leídas', () async {
      final store = LocalNotificationStore(await _db());
      await store.add('ana', _aviso('a1'));
      await store.add(
        'ana',
        _aviso('a2', readAt: DateTime.utc(2026, 11, 6, 9)),
      );
      final model = NotificationsViewModel(repository: store, userId: 'ana');
      await model.load();
      expect(model.items, hasLength(2));
      expect(model.unreadCount, 1);
      model.dispose();
    });

    test('Un resultado tardío no repuebla una carga ya reemplazada', () async {
      final repo = _RepoLento({});
      final model = NotificationsViewModel(repository: repo, userId: 'ana');
      final primera = model.load();
      final segunda = model.load();
      // Llega antes la vieja, con contenido, y despues la nueva, vacia.
      repo.pendientes[0].complete([_aviso('vieja')]);
      repo.pendientes[1].complete([]);
      await Future.wait([primera, segunda]);
      expect(model.items, isEmpty);
      model.dispose();
    });

    test('Un fallo deja la bandeja vacía y no filtra el detalle', () async {
      final model = NotificationsViewModel(
        repository: _RepoQueFalla(),
        userId: 'ana',
      );
      await model.load();
      expect(model.items, isEmpty);
      expect(model.error, isNotNull);
      expect(model.error, isNot(contains('secreto')));
      model.dispose();
    });
  });

  group('Campana', () {
    testWidgets('Sin avisos no se pinta la marca', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: NotificationBell(unread: 0))),
      );
      expect(find.byTooltip('Notificaciones, ninguna sin leer'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('Con avisos muestra el numero y lo dice en voz alta', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: NotificationBell(unread: 3))),
      );
      expect(find.text('3'), findsOneWidget);
      expect(find.byTooltip('Notificaciones, 3 sin leer'), findsOneWidget);
    });

    testWidgets('Mas de noventa y nueve se abrevia', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: NotificationBell(unread: 150))),
      );
      expect(find.text('+99'), findsOneWidget);
    });
  });

  group('Pantalla', () {
    testWidgets('Sin notificaciones explica que apareceria aqui', (
      tester,
    ) async {
      final model = NotificationsViewModel(
        repository: _RepoFalso([]),
        userId: 'ana',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: NotificationsScreen(model: model)),
        ),
      );
      // Sin pumpAndSettle: el indicador de carga anima sin parar y nunca
      // llegaria a asentarse.
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('No tienes notificaciones'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      model.dispose();
    });

    testWidgets('Tocar una con destino la marca leida y navega', (
      tester,
    ) async {
      final store = _RepoFalso([_aviso('a1', route: 'Agenda')]);
      final model = NotificationsViewModel(repository: store, userId: 'ana');
      final visitadas = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationsScreen(
              model: model,
              onOpenRoute: visitadas.add,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Aviso a1'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(visitadas, ['Agenda']);
      expect(model.unreadCount, 0);
      await tester.pumpWidget(const SizedBox());
      model.dispose();
    });
  });
}

/// Repositorio en memoria, sin temporizadores: las pruebas de widget corren
/// con reloj simulado y el trabajo real de sembast no llega a completarse.
class _RepoFalso implements NotificationRepository {
  _RepoFalso(this._items);
  final List<AppNotification> _items;

  @override
  Future<List<AppNotification>> list(String userId, {String? clinicId}) async =>
      List.of(_items)..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<void> add(String userId, AppNotification notification) async =>
      _items.add(notification);

  @override
  Future<void> markRead(String userId, String id, DateTime at) async {
    final i = _items.indexWhere((e) => e.id == id);
    if (i < 0 || !_items[i].unread) return;
    _items[i] = _items[i].copyWith(readAt: at);
  }

  @override
  Future<void> markAllRead(String u, List<String> ids, DateTime at) async {
    for (final id in ids) {
      await markRead(u, id, at);
    }
  }

  @override
  Future<void> remove(String userId, String id) async =>
      _items.removeWhere((e) => e.id == id);
}

class _RepoQueFalla implements NotificationRepository {
  @override
  Future<List<AppNotification>> list(String userId, {String? clinicId}) =>
      Future.error(StateError('token secreto expuesto'));
  @override
  Future<void> add(String userId, AppNotification notification) async {}
  @override
  Future<void> markRead(String userId, String id, DateTime at) async {}
  @override
  Future<void> markAllRead(String u, List<String> ids, DateTime at) async {}
  @override
  Future<void> remove(String userId, String id) async {}
}

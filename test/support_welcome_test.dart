import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetdosis_pro/modules/support/domain/support_repository.dart';
import 'package:vetdosis_pro/modules/support/presentation/support_screen.dart';
import 'package:vetdosis_pro/modules/support/presentation/support_view_model.dart';
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';
import 'package:vetdosis_pro/modules/welcome/presentation/product_screen.dart';
import 'package:vetdosis_pro/modules/welcome/presentation/guided_start_screen.dart';

class SupportFake implements SupportRepository {
  bool denied = false;
  @override
  Future<List<Map<String, dynamic>>> tickets(String clinic) async {
    if (denied) throw StateError('denied');
    return [
      {
        'id': 'ticket',
        'title': 'Private',
        'status': 'open',
        'updated_at': '2026-11-13T00:00:00Z',
      },
    ];
  }

  @override
  Future<Map<String, dynamic>> detail(String ticket) async {
    if (denied) throw StateError('denied');
    return {
      'ticket': {'id': ticket},
      'messages': [],
      'attachments': [],
    };
  }

  @override
  Future<String> create(
    String clinic,
    String category,
    String title,
    String description,
    String operation,
  ) async => 'ticket';
  @override
  Future<void> message(String ticket, String body, String operation) async {}
  @override
  Future<void> attach(
    String ticket,
    String name,
    String mime,
    Uint8List bytes,
  ) async {}
  @override
  Future<Uri> download(String ticket, String path) async =>
      Uri.parse('https://example.test');
}

const _member = ClinicMembership(
  clinicId: 'clinic',
  clinicName: 'Clínica',
  userId: 'user-a',
  role: ClinicRole.admin,
);

void main() {
  test(
    'Support access failure clears previously loaded private data',
    () async {
      final r = SupportFake();
      final vm = SupportViewModel(r, 'clinic');
      await vm.load(ticket: 'ticket');
      expect(vm.detail, isNotNull);
      r.denied = true;
      await vm.load(ticket: 'ticket');
      expect(vm.detail, isNull);
      expect(vm.tickets, isEmpty);
      expect(vm.error, isNotNull);
      vm.dispose();
    },
  );
  testWidgets(
    'Product page fits phone and identifies draft prices and pending integrations',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: ProductScreen())),
        ),
      );
      expect(find.text('Planes y costos'), findsOneWidget);
      expect(find.textContaining('cobros aún desactivados'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Guided progress is scoped to user and workspace and can be revisited',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'guided_start_v1_user:personal': ['0'],
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GuidedStartScreen(
                scope: 'user:personal',
                onNavigate: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('1 de 7'), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GuidedStartScreen(
                key: const ValueKey('other'),
                scope: 'user:clinic',
                onNavigate: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('0 de 7'), findsOneWidget);
    },
  );
  testWidgets(
    'Support screen shows the injected app-help slot before the ticket form',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SupportScreen(
                repository: SupportFake(),
                member: _member,
                helpPanel: const Text('Ayuda IA incluida'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ayuda IA incluida'), findsOneWidget);
      // El panel va antes del formulario de ticket: primero lo que se resuelve
      // solo, después la persona.
      final helpY = tester.getTopLeft(find.text('Ayuda IA incluida')).dy;
      final formY = tester
          .getTopLeft(find.text('Ayuda, contacto y reportes'))
          .dy;
      expect(helpY, greaterThan(formY));
    },
  );
  testWidgets(
    'Support screen hides the app-help slot when none is injected',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SupportScreen(
                repository: SupportFake(),
                member: _member,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ayuda IA incluida'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

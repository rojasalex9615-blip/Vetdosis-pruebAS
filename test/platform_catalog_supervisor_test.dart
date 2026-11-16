import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/beta/domain/beta_repository.dart';
import 'package:vetdosis_pro/modules/beta/presentation/platform_catalog_supervisor_screen.dart';

class SupervisorFake implements PlatformCatalogSupervisorRepository {
  bool fail = false;
  List<Map<String, dynamic>> rows = [
    {
      'user_id': 'platform-account',
      'email': 'platform@example.test',
      'created_at': '2026-11-11T01:35:14Z',
      'is_platform_admin': true,
    },
    {
      'user_id': 'supervisor-a',
      'email': 'supervisor@example.test',
      'created_at': '2026-11-12T10:00:00Z',
      'is_platform_admin': false,
    },
  ];
  List<String>? lastGrant, lastRevocation;
  @override
  Future<List<Map<String, dynamic>>> catalogSupervisors() async {
    if (fail) throw StateError('denied');
    return rows;
  }

  @override
  Future<void> grantCatalogSupervisor(String email, String reason) async {
    lastGrant = [email, reason];
    rows = [
      ...rows,
      {
        'user_id': 'new-supervisor',
        'email': email,
        'created_at': '2026-11-15T00:00:00Z',
        'is_platform_admin': false,
      },
    ];
  }

  @override
  Future<void> revokeCatalogSupervisor(String userId, String reason) async {
    lastRevocation = [userId, reason];
    rows = rows.where((r) => r['user_id'] != userId).toList();
  }
}

Future<void> mount(WidgetTester tester, SupervisorFake repo) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(home: PlatformCatalogSupervisorScreen(repository: repo)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Lists supervisors and keeps the platform admin unremovable', (
    tester,
  ) async {
    await mount(tester, SupervisorFake());
    expect(find.textContaining('nunca el compartido'), findsOneWidget);
    expect(find.text('supervisor@example.test'), findsOneWidget);
    expect(find.textContaining('Administrador de plataforma'), findsOneWidget);
    // La cuenta de plataforma no se puede revocar desde aquí.
    expect(find.byTooltip('Revocar supervisor'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Granting requires a confirmed email and a reason', (
    tester,
  ) async {
    final repo = SupervisorFake();
    await mount(tester, repo);
    await tester.enterText(
      find.widgetWithText(TextField, 'Correo de la persona (ya registrado)'),
      'nuevo@example.test',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Motivo (mínimo 5 caracteres)'),
      'Validará el catálogo de la app',
    );
    await tester.tap(find.text('Nombrar supervisor'));
    await tester.pumpAndSettle();
    expect(repo.lastGrant, [
      'nuevo@example.test',
      'Validará el catálogo de la app',
    ]);
    expect(find.text('nuevo@example.test'), findsOneWidget);
  });

  testWidgets('Revocation requires a reason and explicit confirmation', (
    tester,
  ) async {
    final repo = SupervisorFake();
    await mount(tester, repo);
    await tester.tap(find.byTooltip('Revocar supervisor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar revocación'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Indica el motivo'), findsOneWidget);
    expect(repo.lastRevocation, isNull);
    await tester.enterText(find.byType(TextFormField), 'Ya no supervisa');
    await tester.tap(find.text('Confirmar revocación'));
    await tester.pumpAndSettle();
    expect(repo.lastRevocation, ['supervisor-a', 'Ya no supervisa']);
    expect(find.text('supervisor@example.test'), findsNothing);
  });

  testWidgets('Failed refresh clears the supervisor list from screen', (
    tester,
  ) async {
    final repo = SupervisorFake();
    await mount(tester, repo);
    repo.fail = true;
    await tester.tap(find.text('Actualizar'));
    await tester.pumpAndSettle();
    expect(find.text('supervisor@example.test'), findsNothing);
    expect(find.textContaining('No se pudo consultar'), findsOneWidget);
  });
}

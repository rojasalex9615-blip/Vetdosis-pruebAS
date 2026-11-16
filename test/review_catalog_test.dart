import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';
import 'package:vetdosis_pro/modules/core/domain/navigation_access.dart';
import 'package:vetdosis_pro/modules/review/domain/review_catalog_repository.dart';
import 'package:vetdosis_pro/modules/review/presentation/review_catalog_screen.dart';

class FakeReviewRepository implements ReviewCatalogRepository {
  int reports = 0;
  int globalChanges = 0;
  int clinicChanges = 0;
  int personalChanges = 0;
  String clinicStatus = 'sin_verificar';
  String personalStatus = 'sin_verificar';
  String globalStatus = 'revisar_conflicto';
  bool platformOwner = false;
  bool failClinicChange = false;

  ReviewCatalogItem get item => ReviewCatalogItem(
        key: 'source:1',
        version: 'v1',
        title: 'Producto ficticio',
        laboratory: 'Laboratorio ficticio',
        status: clinicStatus,
        globalStatus: globalStatus,
        personalStatus: personalStatus,
        source: 'Documento de prueba',
        page: 2,
        snapshot: const {'value': 'capturado'},
      );

  @override
  Future<List<ReviewCatalogItem>> list(
    String clinic,
    String search,
    int offset, {
    String source = 'inventario_comercial',
  }) async =>
      source == 'grok_pautas'
          ? [
              ReviewCatalogItem(
                key: 'grok_pautas:pautas_grok_1197_20261115:row:2',
                version: 'pautas_grok_1197_20261115',
                title: 'HEMOSTOP K (pauta)',
                laboratory: 'Laboratorio ficticio',
                status: clinicStatus,
                globalStatus: globalStatus,
                personalStatus: personalStatus,
                source: 'Pautas_VetDosis_MAESTRO.csv',
                doseText: '1 ml / 10 kg',
                snapshot: const {'id_pauta': 'HEMOSTOPK-PERROS-GATOS'},
              ),
            ]
          : [item];

  @override
  Future<Map<String, dynamic>> progress(
    String clinic, {
    String source = 'inventario_comercial',
  }) async =>
      {
        'total': source == 'grok_pautas' ? 1197 : 1,
        'sin_verificar': source == 'grok_pautas' ? 1197 : 1,
        'en_revision': 0,
        'global': {
          'total': 1,
          'sin_verificar': 0,
          'revisar_conflicto': 1,
          'validado': 0,
          'descartado': 0,
        },
      };

  @override
  Future<bool> isPlatformOwner() async => platformOwner;

  @override
  Future<void> setGlobalStatus(String sourceKey, String status) async {
    globalChanges++;
    globalStatus = status;
  }

  @override
  Future<void> setClinicStatus(
    String clinic,
    String sourceKey,
    String status,
  ) async {
    clinicChanges++;
    if (failClinicChange) throw StateError('clinic write rejected');
    clinicStatus = status;
  }

  @override
  Future<void> setPersonalStatus(String sourceKey, String status) async {
    personalChanges++;
    personalStatus = status;
  }

  @override
  Future<void> report({
    required String clinic,
    required String reviewer,
    required ReviewCatalogItem item,
    required String comment,
    String? expected,
    String? source,
  }) async {
    if (clinic != 'clinic' ||
        reviewer != 'reviewer' ||
        item.key != 'source:1' ||
        comment != 'Posible error') {
      throw StateError('wrong report');
    }
    reports++;
  }
}

const reviewer = ClinicMembership(
  clinicId: 'clinic',
  clinicName: 'Clínica',
  userId: 'reviewer',
  role: ClinicRole.revisor,
);

const administrator = ClinicMembership(
  clinicId: 'clinic',
  clinicName: 'Clínica',
  userId: 'admin',
  role: ClinicRole.admin,
);

Future<void> pumpReviewScreen(
  WidgetTester tester,
  FakeReviewRepository repository, {
  ClinicMembership member = reviewer,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ReviewCatalogScreen(
            repository: repository,
            clinic: member.clinicId,
            user: member.userId,
            offline: false,
            canManageClinic: member.role == ClinicRole.admin,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('el rol revisor solo navega a revisión y apartados generales', () {
    expect(ClinicRole.parse('revisor'), ClinicRole.revisor);
    expect(navigationAllowed('Modo revisión', reviewer), isTrue);
    for (final page in [
      'Pacientes',
      'Hospitalización',
      'Receta',
      'Cálculo rápido',
      'Inventario',
      'Asistente IA',
    ]) {
      expect(navigationAllowed(page, reviewer), isFalse, reason: page);
    }
  });

  testWidgets('propietaria puede cambiar el estado global sin tocar otros ámbitos',
      (tester) async {
    final repository = FakeReviewRepository()..platformOwner = true;
    await pumpReviewScreen(tester, repository, member: administrator);

    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(3));
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('validado').last);
    await tester.pumpAndSettle();

    expect(find.text('Cambiar estado global'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(repository.globalChanges, 0);
    expect(repository.globalStatus, 'revisar_conflicto');

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('validado').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar cambio global'));
    await tester.pumpAndSettle();

    expect(repository.globalChanges, 1);
    expect(repository.globalStatus, 'validado');
    expect(repository.clinicStatus, 'sin_verificar');
    expect(repository.personalStatus, 'sin_verificar');
  });

  testWidgets('admin puede cambiar clínica y personal por separado',
      (tester) async {
    final repository = FakeReviewRepository();
    await pumpReviewScreen(tester, repository, member: administrator);

    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));
    expect(find.text('Global (solo lectura): revisar_conflicto'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('en_revision').last);
    await tester.pumpAndSettle();

    expect(repository.clinicChanges, 1);
    expect(repository.clinicStatus, 'en_revision');
    expect(repository.personalStatus, 'sin_verificar');

    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('rechazado').last);
    await tester.pumpAndSettle();

    expect(repository.personalChanges, 1);
    expect(repository.personalStatus, 'rechazado');
    expect(repository.clinicStatus, 'en_revision');
  });

  testWidgets('revisor no puede cambiar el estado de la clínica ni el global',
      (tester) async {
    final repository = FakeReviewRepository();
    await pumpReviewScreen(tester, repository);

    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.text('Global (solo lectura): revisar_conflicto'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('verificado').last);
    await tester.pumpAndSettle();

    expect(repository.globalChanges, 0);
    expect(repository.clinicChanges, 0);
    expect(repository.personalChanges, 1);
    expect(repository.personalStatus, 'verificado');
  });

  testWidgets('un rechazo del servidor restablece el selector al valor real',
      (tester) async {
    final repository = FakeReviewRepository()..failClinicChange = true;
    await pumpReviewScreen(tester, repository, member: administrator);

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('verificado').last);
    await tester.pumpAndSettle();

    expect(repository.clinicChanges, 1);
    expect(repository.clinicStatus, 'sin_verificar');
    expect(find.text('No se pudo cambiar el estado.'), findsOneWidget);
    final picker = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>).first,
    );
    expect(picker.initialValue, 'sin_verificar');
  });

  testWidgets('muestra aviso permanente y registra reporte sin verificar valor',
      (tester) async {
    final repository = FakeReviewRepository();
    await pumpReviewScreen(tester, repository);

    expect(find.text('SIN VERIFICAR — solo revisión, no usar con pacientes'),
        findsOneWidget);
    expect(find.text('Producto ficticio'), findsOneWidget);
    await tester.tap(find.text('Reportar error / comentar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Comentario'),
      'Posible error',
    );
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();
    expect(repository.reports, 1);
  });

  testWidgets('sin conexión no expone los productos', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReviewCatalogScreen(
            repository: FakeReviewRepository(),
            clinic: 'clinic',
            user: 'reviewer',
            offline: true,
          ),
        ),
      ),
    );
    expect(find.text('Producto ficticio'), findsNothing);
    expect(find.textContaining('requiere conexión'), findsOneWidget);
  });

  testWidgets('cambiar a pautas de fabricante lista la fuente de pautas',
      (tester) async {
    final repository = FakeReviewRepository();
    await pumpReviewScreen(tester, repository);
    expect(find.text('Producto ficticio'), findsOneWidget);

    await tester.tap(find.text('Catálogo comercial'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pautas de fabricante'));
    await tester.pumpAndSettle();

    expect(find.text('HEMOSTOP K (pauta)'), findsOneWidget);
    expect(find.text('Producto ficticio'), findsNothing);
    expect(find.text('Posología documentada: 1 ml / 10 kg'), findsOneWidget);
    expect(find.textContaining('Pautas: 1197'), findsOneWidget);
  });
}

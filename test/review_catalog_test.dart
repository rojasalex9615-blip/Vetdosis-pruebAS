import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';
import 'package:vetdosis_pro/modules/core/domain/navigation_access.dart';
import 'package:vetdosis_pro/modules/review/domain/review_catalog_repository.dart';
import 'package:vetdosis_pro/modules/review/presentation/review_catalog_screen.dart';

class FakeReviewRepository implements ReviewCatalogRepository {
  int reports = 0;
  int clinicChanges = 0;
  int personalChanges = 0;
  String clinicStatus = 'sin_verificar';
  String personalStatus = 'sin_verificar';
  String globalStatus = 'revisar_conflicto';
  bool failClinicChange = false;
  bool failPersonalChange = false;

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
    int offset,
  ) async =>
      [item];

  @override
  Future<Map<String, dynamic>> progress(String clinic) async => {
        'total': 1,
        'sin_verificar': 1,
        'en_revision': 0,
      };

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
    if (failPersonalChange) throw StateError('personal write rejected');
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

  testWidgets('admin puede cambiar el estado de clínica y el personal por separado',
      (tester) async {
    final repository = FakeReviewRepository();
    await pumpReviewScreen(tester, repository, member: administrator);

    final pickers = find.byType(DropdownButtonFormField<String>);
    expect(pickers, findsNWidgets(2));
    expect(find.text('Global (solo lectura): revisar_conflicto'), findsOneWidget);

    await tester.tap(pickers.first);
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

  testWidgets('revisor no puede cambiar el estado de la clínica', (tester) async {
    final repository = FakeReviewRepository();
    await pumpReviewScreen(tester, repository);

    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.text('Estado de esta clínica'), findsNothing);
    expect(find.text('Mi estado personal'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('verificado').last);
    await tester.pumpAndSettle();

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
}

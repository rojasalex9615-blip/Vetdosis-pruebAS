import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';
import 'package:vetdosis_pro/modules/core/domain/navigation_access.dart';
import 'package:vetdosis_pro/modules/review/domain/review_catalog_repository.dart';
import 'package:vetdosis_pro/modules/review/presentation/review_catalog_screen.dart';

class FakeReviewRepository implements ReviewCatalogRepository {
  int reports = 0;
  @override
  Future<List<ReviewCatalogItem>> list(String clinic, String search, int offset) async => [
    const ReviewCatalogItem(
      key: 'source:1', version: 'v1', title: 'Producto ficticio',
      laboratory: 'Laboratorio ficticio', status: 'sin_verificar',
      source: 'Documento de prueba', page: 2,
      snapshot: {'value': 'capturado'},
    ),
  ];
  @override
  Future<Map<String, dynamic>> progress(String clinic) async =>
      {'total': 1, 'sin_verificar': 1, 'en_revision': 0};
  @override
  Future<void> setClinicStatus(String clinic, String sourceKey, String status) async {}
  @override
  Future<void> setPersonalStatus(String sourceKey, String status) async {}
  @override
  Future<void> report({required String clinic, required String reviewer,
    required ReviewCatalogItem item, required String comment,
    String? expected, String? source}) async {
    if (clinic != 'clinic' || reviewer != 'reviewer' ||
        item.key != 'source:1' || comment != 'Posible error') {
      throw StateError('wrong report');
    }
    reports++;
  }
}

void main() {
  const reviewer = ClinicMembership(
    clinicId: 'clinic', clinicName: 'Clínica', userId: 'reviewer',
    role: ClinicRole.revisor,
  );

  test('el rol revisor solo navega a revisión y apartados generales', () {
    expect(ClinicRole.parse('revisor'), ClinicRole.revisor);
    expect(navigationAllowed('Modo revisión', reviewer), isTrue);
    for (final page in ['Pacientes', 'Hospitalización', 'Receta',
      'Cálculo rápido', 'Inventario', 'Asistente IA']) {
      expect(navigationAllowed(page, reviewer), isFalse, reason: page);
    }
  });

  testWidgets('muestra aviso permanente y registra reporte sin verificar valor',
      (tester) async {
    final repository = FakeReviewRepository();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: ReviewCatalogScreen(repository: repository, clinic: 'clinic',
        user: 'reviewer', offline: false),
    ))));
    await tester.pumpAndSettle();
    expect(find.text('SIN VERIFICAR — solo revisión, no usar con pacientes'),
        findsOneWidget);
    expect(find.text('Producto ficticio'), findsOneWidget);
    await tester.tap(find.text('Reportar error / comentar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Comentario'),
        'Posible error');
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();
    expect(repository.reports, 1);
  });

  testWidgets('sin conexión no expone los productos', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ReviewCatalogScreen(
      repository: FakeReviewRepository(), clinic: 'clinic', user: 'reviewer',
      offline: true,
    ))));
    expect(find.text('Producto ficticio'), findsNothing);
    expect(find.textContaining('requiere conexión'), findsOneWidget);
  });
}

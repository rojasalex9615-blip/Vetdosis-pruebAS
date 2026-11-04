import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';
import 'package:vetdosis_pro/modules/operations/domain/operations_repository.dart';
import 'package:vetdosis_pro/modules/operations/presentation/operations_screen.dart';

class ServiceCatalogFake implements OperationsRepository {
  @override
  Future<Map<String, dynamic>> dashboard(String clinic) async => {
    'permissions': {'service.read': true, 'service.manage': true},
    'sections': {'services': true},
    'members': <Map<String, dynamic>>[],
    'services': [
      {'id': 's1', 'name': 'Cuidados generales', 'price': '250.00',
       'category': 'hospitalizacion', 'subcategory': 'General',
       'commission_kind': 'bono', 'commission_value': '0', 'version': 1},
    ],
  };

  @override
  Future<void> write(String clinic, String action, Map<String, dynamic> data,
      String operation) async {}

  @override
  Future<List<Map<String, dynamic>>> medical(String clinic,
      {Map<String, dynamic>? details, bool consent = false}) async => [];
}

void main() {
  testWidgets('The beta groups existing clinic services without changing their price',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: OperationsScreen(
        repository: ServiceCatalogFake(),
        member: const ClinicMembership(clinicId: 'clinic', clinicName: 'Pruebas',
            userId: 'admin', role: ClinicRole.admin),
        initialSection: 'services',
      ),
    ))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Hospitalización').first);
    await tester.tap(find.text('Hospitalización').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('General').first);
    await tester.tap(find.text('General').first);
    await tester.pumpAndSettle();
    expect(find.text('Cuidados generales · \$250.00'), findsOneWidget);
    expect(find.textContaining('Comisión: bono 0'), findsOneWidget);
  });
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';
import 'package:vetdosis_pro/modules/doses/data/catalog_repository.dart';
import 'package:vetdosis_pro/modules/doses/domain/catalog.dart';
import 'package:vetdosis_pro/modules/doses/presentation/dose_label_scanner_screen.dart';

import 'dose_test.dart' show fixture;

class LabelCatalog implements CatalogRepository {
  @override
  Future<DoseCatalog> load() async =>
      DoseCatalog.parse(jsonEncode(fixture()));
}

const testClinician = ClinicMembership(
  clinicId: 'clinic-test',
  clinicName: 'Clínica de prueba',
  userId: 'mvz',
  role: ClinicRole.mvz,
);

void main() {
  test('recognition matches full drug or brand without inferring doses', () {
    final catalog = DoseCatalog.parse(jsonEncode(fixture()));
    expect(
      doseLabelSuggestions(catalog, 'MARCA FICTICIA\n10 mg/ml')
          .single.name,
      'Ficticio',
    );
    expect(
      doseLabelSuggestions(catalog, 'Ficticio - lote 123').single.name,
      'Ficticio',
    );
    expect(doseLabelSuggestions(catalog, 'Fictici lote 123'), isEmpty);
    expect(doseLabelSuggestions(catalog, '100 mg/ml dosis 5'), isEmpty);
    expect(normalizeDoseLabel('Solución, INYECCIÓN'), 'solucion inyeccion');
  });

  testWidgets('local label capture only suggests; clinician chooses item', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DoseLabelScannerScreen(
            member: testClinician,
            catalogRepository: LabelCatalog(),
            reader: (source) async {
              expect(source, ImageSource.camera);
              return 'MARCA FICTICIA\n10 mg/ml\nLote sintético';
            },
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('No identifica por'), findsOneWidget);
    expect(find.text('Calcular dosis de un producto'), findsNothing);
    await tester.tap(find.text('Tomar foto de etiqueta'));
    await tester.pumpAndSettle();
    expect(find.text('Texto reconocido (sin verificar)'), findsOneWidget);
    expect(find.text('Ficticio'), findsOneWidget);
    expect(find.text('Calcular dosis de un producto'), findsNothing);
    await tester.ensureVisible(find.text('Ficticio'));
    await tester.tap(find.text('Ficticio'));
    await tester.pumpAndSettle();
    expect(find.text('Revisar dosis'), findsOneWidget);
    expect(find.text('Calcular dosis de un producto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nonclinical role cannot scan dose labels', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: DoseLabelScannerScreen(
        member: ClinicMembership(
          clinicId: 'clinic-test',
          clinicName: 'Clínica de prueba',
          userId: 'reception',
          role: ClinicRole.recepcion,
        ),
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Tomar foto de etiqueta'), findsNothing);
    expect(
      find.textContaining('requiere acceso de MVZ o administrador'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

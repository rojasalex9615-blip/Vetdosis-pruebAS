import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';
import 'package:vetdosis_pro/modules/forms/clinical/clinical_models.dart';
import 'package:vetdosis_pro/modules/forms/clinical/clinical_repository.dart';
import 'package:vetdosis_pro/modules/forms/clinical/clinical_vitals_screen.dart';
import 'package:vetdosis_pro/modules/forms/clinical/vital_reference_catalog.dart';
import 'package:vetdosis_pro/modules/forms/clinical/vital_reference_repository.dart';
import 'package:vetdosis_pro/modules/forms/clinical/vitals_models.dart';

class VitalsFake implements ClinicalRepository {
  Map<String, dynamic>? saved;

  @override
  Future<Map<String, dynamic>> vitals(
    String caseId,
    Map<String, dynamic> data,
    String operationId,
  ) async {
    saved = Map<String, dynamic>.from(data);
    return {
      'id': 'vital',
      ...data,
      'pam': calculatedPam(
        data['bp_systolic'] as String?,
        data['bp_diastolic'] as String?,
      ),
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Un catálogo de constantes de prueba, en la forma que espera el parser.
VitalReferenceCatalog catalogForTest() => VitalReferenceCatalog.parse(r'''
{
  "schema_version": 1,
  "catalog_version": "synthetic-2026-11",
  "references": [
    {
      "id": "canino-fc",
      "species": "Canino",
      "parameter": "fc",
      "unit": "lpm",
      "min": "60",
      "max": "180",
      "status": "unverified",
      "source": "Fuente sintética de prueba",
      "note": "Extremos sin inclusividad indicada.",
      "reviewed_at": "2026-11-08T00:00:00Z"
    },
    {
      "id": "felino-fc",
      "species": "Felino",
      "parameter": "fc",
      "unit": "lpm",
      "min": "140",
      "max": "220",
      "status": "unverified",
      "source": "Fuente sintética de prueba",
      "reviewed_at": "2026-11-08T00:00:00Z"
    }
  ]
}
''');

/// Repositorio que siempre falla: deja la pantalla sin catálogo.
class FailingVitalReferenceRepository implements VitalReferenceRepository {
  const FailingVitalReferenceRepository();

  @override
  Future<VitalReferenceCatalog> load() async =>
      throw const FormatException('sin catálogo');
}

class FixedVitalReferenceRepository implements VitalReferenceRepository {
  const FixedVitalReferenceRepository(this.catalog);
  final VitalReferenceCatalog catalog;

  @override
  Future<VitalReferenceCatalog> load() async => catalog;
}

const member = ClinicMembership(
  clinicId: 'clinic',
  clinicName: 'Synthetic',
  userId: 'person',
  role: ClinicRole.mvz,
);

ClinicalCase patientCase() => ClinicalCase({
  'id': 'case',
  'patient_id': 'patient',
  'responsible_id': 'person',
  'kind': 'clinical_history',
  'title': 'Historia',
  'patient_name': 'Max',
  'patient_species': 'canino',
  'patient_breed': 'Golden Retriever',
  'patient_sex': 'macho',
  'created_at': '2026-10-17T00:00:00Z',
});

void main() {
  test('PAM uses exact systolic plus twice diastolic divided by three', () {
    expect(calculatedPam('125', '75'), '91,7');
    expect(calculatedPam('', ''), isNull);
    expect(() => calculatedPam('125', ''), throwsFormatException);
  });

  test('vital set stays factual and requires paired blood pressure', () {
    final result = validateVitalSet(
      values: {
        'fc': '85',
        'fr': '22',
        'temperature': '38,5',
        'tllc': '1.5',
        'bp_systolic': '125',
        'bp_diastolic': '75',
      },
      performedBy: 'person',
      observedAt: DateTime.utc(2026, 10, 17, 1),
      mucosaColor: 'rosadas',
      mucosaHumidity: 'humedas',
      notes: 'Examen físico general.',
    );
    expect(result['temperature'], '38.5');
    expect(result['mucosa_color'], 'rosadas');
    expect(result.containsKey('triage_status'), false);
    expect(
      () => validateVitalSet(
        values: {'bp_systolic': '125'},
        performedBy: 'person',
        observedAt: DateTime.utc(2026, 10, 17, 1),
      ),
      throwsFormatException,
    );
  });

  test('species labels normalize common patient vocabulary', () {
    expect(speciesLabel('canino'), 'Canino');
    expect(speciesLabel('Gato'), 'Felino');
    expect(speciesLabel('bovino'), 'Bovino');
    expect(speciesLabel('ave'), 'Aves');
  });


  test('versioned vital references classify only verified matching entries', () {
    final catalog = VitalReferenceCatalog.parse(r'''
{
  "schema_version": 1,
  "catalog_version": "synthetic-2026-10",
  "references": [
    {
      "id": "canine-fc",
      "species": "canino",
      "parameter": "fc",
      "unit": "lpm",
      "min": "60",
      "max": "120",
      "status": "verified",
      "source": "Synthetic source for tests only",
      "reviewed_at": "2026-10-17T00:00:00Z"
    },
    {
      "id": "canine-fr-unverified",
      "species": "canino",
      "parameter": "fr",
      "unit": "rpm",
      "min": "10",
      "max": "30",
      "status": "unverified",
      "source": "Synthetic source for tests only",
      "reviewed_at": "2026-10-17T00:00:00Z"
    }
  ]
}
''');

    expect(
      catalog.evaluate(
        species: 'Canino',
        parameter: 'fc',
        rawValue: '85',
      )?.state,
      VitalReferenceState.within,
    );
    expect(
      catalog.evaluate(
        species: 'canino',
        parameter: 'fc',
        rawValue: '130',
      )?.state,
      VitalReferenceState.above,
    );
    expect(
      catalog.evaluate(
        species: 'canino',
        parameter: 'fr',
        rawValue: '22',
      ),
      isNull,
    );
    expect(
      catalog.evaluate(
        species: 'felino',
        parameter: 'fc',
        rawValue: '85',
      ),
      isNull,
    );

    final snapshot = catalog.snapshotFor(
      species: 'canino',
      values: {'fc': '85', 'fr': '22'},
    );
    expect(snapshot, hasLength(1));
    expect(snapshot.single['catalog_version'], 'synthetic-2026-10');
    expect(snapshot.single['reference_id'], 'canine-fc');
    expect(snapshot.single['state'], 'within');
    expect(snapshot.single['source'], 'Synthetic source for tests only');
  });

  test('vital reference catalog rejects inverted ranges and bad review dates', () {
    expect(
      () => VitalReferenceCatalog.parse(r'''
{
  "schema_version": 1,
  "catalog_version": "bad",
  "references": [
    {
      "id": "bad-range",
      "species": "canino",
      "parameter": "fc",
      "unit": "lpm",
      "min": "120",
      "max": "60",
      "status": "verified",
      "source": "Synthetic source",
      "reviewed_at": "2026-10-17T00:00:00Z"
    }
  ]
}
'''),
      throwsFormatException,
    );
  });

  testWidgets('vital monitor shows patient context and avoids unverified triage', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ClinicalVitalsScreen(
          repository: VitalsFake(),
          member: member,
          caseData: patientCase(),
          latestWeight: '28.5',
          referenceRepository: const FailingVitalReferenceRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Monitor de constantes'), findsOneWidget);
    expect(find.text('Max'), findsOneWidget);
    expect(find.textContaining('Canino · Golden Retriever · 28.5 kg'), findsOneWidget);
    final interpretation = find.text(
      'Interpretación automática todavía desactivada',
    );
    await tester.scrollUntilVisible(
      interpretation,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(interpretation, findsOneWidget);
    expect(find.text('ESTABLE / NORMAL'), findsNothing);
    final saveButton = find.text('Guardar constantes en historial clínico');
    await tester.scrollUntilVisible(
      saveButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(saveButton, findsOneWidget);
  });

  test('la banda marca alerta junto al limite y normal en el centro', () {
    final catalog = catalogForTest();
    VitalBand? bandFor(String value) => catalog
        .readings(species: 'Canino', parameter: 'fc', rawValue: value)
        .single
        .band;

    expect(bandFor('50'), VitalBand.low);
    expect(bandFor('61'), VitalBand.alert);
    expect(bandFor('120'), VitalBand.normal);
    expect(bandFor('179'), VitalBand.alert);
    expect(bandFor('200'), VitalBand.high);
    // Sin valor interpretable no se juzga.
    expect(bandFor(''), isNull);
    expect(bandFor('abc'), isNull);
  });

  test('las lecturas no exigen verificacion y traen la cita de cada fuente', () {
    final catalog = catalogForTest();
    final canino = catalog.readings(
      species: 'Canino',
      parameter: 'fc',
      rawValue: '120',
    );
    expect(canino, hasLength(1));
    expect(canino.single.verified, isFalse);
    expect(canino.single.entry.source, 'Fuente sintética de prueba');
    expect(canino.single.range, '60 – 180 lpm');

    // Otra especie: otra referencia.
    final felino = catalog.readings(
      species: 'Felino',
      parameter: 'fc',
      rawValue: '120',
    );
    expect(felino.single.range, '140 – 220 lpm');
    expect(felino.single.band, VitalBand.low);
  });

  test('el indicador en vivo no altera lo que se guarda', () {
    // Aunque las referencias no estén verificadas, el snapshot de guardado
    // sigue vacío: solo lo alimentan entradas verificadas.
    final catalog = catalogForTest();
    final snapshot = catalog.snapshotFor(
      species: 'Canino',
      values: {'fc': '120'},
    );
    expect(snapshot, isEmpty);
  });

  testWidgets('el indicador en vivo muestra referencia, badge y cita', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ClinicalVitalsScreen(
          repository: VitalsFake(),
          member: member,
          caseData: patientCase(),
          referenceRepository: FixedVitalReferenceRepository(catalogForTest()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fc = find.widgetWithText(TextField, 'Frecuencia cardíaca');

    // Dentro: referencia y «Normal».
    await tester.enterText(fc, '120');
    await tester.pumpAndSettle();
    expect(find.text('Ref: 60 – 180 lpm'), findsOneWidget);
    expect(find.text('Normal'), findsOneWidget);
    expect(find.textContaining('Fuente sintética de prueba'), findsWidgets);

    // Bajo: el badge cambia.
    await tester.enterText(fc, '40');
    await tester.pumpAndSettle();
    expect(find.text('Bajo'), findsOneWidget);
    expect(find.text('Normal'), findsNothing);

    // Alto: vuelve a cambiar.
    await tester.enterText(fc, '250');
    await tester.pumpAndSettle();
    expect(find.text('Alto'), findsOneWidget);
    expect(find.text('Bajo'), findsNothing);

    // Cerca del límite bajo: alerta.
    await tester.enterText(fc, '65');
    await tester.pumpAndSettle();
    expect(find.text('Alerta'), findsOneWidget);
  });

  testWidgets('cambiar de especie cambia el texto de referencia', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ClinicalVitalsScreen(
          repository: VitalsFake(),
          member: member,
          caseData: ClinicalCase({
            'id': 'case',
            'patient_id': 'patient',
            'responsible_id': 'person',
            'kind': 'clinical_history',
            'title': 'Historia',
            'patient_name': 'Luna',
            'patient_species': 'felino',
            'patient_breed': 'Siamés',
            'patient_sex': 'hembra',
            'created_at': '2026-10-17T00:00:00Z',
          }),
          referenceRepository: FixedVitalReferenceRepository(catalogForTest()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fc = find.widgetWithText(TextField, 'Frecuencia cardíaca');
    await tester.enterText(fc, '160');
    await tester.pumpAndSettle();
    // La referencia felina, no la canina.
    expect(find.text('Ref: 140 – 220 lpm'), findsOneWidget);
    expect(find.text('Ref: 60 – 180 lpm'), findsNothing);
    expect(find.text('Normal'), findsOneWidget);
  });
}

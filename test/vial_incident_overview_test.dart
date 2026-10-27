import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/forms/clinical/clinical_models.dart';
import 'package:vetdosis_pro/modules/prescribing/presentation/prescribing_screen.dart';
import 'prescribing_test.dart' show RxClinicalFake, auxiliary;
import 'vial_reconciliation_test.dart' show ClosedVialRepository;
import 'forms_test.dart' show FakeForms;

class IncidentRepository extends ClosedVialRepository {
  bool details = true, more = false;
  int writes = 0;
  @override
  Future<dynamic> read(String command, Map<String, dynamic> args) async {
    if (command == 'rx_vials') {
      final rows = (await super.read(command, args) as List)
          .cast<Map<String, dynamic>>();
      return [
        for (final row in rows)
          {
            ...row,
            'incidents_supported': true,
            'has_post_close_movements': true,
            'more_incidents': more,
            'incidents': details
                ? [
                    {
                      'id': 'record',
                      'case_id': 'case',
                      'quantity': '2',
                      'unit': 'ml',
                      'observed_at': '2026-10-27T06:00:00Z',
                      'incidence': 'Aplicación reportada con frasco cerrado',
                    },
                  ]
                : [],
          },
      ];
    }
    if (command == 'rx_medications') {
      return [
        {
          'id': 'record',
          'product_name': 'Producto ficticio',
          'quantity': '2',
          'unit': 'ml',
          'lot': 'TEST',
          'incidence': 'Caso para revisión',
          'superseded': false,
          'responsible_id': 'mvz',
          'review': null,
        },
      ];
    }
    return super.read(command, args);
  }

  @override
  Future<dynamic> write(String command, Map<String, dynamic> args) async {
    writes++;
    throw StateError('Read-only overview must not mutate records');
  }
}

class IncidentClinical extends RxClinicalFake {
  bool accessible = true;
  @override
  Future<List<ClinicalCase>> cases(String clinicId, String? patientId) async =>
      accessible
      ? [
          ClinicalCase({
            'id': 'case',
            'patient_id': 'patient',
            'responsible_id': 'mvz',
            'kind': 'clinical_history',
            'title': 'Caso ficticio',
            'patient_name': 'Paciente ficticio',
            'created_at': '2026-10-27T00:00:00Z',
          }),
        ]
      : [];
}

Widget app(IncidentRepository repo, IncidentClinical clinical) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: PrescribingScreen(
        repository: repo,
        clinical: clinical,
        forms: FakeForms(),
        member: auxiliary,
      ),
    ),
  ),
);
Future<void> showVials(
  WidgetTester tester,
  IncidentRepository repo,
  IncidentClinical clinical,
) async {
  await tester.pumpWidget(app(repo, clinical));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(DropdownButtonFormField<String>).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Frascos').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'physical warning remains visible without exposing clinical detail at 320dp',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = IncidentRepository()..details = false;
      await showVials(tester, repo, IncidentClinical());
      expect(
        find.textContaining('Hay movimientos registrados después del cierre'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Aplicación reportada con frasco cerrado'),
        findsNothing,
      );
      expect(find.text('Ver caso de la incidencia'), findsNothing);
      expect(tester.takeException(), isNull);
      expect(repo.writes, 0);
    },
  );
  testWidgets(
    'accessible incident opens its case with fresh data and performs no clinical write',
    (tester) async {
      final repo = IncidentRepository()..more = true;
      await showVials(tester, repo, IncidentClinical());
      expect(find.textContaining('100 incidencias accesibles'), findsOneWidget);
      await tester.ensureVisible(find.text('Ver caso de la incidencia'));
      await tester.tap(find.text('Ver caso de la incidencia'));
      await tester.pumpAndSettle();
      expect(find.text('Caso para revisión'), findsOneWidget);
      expect(find.text('Reportar aplicación realizada'), findsOneWidget);
      expect(repo.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'case that became unavailable cannot be opened from stale incident data',
    (tester) async {
      final repo = IncidentRepository();
      final clinical = IncidentClinical();
      await showVials(tester, repo, clinical);
      clinical.accessible = false;
      await tester.ensureVisible(find.text('Ver caso de la incidencia'));
      await tester.tap(find.text('Ver caso de la incidencia'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('El caso ya no está disponible'),
        findsOneWidget,
      );
      expect(find.text('Caso para revisión'), findsNothing);
      expect(repo.writes, 0);
    },
  );
}

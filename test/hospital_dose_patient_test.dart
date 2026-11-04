import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';
import 'package:vetdosis_pro/modules/hospital/domain/hospital_models.dart';
import 'package:vetdosis_pro/modules/hospital/presentation/hospital_dose_patient_screen.dart';
import 'hospital_test.dart' show FakeHospital, member, stay;
import 'hospital_weight_test.dart' show WeightClinical, entry;

void main() {
  testWidgets(
    'patient selection keeps persisted weight validation alive and does not write treatment',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final hospital = FakeHospital();
      final clinical = WeightClinical()..entries.add(entry());
      var selected = false;
      await tester.pumpWidget(
        MaterialApp(
          home: HospitalDosePatientScreen(
            hospital: hospital,
            clinical: clinical,
            member: member(ClinicRole.mvz),
            contextIsCurrent: () => true,
            onCalculate: (weight, validate) async {
              expect(weight.patientId, 'patient-a');
              expect(weight.kg, '10.250000000');
              expect(await validate(weight), true);
              selected = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paciente ficticio hospitalizado'));
      await tester.pumpAndSettle();
      final action = find.text('Revisar peso para cálculo');
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(selected, true);
      expect(hospital.writes, 0);
      expect(clinical.writes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('session revocation discards pending names and clears search', (
    tester,
  ) async {
    final hospital = FakeHospital()..pending = Completer<HospitalSnapshot>();
    final changes = ChangeNotifier();
    addTearDown(changes.dispose);
    var current = true;
    await tester.pumpWidget(
      MaterialApp(
        home: HospitalDosePatientScreen(
          hospital: hospital,
          clinical: WeightClinical(),
          member: member(ClinicRole.mvz),
          sessionChanges: changes,
          contextIsCurrent: () => current,
          onCalculate: (_, _) async {},
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Sensitive query');
    current = false;
    changes.notifyListeners();
    hospital.pending!.complete(HospitalSnapshot([stay()], []));
    await tester.pumpAndSettle();
    expect(find.text('Paciente ficticio hospitalizado'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(
      find.textContaining('La sesión o los permisos cambiaron'),
      findsOneWidget,
    );
  });
  testWidgets('wrong clinic snapshot is rejected', (tester) async {
    final source = stay();
    final hospital = FakeHospital()
      ..snapshot = HospitalSnapshot([
        HospitalStay(
          id: source.id,
          clinicId: 'other',
          patientId: source.patientId,
          patientName: 'PRIVATE OTHER CLINIC',
          species: source.species,
          cage: source.cage,
          admittedAt: source.admittedAt,
          version: source.version,
        ),
      ], []);
    await tester.pumpWidget(
      MaterialApp(
        home: HospitalDosePatientScreen(
          hospital: hospital,
          clinical: WeightClinical(),
          member: member(ClinicRole.mvz),
          contextIsCurrent: () => true,
          onCalculate: (_, _) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('PRIVATE OTHER CLINIC'), findsNothing);
    expect(find.textContaining('No se pudieron consultar'), findsOneWidget);
  });
  testWidgets('background hides names and query until fresh reload', (
    tester,
  ) async {
    final hospital = FakeHospital();
    await tester.pumpWidget(
      MaterialApp(
        home: HospitalDosePatientScreen(
          hospital: hospital,
          clinical: WeightClinical(),
          member: member(ClinicRole.mvz),
          contextIsCurrent: () => true,
          onCalculate: (_, _) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Paciente');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(find.text('Paciente ficticio hospitalizado'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Paciente ficticio hospitalizado'), findsOneWidget);
    expect(hospital.reads, 2);
  });
}

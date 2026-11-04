import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetdosis_pro/core/app.dart';
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';
import 'package:vetdosis_pro/modules/auth/presentation/auth_view_model.dart';
import 'package:vetdosis_pro/modules/core/data/settings_repository.dart';
import 'package:vetdosis_pro/modules/core/domain/module_access.dart';
import 'package:vetdosis_pro/modules/core/presentation/core_view_model.dart';
import 'package:vetdosis_pro/modules/hospital/presentation/hospital_calculation_access.dart';
import 'package:vetdosis_pro/modules/hospital/presentation/hospital_dose_patient_screen.dart';
import 'hospital_test.dart' show FakeHospital;
import 'hospital_weight_test.dart' show WeightClinical, entry;
import 'support/fake_auth.dart';
import 'module_navigation_dashboard_test.dart' show contract;

const clinician = ClinicMembership(
  clinicId: 'a',
  clinicName: 'Synthetic',
  userId: 'user-a',
  role: ClinicRole.mvz,
);

class LiveModules implements ModuleAccessRepository {
  bool allowed = true, fail = false;
  int reads = 0;
  Completer<Map<String, dynamic>>? pending;
  @override
  Future<Map<String, dynamic>> workspace(String clinicId) async {
    reads++;
    if (fail) throw StateError('Synthetic unavailable');
    if (pending != null) return pending!.future;
    return contract(enabled: allowed ? 'hospital' : '');
  }
}

void main() {
  late String bundledCatalog;
  setUpAll(() async {
    bundledCatalog = await File(
      'assets/clinical/catalog.v1.json',
    ).readAsString();
  });

  testWidgets(
    'Real CoreShell keeps patient query through refresh and opens the persisted-weight calculator',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'doses.catalog.v1': bundledCatalog,
      });
      tester.view.physicalSize = const Size(600, 1300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeAuth()..rows = [clinician];
      final auth = AuthViewModel(
        repo,
        refreshInterval: const Duration(seconds: 30),
      );
      await auth.start();
      final modules = LiveModules();
      final core = CoreViewModel(SettingsRepository(), const AppSettings());
      core.navigate('Cálculo rápido');
      await tester.pumpWidget(
        VetDosisApp(
          model: core,
          auth: auth,
          moduleAccess: modules,
          hospital: FakeHospital(),
          clinical: WeightClinical()..entries.add(entry()),
        ),
      );
      await tester.pumpAndSettle();
      final choose = find.text('Elegir paciente y peso registrado');
      await tester.ensureVisible(choose);
      await tester.tap(choose);
      await tester.pumpAndSettle();
      expect(find.byType(HospitalDosePatientScreen), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Paciente');
      final originalRevision = auth.accessRevision;
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(auth.accessRevision, greaterThan(originalRevision));
      expect(find.text('Paciente ficticio hospitalizado'), findsOneWidget);
      expect(
        find.textContaining('La sesión o los permisos cambiaron'),
        findsNothing,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        'Paciente',
      );
      await tester.tap(find.text('Paciente ficticio hospitalizado'));
      await tester.pumpAndSettle();
      final reviewWeight = find.text('Revisar peso para cálculo');
      expect(reviewWeight, findsOneWidget);
      await tester.ensureVisible(reviewWeight);
      await tester.tap(reviewWeight);
      await tester.pumpAndSettle();
      expect(find.text('Cálculo con peso registrado'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      core.dispose();
      auth.dispose();
      await repo.controller.close();
    },
  );

  testWidgets('Confirmed module revocation clears the open patient picker', (
    tester,
  ) async {
    final repo = FakeAuth()..rows = [clinician];
    final auth = AuthViewModel(repo);
    await auth.start();
    final modules = LiveModules();
    final access = HospitalCalculationAccess(
      auth: auth,
      member: clinician,
      initialAccess: ModuleAccess.read(contract(enabled: 'hospital')),
      repository: modules,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: HospitalDosePatientScreen(
          hospital: FakeHospital(),
          clinical: WeightClinical(),
          member: clinician,
          contextIsCurrent: () => access.current,
          sessionChanges: access,
          onCalculate: (_, _) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Paciente ficticio hospitalizado'), findsOneWidget);
    modules.allowed = false;
    await auth.refresh(background: true);
    await tester.pumpAndSettle();
    expect(access.current, isFalse);
    expect(find.text('Paciente ficticio hospitalizado'), findsNothing);
    expect(
      find.textContaining('La sesión o los permisos cambiaron'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    access.dispose();
    auth.dispose();
    await repo.controller.close();
  });

  test(
    'A failed or malformed permission recheck denies calculation; stale allowed results cannot restore access',
    () async {
      final repo = FakeAuth()..rows = [clinician];
      final auth = AuthViewModel(repo);
      await auth.start();
      final modules = LiveModules();
      final access = HospitalCalculationAccess(
        auth: auth,
        member: clinician,
        initialAccess: ModuleAccess.read(contract(enabled: 'hospital')),
        repository: modules,
      );
      await access.revalidate();
      modules.pending = Completer();
      final pending = modules.pending!;
      final old = access.revalidate();
      modules.pending = null;
      modules.allowed = false;
      expect(await access.revalidate(), isFalse);
      pending.complete(contract(enabled: 'hospital'));
      expect(await old, isFalse);
      expect(access.current, isFalse);
      modules.allowed = true;
      expect(await access.revalidate(), isTrue);
      modules.fail = true;
      expect(await access.revalidate(), isFalse);
      expect(access.current, isFalse);
      modules.fail = false;
      modules.pending = Completer()..complete({'schema_version': 99});
      expect(await access.revalidate(), isFalse);
      access.dispose();
      auth.dispose();
      await repo.controller.close();
    },
  );

  test(
    'Configured access starts denied until verified and ignores completion after disposal',
    () async {
      final repo = FakeAuth()..rows = [clinician];
      final auth = AuthViewModel(repo);
      await auth.start();
      final modules = LiveModules()..pending = Completer();
      final pending = modules.pending!;
      final access = HospitalCalculationAccess(
        auth: auth,
        member: clinician,
        initialAccess: null,
        repository: modules,
      );
      expect(access.current, isFalse);
      final check = access.revalidate();
      access.dispose();
      pending.complete(contract(enabled: 'hospital'));
      expect(await check, isFalse);
      expect(access.current, isFalse);
      auth.dispose();
      await repo.controller.close();
    },
  );

  for (final outcome in ['allowed', 'revoked', 'error']) {
    test(
      'An overlapping auth refresh resolves the waiting check as $outcome',
      () async {
        final repo = FakeAuth()..rows = [clinician];
        final auth = AuthViewModel(repo);
        await auth.start();
        final modules = LiveModules();
        final access = HospitalCalculationAccess(
          auth: auth,
          member: clinician,
          initialAccess: null,
          repository: modules,
        );
        await access.revalidate();
        final old = Completer<Map<String, dynamic>>();
        modules.pending = old;
        final waiting = access.revalidate();
        final newest = Completer<Map<String, dynamic>>();
        modules.pending = newest;
        await auth.refresh(background: true);
        if (outcome == 'error') {
          newest.completeError(StateError('Synthetic failed latest check'));
        } else {
          newest.complete(
            contract(enabled: outcome == 'allowed' ? 'hospital' : ''),
          );
        }
        // The original RPC is still pending; it must not block the user's check.
        expect(await waiting, outcome == 'allowed');
        expect(access.current, outcome == 'allowed');
        old.complete(contract(enabled: outcome == 'allowed' ? '' : 'hospital'));
        await Future<void>.delayed(Duration.zero);
        expect(access.current, outcome == 'allowed');
        access.dispose();
        auth.dispose();
        await repo.controller.close();
      },
    );
  }

  test('Disposal resolves a waiting check before its RPC completes', () async {
    final repo = FakeAuth()..rows = [clinician];
    final auth = AuthViewModel(repo);
    await auth.start();
    final response = Completer<Map<String, dynamic>>();
    final modules = LiveModules()..pending = response;
    final access = HospitalCalculationAccess(
      auth: auth,
      member: clinician,
      initialAccess: null,
      repository: modules,
    );
    final waiting = access.revalidate();
    access.dispose();
    expect(await waiting, isFalse);
    final reads = modules.reads;
    expect(await access.revalidate(), isFalse);
    expect(modules.reads, reads);
    response.complete(contract(enabled: 'hospital'));
    await Future<void>.delayed(Duration.zero);
    expect(access.current, isFalse);
    auth.dispose();
    await repo.controller.close();
  });

  for (final exit in ['pop', 'signout']) {
    testWidgets('Real patient route owns access through $exit and teardown', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'doses.catalog.v1': bundledCatalog,
      });
      tester.view.physicalSize = const Size(600, 1300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeAuth()..rows = [clinician];
      final auth = AuthViewModel(repo);
      await auth.start();
      final modules = LiveModules();
      final core = CoreViewModel(SettingsRepository(), const AppSettings());
      core.navigate('Cálculo rápido');
      await tester.pumpWidget(
        VetDosisApp(
          model: core,
          auth: auth,
          moduleAccess: modules,
          hospital: FakeHospital(),
          clinical: WeightClinical()..entries.add(entry()),
        ),
      );
      await tester.pumpAndSettle();
      final choose = find.text('Elegir paciente y peso registrado');
      await tester.ensureVisible(choose);
      await tester.tap(choose);
      await tester.pumpAndSettle();
      final picker = find.byType(HospitalDosePatientScreen);
      final access =
          tester.widget<HospitalDosePatientScreen>(picker).sessionChanges!
              as HospitalCalculationAccess;
      if (exit == 'pop') {
        Navigator.of(tester.element(picker)).pop();
        await tester.pump();
        // The push Future has resolved but its route is still animating out.
        expect(picker, findsOneWidget);
        expect(access.current, isTrue);
        expect(await access.revalidate(), isTrue);
        await tester.pump(const Duration(milliseconds: 50));
        expect(
          find.textContaining('La sesión o los permisos cambiaron'),
          findsNothing,
        );
        await tester.pumpAndSettle();
      } else {
        await auth.signOut();
        await tester.pumpAndSettle();
        expect(picker, findsNothing);
        await auth.signIn('synthetic@example.test', 'synthetic-password');
        await tester.pumpAndSettle();
      }
      expect(access.current, isFalse);
      final reads = modules.reads;
      expect(await access.revalidate(), isFalse);
      expect(modules.reads, reads);
      await auth.refresh(background: true);
      // The home boundary reloads on the next frame. A leaked route listener
      // would already have performed an extra RPC synchronously here.
      expect(modules.reads, reads);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      core.dispose();
      auth.dispose();
      await repo.controller.close();
    });
  }

  for (final change in ['clinic', 'role', 'user', 'offline', 'membership']) {
    test('Live $change change invalidates patient/weight context', () async {
      final repo = FakeAuth()..rows = [clinician];
      final auth = AuthViewModel(repo);
      await auth.start();
      final access = HospitalCalculationAccess(
        auth: auth,
        member: clinician,
        initialAccess: null,
      );
      expect(access.current, isTrue);
      switch (change) {
        case 'clinic':
          auth.active = const ClinicMembership(
            clinicId: 'b',
            clinicName: 'B',
            userId: 'user-a',
            role: ClinicRole.mvz,
          );
        case 'role':
          auth.active = const ClinicMembership(
            clinicId: 'a',
            clinicName: 'A',
            userId: 'user-a',
            role: ClinicRole.auxiliar,
          );
        case 'user':
          repo.userId = 'other-user';
        case 'offline':
          auth.offline = true;
        case 'membership':
          repo.rows = [];
          await auth.refresh(background: true);
      }
      expect(access.current, isFalse);
      expect(await access.revalidate(), isFalse);
      access.dispose();
      auth.dispose();
      await repo.controller.close();
    });
  }
}

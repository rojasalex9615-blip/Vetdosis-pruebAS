import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';
import 'package:vetdosis_pro/modules/auth/presentation/auth_view_model.dart';
import 'support/fake_auth.dart';

const clinicB = ClinicMembership(
  clinicId: 'b',
  clinicName: 'Clínica B',
  userId: 'user-a',
  role: ClinicRole.mvz,
);

void main() {
  late FakeAuth repository;
  late AuthViewModel model;

  setUp(() {
    repository = FakeAuth()..rows = [member, clinicB];
    model = AuthViewModel(repository);
  });

  tearDown(() async {
    model.dispose();
    await repository.controller.close();
  });

  test('Una cuenta puede cambiar entre clínicas con roles distintos', () async {
    await model.start();
    expect(model.memberships.length, 2);
    expect(model.active?.clinicId, 'a');
    model.selectClinic(clinicB);
    expect(model.active?.clinicId, 'b');
    expect(model.active?.role, ClinicRole.mvz);
    model.selectClinic(member);
    expect(model.active?.role, ClinicRole.auxiliar);
  });

  test('Una membresía ajena no puede activarse', () async {
    await model.start();
    const outsider = ClinicMembership(
      clinicId: 'c', clinicName: 'Clínica C',
      userId: 'user-other', role: ClinicRole.admin,
    );
    model.selectClinic(outsider);
    expect(model.active?.clinicId, 'a');
  });

  test('Revocación en actualización elimina clínica activa', () async {
    await model.start();
    model.selectClinic(clinicB);
    repository.rows = [member];
    await model.refresh(background: true);
    expect(model.memberships.map((m) => m.clinicId), ['a']);
    expect(model.active?.clinicId, 'a');
  });

  test('Respuesta antigua no restaura una membresía revocada', () async {
    await model.start();
    final oldResult = Completer<List<ClinicMembership>>();
    repository.pending = oldResult;
    final oldRefresh = model.refresh(background: true);
    repository.pending = null;
    repository.rows = [member];
    await model.refresh(background: true);
    oldResult.complete([member, clinicB]);
    await oldRefresh;
    expect(model.memberships.map((m) => m.clinicId), ['a']);
    expect(model.active?.clinicId, 'a');
  });

  test('Respuesta tardía no revierte clínica elegida durante lectura', () async {
    await model.start();
    final pending = Completer<List<ClinicMembership>>();
    repository.pending = pending;
    final refresh = model.refresh(background: true);
    model.selectClinic(clinicB);
    pending.complete([member, clinicB]);
    await refresh;
    expect(model.active?.clinicId, 'b');
  });
  test('Cambio durante lectura no conserva clínica revocada', () async {
    await model.start();
    final pending = Completer<List<ClinicMembership>>();
    repository.pending = pending;
    final refresh = model.refresh(background: true);
    model.selectClinic(clinicB);
    pending.complete([member]);
    await refresh;
    expect(model.active?.clinicId, 'a');
    expect(model.memberships.map((m) => m.clinicId), ['a']);
  });

}

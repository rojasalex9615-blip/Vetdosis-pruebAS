import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';
import 'package:vetdosis_pro/modules/clinic_experience/domain/clinic_experience.dart';
import 'package:vetdosis_pro/modules/clinic_experience/domain/clinic_experience_repository.dart';
import 'package:vetdosis_pro/modules/clinic_experience/presentation/clinic_experience_screen.dart';
import 'package:vetdosis_pro/modules/clinic_experience/presentation/clinic_experience_boundary.dart';

class FakeExperienceRepository implements ClinicExperienceRepository {
  ClinicExperience stored = ClinicExperience.defaults();
  int saves = 0;
  int reads = 0;
  bool failReads = false;
  bool failSaves = false;

  @override
  Future<ClinicExperience> read(String clinicId) async {
    reads++;
    if (failReads) throw StateError('Synthetic network error');
    return stored;
  }

  @override
  Future<ClinicExperience> save(String clinicId, ClinicExperience value) async {
    if (failSaves) throw const FormatException('Synthetic write conflict');
    if (value.revision != stored.revision) {
      throw const FormatException('Conflicto de revisión');
    }
    saves++;
    stored = value.copy(revision: stored.revision + 1);
    return stored;
  }
}

const administrator = ClinicMembership(
  clinicId: 'test-clinic',
  clinicName: 'Clínica de ensayo',
  userId: 'admin',
  role: ClinicRole.admin,
);

void main() {
  test('general shows all and protected routes cannot be hidden', () {
    final config = ClinicExperience.defaults();
    expect(config.visible('Hospitalización'), true);
    expect(config.withPage('Ajustes', false).visible('Ajustes'), true);
    expect(config.withPage('Modo revisión', false).visible('Modo revisión'), true);
    expect(config.withPage('Hospitalización', false).visible('Hospitalización'), false);
    expect(config.withPage('Hospitalización', false).visible('Pacientes'), true);
  });

  test('presets differ without changing permissions or saved workflow choices', () {
    final custom = ClinicExperience.defaults()
        .withFlow('dose', ClinicalFlowMode.free)
        .copy(
          defaultAiProvider: 'openai',
          hospitalNoticeDelivery: HospitalNoticeDelivery.both,
        );
    final hospital = ClinicExperience.forPreset(ClinicPreset.hospital, previous: custom);
    final production = ClinicExperience.forPreset(ClinicPreset.production, previous: custom);
    expect(hospital.visible('Hospitalización'), true);
    expect(production.visible('Hospitalización'), false);
    expect(production.visible('Producción y grandes especies'), true);
    expect(hospital.visible('Producción y grandes especies'), false);
    expect(hospital.flow('dose'), ClinicalFlowMode.free);
    expect(production.defaultAiProvider, 'openai');
    expect(production.hospitalNoticeDelivery, HospitalNoticeDelivery.both);
    expect(hospital.hospitalNoticeDelivery, HospitalNoticeDelivery.both);
  });

  test('versions and unknown values fail closed instead of hiding routes', () {
    final settings = ClinicExperience.defaults().toJson();
    final data = <String, dynamic>{
      'schema_version': 1, 'revision': 3, 'settings': settings,
    };
    expect(ClinicExperience.fromServer(data).revision, 3);
    expect(() => ClinicExperience.fromServer({...data, 'schema_version': 99}),
        throwsFormatException);
    final unknown = {...settings, 'hidden_pages': ['Administer other tenant']};
    expect(() => ClinicExperience.fromServer({...data, 'settings': unknown}),
        throwsFormatException);
    final unsafe = {...settings, 'default_ai_provider': 'service_role'};
    expect(() => ClinicExperience.fromServer({...data, 'settings': unsafe}),
        throwsFormatException);
    final wrongChannel = {...settings, 'hospital_notice_delivery': 'automatic_bypass'};
    expect(() => ClinicExperience.fromServer({...data, 'settings': wrongChannel}),
        throwsFormatException);
    final wrongShape = {...settings, 'hospital_notice_delivery': <String, bool>{'phone': true}};
    expect(() => ClinicExperience.fromServer({...data, 'settings': wrongShape}),
        throwsFormatException);
    final duplicates = {...settings, 'hidden_pages': ['Agenda', 'Agenda']};
    expect(() => ClinicExperience.fromServer({...data, 'settings': duplicates}),
        throwsFormatException);
  });

  test('round-trip keeps submodules, workflow and provider; never stores keys', () {
    final a = ClinicExperience.defaults()
      .withPage('Inventario', false)
      .withFlow('dose', ClinicalFlowMode.mandatory)
      .copy(
        defaultAiProvider: 'google',
        hospitalNoticeDelivery: HospitalNoticeDelivery.whatsapp,
      );
    final wire = a.toJson();
    expect(wire.keys, containsAll([
      'preset', 'hidden_pages', 'workflow_modes', 'default_ai_provider',
      'hospital_notice_delivery',
    ]));
    expect(wire.toString().contains('API_KEY'), false);
    final b = ClinicExperience.fromServer({
      'schema_version': 1, 'revision': 8, 'settings': wire,
    });
    expect(b.visible('Inventario'), false);
    expect(b.flow('dose'), ClinicalFlowMode.mandatory);
    expect(b.defaultAiProvider, 'google');
    expect(b.hospitalNoticeDelivery, HospitalNoticeDelivery.whatsapp);
    expect(b.hospitalNoticeDelivery.phoneSelected, isFalse);
    expect(b.hospitalNoticeDelivery.whatsappSelected, isTrue);
    expect(b.revision, 8);
  });

  test('default channel stays on device and old saved profile loads safely', () {
    final defaults = ClinicExperience.defaults();
    expect(defaults.hospitalNoticeDelivery, HospitalNoticeDelivery.phone);
    expect(defaults.hospitalNoticeDelivery.phoneSelected, isTrue);
    expect(defaults.hospitalNoticeDelivery.whatsappSelected, isFalse);
    final legacy = defaults.toJson()..remove('hospital_notice_delivery');
    final restored = ClinicExperience.fromServer({
      'schema_version': 1, 'revision': 2, 'settings': legacy,
    });
    expect(restored.hospitalNoticeDelivery, HospitalNoticeDelivery.phone);
    final both = restored.copy(hospitalNoticeDelivery: HospitalNoticeDelivery.both);
    expect(both.hospitalNoticeDelivery.phoneSelected, isTrue);
    expect(both.hospitalNoticeDelivery.whatsappSelected, isTrue);
    expect(both.toJson().containsKey('phone_number'), false);
  });

  test('selecting Personalizado preserves previous module choices', () {
    final original = ClinicExperience.defaults()
      .withPage('Hospitalización', false)
      .withPage('Inventario', false)
      .withFlow('dose', ClinicalFlowMode.mandatory)
      .copy(
        revision: 6,
        defaultAiProvider: 'google',
        hospitalNoticeDelivery: HospitalNoticeDelivery.both,
      );
    final custom = ClinicExperience.forPreset(
      ClinicPreset.custom, previous: original,
    );
    expect(custom.hiddenPages, original.hiddenPages);
    expect(custom.visible('Hospitalización'), isFalse);
    expect(custom.visible('Inventario'), isFalse);
    expect(custom.flow('dose'), ClinicalFlowMode.mandatory);
    expect(custom.revision, 6);
    expect(custom.defaultAiProvider, 'google');
    expect(custom.hospitalNoticeDelivery, HospitalNoticeDelivery.both);
  });

  testWidgets('saving conflict waits for readback before showing error', (tester) async {
    final repo = FakeExperienceRepository()..failSaves = true;
    var callbackCompleted = false;
    await tester.pumpWidget(MaterialApp(home: ClinicExperienceScreen(
      member: administrator,
      initial: repo.stored,
      repository: repo,
      ready: true,
      onSaved: () async {
        await repo.read(administrator.clinicId);
        callbackCompleted = true;
      },
    )));
    final saveButton = find.text('Guardar configuración de la clínica');
    await tester.scrollUntilVisible(
      saveButton, 240, scrollable: find.byType(Scrollable).first,
    );
    // Keep the button away from the bottom viewport boundary in test layouts.
    await Scrollable.ensureVisible(
      tester.element(saveButton),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(callbackCompleted, isTrue);
    expect(repo.reads, 1);
    expect(repo.saves, 0);
    expect(find.textContaining('No se pudo guardar.'), findsOneWidget);
  });

  test('restoring a module only restores visibility, never operational records', () {
    final original = ClinicExperience.defaults()
      .withPage('Hospitalización', false)
      .withPage('Agenda', false)
      .withPage('Inventario', false)
      .withFlow('dose', ClinicalFlowMode.mandatory)
      .copy(
        defaultAiProvider: 'anthropic',
        hospitalNoticeDelivery: HospitalNoticeDelivery.both,
        revision: 4,
      );
    final restored = original.restoreModuleVisibility('Atención y expedientes');
    expect(restored.visible('Hospitalización'), isTrue);
    expect(restored.visible('Agenda'), isTrue);
    expect(restored.visible('Inventario'), isFalse);
    expect(restored.flow('dose'), ClinicalFlowMode.mandatory);
    expect(restored.defaultAiProvider, 'anthropic');
    expect(restored.hospitalNoticeDelivery, HospitalNoticeDelivery.both);
    expect(restored.revision, 4); // Optimistic-lock revision stays intact.
    expect(restored.preset, ClinicPreset.custom);
    expect(original.visible('Hospitalización'), isFalse); // Immutable original.
    expect(
      restored.restoreModuleVisibility('Grupo desconocido').toJson(),
      restored.toJson(),
    );
  });

  test('reset workflow restores guided default without touching other settings', () {
    final custom = ClinicExperience.defaults()
        .withFlow('dose', ClinicalFlowMode.mandatory)
        .withFlow('hospital', ClinicalFlowMode.free)
        .withPage('Inventario', false);
    final doseRestored = custom.restoreFlowDefault('dose');
    expect(doseRestored.flow('dose'), ClinicalFlowMode.guided);
    expect(doseRestored.flow('hospital'), ClinicalFlowMode.free);
    expect(doseRestored.visible('Inventario'), isFalse);
    expect(doseRestored.toJson()['workflow_modes'], {'hospital': 'free'});
    expect(custom.flow('dose'), ClinicalFlowMode.mandatory);
    expect(
      custom.restoreFlowDefault('unrecognized').toJson(),
      custom.toJson(),
    );
  });

  testWidgets('module reset button saves only requested visibility', (tester) async {
    final repo = FakeExperienceRepository();
    repo.stored = repo.stored
        .withPage('Agenda', false)
        .withPage('Hospitalización', false)
        .withPage('Inventario', false);
    await tester.pumpWidget(MaterialApp(home: ClinicExperienceScreen(
      member: administrator,
      initial: repo.stored,
      repository: repo,
      ready: true,
    )));
    final group = find.text('Atención y expedientes');
    await tester.scrollUntilVisible(
      group, 220, scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(group);
    await tester.pumpAndSettle();
    final reset = find.text('Restablecer este módulo');
    await tester.scrollUntilVisible(
      reset, 170, scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(repo.saves, 0); // Do not persist without explicit save.
    final save = find.text('Guardar configuración de la clínica');
    await tester.scrollUntilVisible(
      save, 250, scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repo.saves, 1);
    expect(repo.stored.visible('Agenda'), isTrue);
    expect(repo.stored.visible('Hospitalización'), isTrue);
    expect(repo.stored.visible('Inventario'), isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('failed post-save reload keeps hidden pages and reports failure', (tester) async {
    final repo = FakeExperienceRepository();
    repo.stored = repo.stored.withPage('Hospitalización', false);
    late Future<void> Function() refresh;
    await tester.pumpWidget(MaterialApp(home: ClinicExperienceBoundary(
      member: administrator, repository: repo, revision: 0,
      builder: (experience, ready, reload) {
        refresh = reload;
        return Text('${ready ? "ready" : "waiting"}:${experience.visible("Hospitalización")}');
      },
    )));
    await tester.pumpAndSettle();
    expect(find.text('ready:false'), findsOneWidget);
    repo.failReads = true;
    await expectLater(refresh(), throwsStateError);
    await tester.pump();
    expect(find.text('ready:false'), findsOneWidget);
    repo.failReads = false;
    repo.stored = repo.stored.withPage('Hospitalización', true);
    await refresh();
    await tester.pump();
    expect(find.text('ready:true'), findsOneWidget);
  });

  testWidgets('background permission refresh keeps preferences; clinic switch resets', (
    tester,
  ) async {
    final repo = FakeExperienceRepository();
    repo.stored = repo.stored.withPage('Hospitalización', false);
    Widget show(ClinicMembership membership, int revision) => MaterialApp(
      home: ClinicExperienceBoundary(
        member: membership,
        repository: repo,
        revision: revision,
        builder: (experience, ready, reload) => Text(
          '${ready ? 'ready' : 'waiting'}:'
          '${experience.visible('Hospitalización')}',
          textDirection: TextDirection.ltr,
        ),
      ),
    );

    await tester.pumpWidget(show(administrator, 0));
    await tester.pumpAndSettle();
    expect(find.text('ready:false'), findsOneWidget);

    // A background refresh failure must not reveal previously hidden pages.
    repo.failReads = true;
    await tester.pumpWidget(show(administrator, 1));
    await tester.pumpAndSettle();
    expect(find.text('ready:false'), findsOneWidget);

    // Different clinic identity is never allowed to reuse stale preferences.
    await tester.pumpWidget(show(const ClinicMembership(
      clinicId: 'other-clinic',
      clinicName: 'Otra clínica',
      userId: 'admin',
      role: ClinicRole.admin,
    ), 2));
    await tester.pumpAndSettle();
    expect(find.text('waiting:true'), findsOneWidget);
  });

  testWidgets('admin can save preferences and non-admin cannot', (tester) async {
    final repo = FakeExperienceRepository();
    await tester.pumpWidget(MaterialApp(home: ClinicExperienceScreen(
      member: administrator,
      initial: repo.stored,
      repository: repo,
      ready: true,
    )));
    expect(find.text('Personalización de clínica'), findsOneWidget);
    final button = find.text('Guardar configuración de la clínica');
    await tester.scrollUntilVisible(
      button, 220, scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(repo.saves, 1);
    await tester.pumpWidget(MaterialApp(home: ClinicExperienceScreen(
      member: const ClinicMembership(
        clinicId: 'test-clinic', clinicName: 'Clínica de ensayo',
        userId: 'aux', role: ClinicRole.auxiliar,
      ),
      initial: repo.stored,
      repository: repo,
      ready: true,
    )));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Guardar configuración de la clínica'), 220,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<FilledButton>(find.widgetWithText(
      FilledButton, 'Guardar configuración de la clínica',
    )).onPressed, isNull);
  });
}

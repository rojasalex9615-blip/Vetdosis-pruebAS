import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';
import 'package:vetdosis_pro/modules/clinic_experience/domain/clinic_experience.dart';
import 'package:vetdosis_pro/modules/clinic_experience/domain/clinic_experience_repository.dart';
import 'package:vetdosis_pro/modules/clinic_experience/presentation/clinic_experience_screen.dart';

class FakeExperienceRepository implements ClinicExperienceRepository {
  ClinicExperience stored = ClinicExperience.defaults();
  int saves = 0;

  @override
  Future<ClinicExperience> read(String clinicId) async => stored;

  @override
  Future<ClinicExperience> save(String clinicId, ClinicExperience value) async {
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
        .copy(defaultAiProvider: 'openai');
    final hospital = ClinicExperience.forPreset(ClinicPreset.hospital, previous: custom);
    final production = ClinicExperience.forPreset(ClinicPreset.production, previous: custom);
    expect(hospital.visible('Hospitalización'), true);
    expect(production.visible('Hospitalización'), false);
    expect(production.visible('Producción y grandes especies'), true);
    expect(hospital.visible('Producción y grandes especies'), false);
    expect(hospital.flow('dose'), ClinicalFlowMode.free);
    expect(production.defaultAiProvider, 'openai');
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
    final duplicates = {...settings, 'hidden_pages': ['Agenda', 'Agenda']};
    expect(() => ClinicExperience.fromServer({...data, 'settings': duplicates}),
        throwsFormatException);
  });

  test('round-trip keeps submodules, workflow and provider; never stores keys', () {
    final a = ClinicExperience.defaults()
      .withPage('Inventario', false)
      .withFlow('dose', ClinicalFlowMode.mandatory)
      .copy(defaultAiProvider: 'google');
    final wire = a.toJson();
    expect(wire.keys, containsAll([
      'preset', 'hidden_pages', 'workflow_modes', 'default_ai_provider',
    ]));
    expect(wire.toString().contains('API_KEY'), false);
    final b = ClinicExperience.fromServer({
      'schema_version': 1, 'revision': 8, 'settings': wire,
    });
    expect(b.visible('Inventario'), false);
    expect(b.flow('dose'), ClinicalFlowMode.mandatory);
    expect(b.defaultAiProvider, 'google');
    expect(b.revision, 8);
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

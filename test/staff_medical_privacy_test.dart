import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';
import 'package:vetdosis_pro/modules/operations/domain/operations_repository.dart';
import 'package:vetdosis_pro/modules/operations/presentation/staff_medical_screen.dart';

const person = ClinicMembership(
  clinicId: 'clinic',
  clinicName: 'Clinic',
  userId: 'person',
  role: ClinicRole.admin,
);

class MedicalRepository implements StaffMedicalRepository {
  Map<String, dynamic>? profile = {
    'details': {'allergies': 'PRIVATE-HEALTH'},
    'consent_current': true,
  };
  int revision = 1, views = 0, directories = 0;
  bool canTeam = false, lost = false, denyView = false;
  String? actorOverride;
  Completer<Map<String, dynamic>>? pending;
  final writes = <Map<String, dynamic>>[];
  final applied = <String>{};
  @override
  Future<Map<String, dynamic>> staffMedicalWorkspace(
    String clinic,
    String actor,
  ) async {
    if (pending != null && clinic == 'clinic') return pending!.future;
    return {
      'schema_version': 1,
      'clinic_id': clinic,
      'actor_id': actorOverride ?? actor,
      'member_since': '2026-10-27T00:00:00Z',
      'revision': revision,
      'notice': {
        'version': 1,
        'text': 'Aviso ficticio para emergencia. Puedes retirar sin aceptar.',
        'hash': 'a' * 64,
      },
      'profile': profile == null
          ? null
          : {
              ...profile!,
              'details': Map<String, dynamic>.from(profile!['details'] as Map),
            },
      'can_team_read': canTeam,
      'accesses': [],
      'events': [],
    };
  }

  @override
  Future<void> staffMedicalWrite(Map<String, dynamic> args) async {
    writes.add(Map.from(args));
    if (applied.add(args['p_operation'] as String)) {
      revision++;
      profile = args['p_action'] == 'withdraw'
          ? null
          : {'details': args['p_details'], 'consent_current': true};
      if (lost) {
        lost = false;
        throw StateError('Synthetic lost response');
      }
    }
  }

  @override
  Future<Map<String, dynamic>> staffMedicalDirectory(
    String clinic,
    String actor, {
    int offset = 0,
  }) async {
    directories++;
    return {
      'schema_version': 1,
      'clinic_id': clinic,
      'actor_id': actor,
      'items': [
        {'user_id': 'worker', 'display_name': 'Integrante ficticio'},
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> staffMedicalView(
    String clinic,
    String actor,
    String subject,
    String purpose,
  ) async {
    views++;
    if (denyView) throw StateError('staff_medical_profile_unavailable');
    return {
      'schema_version': 1,
      'clinic_id': clinic,
      'actor_id': actor,
      'subject_id': subject,
      'access_id': 'access',
      'details': {'allergies': 'COWORKER-PRIVATE'},
    };
  }
}

Widget app(MedicalRepository repo, {ClinicMembership member = person}) =>
    MaterialApp(
      home: StaffMedicalScreen(repository: repo, member: member),
    );
Future<void> roomy(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Finder field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);
Future<void> auditedConsult(WidgetTester tester) async {
  await tester.tap(find.text('Consultar ficha'));
  await tester.pumpAndSettle();
  expect(
    tester
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Consultar y registrar acceso'),
        )
        .onPressed,
    isNull,
  );
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Emergencia').last);
  await tester.pumpAndSettle();
  await tester.tap(
    find.text('Confirmo esta finalidad y el registro de mi acceso'),
  );
  await tester.pump();
  await tester.tap(find.text('Consultar y registrar acceso'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'hidden withdrawal confirmation reports that no request was sent',
    (tester) async {
      await roomy(tester);
      final repo = MedicalRepository();
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.text('Retirar mi ficha y consentimiento'),
      );
      await tester.tap(find.text('Retirar mi ficha y consentimiento'));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      await tester.tap(find.text('Confirmar retirada'));
      await tester.pumpAndSettle();
      expect(repo.writes, isEmpty);
      expect(
        find.textContaining('Revisa tu ficha y repite la retirada'),
        findsOneWidget,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'withdrawal is independent of acceptance and never opens coworker data',
    (tester) async {
      await roomy(tester);
      final repo = MedicalRepository();
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        false,
      );
      await tester.ensureVisible(
        find.text('Retirar mi ficha y consentimiento'),
      );
      await tester.tap(find.text('Retirar mi ficha y consentimiento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar retirada'));
      await tester.pumpAndSettle();
      expect(repo.writes.single['p_action'], 'withdraw');
      expect(repo.writes.single['p_consent'], false);
      expect(repo.writes.single['p_details'], isNull);
      expect(repo.writes.single['p_notice_hash'], isNull);
      expect(repo.directories, 0);
      expect(repo.views, 0);
      expect(find.text('Retirar mi ficha y consentimiento'), findsNothing);
    },
  );
  testWidgets(
    'save is explicit and retry preserves receipt across equivalent input',
    (tester) async {
      await roomy(tester);
      final repo = MedicalRepository()..lost = true;
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(
                FilledButton,
                'Guardar con mi consentimiento',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(field('Alergias'), 'UPDATED-PRIVATE');
      await tester.pump();
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.text('Guardar con mi consentimiento'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(field('Alergias'));
      await tester.enterText(field('Alergias'), ' UPDATED-PRIVATE ');
      await tester.pump();
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.text('Guardar con mi consentimiento'));
      await tester.pumpAndSettle();
      expect(repo.writes.length, 2);
      expect(repo.writes[0]['p_operation'], repo.writes[1]['p_operation']);
      expect(repo.writes[0]['p_notice_version'], 1);
      expect(repo.writes[0]['p_consent'], true);
      expect(repo.writes[0]['p_actor'], 'person');
      expect(repo.applied.length, 1);
      expect(repo.views, 0);
    },
  );
  testWidgets(
    'wrong actor response is discarded before rendering health data',
    (tester) async {
      final repo = MedicalRepository()..actorOverride = 'other';
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      expect(find.textContaining('PRIVATE-HEALTH'), findsNothing);
      expect(find.text('Guardar con mi consentimiento'), findsNothing);
    },
  );
  testWidgets('scope switch discards a late response from the old clinic', (
    tester,
  ) async {
    final repo = MedicalRepository()..pending = Completer();
    await tester.pumpWidget(app(repo));
    await tester.pump();
    await tester.pumpWidget(
      app(
        repo,
        member: const ClinicMembership(
          clinicId: 'new-clinic',
          clinicName: 'New',
          userId: 'new-person',
          role: ClinicRole.auxiliar,
        ),
      ),
    );
    await tester.pumpAndSettle();
    repo.pending!.complete({
      'schema_version': 1,
      'clinic_id': 'clinic',
      'actor_id': 'person',
      'profile': {
        'details': {'allergies': 'OLD-CLINIC-PRIVATE'},
      },
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('OLD-CLINIC-PRIVATE'), findsNothing);
    expect(repo.writes, isEmpty);
  });
  testWidgets(
    'team directory contains no health details and read requires purpose',
    (tester) async {
      await roomy(tester);
      final repo = MedicalRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: StaffMedicalTeamScreen(repository: repo, member: person),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('COWORKER-PRIVATE'), findsNothing);
      expect(repo.views, 0);
      await auditedConsult(tester);
      expect(find.textContaining('COWORKER-PRIVATE'), findsOneWidget);
      expect(repo.views, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(find.textContaining('COWORKER-PRIVATE'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(repo.views, 1);
      expect(find.textContaining('COWORKER-PRIVATE'), findsNothing);
    },
  );
  testWidgets(
    'withdrawn coworker profile is never shown from a stale directory',
    (tester) async {
      await roomy(tester);
      final repo = MedicalRepository()..denyView = true;
      await tester.pumpWidget(
        MaterialApp(
          home: StaffMedicalTeamScreen(repository: repo, member: person),
        ),
      );
      await tester.pumpAndSettle();
      await auditedConsult(tester);
      expect(find.textContaining('COWORKER-PRIVATE'), findsNothing);
      expect(find.textContaining('La ficha se retiró'), findsOneWidget);
    },
  );
  testWidgets('own medical fields clear when application goes inactive', (
    tester,
  ) async {
    await roomy(tester);
    final repo = MedicalRepository();
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(field('Alergias')).controller!.text,
      'PRIVATE-HEALTH',
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(find.textContaining('PRIVATE-HEALTH'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(repo.writes, isEmpty);
  });
}

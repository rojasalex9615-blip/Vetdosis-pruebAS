import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/auth/domain/auth_repository.dart';
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';
import 'package:vetdosis_pro/modules/auth/presentation/auth_screen.dart';
import 'package:vetdosis_pro/modules/auth/presentation/auth_view_model.dart';
import 'package:vetdosis_pro/modules/operations/domain/operations_repository.dart';
import 'package:vetdosis_pro/modules/operations/presentation/staff_medical_screen.dart';
import 'package:vetdosis_pro/modules/personal_space/domain/personal_space.dart';
import 'package:vetdosis_pro/modules/personal_space/presentation/personal_space_screen.dart';

import 'support/fake_auth.dart';

const personalWorkspace = ClinicMembership(
  clinicId: 'p',
  clinicName: 'Mi espacio personal',
  userId: 'user-a',
  role: ClinicRole.admin,
  workspaceKind: 'personal',
);

class _Auth extends FakeAuth implements PersonalWorkspaceRepository {
  _Auth(this.hasPersonal);
  bool hasPersonal;
  int creates = 0;
  @override
  Future<void> createPersonalWorkspace() async {
    creates++;
    hasPersonal = true;
  }

  @override
  Future<List<ClinicMembership>> memberships() async => [
    member,
    if (hasPersonal) personalWorkspace,
  ];
}

class _Space implements PersonalSpaceRepository {
  final items = <PersonalNote>[];
  final week = <WorkSchedule>[];
  int next = 0;
  @override
  Future<List<PersonalNote>> notes() async => List.of(items);
  @override
  Future<void> saveNote(PersonalNote note) async {
    final saved = PersonalNote(
      id: note.id ?? 'n${next++}',
      title: note.title,
      body: note.body,
      reminder: note.reminder,
      remindAt: note.remindAt,
      done: note.done,
    );
    items.removeWhere((n) => n.id == saved.id);
    items.add(saved);
  }

  @override
  Future<void> deleteNote(String id) async =>
      items.removeWhere((n) => n.id == id);
  @override
  Future<List<WorkSchedule>> schedules() async => sortedWeek(week);
  @override
  Future<void> saveSchedule(WorkSchedule s) async {
    week.removeWhere((w) => w.id != null && w.id == s.id);
    week.add(
      WorkSchedule(
        id: s.id ?? 's${next++}',
        place: s.place,
        clinicId: s.clinicId,
        weekday: s.weekday,
        startMinutes: s.startMinutes,
        endMinutes: s.endMinutes,
        note: s.note,
      ),
    );
  }

  @override
  Future<void> deleteSchedule(String id) async =>
      week.removeWhere((w) => w.id == id);
}

class _Medical
    implements StaffMedicalRepository, StaffMedicalSharingRepository {
  final delegated = <String>{};
  final views = <String>[];
  final sets = <(String, bool)>[];
  Map<String, dynamic> scope(String clinic, String actor) => {
    'schema_version': 1,
    'clinic_id': clinic,
    'actor_id': actor,
  };
  @override
  Future<Map<String, dynamic>> staffMedicalWorkspace(
    String clinic,
    String actor,
  ) async => {
    ...scope(clinic, actor),
    'member_since': '2026-10-27T00:00:00Z',
    'revision': 1,
    'notice': {'version': 2, 'text': 'Aviso ficticio.', 'hash': 'b' * 64},
    'profile': {
      'details': {'blood': 'O+'},
      'consent_current': true,
    },
    'can_team_read': false,
    'accesses': [],
    'events': [],
  };
  @override
  Future<void> staffMedicalWrite(Map<String, dynamic> parameters) async {}
  @override
  Future<Map<String, dynamic>> staffMedicalDirectory(
    String clinic,
    String actor, {
    int offset = 0,
  }) async => {...scope(clinic, actor), 'items': []};
  @override
  Future<Map<String, dynamic>> staffMedicalView(
    String clinic,
    String actor,
    String subject,
    String purpose,
  ) async => throw StateError('not used');
  @override
  Future<Map<String, dynamic>> staffMedicalDelegates(
    String clinic,
    String actor,
  ) async => {
    ...scope(clinic, actor),
    'colleagues': [
      {
        'user_id': 'colega',
        'display_name': 'Colega Uno',
        'delegated': delegated.contains('colega'),
      },
    ],
    'shared_with_me': [
      {'user_id': 'otra', 'display_name': 'Otra Persona', 'available': true},
    ],
  };
  @override
  Future<void> staffMedicalDelegateSet(
    String clinic,
    String actor,
    String delegate,
    bool enabled,
  ) async {
    sets.add((delegate, enabled));
    enabled ? delegated.add(delegate) : delegated.remove(delegate);
  }

  @override
  Future<Map<String, dynamic>> staffMedicalDelegateView(
    String clinic,
    String actor,
    String subject,
    String purpose,
  ) async {
    views.add('$subject:$purpose');
    return {
      ...scope(clinic, actor),
      'subject_id': subject,
      'access_id': 'acc',
      'details': {'drug_allergies': 'Penicilina'},
    };
  }

  @override
  Future<Map<String, dynamic>> staffMedicalAccessLog(
    String clinic,
    String actor,
  ) async => {
    ...scope(clinic, actor),
    'scope': 'own',
    'items': [
      {
        'id': 'x',
        'created_at': '2026-11-12T10:00:00Z',
        'purpose': 'emergency',
        'via': 'delegate',
        'actor_name': 'Colega Uno',
        'subject_name': 'Yo',
      },
    ],
  };
}

void main() {
  testWidgets(
    'Mi cuenta muestra un solo «Mi espacio personal» y abre la pantalla sin cambiar de área',
    (tester) async {
      final repo = _Auth(true);
      final model = AuthViewModel(repo);
      await model.start();
      final active = model.active;
      await tester.pumpWidget(
        MaterialApp(
          home: ClinicAccountScreen(
            model: model,
            personalSpaceBuilder: (_) => PersonalSpaceScreen(
              memberships: model.memberships,
              repository: _Space(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mi espacio personal'), findsOneWidget);
      // La fila del area de trabajo ya no repite el nombre del servidor.
      expect(find.text('Área de trabajo personal'), findsOneWidget);
      expect(find.text('Crear mi área de trabajo personal'), findsNothing);
      await tester.tap(find.text('Mi espacio personal'));
      await tester.pumpAndSettle();
      expect(find.text('Notas'), findsOneWidget);
      expect(find.text('Emergencia'), findsOneWidget);
      expect(repo.creates, 0);
      expect(model.active, active);
      model.dispose();
      await repo.controller.close();
    },
  );

  testWidgets('Sin área de trabajo personal se ofrece crearla', (tester) async {
    final repo = _Auth(false);
    final model = AuthViewModel(repo);
    await model.start();
    await tester.pumpWidget(
      MaterialApp(home: ClinicAccountScreen(model: model)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Crear mi área de trabajo personal'), findsOneWidget);
    model.dispose();
    await repo.controller.close();
  });

  testWidgets('Notas, recordatorios y horarios se guardan en mi cuenta', (
    tester,
  ) async {
    final space = _Space();
    await space.saveNote(
      PersonalNote(
        title: 'Pagar colegiatura',
        reminder: true,
        remindAt: DateTime(2026, 11, 1, 9),
      ),
    );
    await space.saveSchedule(
      const WorkSchedule(
        place: 'Clínica A',
        clinicId: 'a',
        weekday: 6,
        startMinutes: 20 * 60,
        endMinutes: 8 * 60,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PersonalSpaceScreen(
          memberships: const [member, personalWorkspace],
          repository: space,
          now: () => DateTime(2026, 11, 12),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nueva nota'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Título'), 'Idea');
    await tester.enterText(find.widgetWithText(TextField, 'Detalle'), 'Texto');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Idea'), findsOneWidget);
    expect(space.items.where((n) => !n.reminder).single.body, 'Texto');

    await tester.tap(find.text('Recordatorios'));
    await tester.pumpAndSettle();
    expect(find.textContaining('vencido'), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(space.items.where((n) => n.reminder).single.done, isTrue);

    await tester.tap(find.text('Horarios'));
    await tester.pumpAndSettle();
    expect(find.text('Sábado'), findsOneWidget);
    expect(find.textContaining('20:00–08:00 (día siguiente)'), findsOneWidget);

    await tester.tap(find.text('Emergencia'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('requiere conexión al servidor'),
      findsOneWidget,
    );
  });

  testWidgets(
    'La ficha deja elegir compañeros, consultar lo compartido y ver quién accedió',
    (tester) async {
      final medical = _Medical();
      await tester.pumpWidget(
        MaterialApp(
          home: StaffMedicalScreen(repository: medical, member: member),
        ),
      );
      await tester.pumpAndSettle();
      final list = find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first;
      expect(
        find.widgetWithText(TextField, 'Fármacos a los que soy alérgico/a'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byType(Switch),
        150,
        scrollable: list,
      );
      await tester.ensureVisible(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(medical.sets, [('colega', true)]);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

      await tester.scrollUntilVisible(
        find.text('Consultar'),
        150,
        scrollable: list,
      );
      await tester.ensureVisible(find.text('Consultar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Consultar'));
      await tester.pumpAndSettle();
      // Sin finalidad y confirmacion no se consulta.
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Consultar y registrar acceso'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Emergencia').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Consultar y registrar acceso'));
      await tester.pumpAndSettle();
      expect(medical.views, ['otra:emergency']);
      expect(
        find.textContaining('Fármacos a los que soy alérgico/a: Penicilina'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Colega Uno · Compañero elegido'),
        findsOneWidget,
      );
    },
  );
}

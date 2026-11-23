import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';
import 'package:vetdosis_pro/modules/hospital/domain/hospital_automation.dart';
import 'package:vetdosis_pro/modules/hospital/domain/hospital_models.dart';
import 'package:vetdosis_pro/modules/hospital/domain/hospital_repository.dart';
import 'package:vetdosis_pro/modules/hospital/data/supabase_hospital_repository.dart';
import 'package:vetdosis_pro/modules/hospital/presentation/hospital_automation_screen.dart';
import 'package:vetdosis_pro/modules/hospital/presentation/hospital_screen.dart';
import 'package:vetdosis_pro/modules/hospital/presentation/hospital_view_model.dart';
import 'package:vetdosis_pro/modules/prescribing/presentation/rx_entry_screen.dart';
import 'hospital_test.dart' show FakeHospital, FakeAlarms, alerts, stay;
import 'patients_test.dart' show FakePatients;

const member = ClinicMembership(
  clinicId: 'a',
  clinicName: 'Synthetic',
  userId: 'user-a',
  role: ClinicRole.admin,
);
Map<String, dynamic> data() => {
  'procedure_id': 'procedure',
  'label': 'Cuidado sintético',
  'instructions': 'Indicación sintética',
  'first_day': '2026-10-25',
  'last_day': '2026-10-27',
  'zone': 'America/Mexico_City',
  'times': '08:05, 19:30',
  'escalation_minutes': '15',
  'confirmed': true,
};
Map<String, dynamic> order() => {
  ...validateDailyOrder(data()),
  'id': 'order',
  'clinic_id': 'a',
  'stay_id': 'stay-a',
  'version': 1,
  'author_id': 'user-a',
  'created_at': '2026-10-24T12:00:00Z',
  'patient_name': 'Paciente sintético',
  'can_stop': true,
  'stop': null,
};
Map<String, dynamic> notice() => {
  'id': 'notice',
  'clinic_id': 'a',
  'task_id': 'task',
  'stay_id': 'stay-a',
  'stage': 'primary',
  'recipient_id': 'user-a',
  'created_at': '2026-10-24T12:00:00Z',
  'due_at': '2026-10-24T11:00:00Z',
  'patient_name': 'Paciente sintético',
  'task_label': 'Cuidado sintético',
  'task_state': 'pending',
  'can_ack': true,
  'response': null,
};
Map<String, dynamic> workspace({
  String? stay = 'stay-a',
  bool enabled = true,
}) => {
  'schema_version': 1,
  'clinic_id': 'a',
  'actor_id': 'user-a',
  'stay_id': stay,
  'runtime': {'enabled': enabled, 'last_run_at': null},
  'actions': {'create': stay != null && enabled, 'manage': true},
  'route': null,
  'orders': <Map<String, dynamic>>[],
  'notices': <Map<String, dynamic>>[],
  'procedures': [
    {'id': 'procedure', 'name': 'Tipo sintético'},
  ],
  'members': [
    {
      'id': 'user-a',
      'name': 'Encargado sintético',
      'primary_eligible': true,
      'mvz_eligible': false,
    },
    {
      'id': 'mvz',
      'name': 'MVZ sintético',
      'primary_eligible': false,
      'mvz_eligible': true,
    },
  ],
};

class AutomationFake implements HospitalAutomationRepository {
  Map<String, dynamic> value = workspace();
  Completer<Map<String, dynamic>>? pending;
  final writes = <Map<String, dynamic>>[];
  bool fail = false;
  @override
  Future<Map<String, dynamic>> automationWorkspace(
    String clinic,
    String? stay,
  ) async => pending == null ? value : pending!.future;
  Future<void> write(
    String kind,
    Map<String, dynamic> data,
    String operation,
  ) async {
    writes.add({'kind': kind, 'data': data, 'operation': operation});
    if (fail) throw StateError('uncertain_response');
  }

  @override
  Future<void> createDailyOrder(
    String clinic,
    String stay,
    Map<String, dynamic> data,
    String operation,
  ) => write('create', data, operation);
  @override
  Future<void> stopDailyOrder(
    String clinic,
    String order,
    String reason,
    String operation,
  ) => write('stop', {'order': order, 'reason': reason}, operation);
  @override
  Future<void> setNoticeRoute(
    String clinic,
    String primary,
    String mvz,
    String operation,
  ) => write('route', {'primary': primary, 'mvz': mvz}, operation);
  @override
  Future<void> acknowledgeNotice(
    String clinic,
    String notice,
    String note,
    String operation,
  ) => write('ack', {'notice': notice, 'note': note}, operation);
}

class HospitalAutomationFake extends FakeHospital
    implements HospitalAutomationRepository {
  final automation = AutomationFake()..value = workspace(stay: null);
  HospitalAutomationFake() {
    snapshot = HospitalSnapshot([stay()], [], automationEnabled: true);
  }
  @override
  Future<Map<String, dynamic>> automationWorkspace(String c, String? s) async =>
      {
        ...automation.value,
        'stay_id': s,
        'actions': {'manage': true, 'create': s != null},
      };
  @override
  Future<void> createDailyOrder(
    String c,
    String s,
    Map<String, dynamic> d,
    String o,
  ) => automation.createDailyOrder(c, s, d, o);
  @override
  Future<void> stopDailyOrder(String c, String s, String d, String o) =>
      automation.stopDailyOrder(c, s, d, o);
  @override
  Future<void> setNoticeRoute(String c, String p, String m, String o) =>
      automation.setNoticeRoute(c, p, m, o);
  @override
  Future<void> acknowledgeNotice(String c, String n, String d, String o) =>
      automation.acknowledgeNotice(c, n, d, o);
}

void main() {
  test(
    'explicit dates, zone, times and indication have no implicit recurrence or targets',
    () {
      expect(validateDailyOrder(data())['minutes'], [485, 1170]);
      expect(
        validateDailyOrder({
          ...data(),
          'minutes': [1170, 485],
        })['minutes'],
        [485, 1170],
      );
      for (final invalid in [
        {...data()}..remove('zone'),
        {...data()}..remove('instructions'),
        {...data(), 'times': '8:05'},
        {...data(), 'times': '24:00'},
        {...data(), 'times': '08:05,08:05'},
        {
          ...data(),
          'minutes': [1.1],
        },
        {...data(), 'confirmed': false},
        {...data(), 'first_day': '2026-02-30'},
        {...data(), 'last_day': '2026-10-24'},
        {...data(), 'last_day': '2026-12-01'},
        {...data(), 'escalation_minutes': '0'},
        {...data(), 'replaces_id': 'order'},
      ]) {
        expect(() => validateDailyOrder(invalid), throwsFormatException);
      }
    },
  );
  test('scope, contract, recipient and response identity fail closed', () {
    for (final mismatch in [
      {'schema_version': 2},
      {'actor_id': 'other'},
      {'clinic_id': 'other'},
      {'stay_id': 'other'},
      {
        'runtime': {'enabled': 'yes'},
      },
      {
        'actions': {'create': true},
      },
      {
        'orders': [
          {...order(), 'clinic_id': 'other'},
        ],
      },
      {
        'orders': [
          {...order(), 'stay_id': 'other'},
        ],
      },
      {
        'orders': [
          {...order(), 'version': 0},
        ],
      },
      {
        'notices': [
          {...notice(), 'recipient_id': 'other'},
        ],
      },
      {
        'notices': [
          {...notice(), 'stay_id': 'other'},
        ],
      },
      {
        'notices': [
          {
            ...notice(),
            'response': {
              'notice_id': 'notice',
              'clinic_id': 'a',
              'actor_id': 'forged',
              'note': 'Synthetic',
              'created_at': '2026-10-24T12:00:00Z',
            },
          },
        ],
      },
    ]) {
      expect(
        () => HospitalAutomationWorkspace.read(
          {...workspace(), ...mismatch},
          'a',
          'user-a',
          'stay-a',
        ),
        throwsFormatException,
      );
    }
    expect(
      HospitalAutomationWorkspace.read(
        workspace(enabled: false),
        'a',
        'user-a',
        'stay-a',
      ).canCreate,
      false,
    );
  });
  test(
    'RPC boundaries use server generation, acknowledgements never perform tasks',
    () async {
      final requests = <Map<String, dynamic>>[];
      var version = 1;
      final client = SupabaseClient(
        'https://synthetic.invalid',
        'synthetic',
        httpClient: MockClient((request) async {
          requests.add({
            'path': request.url.path,
            'data': jsonDecode(request.body),
          });
          final Object response = request.url.path.endsWith('hospital_snapshot')
              ? {
                  'stays': [],
                  'tasks': [],
                  'capabilities': {'automation_version': version},
                }
              : request.url.path.endsWith('hospital_automation_workspace')
              ? workspace()
              : 'id';
          return http.Response(
            jsonEncode(response),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final repo = SupabaseHospitalRepository(client);
      expect((await repo.load('a')).automationEnabled, true);
      version = 2;
      await expectLater(repo.load('a'), throwsFormatException);
      await repo.automationWorkspace('a', 'stay-a');
      await repo.createDailyOrder('a', 'stay-a', data(), 'op1');
      await repo.stopDailyOrder('a', 'order', 'Synthetic stop', 'op2');
      await repo.setNoticeRoute('a', 'user-a', 'mvz', 'op3');
      await repo.acknowledgeNotice('a', 'notice', 'Synthetic received', 'op4');
      expect(requests[3]['data'], {
        'p_clinic': 'a',
        'p_stay': 'stay-a',
        'p_data': validateDailyOrder(data()),
        'p_operation': 'op1',
      });
      expect(requests.last['path'], '/rest/v1/rpc/hospital_notice_ack');
      expect(requests.last['data'], {
        'p_clinic': 'a',
        'p_notice': 'notice',
        'p_note': 'Synthetic received',
        'p_operation': 'op4',
      });
      expect(
        requests.any(
          (r) => r['path'].toString().contains('hospital_task_action'),
        ),
        false,
      );
    },
  );
  test(
    'loss of known automation capability clears hospital snapshot',
    () async {
      final repo = FakeHospital()
        ..snapshot = const HospitalSnapshot([], [], automationEnabled: true);
      final model = HospitalViewModel(repo, member, await alerts(FakeAlarms()));
      addTearDown(model.dispose);
      await model.refresh();
      expect(model.snapshot.automationEnabled, true);
      repo.snapshot = const HospitalSnapshot([], []);
      await model.refresh();
      expect(model.snapshot.automationEnabled, false);
      expect(model.error, isNotNull);
    },
  );
  testWidgets('320dp form captures explicit server order and retry identity', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = AutomationFake()..fail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: HospitalAutomationScreen(
          repository: repo,
          member: member,
          stayId: 'stay-a',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Crear orden diaria en servidor'));
    await tester.tap(find.text('Crear orden diaria en servidor'));
    await tester.pumpAndSettle();
    final form = tester.widget<RxEntryScreen>(find.byType(RxEntryScreen));
    expect(form.initial, isEmpty);
    Future<void> reveal(Finder f) async {
      final scrollable = find.byType(Scrollable).first;
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pump();
      await tester.scrollUntilVisible(f, 200, scrollable: scrollable);
      await tester.pumpAndSettle();
    }

    Future<void> text(String label, String value) async {
      final f = find.byWidgetPredicate(
        (w) =>
            w is TextField && (w.decoration?.labelText ?? '').startsWith(label),
      );
      await reveal(f);
      await tester.enterText(f, value);
      await tester.pump();
    }

    final procedure = find.byType(DropdownButtonFormField<String>);
    await reveal(procedure);
    await tester.tap(procedure);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tipo sintético').last);
    await tester.pumpAndSettle();
    await text('Nombre del cuidado', 'Cuidado sintético');
    await text('Indicación profesional', 'Indicación sintética');
    await text('Primera fecha', '2026-10-25');
    await text('Última fecha', '2026-10-27');
    await text('Zona IANA', 'America/Mexico_City');
    await text('Horarios diarios', '08:05,19:30');
    await text('Escalar si nadie', '15');
    Future<void> save() async {
      final f = find.widgetWithText(FilledButton, 'Guardar');
      await reveal(f);
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    await save();
    expect(repo.writes, isEmpty);
    final check = find.byType(CheckboxListTile);
    await reveal(check);
    expect(tester.widget<CheckboxListTile>(check).value, false);
    await tester.tap(check);
    await tester.pumpAndSettle();
    await save();
    await save();
    expect(repo.writes.length, 2);
    expect(repo.writes.map((r) => r['operation']).toSet().length, 1);
    expect(repo.writes.first['data']['minutes'], [485, 1170]);
    await text('Indicación profesional', 'Indicación revisada');
    await save();
    expect(repo.writes.map((r) => r['operation']).toSet().length, 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'disabled scheduler and revoked workspace remove write actions; late load discarded',
    (tester) async {
      final repo = AutomationFake()..value = workspace(enabled: false);
      await tester.pumpWidget(
        MaterialApp(
          home: HospitalAutomationScreen(
            repository: repo,
            member: member,
            stayId: 'stay-a',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Crear orden diaria en servidor'), findsNothing);
      repo.value = {...workspace(), 'actor_id': 'other'};
      await tester.tap(find.text('Actualizar órdenes y avisos'));
      await tester.pumpAndSettle();
      expect(find.text('Configurar responsables de avisos'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      repo.pending = Completer<Map<String, dynamic>>();
      await tester.pumpWidget(
        MaterialApp(
          home: HospitalAutomationScreen(
            repository: repo,
            member: member,
            stayId: 'stay-a',
          ),
        ),
      );
      await tester.pumpWidget(const SizedBox());
      repo.pending!.complete(workspace());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'notice response and order replacement preserve distinct commands and history',
    (tester) async {
      final repo = AutomationFake()
        ..value = {
          ...workspace(),
          'orders': [order()],
          'notices': [notice()],
        };
      await tester.pumpWidget(
        MaterialApp(
          home: HospitalAutomationScreen(
            repository: repo,
            member: member,
            stayId: 'stay-a',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final replace = find.text('Crear nueva versión');
      await tester.scrollUntilVisible(
        replace,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(replace);
      await tester.pumpAndSettle();
      var form = tester.widget<RxEntryScreen>(find.byType(RxEntryScreen));
      expect(
        form.fields.any((f) => f.key == 'change_reason' && f.required),
        true,
      );
      await form.submit({
        ...data(),
        'change_reason': 'Synthetic revision',
      }, 'replace');
      expect(repo.writes.single['data']['replaces_id'], 'order');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          home: HospitalAutomationScreen(
            repository: repo,
            member: member,
            stayId: 'stay-a',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final ack = find.text('Confirmar que recibí el aviso');
      await tester.scrollUntilVisible(
        ack,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(ack);
      await tester.pumpAndSettle();
      form = tester.widget<RxEntryScreen>(find.byType(RxEntryScreen));
      expect(form.reviewText, contains('no marca realizado'));
      await form.submit({
        'note': 'Synthetic received',
        'confirmed': true,
      }, 'ack');
      expect(repo.writes.last['kind'], 'ack');
      expect(repo.writes.last['data'], {
        'notice': 'notice',
        'note': 'Synthetic received',
      });
    },
  );
  testWidgets('server orders reachable globally and per admission', (
    tester,
  ) async {
    final repo = HospitalAutomationFake();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HospitalScreen(
              repository: repo,
              patients: FakePatients(),
              member: member,
              alerts: await alerts(FakeAlarms()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Órdenes diarias'));
    await tester.tap(find.text('Órdenes diarias'));
    await tester.pumpAndSettle();
    expect(find.text('Órdenes diarias y avisos'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    final patient = find.text('Órdenes diarias de este paciente');
    await tester.scrollUntilVisible(
      patient,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(patient);
    await tester.pumpAndSettle();
    expect(find.text('Crear orden diaria en servidor'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

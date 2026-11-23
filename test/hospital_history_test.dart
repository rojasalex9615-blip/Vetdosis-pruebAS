import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vetdosis_pro/modules/hospital/domain/hospital_history.dart';
import 'package:vetdosis_pro/modules/hospital/domain/hospital_models.dart';
import 'package:vetdosis_pro/modules/hospital/data/supabase_hospital_repository.dart';
import 'package:vetdosis_pro/modules/hospital/presentation/hospital_history_screen.dart';
import 'package:vetdosis_pro/modules/hospital/presentation/hospital_history_view_model.dart';
import 'package:vetdosis_pro/modules/hospital/presentation/hospital_screen.dart';
import 'hospital_test.dart' show FakeHospital, FakeAlarms, alerts, member;
import 'patients_test.dart' show FakePatients;
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';

Map<String, dynamic> stayRow([String id = 'stay']) => {
  'id': id,
  'clinic_id': 'a',
  'patient_id': 'patient',
  'patient_name': 'Paciente sintético',
  'species': 'Sintética',
  'cage': null,
  'admitted_at': '2026-10-23T12:00:00Z',
  'admitted_by': 'author',
  'discharged_at': '2026-10-24T12:00:00Z',
  'discharged_by': 'author',
  'discharge_reason': 'Alta sintética',
};
Map<String, dynamic> taskRow([String id = 'task']) => {
  'id': id,
  'clinic_id': 'a',
  'stay_id': 'stay',
  'kind': 'revision',
  'state': 'cancelled',
  'label': 'Revisión sintética',
  'instructions': 'Indicación capturada',
  'due_at': '2026-10-24T10:00:00Z',
  'cancelled_at': '2026-10-24T12:00:00Z',
  'cancelled_by': 'author',
  'cancelled_name': 'Responsable sintético',
  'cancel_reason': 'Alta sintética',
  'resolution_kind': 'discharge',
};
Map<String, dynamic> envelope() => {
  'version': 1,
  'clinic_id': 'a',
  'actor_id': 'user-a',
  'next': null,
};
Map<String, dynamic> listRaw({String query = ''}) => {
  ...envelope(),
  'query': query,
  'stays': [stayRow()],
};
Map<String, dynamic> detailRaw() => {
  ...envelope(),
  'stay_id': 'stay',
  'stay': stayRow(),
  'tasks': [taskRow()],
  'events': [
    {
      'action': 'hospital_cage_changed',
      'at': '2026-10-23T14:00:00Z',
      'actor_id': 'author',
      'details': {
        'from': null,
        'to': 'Box sintético',
        'reason': 'Traslado sintético',
      },
    },
  ],
};
HospitalHistoryPage page({String query = ''}) =>
    HospitalHistoryPage.read(listRaw(query: query), 'a', 'user-a', query);
HospitalHistoryDetail detail() =>
    HospitalHistoryDetail.read(detailRaw(), 'a', 'user-a', 'stay');

class HistoryFake extends FakeHospital implements HospitalHistoryRepository {
  Completer<HospitalHistoryPage>? pendingHistory;
  Completer<HospitalHistoryDetail>? pendingDetail;
  HospitalHistoryPage? result;
  final requests = <Map<String, dynamic>>[];
  @override
  Future<HospitalHistoryPage> closedHistory(
    String clinic,
    String query,
    Map<String, dynamic>? before,
  ) async {
    requests.add({'kind': 'list', 'query': query, 'before': before});
    if (this.fail) throw StateError('revoked');
    return pendingHistory?.future ?? Future.value(result ?? page(query: query));
  }

  @override
  Future<HospitalHistoryDetail> closedDetail(
    String clinic,
    String stay,
    Map<String, dynamic>? before,
  ) async {
    requests.add({'kind': 'detail', 'stay': stay, 'before': before});
    if (this.fail) throw StateError('revoked');
    return pendingDetail?.future ?? Future.value(detail());
  }
}

void main() {
  test('Scope, actor, closed dates and action-free tasks are enforced', () {
    expect(page().stays.single['id'], 'stay');
    expect(detail().tasks.single.containsKey('actions'), false);
    for (final mismatch in [
      {'version': 2},
      {'clinic_id': 'b'},
      {'actor_id': 'other'},
      {'query': 'other'},
      {
        'stays': [
          {...stayRow(), 'discharged_at': null},
        ],
      },
      {
        'next': {'at': 'invalid', 'id': 'stay'},
      },
    ]) {
      expect(
        () => HospitalHistoryPage.read(
          {...listRaw(), ...mismatch},
          'a',
          'user-a',
          '',
        ),
        throwsFormatException,
      );
    }
    for (final mismatch in [
      {'stay_id': 'other'},
      {
        'stay': {...stayRow(), 'clinic_id': 'b'},
      },
      {
        'tasks': [
          {...taskRow(), 'stay_id': 'other'},
        ],
      },
      {
        'tasks': [
          {
            ...taskRow(),
            'actions': {'perform': true},
          },
        ],
      },
    ]) {
      expect(
        () => HospitalHistoryDetail.read(
          {...detailRaw(), ...mismatch},
          'a',
          'user-a',
          'stay',
        ),
        throwsFormatException,
      );
    }
  });
  test(
    'Pagination preserves tie cursor and rejects cursor not matching last row',
    () {
      final rows = [for (var i = 0; i < 25; i++) stayRow('stay$i')];
      final raw = {
        ...listRaw(),
        'stays': rows,
        'next': {'id': 'stay24', 'at': rows.last['discharged_at']},
      };
      expect(
        HospitalHistoryPage.read(raw, 'a', 'user-a', '').next!['id'],
        'stay24',
      );
      expect(
        () => HospitalHistoryPage.read(
          {
            ...raw,
            'next': {'id': 'stay23', 'at': rows.last['discharged_at']},
          },
          'a',
          'user-a',
          '',
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'New search discards late response and session loss clears memory',
    () async {
      final repo = HistoryFake();
      var current = true;
      final model = HospitalHistoryViewModel(repo, 'a', () => current);
      final pending = Completer<HospitalHistoryPage>();
      repo.pendingHistory = pending;
      final first = model.load(search: 'old');
      repo.pendingHistory = null;
      await model.load(search: 'new');
      expect(model.query, 'new');
      pending.complete(
        HospitalHistoryPage([
          {...stayRow(), 'patient_name': 'Wrong late patient'},
        ], null),
      );
      await first;
      expect(model.stays.single['patient_name'], 'Paciente sintético');
      current = false;
      await model.load();
      expect(model.stays, isEmpty);
      expect(model.detail, isNull);
      expect(model.query, isEmpty);
      model.dispose();
    },
  );
  test(
    'Failed next page clears old results; late detail cannot replace list',
    () async {
      final repo = HistoryFake()
        ..result = HospitalHistoryPage(
          [stayRow()],
          {'at': stayRow()['discharged_at'], 'id': 'stay'},
        );
      final model = HospitalHistoryViewModel(repo, 'a', () => true);
      await model.load();
      repo.fail = true;
      await model.load(more: true);
      expect(model.stays, isEmpty);
      expect(model.next, isNull);
      expect(model.error, isNotNull);
      repo.fail = false;
      final pending = Completer<HospitalHistoryDetail>();
      repo.pendingDetail = pending;
      final first = model.load(stay: 'stay');
      await model.back();
      pending.complete(detail());
      await first;
      expect(model.selected, isNull);
      expect(model.detail, isNull);
      expect(model.stays, isNotEmpty);
      model.dispose();
    },
  );
  test(
    'Next pages append once, repeated rows fail closed and disposal discards reads',
    () async {
      final repo = HistoryFake()
        ..result = HospitalHistoryPage(
          [stayRow('first')],
          {'id': 'first', 'at': stayRow()['discharged_at']},
        );
      final model = HospitalHistoryViewModel(repo, 'a', () => true);
      await model.load();
      repo.result = HospitalHistoryPage([stayRow('second')], null);
      await model.load(more: true);
      expect(model.stays.map((r) => r['id']), ['first', 'second']);
      expect(repo.requests.last['before']!['id'], 'first');
      repo.result = HospitalHistoryPage(
        [stayRow('first')],
        {'id': 'first', 'at': stayRow()['discharged_at']},
      );
      await model.load();
      await model.load(more: true);
      expect(model.stays, isEmpty);
      expect(model.error, isNotNull);
      repo.pendingHistory = Completer<HospitalHistoryPage>();
      final pending = model.load();
      model.dispose();
      repo.pendingHistory!.complete(page());
      await pending;
      expect(model.stays, isEmpty);
    },
  );
  test(
    'RPCs require a live session and send only scoped read requests',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://synthetic.invalid',
        'synthetic',
        httpClient: MockClient((request) async {
          requests.add(request);
          final response = request.url.path.contains('/auth/')
              ? {
                  'access_token': 'synthetic-access',
                  'refresh_token': 'synthetic-refresh',
                  'token_type': 'bearer',
                  'expires_in': 3600,
                  'user': {
                    'id': 'user-a',
                    'aud': 'authenticated',
                    'role': 'authenticated',
                    'email': 'synthetic@example.test',
                    'app_metadata': {},
                    'user_metadata': {},
                    'created_at': '2026-10-24T00:00:00Z',
                  },
                }
              : request.url.path.endsWith('hospital_closed_history')
              ? listRaw()
              : detailRaw();
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
      await expectLater(repo.closedHistory('a', '', null), throwsStateError);
      expect(requests, isEmpty);
      await client.auth.signInWithPassword(
        email: 'synthetic@example.test',
        password: 'synthetic',
      );
      expect((await repo.closedHistory('a', '', null)).stays.length, 1);
      expect((await repo.closedDetail('a', 'stay', null)).tasks.length, 1);
      final rpc = requests.where((r) => r.url.path.contains('/rpc/')).toList();
      expect(rpc.length, 2);
      expect(jsonDecode(rpc.last.body), {
        'p_clinic': 'a',
        'p_stay': 'stay',
        'p_before': null,
      });
    },
  );
  testWidgets(
    '320dp history shows closed tasks and cage events without clinical actions',
    (tester) async {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = HistoryFake(), identity = ChangeNotifier();
      var current = true;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: HospitalHistoryScreen(
            repository: repo,
            clinic: 'a',
            isCurrent: () => current,
            identityChanges: identity,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paciente sintético'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Motivo de alta: Alta sintética'),
        200,
      );
      await tester.pumpAndSettle();
      expect(find.text('Motivo de alta: Alta sintética'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Cambio de jaula'), 200);
      await tester.pumpAndSettle();
      expect(find.text('Cambio de jaula'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Indicaciones y resoluciones registradas'),
        200,
      );
      await tester.pumpAndSettle();
      expect(find.text('Registrar administración'), findsNothing);
      expect(find.text('Posponer aviso'), findsNothing);
      expect(tester.takeException(), isNull);
      current = false;
      identity.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text('Motivo de alta: Alta sintética'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      identity.dispose();
    },
  );
  testWidgets(
    'Closed history is reachable from the hospital sheet with current read permission',
    (tester) async {
      final repo = HistoryFake()
        ..snapshot = const HospitalSnapshot(
          [],
          [],
          permissions: {'hospital.read': true},
        );
      final alarm = await alerts(FakeAlarms());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HospitalScreen(
                repository: repo,
                patients: FakePatients(),
                member: member(ClinicRole.mvz),
                alerts: alarm,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.text('Altas');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Hospitalizaciones dadas de alta'), findsOneWidget);
      expect(find.text('Paciente sintético'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      alarm.dispose();
    },
  );
}

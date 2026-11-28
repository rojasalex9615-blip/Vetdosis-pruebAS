import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/aviculture/domain/poultry_farm.dart';
import 'package:vetdosis_pro/modules/aviculture/domain/poultry_schedule.dart';
import 'package:vetdosis_pro/modules/aviculture/presentation/poultry_calendar_screen.dart';
import 'poultry_farms_test.dart' show Farms, fixture;

Map<String, dynamic> calendarFixture() => {
  'schema_version': 1,
  'clinic_id': 'c1',
  'items': [
    {
      'id': 's1',
      'clinic_id': 'c1',
      'farm_id': 'norte',
      'house_id': 'h1',
      'flock_id': null,
      'due_on': '2026-11-28',
      'kind': 'vacunacion',
      'title': 'Tarea capturada',
      'days_before': 2,
      'status': 'pendiente',
      'version': 1,
      'notes': 'Capturado por el equipo',
    },
  ],
};

class CalendarRepo extends Farms implements PoultryScheduleRepository {
  final rows = <Map<String, dynamic>>[
    Map<String, dynamic>.from(
      (calendarFixture()['items'] as List).single as Map,
    ),
  ];
  final writes = <Map<String, dynamic>>[];
  bool fail = false;
  @override
  Future<Map<String, dynamic>> calendar(String c) async {
    if (fail) throw StateError('PGRST202');
    return {'schema_version': 1, 'clinic_id': c, 'items': rows};
  }

  @override
  Future<String> saveScheduled(
    String c,
    Map<String, dynamic> data, {
    String? id,
    int? version,
    required String operation,
  }) async {
    writes.add(data);
    rows.add({
      ...data,
      'id': 's2',
      'clinic_id': c,
      'farm_id': 'norte',
      'due_on': data['date'],
      'version': 1,
    });
    return 's2';
  }
}

void main() {
  test('planned warnings honor status and exact calendar days', () {
    final d = PoultryFarmWorkspace.read(fixture(), 'c1');
    final item = PoultrySchedule.read(calendarFixture(), 'c1', d).single;
    expect(item.warnsOn(DateTime(2026, 11, 25)), false);
    expect(item.warnsOn(DateTime(2026, 11, 26)), true);
    expect(item.overdueOn(DateTime(2026, 11, 28)), false);
    expect(item.overdueOn(DateTime(2026, 11, 29)), true);
    item.data['status'] = 'completada';
    expect(item.warnsOn(DateTime(2026, 12, 1)), false);
  });
  test(
    'calendar rejects crossed clinics, houses, flocks and invalid dates',
    () {
      final d = PoultryFarmWorkspace.read(fixture(), 'c1');
      for (final entry in [
        {'clinic_id': 'foreign'},
        {'farm_id': 'sur'},
        {'house_id': 'unknown'},
        {'flock_id': 'foreign'},
        {'due_on': '2026-02-31'},
        {'days_before': 91},
      ]) {
        final r = calendarFixture();
        (r['items'] as List).single.addAll(entry);
        expect(() => PoultrySchedule.read(r, 'c1', d), throwsFormatException);
      }
    },
  );
  testWidgets(
    'calendar shows a task as planned, with in-app warning and actual house',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: PoultryCalendarScreen(
            clinicId: 'c1',
            repository: CalendarRepo(),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Tarea capturada'), findsOneWidget);
      expect(find.text('Tarea dentro del plazo de aviso.'), findsOneWidget);
      expect(find.textContaining('Fecha programada:'), findsOneWidget);
      expect(
        find.textContaining('no son notificaciones del teléfono'),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'missing calendar backend explains activation without fake tasks',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: PoultryCalendarScreen(
            clinicId: 'c1',
            repository: CalendarRepo()..fail = true,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.textContaining('requiere habilitar'), findsOneWidget);
      expect(find.text('Tarea capturada'), findsNothing);
    },
  );
  testWidgets(
    'saving a scheduled task captures house/date/warning without applying it',
    (t) async {
      t.view.physicalSize = const Size(320, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final repo = CalendarRepo();
      await t.pumpWidget(
        MaterialApp(
          home: PoultryCalendarScreen(
            clinicId: 'c1',
            repository: repo,
            houseId: 'h1',
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Programar tarea sanitaria'));
      await t.pumpAndSettle();
      final title = find.widgetWithText(TextFormField, 'Tarea programada *');
      await t.enterText(title, 'Revisar lote');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('Guardar'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Guardar'));
      await t.pumpAndSettle();
      await t.tap(find.text('Guardar'));
      await t.pumpAndSettle();
      expect(repo.writes.single['house_id'], 'h1');
      expect(repo.writes.single['status'], 'pendiente');
      expect(repo.saved, isEmpty);
      await t.scrollUntilVisible(
        find.text('Revisar lote'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Revisar lote'), findsOneWidget);
    },
  );
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/aviculture/domain/poultry_farm.dart';
import 'package:vetdosis_pro/modules/aviculture/presentation/poultry_farm_screen.dart';
import 'package:vetdosis_pro/vet_ui/vet_theme.dart';

Map<String, dynamic> fixture() => {
  'schema_version': 1,
  'clinic_id': 'c1',
  'can_manage': true,
  'farms': [
    for (final id in ['norte', 'sur'])
      {'id': id, 'clinic_id': 'c1', 'name': id, 'version': 1},
  ],
  'house_farms': [
    {'house_id': 'h1', 'farm_id': 'norte'},
    {'house_id': 'h2', 'farm_id': 'sur'},
  ],
  'records': {
    'schema_version': 1,
    'clinic_id': 'c1',
    'day': '2026-11-27',
    'timezone': 'America/Mexico_City',
    'can_write': true,
    'houses': [
      for (final id in ['h1', 'h2'])
        {
          'id': id,
          'name': 'Caseta 1',
          'system': 'piso',
          'capacity': 1000,
          'version': 1,
        },
    ],
    'flocks': [],
    'references': [],
    'equipment': [],
    'records': [],
    'events': [],
  },
  'health': [
    for (final i in [1, 2])
      {
        'id': 'e$i',
        'clinic_id': 'c1',
        'farm_id': i == 1 ? 'norte' : 'sur',
        'house_id': 'h$i',
        'flock_id': null,
        'kind': i == 1 ? 'vacunacion' : 'enfermedad',
        'product': i == 1 ? 'Vacuna registrada' : '',
        'diagnosis': i == 2 ? 'Hallazgo registrado' : '',
        'occurred_on': '2026-11-26',
        'status': 'observada',
      },
  ],
};

class Farms implements PoultryFarmRepository {
  Completer<PoultryFarmWorkspace>? pending;
  final saved = <Map<String, dynamic>>[];
  final operations = <String>[];
  @override
  Future<PoultryFarmWorkspace> load(String c) =>
      pending?.future ?? Future.value(PoultryFarmWorkspace.read(fixture(), c));
  @override
  Future<String> saveHealth(
    String c,
    Map<String, dynamic> data, {
    required String operation,
  }) async {
    saved.add(data);
    operations.add(operation);
    if (saved.length == 1) throw StateError('network');
    return 'saved';
  }

  @override
  Future<String> saveFarm(
    String c,
    Map<String, dynamic> d, {
    String? id,
    int? version,
    required String operation,
  }) async => throw UnimplementedError();
  @override
  Future<String> saveHouse(
    String c,
    String f,
    Map<String, dynamic> d, {
    String? id,
    int? version,
    required String operation,
  }) async => throw UnimplementedError();
  @override
  Future<String> saveFlock(
    String c,
    Map<String, dynamic> d, {
    required String operation,
  }) async => throw UnimplementedError();
}

void main() {
  test(
    'farm mapping preserves duplicate house names across distinct farms',
    () {
      final d = PoultryFarmWorkspace.read(fixture(), 'c1');
      expect(d.farms, hasLength(2));
      expect(d.houseFarmIds['h1'], 'norte');
      expect(d.health.last.houseId, 'h2');
    },
  );
  test('rejects cross-clinic, farm, and flock associations', () {
    var d = fixture();
    d['clinic_id'] = 'other';
    expect(() => PoultryFarmWorkspace.read(d, 'c1'), throwsFormatException);
    d = fixture();
    d['health'][0]['farm_id'] = 'sur';
    expect(() => PoultryFarmWorkspace.read(d, 'c1'), throwsFormatException);
    d = fixture();
    d['health'][0]['flock_id'] = 'foreign';
    expect(() => PoultryFarmWorkspace.read(d, 'c1'), throwsFormatException);
    d = fixture();
    d['farms'][0]['clinic_id'] = 'other';
    expect(() => PoultryFarmWorkspace.read(d, 'c1'), throwsFormatException);
  });
  testWidgets(
    'shows actual records and filters sanitary history by farm on a phone',
    (t) async {
      t.view.physicalSize = const Size(360, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: VetTheme.light(),
          home: PoultryFarmScreen(clinicId: 'c1', repository: Farms()),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Todas las granjas'));
      await t.pumpAndSettle();
      await t.tap(find.text('norte').last);
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('Vacuna registrada'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Hallazgo registrado'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'missing backend shows unavailable state without invented farms',
    (t) async {
      await t.pumpWidget(
        const MaterialApp(home: PoultryFarmScreen(clinicId: 'c1')),
      );
      await t.pumpAndSettle();
      expect(find.textContaining('Conecta tu cuenta'), findsOneWidget);
      expect(find.text('Nueva granja'), findsNothing);
    },
  );
  testWidgets('ignores a stale response after changing clinic', (t) async {
    final repo = Farms()..pending = Completer<PoultryFarmWorkspace>();
    await t.pumpWidget(
      MaterialApp(
        home: PoultryFarmScreen(clinicId: 'c1', repository: repo),
      ),
    );
    await t.pump();
    final old = repo.pending!;
    repo.pending = Completer<PoultryFarmWorkspace>();
    await t.pumpWidget(
      MaterialApp(
        home: PoultryFarmScreen(clinicId: 'other', repository: repo),
      ),
    );
    await t.pump();
    old.complete(PoultryFarmWorkspace.read(fixture(), 'c1'));
    await t.pump();
    expect(find.text('Nueva granja'), findsNothing);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'sanitary form requires a recorded product and retries with same operation',
    (t) async {
      final repo = Farms();
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) => Scaffold(
              body: TextButton(
                onPressed: () => capturePoultryHealth(
                  c,
                  repo,
                  'c1',
                  'h1',
                  DateTime(2026, 11, 27),
                  flocks: [],
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Abrir'));
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
      expect(repo.saved, isEmpty);
      final product = find.widgetWithText(
        TextFormField,
        'Vacuna / producto registrado *',
      );
      await t.scrollUntilVisible(
        product,
        -300,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await t.enterText(product, 'Vacuna capturada');
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
      expect(repo.saved, hasLength(1));
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
      expect(repo.saved, hasLength(2));
      expect(repo.operations.toSet(), hasLength(1));
      expect(repo.saved.last['house_id'], 'h1');
      expect(repo.saved.last['flock_id'], isNull);
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/aviculture/domain/aviculture_records.dart';
import 'package:vetdosis_pro/modules/aviculture/domain/aviculture_records_repository.dart';
import 'package:vetdosis_pro/modules/aviculture/presentation/aviculture_records_screen.dart';

/// Repositorio sintético: la pantalla solo lee; ninguna prueba escribe.
class _FakeAvicultureRepository implements AvicultureRecordsRepository {
  _FakeAvicultureRepository(this.data);

  final Map<String, dynamic> data;
  int reads = 0;

  @override
  Future<AviWorkspace> workspace(String clinicId) async {
    reads++;
    return AviWorkspace.read(data);
  }

  @override
  Future<String> saveHouse(
    String clinicId,
    Map<String, dynamic> data, {
    String? id,
    int? version,
    required String operation,
  }) async => throw UnimplementedError();

  @override
  Future<String> saveFlock(
    String clinicId,
    Map<String, dynamic> data, {
    String? id,
    int? version,
    required String operation,
  }) async => throw UnimplementedError();

  @override
  Future<String> saveRecord(
    String clinicId,
    Map<String, dynamic> data, {
    String? id,
    int? version,
    required String operation,
  }) async => throw UnimplementedError();

  @override
  Future<String> saveEvent(
    String clinicId,
    Map<String, dynamic> data, {
    String? id,
    int? version,
    required String operation,
  }) async => throw UnimplementedError();
}

Map<String, dynamic> _fixture() => {
  'schema_version': 1,
  'day': '2026-11-12',
  'timezone': 'America/Mexico_City',
  'can_write': true,
  'references': [
    {
      'id': 'r1',
      'stage': 'postura',
      'week_from': 13,
      'week_to': null,
      'system': 'jaula_bateria',
      'parameter': 'espacio_por_ave',
      'min': 450,
      'max': 550,
      'unit': 'cm2',
      'source': 'Clase Prod. Avicola',
      'status': 'sin_verificar',
    },
  ],
  'equipment': [
    {
      'id': 'e1',
      'stage': 'crianza',
      'equipment': 'bebedero_campana',
      'birds_per_unit_min': 80,
      'birds_per_unit_max': 100,
      'note': '',
      'source': 'Apuntes',
      'status': 'sin_verificar',
    },
  ],
  'houses': [
    {
      'id': 'h1',
      'name': 'Caseta 1',
      'system': 'piso',
      'capacity': 1000,
      'notes': '',
      'archived': false,
      'version': 1,
    },
  ],
  'flocks': [
    {
      'id': 'f1',
      'code': 'P-2026-01',
      'house_id': 'h1',
      'house': 'Caseta 1',
      'system': 'piso',
      'genetic_line': 'Lohmann Brown',
      'start_date': '2026-09-01',
      'status': 'activa',
      'closed_on': null,
      'initial_birds': 1000,
      'version': 1,
      'week': 10,
      'birds': 998,
      'mortality_total': 2,
      'mortality_pct': 0.2,
      'eggs_total': 800,
      'feed_kg_total': 112.5,
      'records': 1,
      'last_record': '2026-11-11',
      'last_eggs': 800,
      'laying_pct': 80.16,
      'feed_g_bird_day': 112.7,
    },
  ],
  'records': [
    {
      'id': 'p1',
      'flock_id': 'f1',
      'flock': 'P-2026-01',
      'date': '2026-11-11',
      'eggs': 800,
      'eggs_discarded': 12,
      'mortality': 2,
      'feed_kg': 112.5,
      'avg_weight_g': 1850,
      'water_l': null,
      'notes': 'Sintético',
      'version': 1,
    },
  ],
  'events': [
    {
      'id': 'v1',
      'flock_id': 'f1',
      'flock': 'P-2026-01',
      'date': '2026-11-10',
      'kind': 'tratamiento',
      'title': 'Antibiótico sintético',
      'details': '',
      'withdrawal_until': '2026-11-20',
      'version': 1,
    },
  ],
};

Future<void> _host(WidgetTester tester, _FakeAvicultureRepository repo) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AvicultureRecordsScreen(clinicId: 'clinic-1', repository: repo),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('la parvada muestra sus indicadores del servidor', (
    tester,
  ) async {
    await _host(tester, _FakeAvicultureRepository(_fixture()));
    expect(find.text('P-2026-01'), findsWidgets);
    expect(find.text('998'), findsOneWidget);
    expect(find.text('80.16 %'), findsOneWidget);
    expect(find.text('Caseta 1'), findsWidgets);
  });

  testWidgets('el registro diario abre con la parvada elegida', (
    tester,
  ) async {
    await _host(tester, _FakeAvicultureRepository(_fixture()));
    await tester.tap(find.text('Registrar día').first);
    await tester.pumpAndSettle();
    expect(find.text('Huevos totales'), findsOneWidget);
    expect(find.text('Bajas del día'), findsOneWidget);
  });

  testWidgets('sin espacio activo no consulta y explica por qué', (
    tester,
  ) async {
    final repo = _FakeAvicultureRepository(_fixture());
    await tester.pumpWidget(
      MaterialApp(
        home: AvicultureRecordsScreen(clinicId: null, repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Elige un espacio de trabajo'), findsOneWidget);
    expect(repo.reads, 0);
  });
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vetdosis_pro/modules/production/data/supabase_porcino_repository.dart';
import 'package:vetdosis_pro/modules/production/domain/porcino_repository.dart';
import 'package:vetdosis_pro/modules/production/presentation/porcino_panels.dart';
import 'package:vetdosis_pro/modules/production/presentation/production_menu.dart';
import 'package:vetdosis_pro/vet_ui/vet_icons.dart';
import 'section_navigation_test.dart' show admin;

/// El repositorio real sobre un cliente Supabase sintético: comprueba la ruta,
/// el método y los parámetros exactos que salen hacia el RPC y cómo se leen las
/// filas. No usa mocks del repositorio.
Future<SupabaseClient> syntheticClient(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) handler,
) async {
  final client = (await tester.runAsync(
    () async => SupabaseClient(
      'https://synthetic.invalid',
      'synthetic',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(handler),
    ),
  ))!;
  addTearDown(client.dispose);
  return client;
}

/// Repositorio en memoria para ejercitar la lógica de los paneles sin red.
class _FakePorcinoRepository implements PorcinoRepository {
  final plans = <PorcinoBandPlan>[];
  int saves = 0, deletes = 0;
  String? lastOperation;

  @override
  Future<List<PorcinoBandPlan>> listBandPlans(String clinicId) async =>
      List.of(plans);

  @override
  Future<String> saveBandPlan(
    String clinicId,
    Map<String, dynamic> data, {
    required String operation,
  }) async {
    saves++;
    lastOperation = operation;
    final id = 'plan-$saves';
    plans.insert(
      0,
      PorcinoBandPlan(
        id: id,
        name: data['nombre'] as String,
        species: 'cerdo',
        inputs: Map<String, dynamic>.from(data['entradas'] as Map),
        results: const {},
        version: 1,
        updatedAt: null,
      ),
    );
    return id;
  }

  @override
  Future<bool> deleteBandPlan(
    String clinicId,
    String planId, {
    required String operation,
  }) async {
    deletes++;
    plans.removeWhere((p) => p.id == planId);
    return true;
  }

  @override
  Future<List<Map<String, dynamic>>> biosecurityRefs() async => const [];

  @override
  Future<List<Map<String, dynamic>>> uppPhases() async => const [];

  @override
  Future<List<Map<String, dynamic>>> uppWarnings() async => const [];
}

void main() {
  testWidgets('saveBandPlan llama al RPC con la ruta y parámetros exactos', (
    tester,
  ) async {
    final calls = <Map<String, dynamic>>[];
    final client = await syntheticClient(tester, (request) async {
      expect(request.url.path, '/rest/v1/rpc/produccion_banda_guardar');
      expect(request.method, 'POST');
      calls.add(Map<String, dynamic>.from(jsonDecode(request.body) as Map));
      return http.Response(
        jsonEncode('11111111-1111-1111-1111-111111111111'),
        200,
        request: request,
        headers: {'content-type': 'application/json'},
      );
    });
    final repository = SupabasePorcinoRepository(client);
    final id = await repository.saveBandPlan(
      '22222222-2222-2222-2222-222222222222',
      {
        'nombre': 'Banda 550',
        'especie': 'cerdo',
        'entradas': {'vientres': 550},
      },
      operation: 'op-1',
    );
    expect(id, '11111111-1111-1111-1111-111111111111');
    expect(calls.single['p_clinic'], '22222222-2222-2222-2222-222222222222');
    expect(calls.single['p_operation'], 'op-1');
    expect((calls.single['p_data'] as Map)['nombre'], 'Banda 550');
  });

  testWidgets('deleteBandPlan envía p_id y p_operation al RPC de borrado', (
    tester,
  ) async {
    final calls = <Map<String, dynamic>>[];
    final client = await syntheticClient(tester, (request) async {
      expect(request.url.path, '/rest/v1/rpc/produccion_banda_eliminar');
      calls.add(Map<String, dynamic>.from(jsonDecode(request.body) as Map));
      return http.Response(
        jsonEncode(true),
        200,
        request: request,
        headers: {'content-type': 'application/json'},
      );
    });
    final repository = SupabasePorcinoRepository(client);
    final ok = await repository.deleteBandPlan(
      'clinic',
      'plan-9',
      operation: 'op-2',
    );
    expect(ok, true);
    expect(calls.single, containsPair('p_id', 'plan-9'));
    expect(calls.single, containsPair('p_operation', 'op-2'));
  });

  testWidgets('listBandPlans lee las filas y mapea el plan', (tester) async {
    final client = await syntheticClient(tester, (request) async {
      expect(request.url.path, '/rest/v1/produccion_bandas_planes');
      expect(request.url.queryParameters['clinic_id'], 'eq.clinic');
      return http.Response(
        jsonEncode([
          {
            'id': 'p1',
            'nombre': 'Banda 550',
            'especie': 'cerdo',
            'entradas': {'vientres': 550},
            'resultados': {'partos': 43.93},
            'version': 2,
            'updated_at': '2026-11-14T10:00:00Z',
          },
        ]),
        200,
        request: request,
        headers: {'content-type': 'application/json'},
      );
    });
    final repository = SupabasePorcinoRepository(client);
    final plans = await repository.listBandPlans('clinic');
    expect(plans, hasLength(1));
    expect(plans.single.name, 'Banda 550');
    expect(plans.single.version, 2);
    expect(plans.single.inputs['vientres'], 550);
    expect(plans.single.results['partos'], 43.93);
    expect(plans.single.updatedAt, isNotNull);
  });

  testWidgets('El panel de planes guarda y elimina con el repositorio', (
    tester,
  ) async {
    final repository = _FakePorcinoRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PorcinoBandPlanPanel(
              repository: repository,
              clinicId: 'clinic',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aún no hay planes guardados.'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre del plan'),
      'Banda 550',
    );
    await tester.ensureVisible(find.text('Guardar plan'));
    await tester.tap(find.text('Guardar plan'));
    await tester.pumpAndSettle();
    expect(repository.saves, 1);
    expect(repository.lastOperation, isNotEmpty);
    expect(find.text('Banda 550'), findsOneWidget);
    await tester.ensureVisible(find.byIcon(VetIcons.trash));
    await tester.tap(find.byIcon(VetIcons.trash));
    await tester.pumpAndSettle();
    expect(repository.deletes, 1);
    expect(find.text('Aún no hay planes guardados.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Con repositorio aparecen los paneles remotos en el menú', (
    tester,
  ) async {
    final repository = _FakePorcinoRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProductionMenu(
              member: admin,
              onNavigate: (_) {},
              porcino: repository,
            ),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Porcinos'));
    await tester.tap(find.text('Porcinos'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Bioseguridad y ambiente'));
    await tester.tap(find.text('Bioseguridad y ambiente'));
    await tester.pumpAndSettle();
    expect(find.text('Ambiente y bienestar'), findsOneWidget);
    await tester.ensureVisible(find.text('Referencias de bioseguridad'));
    await tester.tap(find.text('Referencias de bioseguridad'));
    await tester.pumpAndSettle();
    expect(find.byType(PorcinoBiosecurityRefsPanel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

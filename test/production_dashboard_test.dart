import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';
import 'package:vetdosis_pro/modules/production/domain/production_farm.dart';
import 'package:vetdosis_pro/modules/production/domain/production_unit.dart';
import 'package:vetdosis_pro/modules/production/domain/production_unit_repository.dart';
import 'package:vetdosis_pro/modules/production/presentation/production_dashboard.dart';
import 'package:vetdosis_pro/modules/production/presentation/production_menu.dart';

class _FakeUnitRepo implements ProductionUnitRepository {
  @override
  Future<List<ProductionUnit>> list(
    String userId,
    String clinicId, {
    String? species,
    String? activity,
  }) async => const [];

  @override
  Future<void> save(String userId, ProductionUnit unit) async {}

  @override
  Future<void> remove(String userId, String id) async {}
}

/// Granja de mentira para las pruebas: devuelve lo que se le diga, sin red.
class _FakeFarmRepo implements ProductionFarmRepository {
  _FakeFarmRepo(this.snapshot);
  final FarmSnapshot snapshot;
  List<String> ultimasEspecies = const [];

  @override
  Future<FarmSnapshot> load(
    String clinicId, {
    required List<String> especies,
  }) async {
    ultimasEspecies = especies;
    return snapshot;
  }
}

/// Repositorio que siempre falla, para distinguir «sin datos» de «sin red».
class _BrokenFarmRepo implements ProductionFarmRepository {
  @override
  Future<FarmSnapshot> load(
    String clinicId, {
    required List<String> especies,
  }) async => throw Exception('sin conexion');
}

const _testMember = ClinicMembership(
  clinicId: 'c1',
  clinicName: 'Rancho Santa Fe',
  userId: 'mvz_carlos',
  role: ClinicRole.mvz,
);

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: child,
        ),
      ),
    );

void main() {
  group('ProductionDashboard: los datos son de la granja, no de ejemplo', () {
    testWidgets('Sin registros lo dice, y no inventa una granja', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ProductionDashboard(
            onNavigate: (_) {},
            member: _testMember,
            units: _FakeUnitRepo(),
            farm: _FakeFarmRepo(const FarmSnapshot()),
            initialSpecies: 'Bovinos',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Lo que debe salir cuando no hay nada.
      expect(find.text('Aún no hay datos de producción'), findsOneWidget);

      // Y lo que NO debe salir nunca mas: las cifras del catalogo de ejemplo
      // que parecian del usuario. Si alguien vuelve a enchufar
      // speciesDataCatalog a la pantalla, esta prueba cae.
      expect(find.textContaining('Silo Ensilado Maíz'), findsNothing);
      expect(find.textContaining('Vaquillas de Reemplazo'), findsNothing);
      expect(find.textContaining('Revacunación Carbunco'), findsNothing);
      expect(find.textContaining('Vaca #402'), findsNothing);
      expect(find.text('Inventario en Silos y Autonomía'), findsNothing);
      expect(find.text('Mapa Operativo de Instalaciones'), findsNothing);
    });

    testWidgets('Las herramientas siguen estando sin datos de granja', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ProductionDashboard(
            onNavigate: (_) {},
            member: _testMember,
            units: _FakeUnitRepo(),
            farm: _FakeFarmRepo(const FarmSnapshot()),
            initialSpecies: 'Bovinos',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Las calculadoras no dependen de que haya lotes: deben seguir ahi.
      expect(find.text('Calculadora de Ración'), findsOneWidget);
      expect(find.text('FCA / Conversión'), findsOneWidget);
      expect(find.text('Densidad Animal'), findsOneWidget);
      expect(find.text('Dosis Seminales'), findsOneWidget);
      // Vivia en la fila de ejecucion diaria, que se retiro: no debe perderse.
      expect(find.text('Dosificación Masiva'), findsOneWidget);
      expect(find.text('Recetas y Control Oficial'), findsOneWidget);
    });

    testWidgets('Con lotes y eventos reales, los pinta', (tester) async {
      final hoy = DateTime.now();
      final granja = FarmSnapshot(
        batches: [
          FarmBatch(
            id: 'l1',
            codigo: 'L-01',
            nombre: 'Hato Lechero Norte',
            especie: 'bovino',
            proposito: 'leche',
            estado: 'activo',
            cabezas: 42,
            fechaInicio: hoy.subtract(const Duration(days: 30)),
          ),
        ],
        events: [
          FarmEvent(
            id: 'e1',
            loteId: 'l1',
            fecha: hoy.add(const Duration(days: 3)),
            tipo: 'vacuna',
            subtipo: 'Revacunación brucelosis',
            detalle: const {},
          ),
        ],
      );

      await tester.pumpWidget(
        _wrap(
          ProductionDashboard(
            onNavigate: (_) {},
            member: _testMember,
            units: _FakeUnitRepo(),
            farm: _FakeFarmRepo(granja),
            initialSpecies: 'Bovinos',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hato Lechero Norte'), findsOneWidget);
      expect(find.text('42'), findsWidgets);
      expect(find.text('Revacunación brucelosis'), findsOneWidget);
      expect(find.text('En 3 d'), findsOneWidget);
      expect(find.text('Aún no hay datos de producción'), findsNothing);
    });

    testWidgets('Un fallo de red no se confunde con una granja vacía', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ProductionDashboard(
            onNavigate: (_) {},
            member: _testMember,
            units: _FakeUnitRepo(),
            farm: _BrokenFarmRepo(),
            initialSpecies: 'Bovinos',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('No se pudieron leer los datos de producción'),
        findsOneWidget,
      );
      expect(find.text('Aún no hay datos de producción'), findsNothing);
    });

    testWidgets('Cada especie pide sus propios códigos al repositorio', (
      tester,
    ) async {
      final repo = _FakeFarmRepo(const FarmSnapshot());
      await tester.pumpWidget(
        _wrap(
          ProductionDashboard(
            onNavigate: (_) {},
            member: _testMember,
            units: _FakeUnitRepo(),
            farm: repo,
            initialSpecies: 'Bovinos',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.ultimasEspecies, ['bovino']);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Porcinos'));
      await tester.pumpAndSettle();
      // El selector dice «Porcinos» pero la tabla guarda «cerdo»: sin esa
      // traduccion la consulta no encontraria nada.
      expect(repo.ultimasEspecies, ['cerdo']);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Aves'));
      await tester.pumpAndSettle();
      expect(repo.ultimasEspecies, ['gallina', 'pavo']);
    });

    testWidgets('Sin repositorio de granja tampoco inventa datos', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ProductionDashboard(
            onNavigate: (_) {},
            member: _testMember,
            units: _FakeUnitRepo(),
            initialSpecies: 'Bovinos',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aún no hay datos de producción'), findsOneWidget);
      expect(find.textContaining('Silo Ensilado Maíz'), findsNothing);
    });

    testWidgets('El selector de especies sigue completo', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProductionDashboard(
            onNavigate: (_) {},
            member: _testMember,
            units: _FakeUnitRepo(),
            farm: _FakeFarmRepo(const FarmSnapshot()),
            initialSpecies: 'Bovinos',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bovinos'), findsWidgets);
      expect(find.text('Porcinos'), findsWidgets);
      expect(find.text('Aves'), findsWidgets);
    });

    testWidgets('ProductionMenu permite alternar al Dashboard Pecuario', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ProductionMenu(
            onNavigate: (_) {},
            member: _testMember,
            units: _FakeUnitRepo(),
            farm: _FakeFarmRepo(const FarmSnapshot()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Dashboard Independiente: Producción Pecuaria'),
        findsOneWidget,
      );
      expect(find.text('Abrir Dashboard Pecuario Completo'), findsOneWidget);

      await tester.tap(find.text('Dashboard Pecuario'));
      await tester.pumpAndSettle();

      // Ya en el panel: sin registros, lo dice.
      expect(find.text('Aún no hay datos de producción'), findsOneWidget);
    });
  });

  group('codigosDeEspecie', () {
    test('Traduce cada etiqueta del panel a los códigos de la base', () {
      // Los codigos salen de `produccion_especies`: son singulares y en
      // minuscula, y no coinciden con lo que se lee en pantalla.
      expect(codigosDeEspecie['Bovinos'], ['bovino']);
      expect(codigosDeEspecie['Porcinos'], ['cerdo']);
      expect(codigosDeEspecie['Aves'], ['gallina', 'pavo']);
      expect(codigosDeEspecie['Ovinos / caprinos'], ['ovino', 'caprino']);
      expect(codigosDeEspecie['Peces'], ['tilapia', 'langostino']);
      expect(codigosDeEspecie['Abejas'], ['abeja']);
      // Equinos no es especie de produccion en el catalogo.
      expect(codigosDeEspecie['Equinos'], isEmpty);
    });
  });

  group('FarmSnapshot', () {
    test('Solo cuenta cabezas de los lotes que siguen abiertos', () {
      final hoy = DateTime.now();
      FarmBatch lote(String id, int cabezas, String estado) => FarmBatch(
            id: id,
            codigo: id,
            nombre: id,
            especie: 'bovino',
            proposito: 'leche',
            estado: estado,
            cabezas: cabezas,
            fechaInicio: hoy,
          );
      final s = FarmSnapshot(
        batches: [lote('a', 10, 'activo'), lote('b', 5, 'cerrado')],
      );
      expect(s.totalCabezas, 10);
      expect(s.sinDatos, isFalse);
    });

    test('El catálogo de métricas por sí solo no es tener datos', () {
      const s = FarmSnapshot(
        metricDefs: [
          FarmMetricDef(
            especie: 'bovino',
            clave: 'temp',
            etiqueta: 'Temperatura',
            unidad: '°C',
            minimo: 38,
            maximo: 39.3,
          ),
        ],
      );
      // El catalogo es referencia y existe siempre: no dice nada de esta
      // granja, asi que la pantalla debe seguir considerandose vacia.
      expect(s.sinDatos, isTrue);
    });

    test('Los próximos eventos excluyen los que ya pasaron', () {
      final hoy = DateTime.now();
      FarmEvent ev(String id, int dias) => FarmEvent(
            id: id,
            loteId: 'l1',
            fecha: hoy.add(Duration(days: dias)),
            tipo: 'vacuna',
            subtipo: id,
            detalle: const {},
          );
      final s = FarmSnapshot(events: [ev('viejo', -5), ev('nuevo', 2)]);
      final proximos = s.proximos(hoy);
      expect(proximos.length, 1);
      expect(proximos.first.subtipo, 'nuevo');
    });
  });

  group('El catálogo por especie ya no guarda cifras inventadas', () {
    test('SpeciesMetrics solo conserva las constantes vitales', () {
      // El catalogo tenia costos, conversion alimenticia, silos, lotes y
      // alertas de una granja de ejemplo. No se pintaban, pero seguian ahi,
      // y un dato inventado que vive en el codigo acaba enchufandose a una
      // pantalla. Lo real sale del inventario de alimento y de los lotes.
      for (final entrada in speciesDataCatalog.entries) {
        expect(
          entrada.value.vitals,
          isNotEmpty,
          reason: '${entrada.key} se quedó sin rangos de referencia',
        );
      }
      expect(speciesDataCatalog.length, 7);
    });

    test('Las constantes vitales siguen siendo rangos de verdad', () {
      // Esto si es un dato general y real: no depende de la granja de nadie.
      final bovinos = speciesDataCatalog['Bovinos']!.vitals;
      expect(
        bovinos.any((v) => v.parameter.toLowerCase().contains('temperatura')),
        isTrue,
      );
      expect(bovinos.every((v) => v.range.isNotEmpty && v.unit.isNotEmpty), isTrue);
    });
  });
}

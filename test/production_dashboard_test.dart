import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';
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
  group('ProductionDashboard Tests', () {
    testWidgets('Dashboard Independiente carga selector de especies y KPIs', (tester) async {
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

      // 1. Selector de especies
      expect(find.text('Bovinos'), findsWidgets);
      expect(find.text('Porcinos'), findsWidgets);
      expect(find.text('Aves'), findsWidgets);

      // Fila 1: Pulso Financiero y Productivo
      expect(find.text('Pulso Financiero y Productivo'), findsOneWidget);
      expect(find.text('Costo por Litro de Leche'), findsOneWidget);
      expect(find.text('Conversión Alimenticia (ICA)'), findsOneWidget);
      expect(find.text('Inventario Total en Granja'), findsOneWidget);

      // Fila 2: Núcleo Analítico y Silos
      expect(find.text('Núcleo Analítico de Rendimiento'), findsOneWidget);
      expect(find.text('Inventario en Silos y Autonomía'), findsOneWidget);

      // Fila 3: Mapa Operativo de Instalaciones
      expect(find.text('Mapa Operativo de Instalaciones'), findsOneWidget);

      // Fila 4: Ejecución Diaria
      expect(find.text('Ejecución Diaria en Campo'), findsOneWidget);
      expect(find.text('Calendario Zootécnico y Sanitario'), findsOneWidget);
      expect(find.text('Dosificación Masiva'), findsOneWidget);

      // 2. Herramientas de la especie elegida
      expect(find.text('Calculadora de Ración'), findsOneWidget);
      expect(find.text('FCA / Conversión'), findsOneWidget);
      expect(find.text('Densidad Animal'), findsOneWidget);
      expect(find.text('Capacidad de Caseta/Nave'), findsOneWidget);
      expect(find.text('Dosis Seminales'), findsOneWidget);
      expect(find.text('Constantes Fisiológicas'), findsOneWidget);
      expect(find.text('Vademécum Pecuario'), findsOneWidget);
      expect(find.text('Registros Productivos'), findsOneWidget);

      // 3. Mis lotes / hatos
      expect(find.text('Mis Lotes y Hatos'), findsOneWidget);

      // 4. Alertas
      expect(find.text('Alertas y Tareas Críticas'), findsOneWidget);

      // 5. Recetas y control
      expect(find.text('Recetas y Control Oficial'), findsOneWidget);
      expect(find.text('Receta Simple'), findsOneWidget);
      expect(find.text('Receta Cuantificada'), findsOneWidget);

      // 6. Próximamente
      expect(find.text('Próximamente'), findsOneWidget);
      expect(find.text('Grandes Especies: Cirugía y Clínica Avanzada'), findsOneWidget);
    });

    testWidgets('Cambiar de especie en el Dashboard actualiza los datos a Porcinos', (tester) async {
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

      // Tocar chip de Porcinos
      final porcinoChip = find.widgetWithText(ChoiceChip, 'Porcinos');
      await tester.tap(porcinoChip);
      await tester.pumpAndSettle();

      // Debe mostrar KPIs de porcinos
      expect(find.text('Costo por Kg Cerdo en Pie'), findsOneWidget);
      expect(find.text('Ganancia Diaria de Peso - GDP (g/día)'), findsOneWidget);
    });

    testWidgets('ProductionMenu permite alternar al Dashboard Pecuario', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProductionMenu(
            onNavigate: (_) {},
            member: _testMember,
            units: _FakeUnitRepo(),
          ),
        ),
      );

      // En el catálogo inicial
      expect(find.text('Dashboard Independiente: Producción Pecuaria'), findsOneWidget);
      expect(find.text('Abrir Dashboard Pecuario Completo'), findsOneWidget);

      // Tocar la pestaña de Dashboard Pecuario
      final dashTab = find.text('Dashboard Pecuario');
      await tester.tap(dashTab);
      await tester.pumpAndSettle();

      // Ahora está en el Dashboard
      expect(find.text('Pulso Financiero y Productivo'), findsOneWidget);
      expect(find.text('Mapa Operativo de Instalaciones'), findsOneWidget);
    });
  });
}

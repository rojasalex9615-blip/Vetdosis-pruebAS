import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/calculations/data/calculation_repository.dart';
import 'package:vetdosis_pro/modules/calculations/domain/calculation_catalog.dart';
import 'package:vetdosis_pro/modules/calculations/presentation/calculation_screen.dart';
import 'package:vetdosis_pro/modules/doses/data/catalog_repository.dart';
import 'package:vetdosis_pro/modules/doses/domain/catalog.dart';
import 'package:vetdosis_pro/modules/exotics/presentation/exotics_menu.dart';
import 'package:vetdosis_pro/modules/production/presentation/production_menu.dart';

import 'dose_test.dart' as fixture;

class _CalcRepo implements CalculationRepository {
  @override
  Future<CalculationCatalog> load() async => CalculationCatalog.parse(
    File('assets/clinical/calculations.v1.json').readAsStringSync(),
  );
}

class _DoseRepo implements CatalogRepository {
  @override
  Future<DoseCatalog> load() async =>
      DoseCatalog.parse(jsonEncode(fixture.fixture()));
}

Future<void> _host(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openSelector(WidgetTester tester) async {
  final selector = find.byType(DropdownButtonFormField<String>).first;
  await tester.ensureVisible(selector);
  await tester.pumpAndSettle();
  await tester.tap(selector);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('La pantalla clínica no ofrece producción ni exóticos', (
    tester,
  ) async {
    await _host(
      tester,
      CalculationScreen(repository: _CalcRepo(), doses: _DoseRepo()),
    );
    await _openSelector(tester);
    // Solo se ofrecen las herramientas clínicas.
    expect(find.text('Fluidoterapia'), findsWidgets);
    expect(find.text('Producción: agua'), findsNothing);
    expect(find.text('Producción: alimento'), findsNothing);
    expect(find.text('Producción: por cabeza y lote'), findsNothing);
    expect(find.text('Peso metabólico en exóticos'), findsNothing);
  });

  testWidgets('La pantalla de producción solo ofrece sus calculadoras', (
    tester,
  ) async {
    await _host(
      tester,
      CalculationScreen(
        repository: _CalcRepo(),
        doses: _DoseRepo(),
        initialTool: 'water',
        tools: productionCalculationTools,
      ),
    );
    await _openSelector(tester);
    expect(find.text('Producción: agua'), findsWidgets);
    expect(find.text('Producción: alimento'), findsWidgets);
    expect(find.text('Producción: por cabeza y lote'), findsWidgets);
    expect(find.text('Fluidoterapia'), findsNothing);
    expect(find.text('Peso metabólico en exóticos'), findsNothing);
  });

  testWidgets('Exóticos ofrece el peso metabólico sin selector', (
    tester,
  ) async {
    await _host(tester, const ExoticsMenu());
    expect(find.text('Calculadora'), findsOneWidget);
    final tarjeta = find.text('Peso metabólico');
    expect(tarjeta, findsOneWidget);
    await tester.ensureVisible(tarjeta);
    await tester.pumpAndSettle();
    await tester.tap(tarjeta);
    // La pantalla carga el catálogo con un indicador que anima sin parar, así
    // que se avanza la transición sin esperar a que se asiente.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final screen = tester.widget<CalculationScreen>(
      find.byType(CalculationScreen),
    );
    expect(screen.initialTool, 'metabolic');
    expect(screen.tools, exoticCalculationTools);
    expect(screen.title, 'Peso metabólico en exóticos');
    expect(tester.takeException(), isNull);
  });

  testWidgets('El menú de producción muestra su apartado de calculadoras', (
    tester,
  ) async {
    await _host(tester, ProductionMenu(onNavigate: (_) {}));
    await tester.tap(find.text('Bovinos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leche'));
    await tester.pumpAndSettle();
    expect(find.text('Calculadoras de producción'), findsOneWidget);
    expect(find.text('Por cabeza y lote'), findsOneWidget);
    expect(find.text('Medicación en agua'), findsOneWidget);
    expect(find.text('Medicación en alimento'), findsOneWidget);
  });
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';
import 'package:vetdosis_pro/modules/exotics/domain/exotic_dashboard.dart';
import 'package:vetdosis_pro/modules/exotics/domain/exotic_taxon.dart';
import 'package:vetdosis_pro/modules/exotics/presentation/exotics_dashboard.dart';
import 'package:vetdosis_pro/modules/production/domain/production_farm.dart';
import 'package:vetdosis_pro/modules/production/presentation/production_dashboard.dart';
import 'package:vetdosis_pro/modules/production/presentation/production_menu.dart';

ClinicMembership member(String clinic) => ClinicMembership(
  clinicId: clinic,
  clinicName: clinic,
  userId: 'user',
  role: ClinicRole.mvz,
);
Widget host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);
FarmSnapshot farm(String name) => FarmSnapshot(
  batches: [
    FarmBatch(
      id: name,
      codigo: name,
      nombre: name,
      especie: 'cerdo',
      proposito: 'engorda',
      estado: 'activo',
      cabezas: 7,
      fechaInicio: DateTime(2026, 1, 1),
    ),
  ],
);
ExoticSnapshot exotic(String name) => ExoticSnapshot(
  specimens: [
    ExoticSpecimen(
      id: name,
      nombre: name,
      especie: 'Iguana',
      taxon: ExoticTaxon.reptiles,
    ),
  ],
);

class PendingFarm implements ProductionFarmRepository {
  final requests = <(String, List<String>, Completer<FarmSnapshot>)>[];
  @override
  Future<FarmSnapshot> load(String clinicId, {required List<String> especies}) {
    final completer = Completer<FarmSnapshot>();
    requests.add((clinicId, especies, completer));
    return completer.future;
  }
}

class PendingExotic implements ExoticDashboardRepository {
  final requests = <(String, Completer<ExoticSnapshot>)>[];
  @override
  Future<ExoticSnapshot> load(String clinicId) {
    final completer = Completer<ExoticSnapshot>();
    requests.add((clinicId, completer));
    return completer.future;
  }
}

void main() {
  testWidgets(
    'Producción descarta respuestas de otra especie, incluso errores',
    (tester) async {
      final repo = PendingFarm();
      await tester.pumpWidget(
        host(
          ProductionDashboard(
            onNavigate: (_) {},
            member: member('a'),
            farm: repo,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Porcinos'));
      await tester.pump(const Duration(milliseconds: 1));
      expect(repo.requests.map((r) => r.$2), [
        ['bovino'],
        ['cerdo'],
      ]);
      repo.requests[1].$3.complete(farm('Lote porcino actual'));
      await tester.pumpAndSettle();
      repo.requests[0].$3.completeError(Exception('Respuesta bovina atrasada'));
      await tester.pumpAndSettle();
      expect(find.text('Lote porcino actual'), findsOneWidget);
      expect(
        find.text('No se pudieron leer los datos de producción'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Producción recarga al cambiar de clínica y oculta la anterior', (
    tester,
  ) async {
    final repo = PendingFarm();
    Widget screen(String clinic) => host(
      ProductionDashboard(
        onNavigate: (_) {},
        member: member(clinic),
        farm: repo,
      ),
    );
    await tester.pumpWidget(screen('a'));
    await tester.pump(const Duration(milliseconds: 1));
    repo.requests.first.$3.complete(farm('Lote de clínica A'));
    await tester.pumpAndSettle();
    expect(find.text('Lote de clínica A'), findsOneWidget);
    await tester.pumpWidget(screen('b'));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Lote de clínica A'), findsNothing);
    expect(repo.requests.last.$1, 'b');
    repo.requests.last.$3.complete(const FarmSnapshot());
    await tester.pumpAndSettle();
    expect(find.text('Aún no hay datos de producción'), findsOneWidget);
  });

  testWidgets('Exóticos descarta ejemplares de una consulta de otra clínica', (
    tester,
  ) async {
    final repo = PendingExotic();
    Widget screen(String clinic) =>
        host(ExoticsDashboard(member: member(clinic), repository: repo));
    await tester.pumpWidget(screen('a'));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpWidget(screen('b'));
    await tester.pump(const Duration(milliseconds: 1));
    expect(repo.requests.map((r) => r.$1), ['a', 'b']);
    repo.requests[1].$2.complete(exotic('Iguana nueva'));
    await tester.pumpAndSettle();
    repo.requests[0].$2.complete(exotic('Iguana anterior'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Iguana');
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.textContaining('Iguana nueva'), findsWidgets);
    expect(find.textContaining('Iguana anterior'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Exóticos no conserva resultados de búsqueda durante una recarga',
    (tester) async {
      final repo = PendingExotic();
      Widget screen(String clinic) =>
          host(ExoticsDashboard(member: member(clinic), repository: repo));
      await tester.pumpWidget(screen('a'));
      await tester.pump(const Duration(milliseconds: 1));
      repo.requests.first.$2.complete(exotic('Iguana anterior'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Iguana');
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.textContaining('Iguana anterior'), findsWidgets);
      await tester.pumpWidget(screen('b'));
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.textContaining('Iguana anterior'), findsNothing);
      repo.requests.last.$2.complete(const ExoticSnapshot());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'Registros del catálogo abre la especie elegida en el dashboard',
    (tester) async {
      final repo = PendingFarm();
      await tester.pumpWidget(
        host(
          ProductionMenu(
            onNavigate: (_) {},
            member: member('a'),
            farm: repo,
            initialSpecies: 'Porcinos',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Registros Productivos'));
      await tester.tap(find.text('Registros Productivos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(repo.requests.single.$2, ['cerdo']);
      repo.requests.single.$3.complete(const FarmSnapshot());
      await tester.pumpAndSettle();
      expect(find.text('Aún no hay datos de producción'), findsOneWidget);
      expect(find.text('Guardar'), findsNothing);
    },
  );

  testWidgets('Vademécum y recetas abren los módulos reales', (tester) async {
    final routes = <String>[];
    await tester.pumpWidget(
      host(ProductionDashboard(onNavigate: routes.add, member: member('a'))),
    );
    await tester.pumpAndSettle();
    for (final label in [
      'Vademécum Pecuario',
      'Constantes Fisiológicas',
      'Receta Simple',
      'Receta Cuantificada',
    ]) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    expect(routes, ['Vademécum', 'Cálculos clínicos', 'Receta', 'Receta']);
    expect(find.textContaining('Retiro oficial:'), findsNothing);
    expect(find.text('Emitir Receta'), findsNothing);
  });

  testWidgets('Un registro sin conexión no finge un guardado', (tester) async {
    await tester.pumpWidget(host(ProductionDashboard(onNavigate: (_) {})));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Registros Productivos'));
    await tester.tap(find.text('Registros Productivos'));
    await tester.pumpAndSettle();
    expect(
      find.text('La captura de producción no está disponible.'),
      findsOneWidget,
    );
    expect(find.text('Registro productivo guardado con éxito.'), findsNothing);
    expect(find.text('Guardar'), findsNothing);
  });

  testWidgets(
    'La ración requiere datos propios y no reemplaza un dato inválido',
    (tester) async {
      await tester.pumpWidget(
        host(
          const ProductionCalculatorModal(
            calcType: 'ration',
            species: 'Bovinos',
          ),
        ),
      );
      expect(find.text('Captura los datos para calcular.'), findsOneWidget);
      final fields = find.byType(TextField);
      for (final field in tester.widgetList<TextField>(fields)) {
        expect(field.controller!.text, isEmpty);
      }
      await tester.enterText(fields.at(0), '10');
      await tester.enterText(fields.at(1), '500');
      await tester.enterText(fields.at(2), '2,5');
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.textContaining('Total lote: 125.0 kg/día'), findsOneWidget);
      await tester.enterText(fields.at(1), 'NaN');
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.textContaining('Total lote:'), findsNothing);
      expect(
        find.text('Captura valores numéricos mayores que cero.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Dosificación masiva no precarga dosis y valida la concentración',
    (tester) async {
      await tester.pumpWidget(
        host(const MassMedicationModal(species: 'Bovinos')),
      );
      final fields = find.byType(TextField);
      expect(find.text('Captura los datos para calcular.'), findsOneWidget);
      await tester.enterText(fields.at(0), '1000');
      await tester.enterText(fields.at(1), '100');
      await tester.enterText(fields.at(2), '10');
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.textContaining('1000.0 gramos'), findsOneWidget);
      await tester.enterText(fields.at(2), '101');
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.textContaining('1000.0 gramos'), findsNothing);
      expect(
        find.textContaining('concentración de hasta 100 %'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'El grupo elegido actualiza la especie de la calculadora de exóticos',
    (tester) async {
      await tester.pumpWidget(host(const ExoticsDashboard()));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(ChoiceChip, ExoticTaxon.reptiles.label),
      );
      await tester.pumpAndSettle();
      final selectors = find.byType(DropdownButtonFormField<ExoticTaxon>);
      expect(
        tester.state<FormFieldState<ExoticTaxon>>(selectors.last).value,
        ExoticTaxon.reptiles,
      );
    },
  );

  test('Una fecha ausente no se presenta como un registro de hoy', () {
    expect(
      () => FarmRecord.read({'id': 'r', 'lote_id': 'l'}),
      throwsFormatException,
    );
    expect(
      () => FarmBatch.read({'id': 'l', 'fecha_inicio': 'ilegible'}),
      throwsFormatException,
    );
    expect(
      () => FarmEvent.read({'id': 'e', 'fecha': null}),
      throwsFormatException,
    );
  });
  test('La clasificación de exóticos reconoce palabras completas', () {
    expect(taxonDeEspecie('Iguana verde'), ExoticTaxon.reptiles);
    expect(taxonDeEspecie('Rana dorada'), ExoticTaxon.anfibios);
    expect(taxonDeEspecie('Reptiles'), ExoticTaxon.reptiles);
    expect(taxonDeEspecie('Tortugas'), ExoticTaxon.reptiles);
    expect(taxonDeEspecie('Avestruz'), ExoticTaxon.aves);
    expect(taxonDeEspecie('Avestruces'), ExoticTaxon.aves);
    expect(taxonDeEspecie('Labrador con hepatopatía'), isNull);
    expect(taxonDeEspecie('Caracal'), isNull);
  });
}

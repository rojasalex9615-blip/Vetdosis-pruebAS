import 'package:vetdosis_pro/modules/production/presentation/production_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/core/widgets/horizontal_choice_strip.dart';
import 'package:vetdosis_pro/modules/production/domain/aquaculture_species.dart';
import 'package:vetdosis_pro/modules/production/presentation/aquaculture_panels.dart';
import 'package:vetdosis_pro/modules/production/presentation/porcino_panels.dart';
import 'package:vetdosis_pro/modules/production/presentation/production_calculator_entries.dart';
import 'package:vetdosis_pro/modules/production/presentation/production_menu.dart';
import 'package:vetdosis_pro/vet_ui/vet_components.dart';

void main() {
  test('each independent panel has an explicit directory label', () {
    final panels = [
      ...aquaculturePanelsFor(FishSpecies.tilapia),
      for (final a in [
        'Reproducción y gestación',
        'Maternidad y destete',
        'Crecimiento y engorda',
        'Bioseguridad y ambiente',
        'Planeación financiera',
      ])
        ...porcinoPanelsFor(a, showCosts: true),
    ];
    for (final p in panels) {
      if (p is! SizedBox && p is! VetNotice && p is! AquacultureSpeciesPanel) {
        expect(productionPanelTitle(p), isNot('Herramienta de producción'));
      }
    }
  });
  testWidgets(
    'fish directory opens only the chosen form and returns to directory',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) => Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: productionCalculatorEntries(
                    c,
                    'Tilapia',
                    aquaculturePanelsFor(FishSpecies.tilapia),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(TextField), findsNothing);
      final entry = find.text('Recambio de agua');
      await t.ensureVisible(entry);
      await t.tap(entry);
      await t.pumpAndSettle();
      expect(find.byType(AquacultureWaterExchangePanel), findsOneWidget);
      expect(find.byType(AquacultureFcrPanel), findsNothing);
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
    },
  );
  for (final sp in [
    'Aves',
    'Peces',
    'Porcinos',
    'Abejas',
    'Equinos',
    'Ovinos / caprinos',
  ]) {
    testWidgets('$sp does not repeat bovine generic calculators', (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProductionMenu(onNavigate: (_) {}, initialSpecies: sp),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('FCA / Conversión'), findsNothing);
      expect(find.text('Calculadora de Ración'), findsNothing);
    });
  }
  testWidgets(
    'long choices stay in one horizontally scrolling row on a phone',
    (t) async {
      t.view.physicalSize = const Size(320, 700);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HorizontalChoiceStrip(
              children: [
                for (var i = 0; i < 8; i++)
                  ChoiceChip(
                    label: Text('Actividad $i'),
                    selected: false,
                    onSelected: (_) {},
                  ),
              ],
            ),
          ),
        ),
      );
      final first = t.getTopLeft(find.text('Actividad 0')).dy;
      expect(t.getTopLeft(find.text('Actividad 7')).dy, first);
      await t.drag(find.byType(HorizontalChoiceStrip), const Offset(-1200, 0));
      await t.pumpAndSettle();
      expect(find.text('Actividad 7').hitTestable(), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'bovine calculator opens a full page; other dashboards hide generic cards',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProductionDashboard(onNavigate: (_) {}),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('FCA / Conversión'));
      await t.tap(find.text('FCA / Conversión'));
      await t.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text('Ganancia de peso total en periodo (kg)'),
        findsOneWidget,
      );
      await t.pageBack();
      await t.pumpAndSettle();
      await t.ensureVisible(find.widgetWithText(ChoiceChip, 'Aves'));
      await t.tap(find.widgetWithText(ChoiceChip, 'Aves'));
      await t.pumpAndSettle();
      expect(find.text('FCA / Conversión'), findsNothing);
      expect(find.text('Dosificación Masiva'), findsNothing);
    },
  );
}

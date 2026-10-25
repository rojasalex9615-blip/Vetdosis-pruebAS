import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/doses/presentation/dose_screen.dart';
import 'package:vetdosis_pro/modules/doses/domain/catalog.dart';
import 'package:vetdosis_pro/modules/doses/data/catalog_repository.dart';
import 'package:vetdosis_pro/modules/patients/domain/recorded_weight.dart';
import 'dose_test.dart' show fixture;

// Fuente ficticia con dosis única: el vademécum fija 2 mg/kg; no hay campo editable.
class RecordedWeightDoseRepo implements CatalogRepository {
  @override
  Future<DoseCatalog> load() async {
    final source = fixture();
    source['farmacos'][0]['min'] = '2';
    return DoseCatalog.parse(jsonEncode(source));
  }
}

RecordedPatientWeight measured() => RecordedPatientWeight(
  id: 'weight',
  clinicId: 'clinic',
  patientId: 'patient',
  patientName: 'Paciente ficticio',
  caseId: 'case',
  kg: '10.25',
  observedAt: DateTime.utc(2026, 10, 24, 10),
  performedBy: 'persona que midió',
  recordedBy: 'persona que registró',
  recordedAt: DateTime.utc(2026, 10, 24, 11),
);
Future<void> showCalculator(
  WidgetTester t,
  Future<bool> Function(RecordedPatientWeight)? validate,
) async {
  await t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DoseScreen(
            repository: RecordedWeightDoseRepo(),
            recordedWeight: measured(),
            validateRecordedWeight: validate,
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> tap(WidgetTester t, String text) async {
  final finder = find.text(text);
  await t.ensureVisible(finder);
  await t.tap(finder);
  await t.pumpAndSettle();
}

Future<void> setupCalculation(WidgetTester t) async {
  await tap(t, 'Ficticio');
  await t.ensureVisible(
    find.byWidgetPredicate((w) => w is DropdownButtonFormField).last,
  );
  await t.tap(find.byWidgetPredicate((w) => w is DropdownButtonFormField).last);
  await t.pumpAndSettle();
  await t.tap(find.textContaining('Marca ficticia').last);
  await t.pumpAndSettle();
  expect(find.text('2 mg/kg · no editable'), findsOneWidget);
  expect(find.text('Dosis seleccionada (mg/kg)'), findsNothing);
  final step = find.widgetWithText(TextField, 'Graduación de jeringa (mL, opcional)');
  await t.ensureVisible(step);
  await t.enterText(step, '0.01');
  await t.pump();
}

void main() {
  testWidgets(
    'explicit recorded selection feeds exact mass and volume; source shown in final review',
    (t) async {
      var checks = 0;
      await showCalculator(t, (w) async {
        checks++;
        expect(w.kg, '10.25');
        return true;
      });
      await setupCalculation(t);
      final weight = find.widgetWithText(TextField, 'Peso (kg)');
      expect(t.widget<TextField>(weight).controller!.text, isEmpty);
      expect(t.widget<TextField>(weight).readOnly, true);
      await tap(t, 'Calcular');
      expect(find.textContaining('Masa:'), findsNothing);
      expect(checks, 0);
      await tap(t, 'Usar peso registrado');
      expect(checks, 1);
      await tap(t, 'Calcular');
      expect(checks, 2);
      expect(find.textContaining('20,5 mg'), findsOneWidget);
      await t.ensureVisible(find.byType(CheckboxListTile));
      await t.tap(find.byType(CheckboxListTile));
      await t.pump();
      await tap(t, 'Confirmar por segunda vez');
      expect(checks, 3);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('Paciente ficticio'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('persona que midió'),
        ),
        findsOneWidget,
      );
      await tap(t, 'Confirmar cálculo');
      expect(checks, 4);
      expect(find.textContaining('Cálculo confirmado.'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'source change while confirmation dialog is open clears result and weight',
    (t) async {
      var valid = true;
      await showCalculator(t, (_) async => valid);
      await tap(t, 'Usar peso registrado');
      await setupCalculation(t);
      await tap(t, 'Calcular');
      await t.ensureVisible(find.byType(CheckboxListTile));
      await t.tap(find.byType(CheckboxListTile));
      await t.pump();
      await tap(t, 'Confirmar por segunda vez');
      valid = false;
      await tap(t, 'Confirmar cálculo');
      expect(find.textContaining('Cálculo confirmado.'), findsNothing);
      expect(find.textContaining('Masa:'), findsNothing);
      expect(
        t
            .widget<TextField>(find.widgetWithText(TextField, 'Peso (kg)'))
            .controller!
            .text,
        isEmpty,
      );
      expect(
        find.textContaining('La medición ya no se pudo comprobar'),
        findsOneWidget,
      );
    },
  );
  testWidgets('missing or failed validator never uses source weight', (
    t,
  ) async {
    await showCalculator(t, null);
    await tap(t, 'Usar peso registrado');
    expect(find.text('Peso registrado seleccionado.'), findsNothing);
    await t.pumpWidget(const SizedBox());
    await showCalculator(t, (_) async => throw StateError('offline'));
    await tap(t, 'Usar peso registrado');
    expect(
      find.textContaining('La medición ya no se pudo comprobar'),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'late permission response after dispose cannot restore a weight',
    (t) async {
      final pending = Completer<bool>();
      await showCalculator(t, (_) => pending.future);
      await t.ensureVisible(find.text('Usar peso registrado'));
      await t.tap(find.text('Usar peso registrado'));
      await t.pump();
      await t.pumpWidget(const SizedBox());
      pending.complete(true);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
  );
}

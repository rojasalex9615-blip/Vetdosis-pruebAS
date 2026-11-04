import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/doses/data/personal_dose_repository.dart';
import 'package:vetdosis_pro/modules/doses/presentation/personal_dose_screen.dart';

class PersonalRepository implements PersonalDoseRepository {
  final writes = <Map<String, dynamic>>[];
  @override
  Future<List<PersonalDoseEntry>> list(String clinicId) async => [];
  @override
  Future<void> create(
    String clinicId,
    Map<String, dynamic> payload, {
    required bool share,
  }) async => writes.add(payload);
  @override
  Future<void> review(String id, {required bool approve}) async {}
}

void main() {
  for (final label in [
    'Dosis 5–10 mg/kg · concentración 25 mg/ml',
    'Dose: 5-10 mg/kg. 20 mg/ml',
    'Dosis 0,5 a 1,0 mg/kg · 2,5 mg/ml',
    'Dosis única 10 mg/kg\nActive ingredient: Example',
  ]) {
    testWidgets(
      'OCR preserves text without choosing a clinical value: $label',
      (tester) async {
        tester.view.physicalSize = const Size(800, 3600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = PersonalRepository();
        await tester.pumpWidget(
          MaterialApp(
            home: PersonalDoseScreen(
              repository: repository,
              clinicId: 'synthetic',
              admin: false,
              general: const [],
              labelReader: () async => label,
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final field in [
          'min',
          'max',
          'concentracion',
          'fuente_presentacion',
        ]) {
          expect(
            tester
                .widget<TextField>(find.byKey(ValueKey('personal-dose-$field')))
                .controller!
                .text,
            isEmpty,
          );
        }
        await tester.tap(find.text('Escanear etiqueta y crear borrador'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Conservar solo el texto'));
        await tester.pumpAndSettle();
        for (final field in [
          'min',
          'max',
          'concentracion',
          'fuente_presentacion',
        ]) {
          expect(
            tester
                .widget<TextField>(find.byKey(ValueKey('personal-dose-$field')))
                .controller!
                .text,
            isEmpty,
          );
        }
        expect(repository.writes, isEmpty);
        expect(
          tester
              .widgetList<TextField>(find.byType(TextField))
              .first
              .controller!
              .text,
          label,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Accepting OCR does not overwrite manual fields or retain verified state',
    (tester) async {
      tester.view.physicalSize = const Size(800, 3600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = PersonalRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: PersonalDoseScreen(
            repository: repository,
            clinicId: 'synthetic',
            admin: false,
            general: const [],
            labelReader: () async => '5–10 mg/kg\n25 mg/ml',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final captured = {
        'min': '2',
        'max': '3',
        'concentracion': '50',
        'fuente_presentacion': 'Fuente manual',
      };
      for (final entry in captured.entries) {
        tester
                .widget<TextField>(
                  find.byKey(ValueKey('personal-dose-${entry.key}')),
                )
                .controller!
                .text =
            entry.value;
      }
      await tester.ensureVisible(find.byType(CheckboxListTile).first);
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile).first)
            .value,
        isTrue,
      );
      await tester.ensureVisible(
        find.text('Escanear etiqueta y crear borrador'),
      );
      await tester.tap(find.text('Escanear etiqueta y crear borrador'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Conservar solo el texto'));
      await tester.pumpAndSettle();
      for (final entry in captured.entries) {
        expect(
          tester
              .widget<TextField>(
                find.byKey(ValueKey('personal-dose-${entry.key}')),
              )
              .controller!
              .text,
          entry.value,
        );
      }
      expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile).first)
            .value,
        isFalse,
      );
      expect(repository.writes, isEmpty);
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetdosis_pro/core/app.dart';
import 'package:vetdosis_pro/modules/core/data/settings_repository.dart';
import 'package:vetdosis_pro/modules/core/presentation/core_view_model.dart';
import 'package:vetdosis_pro/modules/doses/presentation/dose_math_tools.dart';

void main() {
  final examples =
      <DoseMathMode, ({Map<String, String> values, String result})>{
        DoseMathMode.concentration: (
          values: {'weight': '12.5', 'dose': '2', 'concentration': '25'},
          result: '1 mL',
        ),
        DoseMathMode.ruleOfThree: (
          values: {
            'baselineVolume': '2',
            'baselineWeight': '10',
            'weight': '5',
          },
          result: '1 mL',
        ),
        DoseMathMode.internationalUnits: (
          values: {
            'totalUnits': '100',
            'finalVolume': '2',
            'weight': '10',
            'unitsPerKg': '5',
          },
          result: '1 mL',
        ),
        DoseMathMode.conversion: (values: {'amount': '1'}, result: '1000 g'),
      };
  for (final example in examples.entries) {
    testWidgets(
      'Shared Neu controls preserve ${example.key.name} arithmetic at 320dp',
      (t) async {
        t.view.physicalSize = const Size(320, 1100);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final core = CoreViewModel(
          SettingsRepository(),
          const AppSettings(visualStyle: 'neu'),
        );
        await t.pumpWidget(
          MaterialApp(
            theme: VetDosisApp(model: core).theme(Brightness.light),
            home: Scaffold(
              body: SingleChildScrollView(
                child: const DoseMathTools(visualReference: true),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        if (example.key != DoseMathMode.concentration) {
          final picker = find.byType(DropdownButtonFormField<DoseMathMode>);
          await t.ensureVisible(picker);
          await t.tap(picker);
          await t.pumpAndSettle();
          await t.tap(find.text(example.key.label).last);
          await t.pumpAndSettle();
        }
        for (final input in example.value.values.entries) {
          final field = find.byKey(ValueKey(input.key));
          await t.ensureVisible(field);
          await t.enterText(field, input.value);
        }
        final action = find.text(
          example.key == DoseMathMode.conversion
              ? 'Convertir unidades'
              : 'Calcular volumen',
        );
        await t.ensureVisible(action);
        await t.tap(action);
        await t.pumpAndSettle();
        expect(find.text(example.value.result), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        core.dispose();
      },
    );
  }
}

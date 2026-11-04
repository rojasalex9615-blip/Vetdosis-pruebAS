import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/core/app.dart';
import 'package:vetdosis_pro/core/widgets/calculator_surface.dart';
import 'package:vetdosis_pro/core/widgets/neu_identity.dart';
import 'package:vetdosis_pro/modules/core/data/settings_repository.dart';
import 'package:vetdosis_pro/modules/core/presentation/core_view_model.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('Calculator action contrast in $brightness', (tester) async {
      final core = CoreViewModel(
        SettingsRepository(),
        const AppSettings(visualStyle: 'neu'),
      );
      final theme = VetDosisApp(model: core).theme(brightness);
      for (final id in [
        'dose',
        'concentration',
        'manufacturer',
        'fluids',
        'cri',
        'water',
        'metabolic',
        'adjustment',
      ]) {
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: CalculatorActionButton(
                id: id,
                onPressed: () => taps++,
                child: const Text('Calcular'),
              ),
            ),
          ),
        );
        final base = tester
            .widget<NeuPrimaryButton>(find.byType(NeuPrimaryButton))
            .color!;
        final button = tester.widget<FilledButton>(find.byType(FilledButton));
        final foreground = button.style!.foregroundColor!.resolve({})!;
        for (final background in [
          base,
          Color.lerp(
            base,
            Colors.white,
            brightness == Brightness.dark ? .06 : .24,
          )!,
        ]) {
          final a = foreground.computeLuminance();
          final b = background.computeLuminance();
          final contrast = ((a > b ? a : b) + .05) / ((a < b ? a : b) + .05);
          expect(
            contrast,
            greaterThanOrEqualTo(4.5),
            reason: '$id $brightness',
          );
        }
        // Some dose calculators use the shared soft button directly.
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: NeuPrimaryButton(
                soft: true,
                color: calculatorPastel(id),
                onPressed: () => taps++,
                child: const Text('Calcular'),
              ),
            ),
          ),
        );
        final pastel = calculatorPastel(id).computeLuminance();
        final directButton = tester.widget<FilledButton>(
          find.byType(FilledButton),
        );
        final directInk = directButton.style!.foregroundColor!
            .resolve({})!
            .computeLuminance();
        final directContrast =
            ((pastel > directInk ? pastel : directInk) + .05) /
            ((pastel < directInk ? pastel : directInk) + .05);
        expect(
          directContrast,
          greaterThanOrEqualTo(4.5),
          reason: 'Direct soft $id $brightness',
        );
        await tester.tap(find.byType(FilledButton));
        expect(taps, 1);
      }
      await tester.pumpWidget(const SizedBox());
      core.dispose();
    });
  }
}

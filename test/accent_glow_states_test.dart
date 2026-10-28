import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/core/app.dart';
import 'package:vetdosis_pro/core/widgets/accent_glow.dart';
import 'package:vetdosis_pro/modules/core/data/settings_repository.dart';
import 'package:vetdosis_pro/modules/core/presentation/core_view_model.dart';

void main() {
  test('Glow follows visual style in both brightness modes', () {
    for (final style in ['neu', 'standard']) {
      final core = CoreViewModel(
        SettingsRepository(),
        AppSettings(visualStyle: style),
      );
      for (final brightness in Brightness.values) {
        final theme = VetDosisApp(model: core).theme(brightness);
        expect(theme.extension<AccentGlowStyle>()?.enabled, style == 'neu');
      }
      core.dispose();
    }
  });

  testWidgets('Selection, disabled state and edits survive glow toggles', (
    tester,
  ) async {
    final chipKey = GlobalKey();
    var selected = false;
    var enabled = true;
    var glow = true;
    late StateSetter update;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return MaterialApp(
            theme: ThemeData(extensions: [AccentGlowStyle(enabled: glow)]),
            home: Scaffold(
              body: Column(
                children: [
                  const TextField(key: ValueKey('input')),
                  glowChip(
                    ChoiceChip(
                      key: chipKey,
                      label: const Text('Filtro'),
                      selected: selected,
                      onSelected: enabled
                          ? (value) => setState(() => selected = value)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    bool paintsHalo() =>
        tester
            .widget<CustomPaint>(
              find
                  .descendant(
                    of: find.byType(AccentGlow),
                    matching: find.byType(CustomPaint),
                  )
                  .first,
            )
            .painter !=
        null;
    expect(paintsHalo(), isFalse);
    await tester.enterText(find.byType(TextField), '12.5');
    await tester.tap(find.byType(ChoiceChip));
    await tester.pumpAndSettle();
    expect(selected, isTrue);
    expect(paintsHalo(), isTrue);
    update(() => glow = false);
    await tester.pumpAndSettle();
    expect(paintsHalo(), isFalse);
    expect(find.text('12.5'), findsOneWidget);
    expect(tester.widget<ChoiceChip>(find.byType(ChoiceChip)).selected, isTrue);
    update(() {
      glow = true;
      enabled = false;
    });
    await tester.pumpAndSettle();
    expect(paintsHalo(), isFalse);
    expect(tester.takeException(), isNull);
  });
}

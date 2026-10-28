import 'package:vetdosis_pro/core/widgets/accent_glow.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetdosis_pro/core/app.dart';
import 'package:vetdosis_pro/modules/core/data/settings_repository.dart';
import 'package:vetdosis_pro/modules/core/presentation/core_view_model.dart';
import 'package:vetdosis_pro/modules/doses/presentation/dose_math_tools.dart';

// One real calculator, opt-in presentation, fictional arithmetic inputs.
void main() {
  for (final example in [
    (glow: false, compact: false),
    (glow: true, compact: false),
    (glow: true, compact: true),
  ]) {
    final compact = example.compact;
    final glow = example.glow;
    testWidgets(
      'Glow reference ${glow ? 'on' : 'off'}: ${compact ? '320dp' : 'capture'}',
      (t) async {
        t.view.physicalSize = Size(compact ? 320 : 430, compact ? 1000 : 1420);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final previousShadows = debugDisableShadows;
        debugDisableShadows = false;
        try {
          SharedPreferences.setMockInitialValues({});
          await (FontLoader(
            'Roboto',
          )..addFont(rootBundle.load('assets/fonts/DejaVuSans.ttf'))).load();
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
          final core = CoreViewModel(
            SettingsRepository(),
            const AppSettings(visualStyle: 'neu'),
          );
          var patientOpened = 0;
          final capture = GlobalKey();
          await t.pumpWidget(
            MaterialApp(
              theme: VetDosisApp(model: core)
                  .theme(Brightness.light)
                  .copyWith(
                    extensions: [
                      ...VetDosisApp(
                        model: core,
                      ).theme(Brightness.light).extensions.values,
                      AccentGlowStyle(enabled: glow),
                    ],
                  ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(compact ? 1.6 : 1)),
                child: child!,
              ),
              home: RepaintBoundary(
                key: capture,
                child: Scaffold(
                  appBar: AppBar(
                    title: Text(
                      glow
                          ? 'Glow suave · referencia'
                          : 'Sin glow · comparación',
                    ),
                    bottom: const PreferredSize(
                      preferredSize: Size.fromHeight(28),
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Text(
                          'Valores ficticios · ejemplo aritmético',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: DoseMathTools(
                      visualReference: true,
                      onChoosePatient: () async {
                        patientOpened++;
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          final shortcut = find.text('Elegir paciente, peso y fármaco');
          await t.ensureVisible(shortcut);
          await t.tap(shortcut);
          await t.pumpAndSettle();
          expect(patientOpened, 1);
          for (final entry in {
            'weight': '12.5',
            'dose': '2',
            'concentration': '25',
          }.entries) {
            final field = find.byKey(ValueKey(entry.key));
            await t.ensureVisible(field);
            await t.enterText(field, entry.value);
          }
          final calculate = find.text('Calcular volumen');
          await t.ensureVisible(calculate);
          await t.tap(calculate);
          await t.pumpAndSettle();
          expect(find.text('1 mL'), findsOneWidget);
          expect(t.takeException(), isNull);
          if (!compact) {
            await t.drag(
              find.byType(SingleChildScrollView).first,
              const Offset(0, 2000),
            );
            await t.pumpAndSettle();
            await t.runAsync(() async {
              final picture =
                  await (capture.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage();
              final bytes = await picture.toByteData(
                format: ui.ImageByteFormat.png,
              );
              const directory = String.fromEnvironment(
                'GLOW_PREVIEW_DIR',
                defaultValue: 'review/accent-glow-preview-20261028',
              );
              final file = File('$directory/${glow ? 'glow' : 'sin-glow'}.png');
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              picture.dispose();
            });
          }
          // Edits invalidate the result through the existing controller callback.
          await t.ensureVisible(find.byKey(const ValueKey('dose')));
          await t.enterText(find.byKey(const ValueKey('dose')), '0');
          await t.pump();
          expect(find.text('1 mL'), findsNothing);
          await t.ensureVisible(calculate);
          await t.tap(calculate);
          await t.pumpAndSettle();
          expect(find.textContaining('mayor que cero'), findsOneWidget);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
          core.dispose();
        } finally {
          debugDisableShadows = previousShadows;
        }
      },
    );
  }
}

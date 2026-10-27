import 'dart:io';
import 'package:vetdosis_pro/modules/calculations/data/calculation_repository.dart';
import 'package:vetdosis_pro/modules/calculations/domain/calculation_catalog.dart';
import 'package:vetdosis_pro/modules/doses/data/catalog_repository.dart';
import 'package:vetdosis_pro/modules/doses/domain/catalog.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetdosis_pro/core/app.dart';
import 'package:vetdosis_pro/modules/core/data/settings_repository.dart';
import 'package:vetdosis_pro/modules/core/presentation/core_view_model.dart';
import 'package:vetdosis_pro/modules/calculations/presentation/calculation_screen.dart';
import 'package:vetdosis_pro/modules/doses/presentation/dose_math_tools.dart';

// Real calculator widgets with asset references only. No patient/clinic data.
class PreviewCalculations implements CalculationRepository {
  PreviewCalculations(this.value);
  final CalculationCatalog value;
  @override
  Future<CalculationCatalog> load() async => value;
}

class PreviewDoses implements CatalogRepository {
  PreviewDoses(this.value);
  final DoseCatalog value;
  @override
  Future<DoseCatalog> load() async => value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CalculationCatalog calculations;
  late DoseCatalog doses;
  setUpAll(() async {
    calculations = CalculationCatalog.parse(
      await rootBundle.loadString('assets/clinical/calculations.v1.json'),
    );
    doses = DoseCatalog.parse(
      await rootBundle.loadString('assets/clinical/catalog.v1.json'),
    );
  });
  for (final dark in [false, true]) {
    testWidgets('Capture calculator pastels ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      await (FontLoader(
        'Roboto',
      )..addFont(rootBundle.load('assets/fonts/DejaVuSans.ttf'))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      final core = CoreViewModel(
        SettingsRepository(),
        AppSettings(visualStyle: 'neu'),
      );
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: VetDosisApp(
            model: core,
          ).theme(dark ? Brightness.dark : Brightness.light),
          home: RepaintBoundary(
            key: key,
            child: Scaffold(
              body: SafeArea(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final tool in <Widget>[
                      DoseMathTools(),
                      CalculationScreen(
                        initialTool: 'cri',
                        repository: PreviewCalculations(calculations),
                        doses: PreviewDoses(doses),
                      ),
                      CalculationScreen(
                        initialTool: 'water',
                        repository: PreviewCalculations(calculations),
                        doses: PreviewDoses(doses),
                      ),
                    ])
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: tool,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final capture =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await capture.toByteData(format: ui.ImageByteFormat.png);
        final file = File(
          'review/calculator-pastels-20261027/${dark ? 'dark' : 'light'}.png',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        capture.dispose();
      });
      await tester.pumpWidget(const SizedBox());
      core.dispose();
    });
  }
  for (final tool in ['arithmetic', 'cri']) {
    testWidgets('Calculator $tool fits 320dp with enlarged text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final core = CoreViewModel(
        SettingsRepository(),
        const AppSettings(visualStyle: 'neu'),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: VetDosisApp(model: core).theme(Brightness.light),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 900),
              textScaler: TextScaler.linear(1.6),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: tool == 'arithmetic'
                    ? const DoseMathTools()
                    : CalculationScreen(
                        initialTool: 'cri',
                        repository: PreviewCalculations(calculations),
                        doses: PreviewDoses(doses),
                      ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Unidad: kg'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
      core.dispose();
    });
  }
}

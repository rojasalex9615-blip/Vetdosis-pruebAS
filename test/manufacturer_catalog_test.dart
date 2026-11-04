import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/doses/domain/manufacturer_catalog.dart';
import 'package:vetdosis_pro/modules/doses/presentation/manufacturer_catalog_screen.dart';
import 'package:vetdosis_pro/modules/doses/presentation/commercial_package_dose_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ManufacturerCatalog source;
  setUpAll(() async {
    source = await ManufacturerCatalog.load();
  });

  test(
    'all 662 source identities retain their report, original URL and research history',
    () async {
      final catalog = await ManufacturerCatalog.load();
      expect(catalog.products.length, 662);
      expect(catalog.products.map((p) => p.sourceUrl).toSet().length, 662);
      expect(catalog.products.map((p) => p.reportName).toSet().length, 47);
      expect(
        catalog.products.every(
          (p) =>
              p.reportText.isNotEmpty &&
              p.reportUrl.startsWith('https://drive.google.com/'),
        ),
        true,
      );
      expect(catalog.products.where((p) => p.name == 'NECAIN').length, 2);
      expect(catalog.historyText, contains('662/662'));
      expect(catalog.search('florgen genovet').single.name, 'FLORGEN 300');
      expect(catalog.search('acido').isNotEmpty, true);
    },
  );

  test(
    'missing reports and duplicate source IDs cannot silently publish an import',
    () async {
      final text = await rootBundle.loadString(
        'assets/clinical/manufacturer_research.v1.json',
      );
      final raw = jsonDecode(text) as Map<String, dynamic>;
      final first = (raw['products'] as List).first;
      (raw['reports'] as Map).remove(first['Grupo_verificacion']);
      expect(
        () => ManufacturerCatalog.parse(jsonEncode(raw)),
        throwsFormatException,
      );
      final duplicated = jsonDecode(text) as Map<String, dynamic>;
      (duplicated['products'] as List).add(
        (duplicated['products'] as List).first,
      );
      expect(
        () => ManufacturerCatalog.parse(jsonEncode(duplicated)),
        throwsFormatException,
      );
    },
  );

  testWidgets(
    'read-only catalog opens the evidence without offering calculation',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: ManufacturerCatalogScreen(catalog: source)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'FLORGEN 300');
      await tester.pumpAndSettle();
      expect(find.text('1 resultados'), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, 'FLORGEN 300'));
      await tester.pumpAndSettle();
      expect(find.text('Abrir ficha original PLM'), findsOneWidget);
      expect(find.text('Calcular según el empaque'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'product selection identifies manufacturer but never invents a numeric dose',
    (tester) async {
      final catalog = source;
      await tester.pumpWidget(
        MaterialApp(
          home: CommercialPackageDoseScreen(
            initialProduct: catalog.search('FLORGEN 300').single,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final name = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Nombre comercial',
      );
      await tester.scrollUntilVisible(
        name,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final field = tester.widget<TextField>(name);
      expect(field.controller!.text, 'FLORGEN 300');
      expect(field.readOnly, true);
      final instruction = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.labelText == 'Posología literal del empaque',
      );
      await tester.scrollUntilVisible(
        instruction,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<TextField>(instruction).controller!.text, isEmpty);
      expect(find.text('Cantidad aritmética del producto'), findsNothing);
    },
  );
}

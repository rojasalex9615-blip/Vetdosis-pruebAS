import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/doses/domain/commercial_package_dose.dart';
import 'package:vetdosis_pro/modules/doses/domain/manufacturer_pauta.dart';
import 'package:vetdosis_pro/modules/doses/domain/quantity.dart';
import 'package:vetdosis_pro/modules/doses/presentation/commercial_package_dose_screen.dart';

CommercialPackageDose fictionalPackage({
  String amount = '1',
  String perKg = '10',
  CommercialPackageUnit unit = CommercialPackageUnit.tablet,
}) => CommercialPackageDose(
  productName: 'Producto ficticio',
  presentation: 'Tableta de prueba ficticia',
  labelInstruction: '1 tableta por 10 kg (ejemplo aritmético no clínico)',
  quantityOnLabel: Quantity.parse(amount),
  forWeightKg: Quantity.parse(perKg),
  unit: unit,
);

void main() {
  test('25 kg at 1 tablet per 10 kg yields 2 tablets and a half', () {
    final r = fictionalPackage().calculate(
      Quantity.parse('25'),
      tabletPartsAllowed: 2,
    );
    expect(r.amount.display(), '2,5');
    expect(r.quantityText, '2 tabletas + 1/2 de tableta');
    expect(r.tablets!.exactlyDivisible, true);
    expect(r.tablets!.fractionWarning, isNull);
  });

  test('quarter and three-quarter tablets are represented exactly', () {
    expect(
      fictionalPackage().calculate(
        Quantity.parse('12.5'),
        tabletPartsAllowed: 4,
      ).quantityText,
      '1 tableta + 1/4 de tableta',
    );
    expect(
      fictionalPackage().calculate(
        Quantity.parse('7.5'),
        tabletPartsAllowed: 4,
      ).quantityText,
      '3/4 de tableta',
    );
    expect(
      fictionalPackage().calculate(
        Quantity.parse('5'),
        tabletPartsAllowed: 4,
      ).quantityText,
      '1/2 de tableta',
    );
  });

  test('do not propose half tablet unless package explicitly allows it', () {
    final noSplit = fictionalPackage().calculate(Quantity.parse('25'));
    expect(noSplit.tabletFractionRepresentable, false);
    expect(noSplit.tablets!.fractionWarning, contains('No redondear'));
    expect(noSplit.quantityText, contains('2,5'));

    final onlyHalves = fictionalPackage().calculate(
      Quantity.parse('12.5'),
      tabletPartsAllowed: 2,
    );
    expect(onlyHalves.tabletFractionRepresentable, false);
  });

  test('no rounding to represent an unavailable fraction', () {
    final result = fictionalPackage().calculate(
      Quantity.parse('10'),
      tabletPartsAllowed: 4,
    );
    expect(result.tabletFractionRepresentable, true);
    final repeating = fictionalPackage(perKg: '3').calculate(
      Quantity.parse('1'),
      tabletPartsAllowed: 4,
    );
    expect(repeating.tabletFractionRepresentable, false);
    expect(repeating.tablets!.fractionWarning, isNotNull);
  });

  test('non-tablet units never get a tablet breakdown', () {
    final r = fictionalPackage(
      unit: CommercialPackageUnit.ml,
    ).calculate(Quantity.parse('25'));
    expect(r.quantityText, '2,5 mL');
    expect(r.tablets, isNull);
  });

  test('missing product label and nonpositive parameters do not calculate', () {
    expect(
      () => fictionalPackage().calculate(Quantity.parse('0')),
      throwsFormatException,
    );
    expect(
      () => fictionalPackage(amount: '0').calculate(Quantity.parse('10')),
      throwsFormatException,
    );
    expect(
      () => fictionalPackage().calculate(
        Quantity.parse('10'),
        tabletPartsAllowed: 3,
      ),
      throwsFormatException,
    );
    final blank = CommercialPackageDose(
      productName: ' ',
      presentation: 'test',
      labelInstruction: 'test',
      quantityOnLabel: Quantity.parse('1'),
      forWeightKg: Quantity.parse('10'),
      unit: CommercialPackageUnit.tablet,
    );
    expect(
      () => blank.calculate(Quantity.parse('10')),
      throwsFormatException,
    );
  });

  testWidgets('Commercial tab identifies itself as package-based', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: CommercialPackageDoseScreen(),
    ));
    expect(find.text('Vademécum comercial'), findsOneWidget);
    expect(find.text('Dosificar según el empaque'), findsOneWidget);
    expect(find.textContaining('no se precargan automáticamente'), findsOneWidget);
    // Sin pauta precargada no hay aviso de dato en revisión.
    expect(find.text(unvalidatedPautaNotice), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'una pauta del fabricante avisa en pantalla y en el resultado',
    (tester) async {
      // El asset se lee fuera de la zona de tiempo falso del test; dentro de
      // ella la carga se queda esperando y agota el tiempo.
      final catalog = await tester.runAsync(ManufacturerPautaCatalog.load);
      final pauta = catalog!.pautas.firstWhere(
        (p) => p.canCalculate && p.calculator == PautaCalculator.package,
      );
      await tester.pumpWidget(MaterialApp(
        home: CommercialPackageDoseScreen(initialPauta: pauta),
      ));
      await tester.pumpAndSettle();

      // Aviso fijo en la pantalla, antes de calcular.
      expect(find.text(unvalidatedPautaNotice), findsOneWidget);

      // El profesional confirma y calcula con un peso.
      final product = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Nombre comercial',
      );
      await tester.scrollUntilVisible(
        product,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(product, 'RESPIFLOX');

      final weight = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Peso del animal (kg)',
      );
      await tester.scrollUntilVisible(
        weight,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(weight, '20');

      final confirm = find.text('La pauta del empaque es proporcional al peso');
      await tester.scrollUntilVisible(
        confirm,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      final button = find.text('Calcular cantidad según empaque');
      await tester.scrollUntilVisible(
        button,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(button);
      await tester.pumpAndSettle();

      // El resultado existe y vuelve a llevar el aviso, sin confundirse con
      // un resultado aprobado.
      expect(find.text('Cantidad aritmética del producto'), findsOneWidget);
      expect(find.text(unvalidatedPautaNotice), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
}

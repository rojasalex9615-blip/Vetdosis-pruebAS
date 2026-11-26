import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/doses/domain/dosis_farmacologica.dart';
import 'package:vetdosis_pro/modules/doses/domain/pauta_farmacologica.dart';
import 'package:vetdosis_pro/modules/doses/domain/quantity.dart';
import 'package:vetdosis_pro/modules/doses/presentation/farmacologico_dose_screen.dart';

const _catalogo = '''
{"schema_version":1,"version":"prueba","farmacos":[
  {"id":"F1","principio_activo":"Fenbendazol","grupo_clasificacion":"II"},
  {"id":"F2","principio_activo":"Metadona","grupo_clasificacion":null}],
 "dosis":[
  {"id":"D1","id_farmaco":"F1","especie":"Perro y gato","especies":["Perro","Gato"],
   "indicacion":"Parásitos","dosis_original":"50","unidad_original":"mg/kg",
   "dosis_min":"50","dosis_max":"50","base_calculo":"masa","via":"oral",
   "intervalo":"cada 24 h","autor":"Ramsey, I. (ed.) / BSAVA","anio":2017,
   "edicion_pagina":"274"},
  {"id":"D2","id_farmaco":"F1","especie":"Perro y gato","especies":["Perro","Gato"],
   "indicacion":"Giardia","dosis_original":"25–50","unidad_original":"mg/kg",
   "dosis_min":"25","dosis_max":"50","base_calculo":"masa",
   "autor":"Ramsey, I. (ed.) / BSAVA","anio":2017,"edicion_pagina":"275"},
  {"id":"D3","id_farmaco":"F2","especie":"Perro","especies":["Perro"],
   "indicacion":"Analgesia","dosis_original":"0,1–0,5","unidad_original":"mg/kg",
   "dosis_min":"0.1","dosis_max":"0.5","base_calculo":"masa",
   "autor":"Ramsey, I. (ed.) / BSAVA","anio":2017,"edicion_pagina":"300"}]}
''';

PautaFarmacologica _pauta(String id) =>
    FarmacologicoCatalog.parse(_catalogo).pautas.firstWhere((p) => p.id == id);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FarmacologicoCatalog catalog;

  setUpAll(() async {
    catalog = FarmacologicoCatalog.parse(_catalogo);
  });

  group('cálculo de la dosis', () {
    test('la dosis fija se multiplica por el peso sin redondear', () {
      final dosis = calcularDosisFarmacologica(
        pauta: _pauta('D1'),
        peso: Quantity.parse('10'),
      );
      expect(dosis, isNotNull);
      expect(dosis!.texto, '500 mg');
      expect(dosis.esRango, false);
    });

    test('un rango sigue siendo rango', () {
      final dosis = calcularDosisFarmacologica(
        pauta: _pauta('D2'),
        peso: Quantity.parse('10'),
      );
      expect(dosis!.texto, '250–500 mg');
      expect(dosis.esRango, true);
    });

    test('con decimales no aparece el error de la coma flotante', () {
      final dosis = calcularDosisFarmacologica(
        pauta: _pauta('D3'),
        peso: Quantity.parse('3'),
      );
      expect(dosis!.minimas.display(), '0,3');
      expect(dosis.maximas.display(), '1,5');
    });

    test('un peso de cero no calcula', () {
      expect(
        calcularDosisFarmacologica(
          pauta: _pauta('D1'),
          peso: Quantity.parse('0'),
        ),
        isNull,
      );
    });

    test('una pauta en mg/m² no se calcula por peso', () {
      final pauta = FarmacologicoCatalog.parse(
        '{"schema_version":1,"version":"x","farmacos":['
        '{"id":"F1","principio_activo":"Vincristina"}],"dosis":['
        '{"id":"D1","id_farmaco":"F1","especies":["Perro"],'
        '"dosis_min":"2","dosis_max":"2"}]}',
      ).pautas.single;
      expect(pauta.calculable, false);
      expect(
        calcularDosisFarmacologica(pauta: pauta, peso: Quantity.parse('10')),
        isNull,
      );
    });
  });

  group('pantalla', () {
    Future<void> abrir(WidgetTester tester) async {
      // Pantalla alta: con el alto por defecto la tarjeta del resultado queda
      // fuera del ListView y no llega a construirse.
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: FarmacologicoDoseScreen(catalog: catalog)),
      );
      await tester.pumpAndSettle();
    }

    Future<void> elegirEspecie(WidgetTester tester, String especie) async {
      await tester.tap(find.text('Especie'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(especie).last);
      await tester.pumpAndSettle();
    }

    testWidgets('sin especie no muestra dosis', (tester) async {
      await abrir(tester);
      expect(find.textContaining('Elige la especie'), findsOneWidget);
      expect(find.text('Fenbendazol'), findsNothing);
    });

    testWidgets('la especie filtra los principios con pauta', (tester) async {
      await abrir(tester);
      await elegirEspecie(tester, 'Gato');
      expect(find.text('Fenbendazol'), findsWidgets);
    });

    testWidgets('el veterinario elige la pauta y el peso da la dosis', (
      tester,
    ) async {
      await abrir(tester);
      await elegirEspecie(tester, 'Perro');
      await tester.tap(find.text('Fenbendazol').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('La app no elige por ti'), findsOneWidget);
      await tester.tap(find.text('Giardia'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '10');
      await tester.pumpAndSettle();
      expect(find.text('250–500 mg'), findsOneWidget);
      expect(find.textContaining('p. 275'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('las dos pautas del principio se ofrecen por separado', (
      tester,
    ) async {
      await abrir(tester);
      await elegirEspecie(tester, 'Perro');
      await tester.tap(find.text('Fenbendazol').first);
      await tester.pumpAndSettle();
      expect(find.text('Parásitos'), findsOneWidget);
      expect(find.text('Giardia'), findsOneWidget);
    });
  });
}

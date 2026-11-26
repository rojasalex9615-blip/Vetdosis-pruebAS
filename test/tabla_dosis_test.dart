import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/calculations/domain/calculation_branch.dart';
import 'package:vetdosis_pro/modules/core/presentation/core_view_model.dart';
import 'package:vetdosis_pro/modules/doses/domain/manufacturer_pauta.dart';
import 'package:vetdosis_pro/modules/doses/domain/pauta_farmacologica.dart';
import 'package:vetdosis_pro/modules/doses/domain/tabla_dosis.dart';
import 'package:vetdosis_pro/modules/doses/presentation/tabla_dosis_screen.dart';

const _farmacologico = '''
{"schema_version":1,"version":"prueba","farmacos":[
  {"id":"F1","principio_activo":"Fenbendazol","grupo_clasificacion":"II"}],
 "dosis":[
  {"id":"D1","id_farmaco":"F1","especie":"Perro y gato","especies":["Perro","Gato"],
   "indicacion":"Parásitos","dosis_original":"50","unidad_original":"mg/kg",
   "dosis_min":"50","dosis_max":"50","base_calculo":"masa","via":"oral",
   "intervalo":"cada 24 h","duracion":"3 días",
   "condiciones_contraindicaciones":"No en gestación",
   "autor":"Ramsey, I. (ed.) / BSAVA","titulo":"BSAVA","anio":2017,
   "edicion_pagina":"274","estado_normalizacion":"verificada"},
  {"id":"D2","id_farmaco":"F1","especie":"Bovino","especies":["Bovino"],
   "indicacion":"Neumonía","dosis_min":"5","dosis_max":"10",
   "base_calculo":"masa","via":"i.m."}]}
''';

const _marcas = '''
{"schema_version":1,"note":"","pautas":[
  {"id":"m1","product_name":"PANACUR 10%","manufacturer":"LAB A",
   "product_url":"https://example.test/m1",
   "presentation":"Suspensión oral; frasco de 100 mL",
   "registro":"Q-1234","ingredients":"Fenbendazol",
   "ingredient_amount":"100","ingredient_unit":"mg","ingredient_base":"por mL",
   "species":"Caninos","indication":"Parásitos intestinales",
   "literal":"1 mL por 2 kg cada 24 h durante 3 días",
   "route":"Oral","dose_amount":"1","dose_unit":"mL",
   "dose_reference":"por 2 kg","rule":"proporcional al peso",
   "interval":"cada 24 horas","duration":"3 días",
   "age_weight_limits":"Mayores de 2 semanas",
   "contraindications":"No en hembras gestantes",
   "consulted_at":"2026-11-01","state":"sin verificar","warnings":[]}]}
''';

TablaDosis _tabla() => TablaDosis.desde(
  principios: FarmacologicoCatalog.parse(_farmacologico),
  marcas: ManufacturerPautaCatalog.parse(_marcas).pautas,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('el menú clínico ofrece la tabla como tercera opción', () {
    final rutas = calculationBranches[ClinicalBranch.small]!
        .map((e) => e.route)
        .toList();
    expect(
      rutas,
      containsAll([
        'Dosis por principio activo',
        'Dosis por empaque comercial',
        'Tabla acumulativa de dosis',
      ]),
    );
  });

  test('los dos vademécums de la app arman la tabla completa', () async {
    final tabla = await TablaDosisLoader.cargarReal();
    expect(tabla.dePrincipios, greaterThan(500));
    expect(tabla.deMarcas, greaterThan(500));
    expect(tabla.filas.length, tabla.dePrincipios + tabla.deMarcas);
    expect(
      tabla.filas.every((f) => f.columnas.length == 15),
      isTrue,
    );
    expect(tabla.especies, containsAll(['Bovinos', 'Perros', 'Aves']));
  });

  test('la tabla tiene las 15 columnas en cada fila', () {
    for (final fila in _tabla().filas) {
      expect(fila.columnas.length, 15);
      expect(fila.columnas.keys, [
        'Tipo',
        'Especie',
        'Principio activo',
        'Nombre comercial',
        'Presentación',
        'Indicación',
        'Dosis',
        'Vía',
        'Intervalo',
        'Duración',
        'Condiciones',
        'Edad y peso',
        'Fuente',
        'Año',
        'Estado',
      ]);
    }
  });

  test('principios y marcas conviven sin fundirse en una fila', () {
    final tabla = _tabla();
    expect(tabla.filas.length, 3);
    expect(tabla.dePrincipios, 2);
    expect(tabla.deMarcas, 1);

    final principio = tabla.filas.firstWhere(
      (f) => f.origen == OrigenDosis.principio,
    );
    expect(principio.principioActivo, 'Fenbendazol');
    expect(principio.nombreComercial, '—');
    expect(principio.dosis, '50 mg/kg');
    expect(principio.fuente, contains('BSAVA'));
    expect(principio.anio, '2017');
    expect(principio.estado, 'verificada');

    final marca = tabla.filas.singleWhere((f) => f.origen == OrigenDosis.marca);
    expect(marca.nombreComercial, 'PANACUR 10%');
    expect(marca.principioActivo, contains('Fenbendazol'));
    expect(marca.presentacion, contains('frasco de 100 mL'));
    expect(marca.dosis, contains('1 mL por 2 kg'));
    expect(marca.edadPeso, 'Mayores de 2 semanas');
    expect(marca.anio, '2026');
  });

  test('sin dato no se inventa: queda un guion', () {
    final bovino = _tabla().filas.firstWhere((f) => f.especie == 'Bovino');
    expect(bovino.intervalo, '—');
    expect(bovino.duracion, '—');
    expect(bovino.condiciones, '—');
    expect(bovino.fuente, '—', reason: 'esa pauta no cita libro');
  });

  test('buscar recorre las 15 columnas y respeta el origen', () {
    final tabla = _tabla();
    expect(tabla.buscar('panacur').single.nombreComercial, 'PANACUR 10%');
    expect(tabla.buscar('neumonia').single.especie, 'Bovino');
    expect(tabla.buscar('gestacion').single.origen, OrigenDosis.principio);
    expect(tabla.buscar('', origen: OrigenDosis.marca).length, 1);
    expect(tabla.buscar('', especie: 'Bovinos').single.especie, 'Bovino');
    expect(tabla.buscar('', especie: 'Perros').length, 2);
  });

  test('el CSV lleva encabezado de 15 columnas y una fila por pauta', () {
    final csv = tablaDosisCsv(_tabla().filas);
    expect(csv.startsWith('\uFEFF'), isTrue, reason: 'Excel necesita el BOM');
    final lineas = csv.substring(1).split('\r\n')..removeLast();
    expect(lineas.first, columnasTablaDosis.join(','));
    expect(lineas.length, 4);
    expect(lineas[1].split(',').first, 'Principio activo');
    expect(lineas.last.split(',').first, 'Marca comercial');
  });

  test('el CSV entrecomilla comas y comillas sin perder la coma decimal', () {
    final fila = FilaDosis(
      id: 'x',
      origen: OrigenDosis.marca,
      especie: 'Perros',
      grupos: const ['Perros'],
      principioActivo: 'Fenbendazol',
      nombreComercial: 'MARCA "ESPECIAL"',
      presentacion: 'Frasco 100 mL; caja',
      indicacion: 'Parásitos, giardia y más',
      dosis: '0,5 mL por 10 kg',
      via: 'Oral',
      intervalo: 'cada 24 h',
      duracion: '3 días',
      condiciones: '—',
      edadPeso: '—',
      fuente: 'LAB A',
      anio: '2026',
      estado: 'sin verificar',
    );
    final csv = tablaDosisCsv([fila], conBom: false, finLinea: '\n');
    final linea = csv.split('\n').firstWhere((l) => l.isNotEmpty && !l.startsWith('Tipo'));
    expect(linea, contains('"MARCA ""ESPECIAL"""'));
    expect(linea, contains('"Parásitos, giardia y más"'));
    expect(linea, contains('"0,5 mL por 10 kg"'));
    expect(linea, contains('"Frasco 100 mL; caja"'));
  });

  group('pantalla', () {
    testWidgets('muestra las dos fuentes con su conteo', (tester) async {
      tester.view.physicalSize = const Size(390, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: TablaDosisLoader(tabla: _tabla()))),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('2 de principios activos'),
        findsOneWidget,
      );
      expect(find.textContaining('1 de marcas'), findsOneWidget);
      expect(find.text('PANACUR 10%'), findsOneWidget);
      expect(find.textContaining('50 mg/kg'), findsOneWidget);
      expect(find.textContaining('Presentación:'), findsWidgets);
      expect(find.textContaining('Estado:'), findsWidgets);
    });

    testWidgets('exporta a CSV exactamente lo que está filtrado', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final capturado = <(String, String)>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TablaDosisLoader(
              tabla: _tabla(),
              compartir: (nombre, contenido) async =>
                  capturado.add((nombre, contenido)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Exportar 3 filas a CSV'));
      await tester.pumpAndSettle();

      expect(capturado.single.$1, 'tabla-dosis-3-filas.csv');
      final lineas = capturado.single.$2.split('\r\n');
      expect(lineas.first, '\uFEFF${columnasTablaDosis.join(',')}');
      expect(lineas.length, 5, reason: 'encabezado y 3 pautas, más el vacío');
      expect(find.textContaining('CSV de 3 filas'), findsOneWidget);
    });

    testWidgets('el buscador filtra y el filtro de origen separa', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: TablaDosisLoader(tabla: _tabla()))),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar en las 15 columnas'),
        'panacur',
      );
      await tester.pumpAndSettle();
      expect(find.text('1 filas'), findsOneWidget);
      expect(find.text('PANACUR 10%'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar en las 15 columnas'),
        '',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Marca comercial'));
      await tester.pumpAndSettle();
      expect(find.text('1 filas'), findsOneWidget);
      expect(find.text('Fenbendazol'), findsNothing);
    });
  });
}

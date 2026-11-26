import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;
import 'package:vetdosis_pro/modules/doses/data/local_dose_record_store.dart';
import 'package:vetdosis_pro/modules/doses/data/syncing_dose_record_store.dart';
import 'package:vetdosis_pro/modules/doses/domain/dose_record.dart';
import 'package:vetdosis_pro/modules/doses/domain/dosis_farmacologica.dart';
import 'package:vetdosis_pro/modules/doses/domain/pauta_farmacologica.dart';
import 'package:vetdosis_pro/modules/doses/domain/peso_del_expediente.dart';
import 'package:vetdosis_pro/modules/doses/domain/quantity.dart';
import 'package:vetdosis_pro/modules/doses/presentation/farmacologico_dose_screen.dart';
import 'package:vetdosis_pro/modules/patients/domain/recorded_weight.dart';

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

/// Destino en la nube de mentira: dice que guardó y no toca red.
class RemotoFalso implements DoseRecordStore {
  final guardados = <DoseRecord>[];

  @override
  Future<DoseRecord> save(DoseRecord record) async {
    guardados.add(record);
    return record.marcarSincronizado(DateTime.utc(2026, 11, 26, 12));
  }

  @override
  Future<List<DoseRecord>> forPatient(
    String patientId, {
    int limit = 50,
  }) async => guardados;

  @override
  Future<List<DoseRecord>> recent({int limit = 50}) async => guardados;
}

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
    late LocalDoseRecordStore registros;
    setUp(() async {
      registros = LocalDoseRecordStore(
        await databaseFactoryMemory.openDatabase('guardado-widget'),
      );
    });

    Future<void> abrir(
      WidgetTester tester, {
      RecordedPatientWeight? peso,
      PesoDelExpediente? expediente,
      DoseRecordStore? almacen,
    }) async {
      // Pantalla alta: con el alto por defecto la tarjeta del resultado queda
      // fuera del ListView y no llega a construirse.
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FarmacologicoDoseScreen(
              catalog: catalog,
              recordedWeight: peso,
              pesoDelExpediente: expediente,
              records: almacen,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder campo(String etiqueta) => find.widgetWithText(TextField, etiqueta);

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
      await tester.enterText(campo('Peso en kg'), '10');
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

    Future<void> llegarAGiardia(
      WidgetTester tester, {
      String peso = '10',
    }) async {
      await elegirEspecie(tester, 'Perro');
      await tester.tap(find.text('Fenbendazol').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Giardia'));
      await tester.pumpAndSettle();
      await tester.enterText(campo('Peso en kg'), peso);
      await tester.pumpAndSettle();
    }

    testWidgets('la concentración del empaque da el volumen en mL', (
      tester,
    ) async {
      await abrir(tester);
      await llegarAGiardia(tester);
      expect(find.text('250–500 mg'), findsOneWidget);
      expect(find.textContaining('Volumen a administrar'), findsNothing);

      await tester.enterText(campo('Concentración en mg/mL'), '50');
      await tester.pumpAndSettle();
      expect(find.text('5–10 mL'), findsOneWidget);
      expect(find.textContaining('250–500 mg ÷ 50 mg/mL'), findsOneWidget);
    });

    testWidgets('una concentración de cero no inventa un volumen', (
      tester,
    ) async {
      await abrir(tester);
      await llegarAGiardia(tester);
      await tester.enterText(campo('Concentración en mg/mL'), '0');
      await tester.pumpAndSettle();
      expect(find.textContaining('Volumen a administrar'), findsNothing);
    });

    testWidgets('la jeringa redondea pero el número exacto sigue a la vista', (
      tester,
    ) async {
      await abrir(tester);
      await llegarAGiardia(tester, peso: '3');
      await tester.enterText(campo('Concentración en mg/mL'), '50');
      await tester.pumpAndSettle();
      // 25–50 mg/kg × 3 kg = 75–150 mg; entre 50 mg/mL = 1,5–3 mL.
      expect(find.text('1,5–3 mL'), findsOneWidget);
      await tester.tap(find.text('Jeringa 0,1 mL'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Jeringa de 0,1 mL:'), findsOneWidget);
      expect(find.text('1,5–3 mL'), findsOneWidget);
    });

    testWidgets('el peso registrado viene del paciente y no se escribe', (
      tester,
    ) async {
      await abrir(
        tester,
        peso: RecordedPatientWeight(
          id: 'W1',
          clinicId: 'C1',
          patientId: 'P1',
          patientName: 'Anestesia',
          caseId: 'K1',
          kg: '10',
          observedAt: DateTime.utc(2026, 11, 26, 9),
          performedBy: 'MVZ Rojas',
          recordedBy: 'MVZ Rojas',
          recordedAt: DateTime.utc(2026, 11, 26, 9, 5),
        ),
      );
      expect(find.text('Anestesia'), findsOneWidget);
      expect(find.textContaining('Peso medido: 10 kg'), findsOneWidget);
      await elegirEspecie(tester, 'Perro');
      await tester.tap(find.text('Fenbendazol').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Giardia'));
      await tester.pumpAndSettle();
      final peso = tester.widget<TextField>(campo('Peso en kg'));
      expect(peso.readOnly, isTrue);
      expect(find.text('250–500 mg'), findsOneWidget);
    });

    testWidgets('el cálculo se guarda con su cita y su volumen', (
      tester,
    ) async {
      await abrir(
        tester,
        almacen: registros,
        peso: RecordedPatientWeight(
          id: 'W1',
          clinicId: 'C1',
          patientId: 'P1',
          patientName: 'Anestesia',
          caseId: 'K1',
          kg: '10',
          observedAt: DateTime.utc(2026, 11, 26, 9),
          performedBy: 'MVZ Rojas',
          recordedBy: 'MVZ Rojas',
          recordedAt: DateTime.utc(2026, 11, 26, 9, 5),
        ),
      );
      await llegarAGiardia(tester);
      await tester.enterText(campo('Concentración en mg/mL'), '50');
      await tester.pumpAndSettle();

      expect(find.textContaining('Guardar en la ficha de Anestesia'), findsOne);
      await tester.tap(find.textContaining('Guardar en la ficha de Anestesia'));
      // El guardado es asíncrono real: se deja correr fuera del reloj falso.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Cálculo guardado: 250–500 mg'),
        findsOneWidget,
      );

      final guardados = (await tester.runAsync(
        () => registros.forPatient('P1'),
      ))!;
      expect(guardados, hasLength(1));
      expect(guardados.single.principio, 'Fenbendazol');
      expect(guardados.single.indicacion, 'Giardia');
      expect(guardados.single.pesoKg, '10');
      expect(guardados.single.resultadoMg, '250–500 mg');
      expect(guardados.single.resultadoMl, '5–10 mL');
      expect(guardados.single.concentracionMgMl, '50');
      expect(guardados.single.cita, contains('p. 275'));
      // Sin nube, la pantalla dice la verdad: quedó en el dispositivo.
      expect(
        find.textContaining('En este dispositivo. Se envía a la ficha'),
        findsOneWidget,
      );
    });

    testWidgets('el peso del expediente viene puesto y queda ligado', (
      tester,
    ) async {
      final remoto = RemotoFalso();
      final almacen = SyncingDoseRecordStore(
        local: LocalDoseRecordStore(
          await databaseFactoryMemory.openDatabase('expediente-peso'),
        ),
        remote: remoto,
      );
      await abrir(
        tester,
        expediente: const PesoDelExpediente(
          clinicId: 'C1',
          patientId: 'P1',
          patientName: 'Anestesia',
          kg: '10',
          fecha: '2026-11-20',
        ),
        almacen: almacen,
      );

      expect(find.text('Anestesia'), findsOneWidget);
      expect(
        find.textContaining('Peso anotado en el expediente: 10 kg'),
        findsOneWidget,
      );
      expect(find.textContaining('2026-11-20'), findsOneWidget);

      await llegarAGiardia(tester);
      await tester.enterText(campo('Concentración en mg/mL'), '50');
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Guardar en la ficha de Anestesia'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();

      expect(remoto.guardados.single.patientId, 'P1');
      expect(remoto.guardados.single.pesoKg, '10');
      expect(find.textContaining('En la ficha del paciente'), findsOneWidget);
    });

    testWidgets('con nube el guardado dice que quedó en la ficha', (
      tester,
    ) async {
      final remoto = RemotoFalso();
      final almacen = SyncingDoseRecordStore(
        local: LocalDoseRecordStore(
          await databaseFactoryMemory.openDatabase('pantalla-nube'),
        ),
        remote: remoto,
      );
      await abrir(
        tester,
        almacen: almacen,
        peso: RecordedPatientWeight(
          id: 'W1',
          clinicId: 'C1',
          patientId: 'P1',
          patientName: 'Anestesia',
          caseId: 'K1',
          kg: '10',
          observedAt: DateTime.utc(2026, 11, 26, 9),
          performedBy: 'MVZ Rojas',
          recordedBy: 'MVZ Rojas',
          recordedAt: DateTime.utc(2026, 11, 26, 9, 5),
        ),
      );
      await llegarAGiardia(tester);
      await tester.enterText(campo('Concentración en mg/mL'), '50');
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Guardar en la ficha de Anestesia'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('En la ficha del paciente'), findsOneWidget);
      expect(remoto.guardados.single.patientId, 'P1');
      expect(remoto.guardados.single.clinicId, 'C1');
    });
  });

  group('volumen de empaque', () {
    Quantity mg(String value) => Quantity.parse(value);

    test('miligramos entre concentración da mililitros exactos', () {
      final volumen = volumenDeEmpaque(
        dosisMg: mg('250'),
        dosisMaximaMg: mg('500'),
        concentracionMgMl: mg('50'),
      );
      expect(volumen!.texto, '5–10 mL');
    });

    test('una dosis fija da un volumen fijo', () {
      final volumen = volumenDeEmpaque(
        dosisMg: mg('100'),
        concentracionMgMl: mg('20'),
      );
      expect(volumen!.texto, '5 mL');
    });

    test('los decimales no arrastran el error de la coma flotante', () {
      final volumen = volumenDeEmpaque(
        dosisMg: mg('0.3'),
        concentracionMgMl: mg('2'),
      );
      expect(volumen!.minimo.display(), '0,15');
    });

    test('sin concentración no hay volumen', () {
      expect(
        volumenDeEmpaque(dosisMg: mg('250'), concentracionMgMl: mg('0')),
        isNull,
      );
    });

    test('el redondeo de jeringa lleva el volumen a la graduación', () {
      final volumen = volumenDeEmpaque(
        dosisMg: mg('7.5'),
        dosisMaximaMg: mg('15'),
        concentracionMgMl: mg('50'),
      );
      expect(volumen!.redondeado(mg('0.1')), 'Jeringa de 0,1 mL: 0,2–0,3 mL');
      expect(volumen.redondeado(null), isNull);
    });
  });
}

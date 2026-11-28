import 'package:vetdosis_pro/modules/doses/domain/dose_record.dart'
    show volumenDeEmpaque;
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/doses/domain/dosis_farmacologica.dart';
import 'package:vetdosis_pro/modules/doses/domain/pauta_farmacologica.dart';
import 'package:vetdosis_pro/modules/doses/domain/quantity.dart';

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

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/aviculture/domain/poultry_formulas.dart';
import 'package:vetdosis_pro/modules/doses/domain/quantity.dart';

void main() {
  Quantity q(String s) => Quantity.parse(s);
  final catalog = PoultryFormulaCatalog.parseCsv(
    File(
      'assets/clinical/aviculture/formulas_avicola.v1.csv',
    ).readAsStringSync(),
  );
  const layers = LayerFormulas();
  const broilers = BroilerFormulas();

  test('CSV trae 12 fórmulas con fuente y estado', () {
    expect(catalog.formulas, hasLength(12));
    expect(catalog.formulas.every((f) => f.verified), isFalse);
    expect(
      catalog.byId('ic_engorda').title,
      'Conversion alimenticia (engorda)',
    );
    expect(catalog.byId('indice_productividad').note, contains('300'));
  });

  test('CSV rechaza encabezado incompleto y columnas de más', () {
    expect(
      () => PoultryFormulaCatalog.parseCsv('id,titulo\na,b'),
      throwsFormatException,
    );
    expect(
      () => PoultryFormulaCatalog.parseCsv(
        'id,titulo,formula,entradas,fuente,estado,nota\na,b',
      ),
      throwsFormatException,
    );
  });

  test('Conversión de engorda descuenta el peso del pollito', () {
    // 100 kg alimento / (50 − 2) kg de ganancia = 2.0833…
    final v = broilers.feedConversion(q('100'), q('50'), q('2'));
    expect(v.display(places: 4), '2,0833');
    expect(
      () => broilers.feedConversion(q('100'), q('2'), q('2')),
      throwsFormatException,
    );
    expect(
      () => broilers.feedConversion(q('0'), q('50'), q('2')),
      throwsFormatException,
    );
  });

  test('Ganancia diaria de peso', () {
    expect(broilers.dailyGain(q('2.5'), q('50')).display(places: 3), '0,05');
    expect(() => broilers.dailyGain(q('2.5'), q('0')), throwsFormatException);
  });

  test('Viabilidad, mortalidad y % postura', () {
    expect(layers.viability(q('980'), q('1000')).display(), '98');
    expect(
      layers.dailyMortality(q('2'), q('980')).display(places: 4),
      '0,2041',
    );
    expect(layers.accumulatedMortality(q('20'), q('1000')).display(), '2');
    expect(layers.layingPercent(q('850'), q('1000')).display(), '85');
    expect(() => layers.viability(q('980'), q('0')), throwsFormatException);
  });

  test('Peso de huevo y consumo convierten kg a gramos', () {
    // 60 kg × 1000 / 1000 huevos = 60 g.
    expect(layers.eggWeightGrams(q('60'), q('1000')).display(), '60');
    // 120 kg × 1000 / 1000 aves = 120 g/ave/día.
    expect(layers.intakeGramsPerBird(q('120'), q('1000')).display(), '120');
    expect(() => layers.eggWeightGrams(q('60'), q('0')), throwsFormatException);
  });

  test('Conversión de postura, masa de huevo e índice de productividad', () {
    expect(layers.feedConversion(q('120'), q('60')).display(), '2');
    // 85 % × 60 g / 100 = 51 g/ave/día.
    expect(layers.eggMassPerBirdDay(q('85'), q('60')).display(), '51');
    // (40000 / 500 / 2) × 100 = 4000.
    final ip = layers.productivityIndex(q('40000'), q('500'), q('2'));
    expect(ip.display(), '4000');
    expect(productivityIndexBand(ip), 'excelente (>300)');
    expect(productivityIndexBand(Quantity.parse('280')), 'bueno (260–299)');
    expect(productivityIndexBand(Quantity.parse('220')), 'regular (200–259)');
    expect(productivityIndexBand(Quantity.parse('150')), 'malo (<200)');
  });

  test('Índice de forma con sus categorías', () {
    expect(layers.shapeIndex(q('74'), q('100')).display(), '74');
    expect(shapeIndexBand(Quantity.parse('74')), 'óptimo (72–76)');
    expect(shapeIndexBand(Quantity.parse('70')), 'largo (<72)');
    expect(shapeIndexBand(Quantity.parse('80')), 'redondo (>76)');
    expect(() => layers.shapeIndex(q('74'), q('0')), throwsFormatException);
  });
}

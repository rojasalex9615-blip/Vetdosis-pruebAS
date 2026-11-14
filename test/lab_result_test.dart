import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/laboratory/domain/lab_result.dart';

LabReferenceRange range({
  String analyte = 'hematocrito',
  String species = 'Canino',
  String unit = '%',
  double low = 37,
  double high = 55,
  String source = 'Fuente de prueba',
}) => LabReferenceRange(
  analyteKey: analyte,
  species: species,
  unit: unit,
  low: low,
  high: high,
  source: source,
);

LabResult result(double v, {String unit = '%', String key = 'hematocrito'}) =>
    LabResult(analyteKey: key, value: v, unit: unit);

void main() {
  group('Lectura contra rango', () {
    final ranges = [range()];
    test('dentro, debajo, arriba y límites incluidos', () {
      expect(result(45).agreedFlag('Canino', ranges), LabFlag.withinRange);
      expect(result(37).agreedFlag('Canino', ranges), LabFlag.withinRange);
      expect(result(55).agreedFlag('Canino', ranges), LabFlag.withinRange);
      expect(result(36.9).agreedFlag('Canino', ranges), LabFlag.below);
      expect(result(55.1).agreedFlag('Canino', ranges), LabFlag.above);
    });

    test('sin rango para la especie no se juzga', () {
      expect(result(10).agreedFlag('Felino', ranges), LabFlag.noReference);
      expect(result(10).agreedFlag('Canino', const []), LabFlag.noReference);
    });

    test('unidad distinta no se convierte ni se juzga', () {
      expect(
        result(0.45, unit: 'L/L').agreedFlag('Canino', ranges),
        LabFlag.unitMismatch,
      );
    });

    test('mayúsculas y espacios no cambian la coincidencia', () {
      expect(
        result(45, key: ' Hematocrito ').agreedFlag(' canino', ranges),
        LabFlag.withinRange,
      );
    });

    test('dos fuentes: se muestran las dos, no se juntan', () {
      final two = [
        range(low: 37, high: 55),
        range(low: 35, high: 57, source: 'Otra'),
      ];
      // 36 queda bajo para una fuente y dentro para la otra. Antes la union
      // de los rangos lo daba por normal y se perdia que una fuente no lo
      // acepta. Ahora no hay lectura unica: se muestran las dos.
      final lecturas = result(36).readings('Canino', two);
      expect(lecturas.map((l) => l.flag), [LabFlag.below, LabFlag.withinRange]);
      expect(lecturas.map((l) => l.range!.source), [
        'Fuente de prueba',
        'Otra',
      ]);
      expect(result(36).agreedFlag('Canino', two), isNull);

      // Donde las dos coinciden si hay lectura unica.
      expect(result(45).agreedFlag('Canino', two), LabFlag.withinRange);
      expect(result(58).agreedFlag('Canino', two), LabFlag.above);
      expect(result(45).sourcesFor('Canino', two), [
        'Fuente de prueba',
        'Otra',
      ]);
    });
  });

  group('Validaciones', () {
    test('un rango sin fuente no existe', () {
      expect(() => range(source: '  '), throwsFormatException);
    });
    test('rango invertido', () {
      expect(() => range(low: 60, high: 50), throwsFormatException);
    });
    test('valor negativo o unidad vacía', () {
      expect(() => result(-1), throwsFormatException);
      expect(
        () => LabResult(analyteKey: 'x', value: 1, unit: ' '),
        throwsFormatException,
      );
    });
    test('lectura de texto: punto decimal, la coma se rechaza', () {
      expect(LabResult.parseValue('45.2'), 45.2);
      expect(LabResult.parseValue('1200'), 1200);
      expect(LabResult.parseValue('0.123'), 0.123);
      // En Mexico «1,200» son mil doscientos. Leyendo la coma como decimal
      // entraba como 1.2: mil veces menos, en silencio y en un dato clinico.
      expect(() => LabResult.parseValue('1,200'), throwsFormatException);
      expect(() => LabResult.parseValue('4,5'), throwsFormatException);
      expect(() => LabResult.parseValue('1,200.5'), throwsFormatException);
      expect(() => LabResult.parseValue('abc'), throwsFormatException);
    });
  });

  group('Toma de muestra', () {
    test('cuenta los resultados sin juicio', () {
      final panel = LabPanel(
        patientId: 'p1',
        species: 'Canino',
        collectedAt: DateTime(2026, 11, 8),
        results: [
          result(45),
          result(7, key: 'albumina', unit: 'g/dL'),
          result(0.4, unit: 'L/L', key: 'hematocrito2'),
        ],
      );
      final lecturas = panel.evaluate([range()]);
      expect(lecturas['hematocrito']!.single.flag, LabFlag.withinRange);
      expect(lecturas['albumina']!.single.flag, LabFlag.noReference);
      expect(panel.unjudged([range()]), 2);
      expect(panel.disputed([range()]), isEmpty);
    });

    test('no admite analito repetido ni toma vacía', () {
      expect(
        () => LabPanel(
          patientId: 'p',
          species: 'Canino',
          collectedAt: DateTime(2026),
          results: [result(40), result(41)],
        ),
        throwsFormatException,
      );
      expect(
        () => LabPanel(
          patientId: 'p',
          species: 'Canino',
          collectedAt: DateTime(2026),
          results: const [],
        ),
        throwsFormatException,
      );
    });
  });
}

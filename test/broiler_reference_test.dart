import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/aviculture/domain/broiler_reference.dart';
import 'package:vetdosis_pro/modules/doses/domain/quantity.dart';

void main() {
  Quantity q(String s) => Quantity.parse(s);
  final catalog = BroilerCatalog.parseCsv(
    File(
      'assets/clinical/aviculture/engorda_avicola.v1.csv',
    ).readAsStringSync(),
  );

  test('CSV parsea comillas y conserva el límite único de oxígeno', () {
    expect(catalog.refs, hasLength(51));
    final oxygen = catalog.refs.firstWhere(
      (r) => r.parameter == 'calidad_aire_oxigeno',
    );
    expect(oxygen.max, isEmpty);
    expect(oxygen.range, '≥ 19.6 %_minimo');
    final thermoneutral = catalog.refs.firstWhere(
      (r) => r.parameter == 'zona_termoneutral',
    );
    // La fuente trae una coma dentro de comillas: no debe partir la fila.
    expect(thermoneutral.source, contains('DISCREPANCIA'));
    expect(thermoneutral.range, '10–20 C');
    final alternative = catalog.refs.firstWhere(
      (r) => r.parameter == 'zona_termoneutral_alt_Salvador2017',
    );
    expect(alternative.alternative, isTrue);
    expect(catalog.refs.every((r) => r.verified), isFalse);
  });

  test('Densidad por día usa la fila correcta y no interpola', () {
    expect(catalog.densityForDay(1)!.stage, 'dias_1_3');
    expect(catalog.densityForDay(3)!.stage, 'dias_1_3');
    expect(catalog.densityForDay(4)!.stage, 'dias_4_6');
    expect(catalog.densityForDay(19)!.stage, 'dias_16_19');
    expect(catalog.densityForDay(21)!.stage, 'dias_21_adelante');
    expect(catalog.densityForDay(60)!.stage, 'dias_21_adelante');
    expect(catalog.densityForDay(0), isNull);
    // Hueco real en la fuente: 16–19 y luego 21+; el día 20 no está cubierto
    // y no se interpola.
    expect(catalog.densityForDay(20), isNull);
  });

  test('Capacidad por densidad redondea hacia abajo', () {
    final row = catalog.densityForDay(1)!;
    expect(broilerCapacity(q('10'), q(row.min)), BigInt.from(500));
    expect(broilerCapacity(q('10'), q(row.max)), BigInt.from(600));
    expect(broilerCapacity(q('10.5'), q('10')), BigInt.from(105));
    expect(() => broilerCapacity(q('0'), q('10')), throwsFormatException);
    expect(() => broilerCapacity(q('10'), q('0')), throwsFormatException);
  });

  test('Capacidad por carga del lote depende del sistema de ventilación', () {
    final open = catalog.maxDensityByVentilation(
      'lados_abiertos_ventilacion_natural',
    )!;
    expect(open.range, '30 kg_por_m2');
    // 100 m² × 30 kg/m² / 2.5 kg/ave = 1200 aves.
    expect(
      broilerBirdsByLoad(q('100'), q(open.min), q('2.5')),
      BigInt.from(1200),
    );
    final tunnel = catalog.maxDensityByVentilation(
      'paredes_solidas_tunel_enfriamiento_evaporativo',
    )!;
    expect(tunnel.range, '42 kg_por_m2');
    expect(catalog.maxDensityByVentilation('inexistente'), isNull);
  });

  test('Temperatura objetivo baja 3 °C por semana sin pasar de 18 °C', () {
    expect(broilerTargetTemperature(0).display(), '33');
    expect(broilerTargetTemperature(1).display(), '30');
    expect(broilerTargetTemperature(4).display(), '21');
    expect(broilerTargetTemperature(5).display(), '18');
    expect(broilerTargetTemperature(9).display(), '18');
    expect(() => broilerTargetTemperature(-1), throwsFormatException);
  });

  test('CSV rechaza rangos invertidos y columnas incompletas', () {
    const header =
        'etapa,sem_desde,sem_hasta,sistema,parametro,min,max,'
        'unidad,fuente,estado';
    expect(
      () =>
          BroilerCatalog.parseCsv('$header\na,,,piso,x,10,5,C,f,sin_verificar'),
      throwsFormatException,
    );
    expect(
      () => BroilerCatalog.parseCsv('$header\na,,,piso,x,10,15'),
      throwsFormatException,
    );
    expect(
      () => BroilerCatalog.parseCsv('$header\na,,,piso,x,,,C,f,sin_verificar'),
      throwsFormatException,
    );
  });
}

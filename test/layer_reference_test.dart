import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/aviculture/domain/layer_reference.dart';
import 'package:vetdosis_pro/modules/doses/domain/quantity.dart';

void main() {
  Quantity q(String s) => Quantity.parse(s);
  final csv = File(
    'assets/clinical/aviculture/postura_avicola_adicional.v1.csv',
  ).readAsStringSync();
  final catalog = LayerCatalog.parseCsv(csv);

  test('CSV trae 37 filas y respeta las comas dentro de comillas', () {
    expect(catalog.refs, hasLength(37));
    // La fila de crisis trae la causa entre comillas: no debe partirse.
    final crisis = catalog.byParameter('crisis_18_35_semanas').single;
    expect(crisis.isAlert, isTrue);
    expect(crisis.range, 'alerta');
    expect(crisis.source, contains('uniformidad'));
    expect(catalog.refs.every((r) => r.verified), isFalse);
  });

  test('Alternativa y sin verificar se distinguen', () {
    final alternative = catalog.byParameter(
      'espacio_por_ave_alternativa',
    ).single;
    expect(alternative.alternative, isTrue);
    expect(alternative.range, '400 cm2');
    expect(
      catalog.refs.where((r) => r.alternative),
      hasLength(1),
    );
  });

  test('CSV rechaza encabezado incompleto y columnas de más', () {
    expect(
      () => LayerCatalog.parseCsv('etapa,parametro\na,b'),
      throwsFormatException,
    );
    expect(
      () => LayerCatalog.parseCsv(
        'etapa,sem_desde,sem_hasta,sistema,parametro,min,max,unidad,fuente,estado\na,b',
      ),
      throwsFormatException,
    );
    expect(
      () => LayerCatalog.parseCsv(
        'etapa,sem_desde,sem_hasta,sistema,parametro,min,max,unidad,fuente,estado\n'
        'postura,,,ambos,x,9,1,mm,f,sin_verificar',
      ),
      throwsFormatException,
    );
  });

  test('Huevos por ave y año varía por sistema y no se elige solo', () {
    final intensive = catalog.byParameterSystem(
      'huevos_por_ave_por_ano',
      'intensivo_jaula',
    )!;
    expect(intensive.range, '300 huevos');
    expect(
      catalog
          .byParameterSystem('huevos_por_ave_por_ano', 'semiintensivo_piso')!
          .range,
      '150 huevos',
    );
    expect(
      catalog
          .byParameterSystem('huevos_por_ave_por_ano', 'extensivo_pastoreo')!
          .range,
      '60–70 huevos',
    );
    expect(
      catalog.byParameterSystem('huevos_por_ave_por_ano', 'inexistente'),
      isNull,
    );
  });

  test('Clase de peso del huevo usa cortes [min, max) y XL abierta', () {
    expect(
      catalog
          .eggWeightClassFor(q('40'))
          ?.parameter,
      'peso_huevo_S_pequeno',
    );
    expect(catalog.eggWeightClassFor(q('53'))?.parameter, 'peso_huevo_M_mediano');
    expect(catalog.eggWeightClassFor(q('62.9'))?.parameter, 'peso_huevo_M_mediano');
    expect(catalog.eggWeightClassFor(q('63'))?.parameter, 'peso_huevo_L_grande');
    expect(catalog.eggWeightClassFor(q('73'))?.parameter, 'peso_huevo_XL_super_grande');
    expect(catalog.eggWeightClassFor(q('90'))?.parameter, 'peso_huevo_XL_super_grande');
  });

  test('Categoría de cámara de aire: A hasta 6 mm, B hasta 9 mm', () {
    expect(catalog.airCellCategoryFor(q('3'))?.stage, 'categoria_A');
    expect(catalog.airCellCategoryFor(q('6'))?.stage, 'categoria_A');
    expect(catalog.airCellCategoryFor(q('7'))?.stage, 'categoria_B');
    expect(catalog.airCellCategoryFor(q('9'))?.stage, 'categoria_B');
    expect(catalog.airCellCategoryFor(q('10')), isNull);
  });

  test('Plan de luz conserva estímulo, incremento, meta e intensidad', () {
    final lighting = catalog.lighting;
    expect(
      lighting.map((r) => r.parameter),
      containsAll(<String>[
        'inicio_estimulo_luz',
        'aumento_inicial_luz_minimo',
        'incremento_luz',
        'horas_luz_meta',
        'intensidad_luz_a_nivel_comedero',
      ]),
    );
    expect(
      catalog.byParameter('inicio_estimulo_luz').single.range,
      '17–18 semanas',
    );
    expect(catalog.byParameter('horas_luz_meta').single.range, '16 horas');
  });

  test('Curva mensual y ponedora eficiente quedan completas', () {
    expect(catalog.byParameter('huevos_por_ave_mes'), hasLength(4));
    expect(catalog.byParameter('peso_huevo'), hasLength(4));
    expect(
      catalog.refs.where((r) => r.parameter.startsWith('parametro_eficiente')),
      hasLength(6),
    );
    expect(
      catalog.byParameter('parametro_eficiente_viabilidad').single.range,
      '94 %',
    );
  });
}

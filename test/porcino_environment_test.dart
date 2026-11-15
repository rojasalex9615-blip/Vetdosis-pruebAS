import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/production/domain/porcino_environment.dart';

/// Fija los datos del CSV
/// `VetDosis_Dictamen_Ambiental_Yucatan_SEMARNAT.csv` (SEMARNAT, marzo 2023):
/// ecuaciones, parámetros del NCA y reparto de municipios.
void main() {
  test('El reparto de municipios suma 51 y cuadra con el dictamen', () {
    const municipal = PorcinoMunicipalNca();
    expect(municipal.critical, 26);
    expect(municipal.urgent, 4);
    expect(municipal.sustainable, 21);
    expect(municipal.total, 51);
  });

  test('Los parámetros del NCA conservan los valores del dictamen', () {
    final byId = {for (final r in porcinoEnvironmentRefs) r.id: r};
    expect(byId['carga_nitrogeno_por_cerdo']!.valor, '18');
    expect(byId['carga_nitrogeno_por_cerdo']!.unidad, 'kg N/cerdo/año');
    expect(byId['cnat_nitrogeno']!.valor, '1.5');
    expect(byId['cmax_propuesto_doble_natural']!.valor, '3.0');
    expect(byId['cmax_ajustado_otras_fuentes']!.valor, '10.0');
    expect(byId['recarga_anual_acuifero']!.valor, '21813');
    expect(byId['superficie_acuifero']!.valor, '124409');
    expect(byId['recarga_unitaria']!.valor, '175336');
  });

  test('Las ecuaciones reproducen la fórmula de Mekonnen y Hoekstra', () {
    final byId = {for (final r in porcinoEnvironmentRefs) r.id: r};
    expect(byId['ecuacion_hhgris']!.valor, 'HHGris = Carga / (Cmax - Cnat)');
    expect(byId['ecuacion_nca']!.valor, 'NCA = HHGris / Recarga unitaria');
  });

  test('Toda fila declara fuente, página y categoría', () {
    expect(porcinoEnvironmentRefs, hasLength(14));
    for (final ref in porcinoEnvironmentRefs) {
      expect(ref.category, isNotEmpty);
      expect(ref.dato, isNotEmpty);
      expect(ref.page, isNotEmpty);
      expect(ref.id, matches(RegExp(r'^[a-z][a-z0-9_]+$')));
    }
    expect(porcinoEnvironmentSource, contains('SEMARNAT'));
  });
}

/// Dictamen Diagnóstico Ambiental de la Actividad Porcícola en Yucatán
/// (SEMARNAT, marzo 2023): nivel de contaminación del agua (NCA) y huella
/// hídrica gris del sector porcícola.
///
/// Fuente: `VetDosis_Dictamen_Ambiental_Yucatan_SEMARNAT.csv`. Puro y sin
/// estado. Son valores publicados del dictamen: no son mediciones de la granja
/// ni límites aplicables a otra región. Las constantes por defecto son de
/// Yucatán; para otro estado hay que sustituirlas.
library;

/// Fuente citada por las filas del dictamen.
const porcinoEnvironmentSource =
    'Dictamen Diagnóstico Ambiental de la Actividad Porcícola en Yucatán '
    '(SEMARNAT, marzo 2023)';

/// Una fila del dictamen, tal como viene en el CSV de origen.
class PorcinoEnvironmentRef {
  const PorcinoEnvironmentRef({
    required this.id,
    required this.category,
    required this.dato,
    this.valor = '',
    this.unidad = '',
    this.nota = '',
    this.page = '',
  });

  final String id, category, dato, valor, unidad, nota, page;
}

/// Parámetros y resultados del NCA en Yucatán (dictamen, p. 84-86).
///
/// El NCA (nivel de contaminación del agua) es HHGris ÷ recarga disponible del
/// municipio. Con Cmax = 3.0 mg/L, de 51 municipios con actividad porcícola,
/// 26 superan 2 (críticos), 4 están entre 1 y 2 y 21 por debajo de 1.
const porcinoEnvironmentRefs = <PorcinoEnvironmentRef>[
  PorcinoEnvironmentRef(
    id: 'ecuacion_hhgris',
    category: 'Ecuaciones',
    dato: 'Huella hídrica gris',
    valor: 'HHGris = Carga / (Cmax - Cnat)',
    nota: 'Mekonnen y Hoekstra (2016)',
    page: '84',
  ),
  PorcinoEnvironmentRef(
    id: 'ecuacion_nca',
    category: 'Ecuaciones',
    dato: 'Nivel de contaminación del agua',
    valor: 'NCA = HHGris / Recarga unitaria',
    nota: 'Si NCA > 1, condición de no sustentabilidad',
    page: '84',
  ),
  PorcinoEnvironmentRef(
    id: 'carga_nitrogeno_por_cerdo',
    category: 'Parámetros NCA',
    dato: 'Carga de nitrógeno por cerdo',
    valor: '18',
    unidad: 'kg N/cerdo/año',
    nota: 'Según DEFRA (2007)',
    page: '84',
  ),
  PorcinoEnvironmentRef(
    id: 'cnat_nitrogeno',
    category: 'Parámetros NCA',
    dato: 'Concentración natural de N en el acuífero',
    valor: '1.5',
    unidad: 'mg/L',
    nota: 'Muestreo en 20 cenotes de zonas con baja presencia humana',
    page: '84',
  ),
  PorcinoEnvironmentRef(
    id: 'cmax_propuesto_doble_natural',
    category: 'Parámetros NCA',
    dato: 'Cmax propuesto (doble de la natural)',
    valor: '3.0',
    unidad: 'mg/L',
    nota: 'Doble de la concentración natural definida en el estudio',
    page: '84-85',
  ),
  PorcinoEnvironmentRef(
    id: 'cmax_ajustado_otras_fuentes',
    category: 'Parámetros NCA',
    dato: 'Cmax ajustado por otras fuentes',
    valor: '10.0',
    unidad: 'mg/L',
    nota:
        'Tres veces por encima del propuesto por Liu et al. 2012; '
        'considera otras fuentes (avícolas y demás)',
    page: '86',
  ),
  PorcinoEnvironmentRef(
    id: 'recarga_anual_acuifero',
    category: 'Parámetros NCA',
    dato: 'Recarga anual del acuífero',
    valor: '21813',
    unidad: 'Hm³/año',
    nota: 'Datos oficiales',
    page: '84',
  ),
  PorcinoEnvironmentRef(
    id: 'superficie_acuifero',
    category: 'Parámetros NCA',
    dato: 'Superficie del acuífero',
    valor: '124409',
    unidad: 'km²',
    page: '84',
  ),
  PorcinoEnvironmentRef(
    id: 'recarga_unitaria',
    category: 'Parámetros NCA',
    dato: 'Recarga unitaria',
    valor: '175336',
    unidad: 'm³/km²',
    nota: 'Recarga anual ÷ superficie = 21 813 Hm³/año ÷ 124 409 km²',
    page: '84',
  ),
  PorcinoEnvironmentRef(
    id: 'interpretacion_nca_mayor_1',
    category: 'Interpretación',
    dato: 'NCA > 1',
    nota:
        'Condición de no sustentabilidad: se rebasa la capacidad de renovación '
        'del agua',
    page: '84',
  ),
  PorcinoEnvironmentRef(
    id: 'interpretacion_nca_mayor_2',
    category: 'Interpretación',
    dato: 'NCA > 2',
    nota: 'Condiciones críticas para la sustentabilidad hídrica',
    page: '85',
  ),
  PorcinoEnvironmentRef(
    id: 'municipios_nca_mayor_2_cmax3',
    category: 'Resultados con Cmax = 3.0',
    dato: 'Municipios con NCA > 2',
    valor: '26',
    unidad: 'municipios',
    nota: 'De 51 municipios con actividad porcícola',
    page: '85',
  ),
  PorcinoEnvironmentRef(
    id: 'municipios_nca_entre_1_y_2_cmax3',
    category: 'Resultados con Cmax = 3.0',
    dato: 'Municipios con NCA entre 1 y 2',
    valor: '4',
    unidad: 'municipios',
    nota: 'Condiciones urgentes de atención',
    page: '85',
  ),
  PorcinoEnvironmentRef(
    id: 'municipios_nca_menor_1_cmax3',
    category: 'Resultados con Cmax = 3.0',
    dato: 'Municipios con NCA < 1',
    valor: '21',
    unidad: 'municipios',
    nota: 'Rango sustentable',
    page: '85',
  ),
];

/// Reparto de los 51 municipios por rango de NCA, con Cmax = 3.0 mg/L.
class PorcinoMunicipalNca {
  const PorcinoMunicipalNca({
    this.critical = 26,
    this.urgent = 4,
    this.sustainable = 21,
  });

  /// NCA > 2: condiciones críticas.
  final int critical;

  /// 1 < NCA ≤ 2: atención urgente.
  final int urgent;

  /// NCA ≤ 1: rango sustentable.
  final int sustainable;

  int get total => critical + urgent + sustainable;
}

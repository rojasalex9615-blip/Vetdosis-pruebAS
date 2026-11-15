/// Sistemas de alimentación por etapas (Pork School, ago-2026): transporte de
/// alimento, silos-tolva, tolva-báscula, manejo de comederos y tamaño de
/// partícula.
///
/// Fuente: `VetDosis_Sistemas_Alimentacion_PorkSchool.csv`. Puro y sin estado.
/// Son valores de referencia de material de clase (no metas de rendimiento ni
/// límites operativos) y no tienen validación externa independiente.
library;

const porcinoFeedingSource =
    'Sistemas de Alimentación por etapas (Pork School, ago-2026). '
    'Material de clase, sin validación externa.';

/// Una fila del CSV de origen, tal como viene.
class PorcinoFeedingRef {
  const PorcinoFeedingRef({
    required this.id,
    required this.category,
    required this.dato,
    this.valor = '',
    this.unidad = '',
    this.nota = '',
    this.section = '',
  });

  final String id, category, dato, valor, unidad, nota, section;
}

/// Fila del CSV.
const porcinoFeedingRefs = <PorcinoFeedingRef>[
  PorcinoFeedingRef(
    id: 'capacidad_max_transporte_mod220',
    category: 'Sistema de transporte',
    dato: 'Capacidad máxima de transporte (Mod. 220)',
    valor: '400',
    unidad: 'kg/h',
    nota: 'Mod. 220 (2.2" de diámetro), longitud máxima 75 m',
    section: 'Sistemas de transporte de alimento',
  ),
  PorcinoFeedingRef(
    id: 'capacidad_max_transporte_mod300',
    category: 'Sistema de transporte',
    dato: 'Capacidad máxima de transporte (Mod. 300)',
    valor: '1.36',
    unidad: 'ton/h',
    nota: 'Mod. 300 (3.0" de diámetro), longitud máxima 60 m',
    section: 'Sistemas de transporte de alimento',
  ),
  PorcinoFeedingRef(
    id: 'capacidad_max_transporte_mod350',
    category: 'Sistema de transporte',
    dato: 'Capacidad máxima de transporte (Mod. 350)',
    valor: '2.72',
    unidad: 'ton/h',
    nota: 'Mod. 350 (3.5" de diámetro), longitud máxima 46 m',
    section: 'Sistemas de transporte de alimento',
  ),
  PorcinoFeedingRef(
    id: 'capacidad_max_transporte_mod500',
    category: 'Sistema de transporte',
    dato: 'Capacidad máxima de transporte (Mod. 500)',
    valor: '5.99',
    unidad: 'ton/h',
    nota: 'Mod. 500 (5.0" de diámetro), longitud máxima 46 m',
    section: 'Sistemas de transporte de alimento',
  ),
  PorcinoFeedingRef(
    id: 'diametros_silos_disponibles',
    category: 'Silos-Tolva',
    dato: 'Diámetros disponibles',
    valor: '6, 7, 9, 12 y 15',
    unidad: 'pies',
    section: 'Silos - Tolva',
  ),
  PorcinoFeedingRef(
    id: 'angulos_tolva_descarga',
    category: 'Silos-Tolva',
    dato: 'Ángulos de tolva de descarga',
    valor: '45, 60 ó 67',
    unidad: 'grados',
    section: 'Silos - Tolva',
  ),
  PorcinoFeedingRef(
    id: 'inclinacion_techos_silo',
    category: 'Silos-Tolva',
    dato: 'Inclinación de techos del silo',
    valor: '30 ó 40',
    unidad: 'grados',
    section: 'Silos - Tolva',
  ),
  PorcinoFeedingRef(
    id: 'boca_salida_silo',
    category: 'Silos-Tolva',
    dato: 'Boca de salida',
    valor: '16" ó 22"',
    unidad: 'pulgadas',
    nota: '16" para 1-2 sistemas; 22" para 3-4 sistemas',
    section: 'Bocas de salida',
  ),
  PorcinoFeedingRef(
    id: 'capacidad_tolva_bascula_interior',
    category: 'Tolva-Báscula',
    dato: 'Capacidad de la tolva-báscula para interior del galpón',
    valor: '281',
    unidad: 'kg',
    nota: '620 lb = 281 kg',
    section: 'Tolva – Báscula para interior del galpón',
  ),
  PorcinoFeedingRef(
    id: 'nivel_alimento_charola_primera_semana_destete',
    category: 'Manejo de comederos - Destete',
    dato: 'Nivel de alimento en charola la primera semana',
    valor: '2/3 de la charola cubierta',
    unidad: 'proporción',
    nota: 'Para atraer a los lechones',
    section: 'Regla #5',
  ),
  PorcinoFeedingRef(
    id: 'nivel_alimento_charola_siguientes_semanas_destete',
    category: 'Manejo de comederos - Destete',
    dato: 'Nivel de alimento en charola las semanas siguientes',
    valor: '1/3 de la charola',
    unidad: 'proporción',
    nota: 'Especialmente con alimento en harina',
    section: 'Regla #5',
  ),
  PorcinoFeedingRef(
    id: 'nivel_alimento_charola_crecimiento_finalizacion',
    category: 'Manejo de comederos - Crecimiento/Finalización',
    dato: 'Nivel de alimento en charola',
    valor: 'máximo 1/4 de la charola cubierta',
    unidad: 'proporción',
    section: 'Regla #5',
  ),
  PorcinoFeedingRef(
    id: 'tamano_particula_optimo_flujo',
    category: 'Flujo de alimento',
    dato: 'Tamaño de partícula óptimo',
    valor: '700',
    unidad: 'micrones',
    nota:
        'Óptimo para dietas a base de cereales; mejora la eficiencia y reduce '
        'la excreción de nutrientes',
    section: 'Regla #9',
  ),
];

/// Modelo de transporte de alimento (Pork School). La capacidad y la longitud
/// máxima del tubo cambian con el diámetro: no se interpolan.
class PorcinoFeedTransport {
  const PorcinoFeedTransport({
    required this.model,
    required this.diameterInches,
    required this.maxLengthM,
    required this.capacity,
    required this.unit,
  });

  final String model;
  final double diameterInches;
  final double maxLengthM;
  final double capacity;
  final String unit;
}

const porcinoFeedTransports = <PorcinoFeedTransport>[
  PorcinoFeedTransport(
    model: '220',
    diameterInches: 2.2,
    maxLengthM: 75,
    capacity: 400,
    unit: 'kg/h',
  ),
  PorcinoFeedTransport(
    model: '300',
    diameterInches: 3.0,
    maxLengthM: 60,
    capacity: 1.36,
    unit: 'ton/h',
  ),
  PorcinoFeedTransport(
    model: '350',
    diameterInches: 3.5,
    maxLengthM: 46,
    capacity: 2.72,
    unit: 'ton/h',
  ),
  PorcinoFeedTransport(
    model: '500',
    diameterInches: 5.0,
    maxLengthM: 46,
    capacity: 5.99,
    unit: 'ton/h',
  ),
];

/// Diámetros comerciales de silo-tolva, en pies.
const porcinoSiloDiametersFt = [6, 7, 9, 12, 15];

/// Ángulos de tolva de descarga disponibles, en grados.
const porcinoSiloHopperAngles = [45, 60, 67];

/// Inclinaciones de techo de silo disponibles, en grados.
const porcinoSiloRoofSlopes = [30, 40];

/// Tamaño de partícula óptimo del alimento, en micrones.
const porcinoOptimalParticleMicrons = 700;

/// Boca de salida del silo según el número de sistemas (líneas) que alimenta.
/// 16" para 1-2 sistemas y 22" para 3-4; fuera de ese rango no hay dato.
String? porcinoSiloOutletInches(int systems) {
  if (systems < 1 || systems > 4) return null;
  return systems <= 2 ? '16"' : '22"';
}

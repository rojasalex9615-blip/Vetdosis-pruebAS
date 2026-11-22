/// Valores de referencia de material de clase (Pork School, ago-2026) y de la
/// asignatura Producción de Cerdos. Extraídos de los documentos de
/// Drive (Coordinacion_Agentes_VetDosis, CSV del 6-7 nov 2026). Son referencias
/// de diseño y enseñanza: no son metas de rendimiento ni límites operativos, y
/// no cuentan con validación externa independiente.
library;

import '../../../vet_ui/vet_components.dart';

const porcinoReferenceSource =
    'Pork School, ago-2026 (material de clase). Extracción: Grok, 6-7 nov 2026. Sin validación externa.';

/// Consumo diario por cabeza usado en el diseño de silos de la hoja de clase
/// «Formato consumo de alimento y sistemas».
class PorcinoFeedPhase {
  const PorcinoFeedPhase(this.name, this.kgPerHeadDay);
  final String name;
  final double kgPerHeadDay;
}

const porcinoGestationFeed = [PorcinoFeedPhase('Gestación', 2.2)];
const porcinoMaternityFeed = [PorcinoFeedPhase('Maternidad / lactancia', 7.0)];
const porcinoNurseryFeed = [PorcinoFeedPhase('Iniciación (destete)', 1.2)];
const porcinoGrowingFeed = [
  PorcinoFeedPhase('Desarrollo', 1.8),
  PorcinoFeedPhase('Finalizador', 2.7),
];

/// Coeficiente k del modelo alométrico de espacio vital (tabla Gonyou 2006).
enum PorcinoFloor {
  slat('Slat total', 0.034),
  partial('Piso parcial', 0.039),
  solid('Piso sólido', 0.047);

  const PorcinoFloor(this.label, this.k);
  final String label;
  final double k;
}

/// m² por animal según peso (kg) y tipo de piso.
const porcinoSpaceM2 = <int, Map<PorcinoFloor, double>>{
  25: {
    PorcinoFloor.slat: 0.29,
    PorcinoFloor.partial: 0.34,
    PorcinoFloor.solid: 0.41,
  },
  30: {
    PorcinoFloor.slat: 0.33,
    PorcinoFloor.partial: 0.38,
    PorcinoFloor.solid: 0.45,
  },
  100: {
    PorcinoFloor.slat: 0.73,
    PorcinoFloor.partial: 0.84,
    PorcinoFloor.solid: 1.01,
  },
  120: {
    PorcinoFloor.slat: 0.83,
    PorcinoFloor.partial: 0.95,
    PorcinoFloor.solid: 1.15,
  },
  130: {
    PorcinoFloor.slat: 0.87,
    PorcinoFloor.partial: 1.00,
    PorcinoFloor.solid: 1.21,
  },
};

const porcinoNurseryWeights = [25, 30];
const porcinoFinishingWeights = [100, 120, 130];

/// Fila de referencia para mostrar: dato, valor y nota breve.
class PorcinoReferenceRow {
  const PorcinoReferenceRow(
    this.label,
    this.value, {
    this.note,
    this.referencias,
  });
  final String label, value;
  final String? note;

  /// Cuando un dato tiene mas de una referencia legitima, cada una con su
  /// fuente. Si es nulo, [value] es la unica y la cita es la del bloque.
  final List<VetReferenceValue>? referencias;
}

const porcinoReproductionReference = [
  PorcinoReferenceRow(
    'Ciclo productivo (clase)',
    '114 + 28 + 7 = 149 días',
    note: 'Gestación + lactancia + intervalo destete-servicio.',
  ),
  PorcinoReferenceRow(
    'Duración de lactancia',
    '21 d · 28 d',
    note:
        'Dos supuestos de manejo distintos, no una contradicción. La app muestra ambos con su procedencia en vez de elegir uno.',
    referencias: [
      VetReferenceValue('21 días', qualifier: 'Destete temprano', source: 'NRC 2012'),
      VetReferenceValue('28 días', qualifier: 'Ciclo de clase', source: 'Pork School, ago-2026'),
    ],
  ),
  PorcinoReferenceRow(
    'Factor 25 (sistema simple)',
    'partos por semana × 25 = vientres productivos',
    note: '52 ÷ 25 = 2.08 partos por hembra al año.',
  ),
  PorcinoReferenceRow(
    'Modelo 2400, promedio',
    '2.3 partos/hembra/año · 9.0 destetados/parto · fertilidad 85 %',
  ),
  PorcinoReferenceRow(
    'Modelo 2400, Top 10 %',
    '2.4 partos/hembra/año · 10.0 destetados/parto · fertilidad 87 %',
  ),
  PorcinoReferenceRow(
    'Espacio en gestación (proyecto 2400)',
    '2.06 m² por vientre',
  ),
];

const porcinoMaternityReference = [
  PorcinoReferenceRow(
    'Sistema de bandas 4-8-16',
    '3+1 maternidad · 7+1 destete · 15+1 engorda (semanas)',
    note: 'La semana «+1» es de limpieza y vacío.',
  ),
  PorcinoReferenceRow(
    'Jaulas de maternidad, Modelo 2400',
    '384 (8 salas × 48)',
  ),
  PorcinoReferenceRow(
    'Espacio en maternidad (proyecto 2400)',
    '1.6 m² por vientre',
  ),
  PorcinoReferenceRow(
    'Charola en destete',
    'primera semana: 2/3 cubierta · después: 1/3',
    note: 'Sobre todo con alimento en harina.',
  ),
  PorcinoReferenceRow(
    'Ventilación en destete (métrico)',
    'frío 8-10 · templado 25-30 · cálido 70 m³/h por animal',
    note: 'Animales de 5 a 35 kg.',
  ),
];

const porcinoGrowingReference = [
  PorcinoReferenceRow(
    'Ventilación en engorda (métrico)',
    'frío 15 · templado 70 · cálido 200 m³/h por animal',
    note: 'Animales de 30 a 120 kg.',
  ),
  PorcinoReferenceRow(
    'Charola en crecimiento y finalización',
    'máximo 1/4 cubierta',
  ),
  PorcinoReferenceRow(
    'Tamaño de partícula del alimento',
    '700 micras',
    note: 'Óptimo para dietas con cereales según la diapositiva.',
  ),
  PorcinoReferenceRow(
    'Requisito de mercado citado en clase',
    '130 kg en rastro · conversión mínima 2.3',
  ),
  PorcinoReferenceRow(
    'Agua de bebida',
    '8-9 L/día por animal (general)',
    note:
        'Sin desglose por etapa; otro ejemplo del mismo material usa 14 L/día.',
  ),
];

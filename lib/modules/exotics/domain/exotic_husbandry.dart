/// Fichas rápidas de manejo: temperatura, humedad y dieta por especie.
///
/// En exóticos la mayoría de lo que se ve en consulta no es infeccioso sino
/// ambiental: un reptil a temperatura insuficiente no digiere ni responde al
/// tratamiento, y un anfibio en agua caliente se muere aunque el fármaco sea
/// el correcto. Por eso el manejo va junto a la clínica y no en un anexo.
///
/// Estos son **rangos orientativos de manejo en cautiverio**, no valores
/// clínicos medidos. Van siempre acompañados del aviso de contrastar con la
/// obra de referencia de la especie: igual que en `exotic_reference.dart`, se
/// prefiere enseñar de dónde sale el número a dar una cifra sin origen.
library;

import 'exotic_taxon.dart';

/// Ficha de manejo de una especie.
class HusbandrySheet {
  const HusbandrySheet({
    required this.especie,
    required this.taxon,
    required this.temperatura,
    required this.humedad,
    required this.dieta,
    this.uv = '',
    this.agua = '',
    this.advertencia = '',
  });

  final String especie;
  final ExoticTaxon taxon;

  /// Gradiente térmico, no un número: el ejemplar necesita poder elegir.
  final String temperatura;

  final String humedad;
  final String dieta;

  /// Índice UV o tipo de lámpara, cuando la especie lo requiere.
  final String uv;

  /// Parámetros del agua en especies acuáticas.
  final String agua;

  /// El error de manejo que más veces acaba en consulta con esta especie.
  final String advertencia;
}

/// Las fichas disponibles, ordenadas por grupo.
const List<HusbandrySheet> fichasDeManejo = [
  // ---------- Reptiles ----------
  HusbandrySheet(
    especie: 'Dragón barbudo (Pogona vitticeps)',
    taxon: ExoticTaxon.reptiles,
    temperatura:
        'Punto de asoleo 38-42 °C; zona fría 24-27 °C; noche 18-21 °C',
    humedad: '30-40 %',
    dieta:
        'Omnívoro: en juveniles predomina el insecto, en adultos la verdura de '
        'hoja. Suplementar calcio.',
    uv: 'UVB imprescindible, índice UV 3-4 en la zona de asoleo',
    advertencia:
        'Sin UVB y sin calcio aparece enfermedad metabólica ósea; es el motivo '
        'de consulta más frecuente de la especie.',
  ),
  HusbandrySheet(
    especie: 'Gecko leopardo (Eublepharis macularius)',
    taxon: ExoticTaxon.reptiles,
    temperatura: 'Zona caliente 30-32 °C; zona fría 24-26 °C',
    humedad: '30-40 %, con refugio húmedo para la muda',
    dieta: 'Insectívoro estricto. Suplementar calcio y vitamina D3.',
    uv: 'UVB de baja intensidad recomendable, índice UV 0.5-1',
    advertencia:
        'Sin refugio húmedo la muda se retiene en los dedos y los estrangula.',
  ),
  HusbandrySheet(
    especie: 'Pitón bola (Python regius)',
    taxon: ExoticTaxon.reptiles,
    temperatura: 'Zona caliente 30-32 °C; zona fría 24-26 °C',
    humedad: '55-65 %, subir durante la muda',
    dieta: 'Presa entera de tamaño adecuado cada 7-14 días según edad.',
    advertencia:
        'La anorexia estacional es habitual y no siempre es patológica, pero '
        'debe pesarse al ejemplar para distinguirla de una pérdida real.',
  ),
  HusbandrySheet(
    especie: 'Tortuga de orejas rojas (Trachemys scripta)',
    taxon: ExoticTaxon.reptiles,
    temperatura: 'Agua 24-28 °C; plataforma de asoleo 30-33 °C',
    humedad: 'No aplica: especie acuática con zona seca obligatoria',
    dieta:
        'Omnívora; con la edad aumenta el componente vegetal. Evitar exceso de '
        'proteína.',
    uv: 'UVB sobre la plataforma seca, índice UV 2-3',
    agua: 'Filtración suficiente; el agua sucia causa dermatitis y otitis',
    advertencia:
        'Sin zona seca donde secarse por completo aparecen abscesos y micosis '
        'del caparazón.',
  ),

  // ---------- Aves ----------
  HusbandrySheet(
    especie: 'Ninfa (Nymphicus hollandicus)',
    taxon: ExoticTaxon.aves,
    temperatura: 'Ambiente estable 18-26 °C, sin corrientes de aire',
    humedad: '40-60 %',
    dieta:
        'Mezcla formulada como base, no semillas solas; verdura diaria. La '
        'dieta exclusiva de semilla causa carencias.',
    advertencia:
        'Las aves esconden la enfermedad: cuando se ve decaída suele llevar '
        'días mala. Un peso diario detecta antes que la observación.',
  ),
  HusbandrySheet(
    especie: 'Periquito australiano (Melopsittacus undulatus)',
    taxon: ExoticTaxon.aves,
    temperatura: 'Ambiente estable 18-26 °C',
    humedad: '40-60 %',
    dieta: 'Formulada como base, verdura; limitar la semilla grasa.',
    advertencia:
        'Propenso a lipomas y obesidad con dieta de semilla a discreción.',
  ),

  // ---------- Anfibios ----------
  HusbandrySheet(
    especie: 'Ajolote (Ambystoma mexicanum)',
    taxon: ExoticTaxon.anfibios,
    temperatura: 'Agua 16-18 °C; por encima de 22 °C hay estrés térmico',
    humedad: 'Especie acuática permanente',
    dieta: 'Carnívoro: lombriz, pellet específico. No alimento con cloro.',
    agua: 'pH 7.0-7.5; amoniaco 0; nitrito 0; sin cloro ni cloramina',
    advertencia:
        'El calor es la causa más común de muerte en cautiverio; no tolera '
        'temperaturas de acuario tropical.',
  ),
  HusbandrySheet(
    especie: 'Rana arborícola (Dendrobatidae y similares)',
    taxon: ExoticTaxon.anfibios,
    temperatura: '22-26 °C según especie',
    humedad: '70-100 %',
    dieta: 'Insectívoro de presa pequeña viva, espolvoreada con suplemento.',
    advertencia:
        'La piel absorbe lo que toca: manipular con guantes húmedos sin '
        'residuos de jabón.',
  ),

  // ---------- Mamíferos pequeños ----------
  HusbandrySheet(
    especie: 'Conejo (Oryctolagus cuniculus)',
    taxon: ExoticTaxon.mamiferosPequenos,
    temperatura: 'Ambiente 16-21 °C; por encima de 28 °C hay golpe de calor',
    humedad: '40-60 %',
    dieta:
        'Heno a discreción como base (80 %), verdura de hoja y poco pienso. El '
        'heno mantiene el desgaste dental y la motilidad digestiva.',
    advertencia:
        'La estasis gastrointestinal es una urgencia: un conejo que deja de '
        'comer y de defecar necesita atención el mismo día.',
  ),
  HusbandrySheet(
    especie: 'Cuyo / cobayo (Cavia porcellus)',
    taxon: ExoticTaxon.mamiferosPequenos,
    temperatura: 'Ambiente 18-24 °C',
    humedad: '40-60 %',
    dieta:
        'Heno a discreción, pienso específico y vitamina C diaria: no la '
        'sintetiza y la carencia produce escorbuto.',
    advertencia:
        'Usar pienso de conejo en lugar del específico deja al animal sin '
        'vitamina C.',
  ),
  HusbandrySheet(
    especie: 'Chinchilla (Chinchilla lanigera)',
    taxon: ExoticTaxon.mamiferosPequenos,
    temperatura: 'Ambiente 15-21 °C; mal tolerado por encima de 25 °C',
    humedad: 'Baja, 40-50 %',
    dieta: 'Heno a discreción y pienso específico; muy poca fruta.',
    advertencia:
        'El pelaje denso impide disipar calor: calor y humedad altos causan '
        'golpe de calor con facilidad.',
  ),
  HusbandrySheet(
    especie: 'Hurón (Mustela putorius furo)',
    taxon: ExoticTaxon.mamiferosPequenos,
    temperatura: 'Ambiente 15-24 °C',
    humedad: '40-65 %',
    dieta:
        'Carnívoro estricto: proteína y grasa animal altas, fibra e hidratos '
        'mínimos.',
    advertencia:
        'Las dietas con cereal favorecen urolitiasis e insulinoma; no es un '
        'roedor y no come como tal.',
  ),

  // ---------- Peces ornamentales ----------
  HusbandrySheet(
    especie: 'Pez dorado (Carassius auratus)',
    taxon: ExoticTaxon.pecesOrnamentales,
    temperatura: 'Agua 18-22 °C: es un pez de agua fría, no tropical',
    humedad: 'No aplica',
    dieta: 'Pellet específico; evitar sobrealimentar.',
    agua: 'pH 7.0-8.0; amoniaco 0; nitrito 0; nitrato < 40 mg/L',
    advertencia:
        'La pecera sin filtro ni ciclado es la causa habitual de intoxicación '
        'por amoniaco.',
  ),
  HusbandrySheet(
    especie: 'Betta (Betta splendens)',
    taxon: ExoticTaxon.pecesOrnamentales,
    temperatura: 'Agua 24-28 °C, con calentador',
    humedad: 'No aplica',
    dieta: 'Carnívoro de superficie: pellet específico, poca cantidad.',
    agua: 'pH 6.5-7.5; amoniaco 0; nitrito 0',
    advertencia:
        'Respira aire atmosférico y necesita llegar a la superficie: el '
        'recipiente nunca debe estar cerrado.',
  ),
];

List<HusbandrySheet> fichasDe(ExoticTaxon taxon) =>
    fichasDeManejo.where((f) => f.taxon == taxon).toList();

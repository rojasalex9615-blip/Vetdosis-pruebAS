import 'dart:convert';
import 'package:flutter/services.dart';
import 'catalog.dart';

/// Regla de dosificación documentada por el fabricante.
///
/// Solo [proportionalToWeight] puede alimentar la calculadora proporcional.
/// El resto (fija, bandas, agua/alimento, esquema vacunal) requiere otra regla
/// y nunca se convierte a proporcional: el texto literal es la única verdad.
enum PautaRule {
  proportionalToWeight('proporcional al peso'),
  fixedPerAnimal('fija por animal'),
  weightBands('bandas de peso'),
  waterFeed('agua/alimento'),
  vaccination('esquema vacunal'),
  other('otra'),
  unspecified('no especificado');

  const PautaRule(this.label);
  final String label;

  static PautaRule parse(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    for (final rule in values) {
      if (rule.label == value) return rule;
    }
    if (value.contains('proporcional')) return PautaRule.proportionalToWeight;
    if (value.contains('banda')) return PautaRule.weightBands;
    if (value.contains('fija')) return PautaRule.fixedPerAnimal;
    if (value.contains('agua') || value.contains('alimento')) {
      return PautaRule.waterFeed;
    }
    if (value.contains('vacun')) return PautaRule.vaccination;
    return PautaRule.unspecified;
  }
}

/// Calculadora de destino de una pauta proporcional al peso.
///
/// El nombre comercial y la indicación del empaque pertenecen a la calculadora
/// de dosis de empaque (mL, tableta, sobre… por kg). La dosis en masa por kg
/// pertenece a la calculadora por agente farmacéutico (mg/kg).
enum PautaCalculator {
  package('dosis de empaque'),
  agent('agente farmacéutico');

  const PautaCalculator(this.label);
  final String label;
}

/// Referencia de dosis proporcional al peso, extraída de la pauta.
/// Devuelve null cuando el texto no declara un único peso en kg: en ese caso
/// la calculadora proporcional no se precarga.
class PautaWeightReference {
  const PautaWeightReference({
    required this.amount,
    required this.unit,
    required this.kg,
    required this.text,
  });
  final String amount, unit, kg, text;

  /// Interpreta únicamente referencias explícitas a kg de peso vivo.
  ///
  /// No convierte «por kg» genérico, kg de alimento/producto ni rangos en
  /// una dosis por peso vivo. Una referencia sin cifra equivale a 1 kg solo
  /// cuando declara expresamente «por kg de peso vivo».
  static PautaWeightReference? parse({
    required String amount,
    required String unit,
    required String reference,
  }) {
    final dose = amount.trim();
    final doseUnit = unit.trim();
    final source = reference.trim();
    if (dose.isEmpty || doseUnit.isEmpty || source.isEmpty) return null;

    final normalized = source.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final match = RegExp(
      r'\b(?:por\s+(?:cada\s+)?|cada\s+)(?:(\d+(?:[.,]\d+)?)\s*)?kg\s+(?:de\s+)?peso\s+vivo\b',
    ).firstMatch(normalized);
    if (match == null) return null;

    final numbers = RegExp(
      r'\d+(?:[.,]\d+)?',
    ).allMatches(source).map((item) => item.group(0)!).toList();
    final declaredKg = match.group(1);
    if (numbers.length != (declaredKg == null ? 0 : 1)) return null;

    return PautaWeightReference(
      amount: dose,
      unit: doseUnit,
      kg: declaredKg?.replaceAll(',', '.') ?? '1',
      text: source,
    );
  }
}

class ManufacturerPauta {
  const ManufacturerPauta({
    required this.id,
    required this.productName,
    required this.manufacturer,
    required this.productUrl,
    required this.presentation,
    required this.registro,
    required this.ingredients,
    required this.ingredientAmount,
    required this.ingredientUnit,
    required this.ingredientBase,
    required this.species,
    required this.stage,
    required this.indication,
    required this.ageWeightLimits,
    required this.literal,
    required this.route,
    required this.doseAmount,
    required this.doseUnit,
    required this.doseReference,
    required this.ruleText,
    required this.interval,
    required this.duration,
    required this.applications,
    required this.repeatConditions,
    required this.siteMax,
    required this.weightBands,
    required this.tabletSplit,
    required this.contraindications,
    required this.withdrawal,
    required this.evidenceUrl,
    required this.evidenceSection,
    required this.consultedAt,
    required this.discrepancies,
    required this.state,
    required this.notes,
    required this.warnings,
  });

  final String id, productName, manufacturer, productUrl, presentation;
  final String registro, ingredients, ingredientAmount, ingredientUnit;
  final String ingredientBase, species, stage, indication, ageWeightLimits;
  final String literal, route, doseAmount, doseUnit, doseReference, ruleText;
  final String interval, duration, applications, repeatConditions, siteMax;
  final String weightBands, tabletSplit, contraindications, withdrawal;
  final String evidenceUrl, evidenceSection, consultedAt, discrepancies;
  final String state, notes;
  final List<String> warnings;

  PautaRule get rule => PautaRule.parse(ruleText);

  /// Una pauta con avisos de integridad no se ofrece para calcular.
  bool get trustworthy => warnings.isEmpty;

  /// Unidad de administración en masa → calculadora por agente (mg/kg).
  /// Unidad de empaque (volumen, tableta, sobre…) → calculadora de empaque.
  /// Otra unidad (UI, atomización, mcg/mg) no tiene una calculadora fiable.
  PautaCalculator? get calculator {
    final unit = doseUnit.trim().toLowerCase();
    if (unit.isEmpty) return null;
    const mass = {'mg', 'g', 'µg', 'mcg', 'mg/kg'};
    const packaged = {
      'ml',
      'mililitros',
      'cc',
      'tableta',
      'comprimido',
      'comprimido(s) o fracción',
      'cápsula',
      'cápsula(s)',
      'sobres',
      'sobre',
      'g (sobre)',
      'bolos',
    };
    if (mass.contains(unit)) return PautaCalculator.agent;
    if (packaged.contains(unit)) return PautaCalculator.package;
    return null;
  }

  bool get canCalculate =>
      rule == PautaRule.proportionalToWeight &&
      trustworthy &&
      weightReference != null &&
      calculator != null;

  /// Extrae una referencia inequívoca a kg de peso vivo.
  PautaWeightReference? get weightReference {
    if (rule != PautaRule.proportionalToWeight) return null;
    return PautaWeightReference.parse(
      amount: doseAmount,
      unit: doseUnit,
      reference: doseReference,
    );
  }

  factory ManufacturerPauta.read(Map<String, dynamic> row) {
    String text(String key) => (row[key] as String?)?.trim() ?? '';
    final warnings = (row['warnings'] as List?)?.cast<String>() ?? const [];
    return ManufacturerPauta(
      id: text('id'),
      productName: text('product_name'),
      manufacturer: text('manufacturer'),
      productUrl: text('product_url'),
      presentation: text('presentation'),
      registro: text('registro'),
      ingredients: text('ingredients'),
      ingredientAmount: text('ingredient_amount'),
      ingredientUnit: text('ingredient_unit'),
      ingredientBase: text('ingredient_base'),
      species: text('species'),
      stage: text('stage'),
      indication: text('indication'),
      ageWeightLimits: text('age_weight_limits'),
      literal: text('literal'),
      route: text('route'),
      doseAmount: text('dose_amount'),
      doseUnit: text('dose_unit'),
      doseReference: text('dose_reference'),
      ruleText: text('rule'),
      interval: text('interval'),
      duration: text('duration'),
      applications: text('applications'),
      repeatConditions: text('repeat_conditions'),
      siteMax: text('site_max'),
      weightBands: text('weight_bands'),
      tabletSplit: text('tablet_split'),
      contraindications: text('contraindications'),
      withdrawal: text('withdrawal'),
      evidenceUrl: text('evidence_url'),
      evidenceSection: text('evidence_section'),
      consultedAt: text('consulted_at'),
      discrepancies: text('discrepancies'),
      state: text('state'),
      notes: text('notes'),
      warnings: List.unmodifiable(warnings),
    );
  }
}

class ManufacturerPautaCatalog {
  ManufacturerPautaCatalog(this.pautas, this.note);
  final List<ManufacturerPauta> pautas;
  final String note;

  static Future<ManufacturerPautaCatalog> load() async => parse(
    await rootBundle.loadString('assets/clinical/manufacturer_pautas.v1.json'),
  );

  static ManufacturerPautaCatalog parse(String text) {
    final raw = jsonDecode(text) as Map<String, dynamic>;
    if (raw['schema_version'] != 1) {
      throw const FormatException('Catálogo de pautas incompatible.');
    }
    final list = raw['pautas'];
    if (list is! List || list.any((item) => item is! Map<String, dynamic>)) {
      throw const FormatException('Pautas inválidas.');
    }
    final pautas = list
        .map((row) => ManufacturerPauta.read(row as Map<String, dynamic>))
        .toList();
    if (pautas.any((p) => p.id.isEmpty || p.productUrl.isEmpty)) {
      throw const FormatException('Pauta sin identificador o URL de producto.');
    }
    return ManufacturerPautaCatalog(
      List.unmodifiable(pautas),
      raw['note'] as String? ?? '',
    );
  }

  /// Pautas del producto, identificado por su URL PLM (misma clave que la
  /// ficha comercial). Devuelve lista vacía si el producto no tiene pauta.
  List<ManufacturerPauta> forProduct(String productUrl) =>
      pautas.where((p) => p.productUrl == productUrl).toList(growable: false);
}

/// Grupos de especie del filtro del vademécum.
///
/// La fuente escribe la especie libremente («Caninos y felinos», «Perros y
/// gatos», «Cerdos»): 435 textos distintos para una docena de grupos. El
/// filtro trabaja con el grupo, no con el texto literal.
const especiesDelVademecum = [
  'Caninos',
  'Felinos',
  'Bovinos',
  'Porcinos',
  'Ovinos',
  'Caprinos',
  'Equinos',
  'Aves',
  'Conejos',
  'Peces',
  'Abejas',
  'Reptiles',
];

const _clavesDeEspecie = <String, List<String>>{
  'Caninos': ['canin', 'perr', 'cachorr'],
  'Felinos': ['felin', 'gat'],
  'Bovinos': ['bovin', 'vaca', 'toro', 'terner', 'becerr', 'buey'],
  'Porcinos': ['porcin', 'cerd', 'lechon', 'cochin'],
  'Ovinos': ['ovin', 'ovej', 'cordero', 'borreg'],
  'Caprinos': ['caprin', 'cabra', 'cabrit', 'chivo'],
  'Equinos': ['equin', 'caball', 'yegu', 'potro', 'mular', 'burro'],
  'Aves': [
    'ave',
    'aviar',
    'poll',
    'gallin',
    'pavo',
    'pata',
    'ganso',
    'codorniz',
    'psitac',
    'loro',
    'periquito',
    'canari',
  ],
  'Conejos': ['conejo', 'cunicul'],
  'Peces': ['pez', 'pece', 'tilapia', 'trucha', 'carpa', 'bagre', 'salmon'],
  'Abejas': ['abej', 'apis'],
  'Reptiles': [
    'reptil',
    'serpient',
    'lagart',
    'tortug',
    'gecko',
    'iguana',
    'ofidio',
  ],
};

/// Grupo o grupos a los que pertenece el texto de especie de una pauta.
List<String> gruposDeEspecie(String texto) {
  final t = normalizeDoseSearch(texto);
  if (t.isEmpty ||
      t.contains('no especificado') ||
      t.contains('sin datos') ||
      t.contains('no aplica')) {
    return const ['Sin especificar'];
  }
  // Con `contains` a secas, «bovinos» también caería en Ovinos por la cadena
  // «ovin». La clave tiene que empezar palabra.
  final out = [
    for (final entry in _clavesDeEspecie.entries)
      if (entry.value.any((clave) => RegExp('(?:^|[^a-z])$clave').hasMatch(t)))
        entry.key,
  ];
  return out.isEmpty ? const ['Sin especificar'] : out;
}

bool pautaDeEspecie(ManufacturerPauta pauta, String grupo) =>
    grupo == 'Todas' || gruposDeEspecie(pauta.species).contains(grupo);

/// Principio activo con las pautas que lo mencionan.
///
/// Es un índice de consulta, no una regla: agrupa por el texto de
/// [ManufacturerPauta.ingredients] sin convertir la mezcla en dosis.
class ManufacturerIngredient {
  ManufacturerIngredient(this.name, this.pautas);
  final String name;
  final List<ManufacturerPauta> pautas;

  Set<String> get products => {
    for (final p in pautas) '${p.productName} · ${p.manufacturer}',
  };
}

/// Agrupa las pautas por principio activo, de más a menos pautas.
///
/// Los ingredientes vienen como «A + B + C»; se separan por «+» y «/». No se
/// parte por comas porque hay nombres con coma y quedarían fragmentos.
List<ManufacturerIngredient> indexByIngredient(
  Iterable<ManufacturerPauta> pautas,
) {
  final names = <String, String>{};
  final groups = <String, List<ManufacturerPauta>>{};
  for (final pauta in pautas) {
    for (final raw in pauta.ingredients.split(RegExp(r'[+/]'))) {
      final name = raw.trim().replaceAll(RegExp(r'^[\s-]+|[\s.;,]+$'), '');
      if (name.length < 3 || name.toLowerCase() == 'no especificado') continue;
      final key = normalizeDoseSearch(name);
      if (key.isEmpty) continue;
      names.putIfAbsent(key, () => name);
      groups.putIfAbsent(key, () => []).add(pauta);
    }
  }
  final result = [
    for (final entry in groups.entries)
      ManufacturerIngredient(names[entry.key]!, entry.value),
  ];
  result.sort((a, b) {
    final byCount = b.pautas.length.compareTo(a.pautas.length);
    return byCount != 0
        ? byCount
        : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return result;
}

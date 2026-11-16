import 'dart:convert';
import 'package:flutter/services.dart';

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

  /// Extrae un único peso en kg de la referencia ("por 20 kg de peso vivo").
  PautaWeightReference? get weightReference {
    if (rule != PautaRule.proportionalToWeight) return null;
    final amount = doseAmount.trim();
    final unit = doseUnit.trim();
    if (amount.isEmpty || unit.isEmpty) return null;
    final numbers = RegExp(
      r'\d+(?:[.,]\d+)?',
    ).allMatches(doseReference).map((m) => m.group(0)!).toList();
    final normalized = doseReference.toLowerCase();
    if (numbers.length != 1 || !normalized.contains('kg')) return null;
    return PautaWeightReference(
      amount: amount,
      unit: unit,
      kg: numbers.single.replaceAll(',', '.'),
      text: doseReference.trim(),
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

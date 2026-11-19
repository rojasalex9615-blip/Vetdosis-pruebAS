import 'dart:convert';

import '../../doses/domain/quantity.dart';
import 'vitals_models.dart';

enum VitalReferenceState { below, within, above }

/// Banda de lectura para el indicador en vivo. Es más fina que
/// [VitalReferenceState]: separa «alerta» (pegado a un límite, pero dentro)
/// de «normal», que es lo que el profesional necesita distinguir mientras
/// teclea. No sustituye al estado del catálogo, que es el que se guarda.
enum VitalBand { low, alert, normal, high }

class VitalReferenceEntry {
  const VitalReferenceEntry({
    required this.id,
    required this.species,
    required this.parameter,
    required this.unit,
    required this.min,
    required this.max,
    required this.source,
    required this.reviewedAt,
    required this.verified,
    this.note,
  });

  final String id;
  final String species;
  final String parameter;
  final String unit;
  final Quantity min;
  final Quantity max;
  final String source;
  final DateTime reviewedAt;
  final bool verified;

  /// Aviso de la transcripción (p. ej. «extremos sin inclusividad indicada»).
  final String? note;

  VitalReferenceState evaluate(Quantity value) {
    if (!verified) {
      throw const FormatException(
        'Una referencia sin verificar no puede clasificar constantes.',
      );
    }
    if (value.compareTo(min) < 0) return VitalReferenceState.below;
    if (value.compareTo(max) > 0) return VitalReferenceState.above;
    return VitalReferenceState.within;
  }

  /// Banda para el indicador en vivo, sin exigir verificación.
  ///
  /// «Alerta» es el 5 % del ancho del rango pegado a cada extremo. Se calcula
  /// con la fracción exacta, no con el texto mostrado.
  VitalBand band(Quantity value) {
    if (value.compareTo(min) < 0) return VitalBand.low;
    if (value.compareTo(max) > 0) return VitalBand.high;
    final span = Quantity(max.n * min.d - min.n * max.d, max.d * min.d);
    final margin = Quantity(span.n, span.d * BigInt.from(20));
    final lowGap = Quantity(value.n * min.d - min.n * value.d, value.d * min.d);
    final highGap = Quantity(max.n * value.d - value.n * max.d, max.d * value.d);
    if (lowGap.compareTo(margin) <= 0 || highGap.compareTo(margin) <= 0) {
      return VitalBand.alert;
    }
    return VitalBand.normal;
  }
}

/// Una referencia aplicable a un parámetro, con la banda del valor tecleado.
///
/// [band] es nulo mientras no haya un valor interpretable: entonces solo se
/// enseña el intervalo de referencia, sin juzgar.
class VitalReferenceReading {
  const VitalReferenceReading({required this.entry, this.band});

  final VitalReferenceEntry entry;
  final VitalBand? band;

  bool get verified => entry.verified;

  String get range =>
      '${entry.min.display()} – ${entry.max.display()} ${entry.unit}';
}

class VitalReferenceEvaluation {
  const VitalReferenceEvaluation({
    required this.entry,
    required this.state,
  });

  final VitalReferenceEntry entry;
  final VitalReferenceState state;

  String get label {
    switch (state) {
      case VitalReferenceState.below:
        return 'Por debajo de referencia';
      case VitalReferenceState.within:
        return 'Dentro de referencia';
      case VitalReferenceState.above:
        return 'Por encima de referencia';
    }
  }
}

class VitalReferenceCatalog {
  const VitalReferenceCatalog({
    required this.version,
    required this.entries,
  });

  final String version;
  final List<VitalReferenceEntry> entries;

  factory VitalReferenceCatalog.parse(String text) {
    final raw = jsonDecode(text);
    if (raw is! Map<String, dynamic> || raw['schema_version'] != 1) {
      throw const FormatException(
        'Versión de catálogo de constantes no compatible.',
      );
    }
    final version = _requiredText(raw, 'catalog_version');
    final list = raw['references'];
    if (list is! List ||
        list.any((item) => item is! Map<String, dynamic>)) {
      throw const FormatException('references debe ser una lista de objetos.');
    }
    final entries = list
        .cast<Map<String, dynamic>>()
        .map(_readEntry)
        .toList(growable: false);
    if (entries.map((entry) => entry.id).toSet().length != entries.length) {
      throw const FormatException(
        'Hay identificadores de referencia duplicados.',
      );
    }
    return VitalReferenceCatalog(
      version: version,
      entries: List.unmodifiable(entries),
    );
  }

  VitalReferenceEvaluation? evaluate({
    required String species,
    required String parameter,
    required String? rawValue,
  }) {
    final valueText = rawValue?.trim() ?? '';
    if (valueText.isEmpty) return null;

    final normalizedSpecies = speciesLabel(species).toLowerCase();
    final matches = entries
        .where(
          (entry) =>
              entry.verified &&
              speciesLabel(entry.species).toLowerCase() == normalizedSpecies &&
              entry.parameter == parameter,
        )
        .toList(growable: false);
    if (matches.length != 1) return null;

    final value = Quantity.parse(valueText.replaceAll(',', '.'));
    return VitalReferenceEvaluation(
      entry: matches.single,
      state: matches.single.evaluate(value),
    );
  }

  /// Todas las referencias que aplican a un parámetro, cada una con la banda
  /// del valor tecleado. Es lo que alimenta el indicador en vivo.
  ///
  /// A diferencia de [evaluate], NO exige verificación ni un único resultado:
  /// enseña cada fuente con su cita y marca «sin verificar» las que aún no
  /// pasaron revisión MVZ, en vez de callarlas. Es la misma regla que sigue
  /// el laboratorio. No participa del guardado; [snapshotFor] sigue siendo el
  /// único que decide qué se anexa al expediente.
  List<VitalReferenceReading> readings({
    required String species,
    required String parameter,
    required String? rawValue,
  }) {
    final normalizedSpecies = speciesLabel(species).toLowerCase();
    final matches = entries
        .where(
          (entry) =>
              speciesLabel(entry.species).toLowerCase() == normalizedSpecies &&
              entry.parameter == parameter,
        )
        .toList(growable: false);
    if (matches.isEmpty) return const [];

    final text = rawValue?.trim() ?? '';
    Quantity? value;
    if (text.isNotEmpty) {
      try {
        value = Quantity.parse(text.replaceAll(',', '.'));
      } on FormatException {
        value = null;
      }
    }
    return List.unmodifiable([
      for (final entry in matches)
        VitalReferenceReading(
          entry: entry,
          band: value == null ? null : entry.band(value),
        ),
    ]);
  }


  List<Map<String, dynamic>> snapshotFor({
    required String species,
    required Map<String, String?> values,
  }) {
    final snapshots = <Map<String, dynamic>>[];
    for (final entry in values.entries) {
      final evaluation = evaluate(
        species: species,
        parameter: entry.key,
        rawValue: entry.value,
      );
      if (evaluation == null) continue;
      snapshots.add(
        Map.unmodifiable({
          'catalog_version': version,
          'reference_id': evaluation.entry.id,
          'species': speciesLabel(evaluation.entry.species),
          'parameter': evaluation.entry.parameter,
          'unit': evaluation.entry.unit,
          'min': evaluation.entry.min.display(places: 9),
          'max': evaluation.entry.max.display(places: 9),
          'source': evaluation.entry.source,
          'reviewed_at': evaluation.entry.reviewedAt.toIso8601String(),
          'state': evaluation.state.name,
        }),
      );
    }
    return List.unmodifiable(snapshots);
  }

  static VitalReferenceEntry _readEntry(Map<String, dynamic> raw) {
    final min = _quantity(raw, 'min');
    final max = _quantity(raw, 'max');
    if (min.compareTo(max) > 0) {
      throw const FormatException('Rango de referencia invertido.');
    }
    final status = _requiredText(raw, 'status');
    if (status != 'verified' && status != 'unverified') {
      throw const FormatException('Estado de referencia inválido.');
    }
    final source = _requiredText(raw, 'source');
    final reviewed = DateTime.tryParse(_requiredText(raw, 'reviewed_at'));
    if (reviewed == null) {
      throw const FormatException('Fecha de revisión inválida.');
    }
    return VitalReferenceEntry(
      id: _requiredText(raw, 'id'),
      species: _requiredText(raw, 'species'),
      parameter: _requiredText(raw, 'parameter'),
      unit: _requiredText(raw, 'unit'),
      min: min,
      max: max,
      source: source,
      reviewedAt: reviewed.toUtc(),
      verified: status == 'verified',
      note: _optionalText(raw, 'note'),
    );
  }

  static Quantity _quantity(Map<String, dynamic> raw, String key) {
    final value = raw[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key debe ser un decimal entre comillas.');
    }
    return Quantity.parse(value.trim());
  }

  static String _requiredText(Map<String, dynamic> raw, String key) {
    final value = raw[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Falta $key.');
    }
    return value.trim();
  }

  static String? _optionalText(Map<String, dynamic> raw, String key) {
    final value = raw[key];
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }
}

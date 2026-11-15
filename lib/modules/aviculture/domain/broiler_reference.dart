/// Referencias de pollo de engorda: densidad por edad, carga máxima por
/// sistema de ventilación, cama, líneas de alimentación, calidad del aire,
/// temperatura, fases de dieta y calendario.
///
/// Fuente: `Pollo de engorda (pptx CUCBA); tabla Cobb`. Material de clase, sin
/// validación externa independiente. Puro y sin estado.
library;

import 'dart:convert';

import '../../doses/domain/quantity.dart';

const broilerSource =
    'Pollo de engorda (pptx CUCBA); tabla Cobb. Material de clase, sin '
    'validación externa.';

/// Una fila del CSV de origen. [min]/[max] quedan como texto porque hay filas
/// de un solo límite (p. ej. oxígeno mínimo) o de valor fijo.
class BroilerRef {
  const BroilerRef({
    required this.stage,
    required this.parameter,
    required this.system,
    required this.unit,
    required this.source,
    required this.status,
    this.min = '',
    this.max = '',
    this.weekFrom = '',
    this.weekTo = '',
  });

  final String stage, parameter, system, unit, source, status;
  final String min, max, weekFrom, weekTo;

  /// Una fila «alternativa» procede de otra figura de la clase; se conserva
  /// junto a la principal en lugar de elegir una.
  bool get verified => status == 'verificada';
  bool get alternative => status == 'alternativa';

  Quantity? get minQuantity => min.isEmpty ? null : Quantity.parse(min);
  Quantity? get maxQuantity => max.isEmpty ? null : Quantity.parse(max);

  /// Rango legible: «50–60 pollitos/m²», «≥ 19.6 %», «30 kg/m²».
  String get range {
    if (max.isEmpty) return '≥ $min $unit';
    if (min == max) return '$min $unit';
    return '$min–$max $unit';
  }
}

/// Divide una línea CSV respetando comillas dobles (una fuente trae comas
/// dentro de comillas).
List<String> broilerSplitCsv(String line) {
  final out = <String>[];
  final buffer = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"') {
      if (quoted && i + 1 < line.length && line[i + 1] == '"') {
        buffer.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (c == ',' && !quoted) {
      out.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(c);
    }
  }
  out.add(buffer.toString());
  return out;
}

/// Catálogo de referencias de engorda, agrupado para su uso en pantalla.
class BroilerCatalog {
  BroilerCatalog(this.refs);
  final List<BroilerRef> refs;

  static BroilerCatalog parseCsv(String csv) {
    final lines = const LineSplitter()
        .convert(csv)
        .where((s) => s.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) throw const FormatException('CSV vacío.');
    final header = broilerSplitCsv(lines.first);
    if (header.length != 10) {
      throw const FormatException('Encabezado de engorda incompleto.');
    }
    final refs = <BroilerRef>[];
    for (final line in lines.skip(1)) {
      final v = broilerSplitCsv(line);
      if (v.length != header.length) {
        throw const FormatException('Columnas CSV incompletas.');
      }
      final row = Map.fromIterables(header, v);
      final min = row['min'] ?? '';
      final max = row['max'] ?? '';
      if (min.isEmpty && max.isEmpty) {
        throw const FormatException('Rango de engorda vacío.');
      }
      final lo = min.isEmpty ? null : Quantity.parse(min);
      final hi = max.isEmpty ? null : Quantity.parse(max);
      if (lo != null && hi != null && lo.compareTo(hi) > 0) {
        throw const FormatException('Rango de engorda invertido.');
      }
      refs.add(
        BroilerRef(
          stage: row['etapa'] ?? '',
          parameter: row['parametro'] ?? '',
          system: row['sistema'] ?? '',
          unit: row['unidad'] ?? '',
          source: row['fuente'] ?? '',
          status: row['estado'] ?? '',
          min: min,
          max: max,
          weekFrom: row['sem_desde'] ?? '',
          weekTo: row['sem_hasta'] ?? '',
        ),
      );
    }
    return BroilerCatalog(refs);
  }

  List<BroilerRef> byParameter(String parameter) =>
      refs.where((r) => r.parameter == parameter).toList();

  /// Densidad de pollitos por m² para un día de vida. Devuelve la fila cuyo
  /// rango incluye el día; null si el día no está cubierto (no se interpola).
  BroilerRef? densityForDay(int day) {
    for (final r in refs.where((r) => r.parameter == 'densidad')) {
      final bounds = _dayBounds(r.stage);
      if (bounds == null) continue;
      final (from, to) = bounds;
      if (day >= from && (to == null || day <= to)) return r;
    }
    return null;
  }

  /// Carga máxima del lote (kg/m²) por sistema de ventilación.
  BroilerRef? maxDensityByVentilation(String system) {
    for (final r in refs.where((r) => r.parameter == 'densidad_maxima_lote')) {
      if (r.system == system) return r;
    }
    return null;
  }

  static (int, int?)? _dayBounds(String stage) => switch (stage) {
    'dias_1_3' => (1, 3),
    'dias_4_6' => (4, 6),
    'dias_7_9' => (7, 9),
    'dias_10_12' => (10, 12),
    'dias_13_15' => (13, 15),
    'dias_16_19' => (16, 19),
    'dias_21_adelante' => (21, null),
    _ => null,
  };
}

/// Aves que caben en un área a una densidad dada (aves/m²). Redondeo hacia
/// abajo: no se promete superficie que no existe.
BigInt broilerCapacity(Quantity areaM2, Quantity birdsPerM2) {
  if (!areaM2.positive || !birdsPerM2.positive) {
    throw const FormatException('Área y densidad deben ser mayores que cero.');
  }
  final birds = areaM2 * birdsPerM2;
  return birds.n ~/ birds.d;
}

/// Aves máximas por carga del lote: área × carga máxima ÷ peso objetivo.
BigInt broilerBirdsByLoad(
  Quantity areaM2,
  Quantity maxKgPerM2,
  Quantity targetWeightKg,
) {
  if (!areaM2.positive || !maxKgPerM2.positive || !targetWeightKg.positive) {
    throw const FormatException(
      'Área, carga y peso deben ser mayores que cero.',
    );
  }
  final birds = areaM2 * maxKgPerM2 / targetWeightKg;
  return birds.n ~/ birds.d;
}

/// Temperatura objetivo de la caseta (°C) por semana de vida, derivada de la
/// regla de clase: 33 °C el día 1 y −3 °C por semana, sin bajar del piso de
/// 18 °C que la fuente fija desde la semana 5 (banda 18–21 °C).
Quantity broilerTargetTemperature(int week) {
  if (week < 0) throw const FormatException('La semana no puede ser negativa.');
  final degrees = 33 - 3 * week;
  return Quantity(BigInt.from(degrees < 18 ? 18 : degrees), BigInt.one);
}

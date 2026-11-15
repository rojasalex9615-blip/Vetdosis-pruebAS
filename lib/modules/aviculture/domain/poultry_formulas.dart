/// Fórmulas de producción avícola: índices de engorda y de postura.
///
/// Fuente: `Pollo de engorda (pptx)` y `Aves de postura (pdf exposición CUCBA
/// 2024)`. Material de clase, sin validación externa. Cada fórmula se calcula
/// con aritmética racional exacta; el catálogo solo describe la referencia.
library;

import 'dart:convert';

import '../../doses/domain/quantity.dart';

const poultryFormulaSource =
    'Engorda: pptx CUCBA. Postura: pdf exposición CUCBA 2024. Material de '
    'clase, sin validación externa.';

/// Una fórmula documentada: título, expresión simbólica y campos de entrada.
class PoultryFormula {
  const PoultryFormula({
    required this.id,
    required this.title,
    required this.expression,
    required this.inputs,
    required this.source,
    required this.status,
    this.note = '',
  });

  final String id, title, expression, inputs, source, status, note;
  bool get verified => status == 'verificada';
}

class PoultryFormulaCatalog {
  PoultryFormulaCatalog(this.formulas);
  final List<PoultryFormula> formulas;

  static PoultryFormulaCatalog parseCsv(String csv) {
    final lines = const LineSplitter()
        .convert(csv)
        .where((s) => s.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) throw const FormatException('CSV vacío.');
    final header = _split(lines.first);
    if (header.length != 7) {
      throw const FormatException('Encabezado de fórmulas incompleto.');
    }
    final formulas = <PoultryFormula>[];
    for (final line in lines.skip(1)) {
      final v = _split(line);
      if (v.length != header.length) {
        throw const FormatException('Columnas CSV incompletas.');
      }
      final row = Map.fromIterables(header, v);
      if ((row['id'] ?? '').isEmpty || (row['formula'] ?? '').isEmpty) {
        throw const FormatException('Fórmula sin id o expresión.');
      }
      formulas.add(
        PoultryFormula(
          id: row['id']!,
          title: row['titulo'] ?? '',
          expression: row['formula']!,
          inputs: row['entradas'] ?? '',
          source: row['fuente'] ?? '',
          status: row['estado'] ?? '',
          note: row['nota'] ?? '',
        ),
      );
    }
    return PoultryFormulaCatalog(formulas);
  }

  PoultryFormula byId(String id) => formulas.firstWhere((f) => f.id == id);

  static List<String> _split(String line) {
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
}

Quantity _require(String name, Quantity value) {
  if (value.positive) return value;
  throw FormatException('«$name» debe ser mayor que cero.');
}

final _hundred = Quantity(BigInt.from(100), BigInt.one);

/// Porcentaje de un cociente: (parte / total) × 100.
Quantity poultryPercent(Quantity part, Quantity total) =>
    part * _hundred / _require('total', total);

/// Índices de engorda.
class BroilerFormulas {
  const BroilerFormulas();

  /// kg de alimento por kg de carne vendida, descontando el peso del pollito.
  Quantity feedConversion(Quantity feedKg, Quantity soldKg, Quantity chickKg) {
    if (soldKg.compareTo(chickKg) <= 0) {
      throw const FormatException(
        'La carne vendida debe superar el peso del pollito.',
      );
    }
    final gain = Quantity(
      soldKg.n * chickKg.d - chickKg.n * soldKg.d,
      soldKg.d * chickKg.d,
    );
    return _require('alimento', feedKg) / gain;
  }

  /// Ganancia diaria de peso (kg/día).
  Quantity dailyGain(Quantity averageKg, Quantity days) =>
      _require('peso promedio', averageKg) / _require('días', days);
}

/// Índices de postura.
class LayerFormulas {
  const LayerFormulas();

  Quantity viability(Quantity current, Quantity initial) =>
      poultryPercent(current, initial);

  Quantity dailyMortality(Quantity deaths, Quantity current) =>
      poultryPercent(deaths, current);

  Quantity accumulatedMortality(Quantity deaths, Quantity housed) =>
      poultryPercent(deaths, housed);

  Quantity layingPercent(Quantity eggs, Quantity hens) =>
      poultryPercent(eggs, hens);

  /// Peso promedio del huevo en gramos: kg recolectados × 1000 / nº de huevos.
  Quantity eggWeightGrams(Quantity kg, Quantity eggs) =>
      _require('kg recolectados', kg) *
      Quantity(BigInt.from(1000), BigInt.one) /
      _require('huevos', eggs);

  /// Consumo por ave y día en gramos: kg ofrecidos × 1000 / existencias.
  Quantity intakeGramsPerBird(Quantity kg, Quantity birds) =>
      _require('alimento ofrecido', kg) *
      Quantity(BigInt.from(1000), BigInt.one) /
      _require('existencias', birds);

  /// Conversión de postura (kg de alimento por kg de huevo).
  Quantity feedConversion(Quantity feedKg, Quantity eggKg) =>
      _require('alimento', feedKg) / _require('kg de huevo', eggKg);

  /// Masa de huevo por ave y día (g) = % postura × peso del huevo / 100.
  Quantity eggMassPerBirdDay(Quantity layingPercent, Quantity eggGrams) =>
      _require('peso del huevo', eggGrams) *
      layingPercent /
      Quantity(BigInt.from(100), BigInt.one);

  /// Índice de productividad (IP) = (masa acumulada / días / conversión) × 100.
  Quantity productivityIndex(
    Quantity accumulatedEggMass,
    Quantity days,
    Quantity conversion,
  ) =>
      _require('masa acumulada', accumulatedEggMass) /
      _require('días', days) /
      _require('conversión', conversion) *
      Quantity(BigInt.from(100), BigInt.one);

  /// Índice de forma = ancho / longitud × 100.
  Quantity shapeIndex(Quantity widthMm, Quantity lengthMm) =>
      _require('ancho', widthMm) *
      Quantity(BigInt.from(100), BigInt.one) /
      _require('longitud', lengthMm);
}

/// Categoría del índice de productividad, según la nota de la fuente.
String productivityIndexBand(Quantity ip) {
  if (ip.compareTo(Quantity.parse('300')) > 0) return 'excelente (>300)';
  if (ip.compareTo(Quantity.parse('260')) >= 0) return 'bueno (260–299)';
  if (ip.compareTo(Quantity.parse('200')) >= 0) return 'regular (200–259)';
  return 'malo (<200)';
}

/// Categoría del índice de forma, según la nota de la fuente.
String shapeIndexBand(Quantity index) {
  if (index.compareTo(Quantity.parse('72')) < 0) return 'largo (<72)';
  if (index.compareTo(Quantity.parse('76')) > 0) return 'redondo (>76)';
  return 'óptimo (72–76)';
}

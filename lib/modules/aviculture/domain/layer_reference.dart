/// Referencias adicionales de gallina de postura: plan de luz, huevos por
/// ave y año por sistema, metas de la ponedora eficiente, curva mensual y
/// calidad del huevo (índice de forma, cáscara, cámara de aire y clase de
/// peso).
///
/// Fuente: `Sistema intensivo de gallina de postura (pptx CUCBA)` y
/// `Aves de postura (pdf exposición CUCBA 2024)`. Material de clase, sin
/// validación externa independiente. Puro y sin estado.
library;

import 'dart:convert';

import '../../doses/domain/quantity.dart';
import 'broiler_reference.dart' show broilerSplitCsv;

const layerSource =
    'Postura: pptx CUCBA y pdf exposición CUCBA 2024. Material de clase, sin '
    'validación externa.';

/// Una fila del CSV de origen. [min]/[max] quedan como texto porque hay filas
/// de un solo límite (clase XL) y filas de aviso sin rango (crisis 18–35).
class LayerRef {
  const LayerRef({
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

  bool get verified => status == 'verificada';

  /// Una fila «alternativa» procede de otra figura de la clase; se conserva
  /// junto a la principal en lugar de elegir una.
  bool get alternative => status == 'alternativa';

  /// Aviso sin rango numérico (p. ej. la crisis de las semanas 18–35): se
  /// conserva como alerta, no como rango de diseño.
  bool get isAlert => min.isEmpty && max.isEmpty;

  Quantity? get minQuantity => min.isEmpty ? null : Quantity.parse(min);
  Quantity? get maxQuantity => max.isEmpty ? null : Quantity.parse(max);

  /// Rango legible: «400 cm2», «15–30 …», «≥ 73 g», «17–18 semanas».
  String get range {
    if (isAlert) return 'alerta';
    if (max.isEmpty) return '≥ $min $unit';
    if (min == max) return '$min $unit';
    return '$min–$max $unit';
  }
}

/// Catálogo de referencias de postura, agrupado para su uso en pantalla.
class LayerCatalog {
  LayerCatalog(this.refs);
  final List<LayerRef> refs;

  static LayerCatalog parseCsv(String csv) {
    final lines = const LineSplitter()
        .convert(csv)
        .where((s) => s.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) throw const FormatException('CSV vacío.');
    final header = broilerSplitCsv(lines.first);
    if (header.length != 10) {
      throw const FormatException('Encabezado de postura incompleto.');
    }
    final refs = <LayerRef>[];
    for (final line in lines.skip(1)) {
      final v = broilerSplitCsv(line);
      if (v.length != header.length) {
        throw const FormatException('Columnas CSV incompletas.');
      }
      final row = Map.fromIterables(header, v);
      final min = row['min'] ?? '';
      final max = row['max'] ?? '';
      // Las filas de aviso no traen rango; no se rechazan, se conservan.
      if (min.isNotEmpty && max.isNotEmpty) {
        if (Quantity.parse(min).compareTo(Quantity.parse(max)) > 0) {
          throw const FormatException('Rango de postura invertido.');
        }
      }
      refs.add(
        LayerRef(
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
    return LayerCatalog(refs);
  }

  List<LayerRef> byParameter(String parameter) =>
      refs.where((r) => r.parameter == parameter).toList();

  List<LayerRef> byStage(String stage) =>
      refs.where((r) => r.stage == stage).toList();

  /// Rango por sistema de un parámetro con varias filas (p. ej. huevos por
  /// ave y año en jaula, piso y pastoreo). Null si el sistema no aparece.
  LayerRef? byParameterSystem(String parameter, String system) {
    for (final r in refs.where((r) => r.parameter == parameter)) {
      if (r.system == system) return r;
    }
    return null;
  }

  /// Plan de luz: estímulo, aumento, meta de horas e intensidad.
  List<LayerRef> get lighting => refs
      .where(
        (r) =>
            r.parameter.contains('luz') ||
            r.parameter.startsWith('horas_luz') ||
            r.parameter.startsWith('inicio_estimulo'),
      )
      .toList();

  /// Clase de peso del huevo (S/M/L/XL) para un peso en gramos, con el
  /// criterio de la fuente: [min, max) y XL abierta por arriba. Null si el
  /// peso no cae en ninguna clase (no se interpola ni se aproxima).
  LayerRef? eggWeightClassFor(Quantity grams) {
    for (final r in byStage('clase_peso')) {
      final lo = r.minQuantity;
      if (lo == null) continue;
      final hi = r.maxQuantity;
      if (grams.compareTo(lo) >= 0 && (hi == null || grams.compareTo(hi) < 0)) {
        return r;
      }
    }
    return null;
  }

  /// Categoría de cámara de aire (A hasta 6 mm, B hasta 9 mm) según la altura
  /// medida. Null por encima de la categoría B.
  LayerRef? airCellCategoryFor(Quantity millimeters) {
    for (final r in byStage('categoria_A').followedBy(byStage('categoria_B'))) {
      final hi = r.maxQuantity;
      if (hi != null && millimeters.compareTo(hi) <= 0) return r;
    }
    return null;
  }
}

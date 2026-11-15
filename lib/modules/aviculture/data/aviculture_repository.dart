import 'dart:convert';
import 'package:flutter/services.dart';
import '../../doses/domain/quantity.dart';
import '../domain/broiler_reference.dart';
import '../domain/layer_reference.dart';
import '../domain/poultry_formulas.dart';

class AvicultureParameter {
  AvicultureParameter(this.fields);
  final Map<String, String> fields;
  String get label => fields['parametro'] ?? fields['equipo']!;
  String get unit => fields['unidad'] ?? 'aves_por_unidad';
  String get min => fields['min'] ?? fields['aves_por_unidad_min']!;
  String get max => fields['max'] ?? fields['aves_por_unidad_max']!;
  List<String> warnings(Quantity design) => [
    if (fields['estado'] != 'verificada')
      'Referencia sin verificar: requiere revisión; no acredita capacidad operativa.',
    if (design.compareTo(Quantity.parse(min)) < 0 ||
        design.compareTo(Quantity.parse(max)) > 0)
      'Valor de diseño fuera del rango de la fuente ($min–$max $unit).',
  ];
}

class AvicultureCatalog {
  AvicultureCatalog(this.capacity, this.equipment, this.additional);
  final List<AvicultureParameter> capacity, equipment;
  final Map<String, dynamic> additional;
  static List<AvicultureParameter> parseCsv(String csv) {
    final lines = const LineSplitter()
        .convert(csv)
        .where((s) => s.trim().isNotEmpty)
        .toList();
    final header = lines.first.split(',');
    return lines.skip(1).map((line) {
      final values = line.split(',');
      if (values.length != header.length) {
        throw const FormatException('Columnas CSV incompletas.');
      }
      final p = AvicultureParameter(Map.fromIterables(header, values));
      if (!Quantity.parse(p.min).positive ||
          Quantity.parse(p.min).compareTo(Quantity.parse(p.max)) > 0) {
        throw const FormatException('Rango avícola inválido.');
      }
      return p;
    }).toList();
  }
}

class AvicultureRepository {
  Future<AvicultureCatalog> load() async {
    const path = 'assets/clinical/aviculture/';
    final capacity = await rootBundle.loadString(
      '${path}capacidad_avicola.v1.csv',
    );
    final equipment = await rootBundle.loadString(
      '${path}equipos_avicola.v1.csv',
    );
    final extra = await rootBundle.loadString(
      '${path}pendientes_avicola.v1.json',
    );
    return AvicultureCatalog(
      AvicultureCatalog.parseCsv(capacity),
      AvicultureCatalog.parseCsv(equipment),
      jsonDecode(extra) as Map<String, dynamic>,
    );
  }

  /// Referencias de pollo de engorda (CUCBA / Cobb).
  Future<BroilerCatalog> loadBroiler() async {
    final csv = await rootBundle.loadString(
      'assets/clinical/aviculture/engorda_avicola.v1.csv',
    );
    return BroilerCatalog.parseCsv(csv);
  }

  /// Referencias adicionales de gallina de postura (plan de luz, huevos por
  /// ave y año, ponedora eficiente, curva mensual y calidad del huevo).
  Future<LayerCatalog> loadLayer() async {
    final csv = await rootBundle.loadString(
      'assets/clinical/aviculture/postura_avicola_adicional.v1.csv',
    );
    return LayerCatalog.parseCsv(csv);
  }

  /// Fórmulas de producción avícola (engorda y postura).
  Future<PoultryFormulaCatalog> loadFormulas() async {
    final csv = await rootBundle.loadString(
      'assets/clinical/aviculture/formulas_avicola.v1.csv',
    );
    return PoultryFormulaCatalog.parseCsv(csv);
  }
}

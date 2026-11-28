import 'dart:convert';

import '../../doses/domain/quantity.dart';

/// Las tablas son assets versionados. Ninguna curva se interpola ni se inventa.
class PulletGuide {
  PulletGuide(this.data) {
    if (id.isEmpty ||
        !['piso', 'jaula'].contains(system) ||
        !Uri.parse(url).isScheme('https') ||
        rows.isEmpty) {
      throw const FormatException('Guía de crianza incompleta.');
    }
    final weeks = <int>{};
    for (final row in rows) {
      final week = row['week'] as int;
      if (week < 1 || !weeks.add(week) || (row['page'] as int) < 1) {
        throw const FormatException('Semana o página de guía inválida.');
      }
      for (final field in ['feed', 'weight', 'cumulative', 'light']) {
        final lo = row['${field}Min'], hi = row['${field}Max'];
        if ((lo == null) != (hi == null) ||
            (lo != null &&
                Quantity.parse('$lo').compareTo(Quantity.parse('$hi')) > 0)) {
          throw const FormatException('Rango de guía inválido.');
        }
      }
    }
  }
  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  String get brand => data['brand'] as String;
  String get strain => data['strain'] as String;
  String get system => data['system'] as String;
  String get edition => data['edition'] as String;
  String get url => data['url'] as String;
  String get title => data['title'] as String;
  String get citation => '$title · $edition';
  List<String> get notes => (data['notes'] as List? ?? []).cast<String>();
  List<Map<String, dynamic>> get rows => (data['rows'] as List)
      .map((r) => Map<String, dynamic>.from(r as Map))
      .toList();
  Map<String, dynamic>? week(int week) =>
      rows.where((r) => r['week'] == week).firstOrNull;
  String source(int week, {String? field}) {
    final r = this.week(week);
    if (r == null) return 'Sin datos de guía para esta línea/semana.';
    return '$citation · p. ${r['${field}Page'] ?? r['page']}';
  }

  Map<String, dynamic> toJson() =>
      jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
}

class PulletGuideCatalog {
  PulletGuideCatalog(this.guides, this.equipmentDefaults);
  final List<PulletGuide> guides;
  final List<Map<String, dynamic>> equipmentDefaults;
  factory PulletGuideCatalog.parse(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    if (data['schemaVersion'] != 1) {
      throw const FormatException('Versión de guías desconocida.');
    }
    final guides = (data['guides'] as List)
        .map((g) => PulletGuide(Map<String, dynamic>.from(g as Map)))
        .toList();
    if (guides.map((g) => g.id).toSet().length != guides.length) {
      throw const FormatException('Guía duplicada.');
    }
    return PulletGuideCatalog(
      guides,
      (data['equipmentDefaults'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }
  List<PulletGuide> forBrand(String brand, {String? system}) => guides
      .where((g) => g.brand == brand && (system == null || g.system == system))
      .toList();
}

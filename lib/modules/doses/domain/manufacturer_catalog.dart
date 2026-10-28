import 'dart:convert';
import 'package:flutter/services.dart';
import 'catalog.dart' show normalizeDoseSearch;

class ManufacturerProduct {
  const ManufacturerProduct({
    required this.name,
    required this.manufacturer,
    required this.ingredients,
    required this.form,
    required this.sourceUrl,
    required this.researchStatus,
    required this.notes,
    required this.reportName,
    required this.reportText,
    required this.reportUrl,
  });
  final String name, manufacturer, ingredients, form, sourceUrl;
  final String researchStatus, notes, reportName, reportText, reportUrl;
}

class ManufacturerCatalog {
  ManufacturerCatalog(this.products, this.historyText, this.historyUrl);
  final List<ManufacturerProduct> products;
  final String historyText, historyUrl;
  static Future<ManufacturerCatalog> load() async => parse(
    await rootBundle.loadString(
      'assets/clinical/manufacturer_research.v1.json',
    ),
  );

  static ManufacturerCatalog parse(String text) {
    final raw = jsonDecode(text) as Map<String, dynamic>;
    if (raw['schema_version'] != 1) {
      throw const FormatException('Catálogo comercial incompatible.');
    }
    final reports = raw['reports'] as Map<String, dynamic>;
    final ids = <String>{};
    final products = <ManufacturerProduct>[];
    for (final row in raw['products'] as List) {
      String read(String key) {
        final value = row[key];
        if (value is! String || value.trim().isEmpty) {
          throw FormatException('Falta $key.');
        }
        return value;
      }

      final url = read('Ficha original PLM');
      final uri = Uri.parse(url);
      if (uri.scheme != 'https' ||
          uri.host != 'www.diccionarioveterinarioplm.com' ||
          !ids.add(url)) {
        throw const FormatException(
          'Identificador comercial inválido o duplicado.',
        );
      }
      if (read('URL_fuente_principal') != url) {
        throw const FormatException('Fuente principal inconsistente.');
      }
      final group = read('Grupo_verificacion');
      final report = reports[group];
      if (report is! Map ||
          report['text'] is! String ||
          report['drive_url'] is! String) {
        throw const FormatException('Informe comercial ausente.');
      }
      products.add(
        ManufacturerProduct(
          name: read('Producto'),
          manufacturer: read('Fabricante (índice)'),
          ingredients: read('Ingredientes (índice)'),
          form: read('Forma farmacéutica'),
          sourceUrl: url,
          researchStatus: read('Estado'),
          notes: read('Notas'),
          reportName: group,
          reportText: report['text'] as String,
          reportUrl: report['drive_url'] as String,
        ),
      );
    }
    return ManufacturerCatalog(
      List.unmodifiable(products),
      raw['history']['text'] as String,
      raw['history']['url'] as String,
    );
  }

  List<ManufacturerProduct> search(String query) {
    final terms = normalizeDoseSearch(
      query,
    ).split(' ').where((t) => t.isNotEmpty);
    return products.where((p) {
      final haystack = normalizeDoseSearch(
        '${p.name} ${p.manufacturer} ${p.ingredients} ${p.form}',
      );
      return terms.every(haystack.contains);
    }).toList();
  }
}

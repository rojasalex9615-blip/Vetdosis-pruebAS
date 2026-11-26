import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/doses/domain/pauta_farmacologica.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FarmacologicoCatalog catalog;
  setUpAll(() async {
    catalog = await FarmacologicoCatalog.load();
  });

  test('el asset carga con todos los principios y pautas', () {
    expect(catalog.principios.length, 540);
    expect(catalog.pautas.length, 1077);
    expect(catalog.version, isNotEmpty);
  });

  test('ninguna pauta queda sin principio activo', () {
    final ids = catalog.principios.map((p) => p.id).toSet();
    final huerfanas = catalog.pautas.where((p) => !ids.contains(p.idFarmaco));
    expect(huerfanas, isEmpty);
  });

  test('los decimales se leen exactos, sin error binario', () {
    final pauta = catalog.pautas.firstWhere((p) => p.dosisMin?.display() == '0,03');
    expect(pauta.dosisMin!.display(), '0,03');
    expect(pauta.dosisMax, isNotNull);
  });

  test('la dosis muestra lo que escribió el autor, no el rango', () {
    final pauta = catalog.pautas.firstWhere(
      (p) => p.dosisOriginal == '140–280' && p.unidadOriginal == 'mg/kg',
    );
    expect(pauta.dosisTexto, '140–280 mg/kg');
    expect(pauta.autor, contains('BSAVA'));
    expect(pauta.anio, 2017);
  });

  test('solo se calcula con rango numérico y unidad convertible', () {
    final calculables = catalog.pautas.where((p) => p.calculable);
    expect(calculables.length, 586);
    expect(
      calculables.every((p) => p.dosisMin != null && p.baseCalculo != null),
      true,
    );
    // mg/m² y gotas tienen rango pero no se calculan por peso.
    final noCalculables = catalog.pautas.where(
      (p) => p.dosisMin != null && p.baseCalculo == null,
    );
    expect(noCalculables, isNotEmpty);
    expect(noCalculables.every((p) => !p.calculable), true);
  });

  test('una pauta en ml/kg se calcula como volumen', () {
    final volumen = catalog.pautas.where((p) => p.porVolumen);
    expect(volumen, isNotEmpty);
    expect(volumen.every((p) => !p.porMasa), true);
  });

  test('una pauta de perro y gato aparece en las dos especies', () {
    final compartida = catalog.pautas.firstWhere(
      (p) => p.especies.contains('Perro') && p.especies.contains('Gato'),
    );
    expect(catalog.pautasDe(compartida.idFarmaco, especie: 'Perro'), isNotEmpty);
    expect(catalog.pautasDe(compartida.idFarmaco, especie: 'Gato'), isNotEmpty);
    final soloPerro = catalog
        .pautasDe(compartida.idFarmaco, especie: 'Perro')
        .map((p) => p.id)
        .toSet();
    expect(soloPerro.contains(compartida.id), true);
  });

  test('la búsqueda ignora acentos y encuentra por principio activo', () {
    final resultados = catalog.buscar('acepromazina', especie: 'Perro');
    expect(resultados, isNotEmpty);
    expect(
      resultados.any((p) => p.nombre.toLowerCase().contains('acepromazina')),
      true,
    );
    expect(catalog.buscar('ACEPROMAZINA'), isNotEmpty);
  });

  test('el filtro de especie no devuelve principios sin pauta de esa especie', () {
    for (final especie in catalog.especies) {
      final principios = catalog.buscar('', especie: especie);
      expect(principios, isNotEmpty, reason: 'sin principios para $especie');
      for (final p in principios) {
        expect(catalog.pautasDe(p.id, especie: especie), isNotEmpty);
      }
    }
  });

  test('un id repetido se rechaza al cargar', () {
    final fila = {
      'id': 'X1',
      'id_farmaco': 'F1',
      'especie': 'Perro',
      'especies': ['Perro'],
      'indicacion': 'prueba',
    };
    final doc = jsonEncode({
      'schema_version': 1,
      'version': 'prueba',
      'farmacos': [
        {'id': 'F1', 'principio_activo': 'A'},
        {'id': 'F1', 'principio_activo': 'B'},
      ],
      'dosis': [fila],
    });
    expect(() => FarmacologicoCatalog.parse(doc), throwsFormatException);
  });

  test('un esquema desconocido se rechaza', () {
    expect(
      () => FarmacologicoCatalog.parse(
        jsonEncode({'schema_version': 2, 'farmacos': [], 'dosis': []}),
      ),
      throwsFormatException,
    );
  });

  test('un rango invertido se rechaza', () {
    final doc = jsonEncode({
      'schema_version': 1,
      'version': 'prueba',
      'farmacos': [
        {'id': 'F1', 'principio_activo': 'A'},
      ],
      'dosis': [
        {
          'id': 'D1',
          'id_farmaco': 'F1',
          'especies': ['Perro'],
          'dosis_min': '5',
          'dosis_max': '1',
          'base_calculo': 'masa',
        },
      ],
    });
    expect(() => FarmacologicoCatalog.parse(doc), throwsFormatException);
  });
}

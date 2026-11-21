import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/core/domain/section_catalog.dart';
import 'package:vetdosis_pro/modules/welcome/presentation/guided_start_screen.dart';

/// `docs/mapa-de-la-app.md` es la referencia que se lee antes de tocar una
/// pantalla. Si se queda atras, manda a archivos y widgets que ya no existen.
/// Estas comprobaciones atan el mapa al codigo actual.
void main() {
  final mapa = File('docs/mapa-de-la-app.md');
  final codigo = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map((f) => f.readAsStringSync())
      .join('\n');

  test('el mapa de la app existe y no esta vacio', () {
    expect(mapa.existsSync(), isTrue);
    expect(mapa.readAsStringSync().trim(), isNotEmpty);
  });

  test('cada apartado del catalogo tiene su fila en el mapa', () {
    final lineas = mapa.readAsLinesSync();
    final inicio = lineas.indexWhere((l) => l.startsWith('## 3.'));
    final fin = lineas.indexWhere((l) => l.startsWith('## 4.'));
    expect(inicio, greaterThan(-1));
    expect(fin, greaterThan(inicio));

    // La primera columna puede agrupar apartados («Inventario / Caja»), asi
    // que se compara por nombre completo y no por prefijo.
    final documentados = <String>{
      for (final linea in lineas.sublist(inicio, fin))
        if (linea.startsWith('|') && !linea.startsWith('|---'))
          ...linea
              .split('|')[1]
              .split('/')
              .map((n) => n.trim().replaceAll('(ruta)', '').trim()),
    }..removeWhere((n) => n.isEmpty || n == 'Apartado');

    final sinFila = [
      for (final grupo in sectionGroups)
        for (final page in grupo.pages)
          if (!documentados.contains(page)) page,
    ];
    expect(sinFila, isEmpty, reason: 'apartados sin fila en el mapa: $sinFila');
  });

  test('cada widget citado en el mapa existe en lib', () {
    final texto = mapa.readAsStringSync();
    final citados = RegExp(
      r'`([A-Z][A-Za-z0-9_]*(?:Screen|Menu|Banner|Panel))`',
    ).allMatches(texto).map((m) => m.group(1)!).toSet();
    expect(citados, isNotEmpty, reason: 'el mapa no cita ningun widget');
    final inexistentes = citados
        .where((n) => !RegExp('class $n\\b').hasMatch(codigo))
        .toList();
    expect(inexistentes, isEmpty, reason: 'widgets que ya no existen: $inexistentes');
  });

  test('los pasos del Inicio guiado llevan a apartados reales', () {
    final texto = mapa.readAsStringSync();
    expect(texto, contains('GuidedStartScreen'));
    for (final paso in guideSteps) {
      final destino = paso.$3;
      expect(
        texto,
        contains(destino),
        reason: 'el paso "${paso.$1}" va a "$destino", que el mapa no menciona',
      );
    }
  });
}

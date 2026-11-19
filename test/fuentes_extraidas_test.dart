import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Las fuentes de referencia se revisan en git, no en una hoja de calculo.
/// Cada fuente debe tener su volcado en Markdown, y el volcado debe traer el
/// texto de la fuente: comprobar solo que el archivo existe dejaria pasar un
/// .md vacio o desactualizado.
void main() {
  final dir = Directory('docs/product/fuentes');
  final fuentes = dir
      .listSync()
      .whereType<File>()
      .where(
        (f) => const {'.xlsx', '.csv', '.html', '.json'}.contains(
          f.path.substring(f.path.lastIndexOf('.')),
        ),
      )
      .toList();

  test('hay fuentes de referencia que revisar', () {
    expect(fuentes, isNotEmpty);
  });

  for (final fuente in fuentes) {
    final nombre = fuente.uri.pathSegments.last;
    test('$nombre tiene su texto en Markdown', () {
      final md = File('${fuente.path.substring(0, fuente.path.lastIndexOf('.'))}.md');
      expect(md.existsSync(), isTrue, reason: 'falta el volcado de $nombre');

      final texto = md.readAsStringSync();
      expect(texto.trim(), isNotEmpty, reason: 'el volcado de $nombre esta vacio');
      expect(
        texto,
        contains(fuente.uri.pathSegments.last),
        reason: 'el volcado de $nombre no cita la fuente',
      );

      // Cada fuente trae al menos una cifra o un nombre propio; si el volcado
      // perdiera el cuerpo, solo quedaria la cabecera.
      expect(
        texto.length,
        greaterThan(500),
        reason: 'el volcado de $nombre parece solo la cabecera',
      );
    });
  }
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Las fuentes de referencia se revisan en git, no en una hoja de calculo.
/// Cada fuente debe tener su volcado en Markdown, y el volcado debe traer el
/// texto de la fuente: comprobar solo que el archivo existe dejaria pasar un
/// .md vacio o desactualizado.
void main() {
  // Fuentes tabulares y documentos: cada una debe tener su volcado legible.
  const fuentes = {
    'docs/product/fuentes': {'.xlsx', '.csv', '.html', '.json'},
    'docs/formatos-referencia': {'.pdf'},
    'review/formatos': {'.pdf'},
  };

  final pendientes = <File>[];
  for (final entrada in fuentes.entries) {
    final dir = Directory(entrada.key);
    if (!dir.existsSync()) continue;
    pendientes.addAll(
      dir
          .listSync()
          .whereType<File>()
          .where(
            (f) => entrada.value.contains(
              f.path.substring(f.path.lastIndexOf('.')),
            ),
          ),
    );
  }

  test('hay fuentes de referencia que revisar', () {
    expect(pendientes, isNotEmpty);
  });

  for (final fuente in pendientes) {
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

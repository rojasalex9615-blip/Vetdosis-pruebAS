import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// La escala viva de [VetTheme.textTheme] mas los tamanos de cartel que se
/// dibujan a mano (imagen promocional, marca). Un texto de interfaz que fije
/// su propio tamano fuera de esta lista rompe la jerarquia: es exactamente lo
/// que hacia ilegibles y desordenadas las pantallas Neu (86 textos a 11 px,
/// titulos de seccion a 18, saludo a 17, botones con Roboto fijado).
const _escala = <double>[12, 14, 16, 22, 24, 26, 30, 32];

/// El PDF no es interfaz: su tamano se mide en milimetros de papel y no sigue
/// la escala de pantalla.
const _fueraDeAlcance = <String>[
  'lib/modules/exports/', // pw.TextStyle: documentos impresos
];

/// Fuentes donde se admite un tamano suelto: carteles que se pintan como
/// imagen, no texto de pantalla.
const _permitidos = <String>[
  'lib/modules/operations/presentation/promotion_image_screen.dart',
];

/// Un `fontSize:` con un numero literal, y su valor.
final _literal = RegExp(r'fontSize:\s*([0-9]+(?:\.[0-9]+)?)');

/// Los tamanos del PDF se miden en milimetros de papel, no en la escala de
/// pantalla: `pw.TextStyle(fontSize: 18)` no es un texto de interfaz.
final _pdf = RegExp(r'\bpw\s*\.\s*TextStyle');

void main() {
  test('Ningun texto de interfaz fija un tamano fuera de la escala', () {
    final infracciones = <String>[];
    final raiz = Directory('lib');
    for (final f in raiz.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final ruta = f.path.replaceAll(r'\', '/');
      if (_fueraDeAlcance.any(ruta.startsWith)) continue;
      if (_permitidos.contains(ruta)) continue;
      final lineas = f.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        final linea = lineas[i];
        if (linea.trimLeft().startsWith('//')) continue;
        if (_pdf.hasMatch(linea)) continue;
        final m = _literal.firstMatch(linea);
        if (m == null) continue;
        final valor = double.parse(m.group(1)!);
        if (!_escala.contains(valor)) {
          infracciones.add('$ruta:${i + 1} → fontSize: $valor');
        }
      }
    }
    expect(
      infracciones,
      isEmpty,
      reason:
          'Estos tamanos no pertenecen a la escala $_escala. Usa '
          'Theme.of(context).textTheme.<estilo> en vez de un numero suelto, '
          'o anade el valor a la escala si de verdad falta:\n'
          '${infracciones.join('\n')}',
    );
  });

  test('La escala del tema no baja del suelo legible', () {
    // El suelo son 12 px: por debajo, en un telefono, el texto no se lee.
    final suelo = 12.0;
    final pequenos = <String>[];
    final f = File('lib/vet_ui/vet_theme.dart');
    for (var i = 0; i < f.readAsLinesSync().length; i++) {
      final linea = f.readAsLinesSync()[i];
      final m = _literal.firstMatch(linea);
      if (m == null) continue;
      final valor = double.parse(m.group(1)!);
      if (valor < suelo) pequenos.add('vet_theme.dart:${i + 1} → $valor');
    }
    expect(
      pequenos,
      isEmpty,
      reason: 'La escala no puede bajar de $suelo px:\n${pequenos.join('\n')}',
    );
  });
}

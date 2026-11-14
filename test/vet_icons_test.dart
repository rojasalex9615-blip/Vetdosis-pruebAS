import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/vet_ui/vet_icons.dart';

void main() {
  test('cada icono apunta a la fuente VetIcons con un codigo unico', () {
    final codes = <int>{};
    for (final entry in VetIcons.all.entries) {
      expect(entry.value.fontFamily, 'VetIcons', reason: entry.key);
      expect(codes.add(entry.value.codePoint), isTrue, reason: entry.key);
    }
  });

  test('la clase generada coincide con codepoints.json y con svg/', () {
    final json =
        jsonDecode(File('tools/icons/codepoints.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(
      {for (final e in VetIcons.all.entries) e.key: e.value.codePoint},
      json,
      reason: 'Falta volver a correr tools/icons/build_font.py',
    );
    final svgs = Directory('tools/icons/svg')
        .listSync()
        .map((f) => f.uri.pathSegments.last)
        .where((f) => f.endsWith('.svg'))
        .map((f) => f.substring(0, f.length - 4))
        .toSet();
    expect(svgs, json.keys.toSet());
  });

  test('pubspec declara la fuente que usan los iconos', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('family: VetIcons'));
    expect(pubspec, contains('assets/fonts/VetIcons.ttf'));
    expect(File('assets/fonts/VetIcons.ttf').existsSync(), isTrue);
  });

  testWidgets('un Icon de VetIcons se pinta con el color del tema', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: IconTheme(
          data: IconThemeData(color: Color(0xFF7C4DFF), size: 32),
          child: Icon(VetIcons.paw),
        ),
      ),
    );
    final text = tester.widget<RichText>(find.byType(RichText));
    expect(text.text.style?.fontFamily, 'VetIcons');
    expect(text.text.style?.color, const Color(0xFF7C4DFF));
    expect(text.text.style?.fontSize, 32);
  });

  // En telefono los iconos salian corridos a la izquierda: la fuente declaraba
  // margen izquierdo 0 y el motor pegaba cada dibujo al borde. Se pinta de
  // verdad y se mide donde cae la tinta.
  testWidgets('el dibujo queda centrado en su caja', (tester) async {
    await tester.runAsync(
      () => (FontLoader(
        'VetIcons',
      )..addFont(rootBundle.load('assets/fonts/VetIcons.ttf'))).load(),
    );
    const size = 96.0;
    for (final name in const ['paw', 'home', 'calendar', 'calculator']) {
      final key = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: key,
              child: ColoredBox(
                color: const Color(0xFFFFFFFF),
                child: Icon(
                  VetIcons.all[name],
                  size: size,
                  color: const Color(0xFF000000),
                ),
              ),
            ),
          ),
        ),
      );
      late double centerX;
      late double centerY;
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        var minX = image.width, maxX = -1, minY = image.height, maxY = -1;
        for (var y = 0; y < image.height; y++) {
          for (var x = 0; x < image.width; x++) {
            if (data.getUint8((y * image.width + x) * 4) < 128) {
              if (x < minX) minX = x;
              if (x > maxX) maxX = x;
              if (y < minY) minY = y;
              if (y > maxY) maxY = y;
            }
          }
        }
        expect(maxX, greaterThan(minX), reason: '$name no pinto nada');
        centerX = (minX + maxX + 1) / 2;
        centerY = (minY + maxY + 1) / 2;
        image.dispose();
      });
      expect(centerX, closeTo(size / 2, 1.5), reason: '$name, horizontal');
      expect(centerY, closeTo(size / 2, 1.5), reason: '$name, vertical');
    }
  });
}

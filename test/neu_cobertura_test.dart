import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/core/widgets/workspace_panel.dart';
import 'package:vetdosis_pro/vet_ui/vet_components.dart';

/// Cobertura del relieve neu: que no quede una superficie fuera del sistema.
///
/// Ale lo pillo mirando el APK: varios apartados se veian planos en medio de
/// pantallas con relieve. La causa no era que faltara aplicarlo en cada
/// pantalla, sino que la tarjeta compartida no era neu y que dos sitios se
/// habian pintado su propio par de sombras a mano, con valores de antes de
/// que el relieve se suavizara. La app tenia tres profundidades distintas.
void main() {
  Future<void> montar(WidgetTester tester, {required bool neu}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF087F83)),
          extensions: [WorkspaceStyle(neumorphic: neu)],
        ),
        home: const Scaffold(body: VetCard(child: Text('Secciones'))),
      ),
    );
    await tester.pumpAndSettle();
  }

  BoxDecoration decoracionExterior(WidgetTester tester) => tester
      .widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(VetCard),
          matching: find.byType(DecoratedBox),
        ),
      )
      .map((d) => d.decoration)
      .whereType<BoxDecoration>()
      .firstWhere((d) => d.boxShadow != null && d.boxShadow!.isNotEmpty);

  testWidgets('La tarjeta compartida se levanta con el PAR, no con una sombra', (
    tester,
  ) async {
    // Una sola sombra hacia abajo es la elevacion de Material. El neu necesita
    // dos: una clara arriba a la izquierda y una oscura abajo a la derecha. Es
    // lo que distingue «levantado» de «flotando sobre la pagina».
    await montar(tester, neu: true);
    final sombras = decoracionExterior(tester).boxShadow!;
    expect(sombras, hasLength(2), reason: 'el relieve neu es un par');
    final claras = sombras.where((s) => s.offset.dx < 0 && s.offset.dy < 0);
    final oscuras = sombras.where((s) => s.offset.dx > 0 && s.offset.dy > 0);
    expect(claras, hasLength(1), reason: 'falta la luz de arriba a la izquierda');
    expect(oscuras, hasLength(1), reason: 'falta la sombra de abajo a la derecha');
  });

  testWidgets('En neu la tarjeta no se dibuja con trazo', (tester) async {
    // Lo que sobresale se define por la sombra. Un borde visible encima lo
    // devuelve al lenguaje de Material y es lo que se veia en las capturas.
    await montar(tester, neu: true);
    final bordes = tester
        .widgetList<Container>(find.descendant(
          of: find.byType(VetCard),
          matching: find.byType(Container),
        ))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.border)
        .whereType<Border>();
    expect(bordes, isNotEmpty);
    for (final b in bordes) {
      expect(
        b.top.color.a,
        0,
        reason: 'el trazo debe ser transparente, no ausente: ocupa 1 px y de '
            'el sale el padding efectivo de 17 que ya miden otras pruebas',
      );
      expect(b.top.width, greaterThan(0), reason: 'la geometria no se mueve');
    }
  });

  testWidgets('El clasico se queda como estaba', (tester) async {
    await montar(tester, neu: false);
    final d = decoracionExterior(tester);
    expect(d.boxShadow, hasLength(1), reason: 'el clasico es Material, no neu');
    final bordes = tester
        .widgetList<Container>(find.descendant(
          of: find.byType(VetCard),
          matching: find.byType(Container),
        ))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.border)
        .whereType<Border>();
    for (final b in bordes) {
      expect(b.top.color.a, greaterThan(0), reason: 'el clasico si lleva trazo');
    }
  });

  test('Nadie se pinta su propio par de sombras', () {
    // El defecto de fondo: tres sitios con relieve propio y tres
    // profundidades. Quien necesite otra intensidad usa el parametro depth de
    // neuShadows, que escala las dos a la vez, en vez de copiar los offsets.
    final sospechosos = <String>[];
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      // neu_identity es donde vive neuShadows: ahi si se escriben a mano.
      if (f.path.endsWith('neu_identity.dart')) continue;
      final texto = f.readAsStringSync();
      for (final m in RegExp(r'boxShadow:\s*\[').allMatches(texto)) {
        final trozo = texto.substring(
          m.start,
          (m.start + 420).clamp(0, texto.length),
        );
        // Dos BoxShadow seguidos en una lista escrita a mano es un par neu
        // reinventado. Uno solo puede ser elevacion legitima del clasico.
        if ('BoxShadow('.allMatches(trozo).length >= 2) {
          sospechosos.add(f.path.replaceFirst('lib/', ''));
        }
      }
    }
    expect(
      sospechosos,
      isEmpty,
      reason: 'usa neuShadows(dark, depth: ...) en vez de copiar el par',
    );
  });
}

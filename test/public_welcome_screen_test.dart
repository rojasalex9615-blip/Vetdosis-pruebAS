import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/welcome/presentation/public_welcome_screen.dart';
import 'package:vetdosis_pro/modules/welcome/presentation/welcome_intro_video.dart';

void main() {
  Future<void> pumpWelcome(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PublicWelcomeScreen(auth: null)),
    );
    await tester.pump();
  }

  testWidgets(
    'La bienvenida abre con la animacion de marca y los dos accesos',
    (tester) async {
      await pumpWelcome(tester);
      expect(find.byType(WelcomeIntroVideo), findsOneWidget);
      expect(find.text('Bienvenido a VetDosis'), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(find.text('Crear cuenta'), findsOneWidget);
    },
  );

  testWidgets(
    'Sin reproductor de video la pantalla sigue en pie',
    (tester) async {
      // En la prueba no hay plugin de video: el arranque falla y la pantalla
      // debe quedarse con el poster, sin excepciones ni hueco.
      await pumpWelcome(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(WelcomeIntroVideo), findsOneWidget);
    },
  );

  testWidgets('Las tres laminas se pueden recorrer', (tester) async {
    await pumpWelcome(tester);
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Qué incluye VetDosis Pro'), findsOneWidget);
    expect(find.text('Cálculos con criterio'), findsOneWidget);

    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Planes'), findsOneWidget);
    expect(find.text('Beta cerrada. Planes y precios por anunciar.'),
        findsOneWidget);
    // Los planes conservan su lista y debajo llevan el mismo resumen
    // numerado que la lamina anterior.
    await tester.dragUntilVisible(
      find.text('IA que asiste, no decide'),
      find.byType(ListView).last,
      const Offset(0, -200),
    );
    expect(find.text('5'), findsOneWidget);
  });

  test('Cada tema tiene su video y su poster, y los archivos existen', () {
    for (final brightness in Brightness.values) {
      final video = WelcomeIntroVideo.assetFor(brightness);
      final poster = WelcomeIntroVideo.posterFor(brightness);
      expect(File(video).existsSync(), isTrue, reason: video);
      expect(File(poster).existsSync(), isTrue, reason: poster);
    }
    expect(
      WelcomeIntroVideo.assetFor(Brightness.dark),
      isNot(WelcomeIntroVideo.assetFor(Brightness.light)),
    );
  });
}

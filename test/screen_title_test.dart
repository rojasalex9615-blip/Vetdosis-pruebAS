import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/core/widgets/screen_title.dart';

/// Los titulos llegaban cortados al telefono: «Produccion y g...», «Calculos
/// clinic...». Estas pruebas miden el widget que se pinta de verdad, dentro
/// de una barra real y a ancho de telefono, no una copia escrita aqui.
void main() {
  // Los nombres de pantalla mas largos que el menu puede mostrar.
  const largos = [
    'Producción y grandes especies',
    'Escanear etiqueta para dosis',
    'Administración y finanzas',
    'Estadísticas y respaldo',
    'Cálculos clínicos',
  ];

  Future<void> montar(WidgetTester tester, String titulo, double ancho) async {
    tester.view.physicalSize = Size(ancho * 2, 1560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: ScreenTitle(screen: titulo, clinic: 'vet prueba1'),
            // Los dos iconos reales de la barra: comen ancho del titulo.
            actions: const [
              Icon(Icons.person_outline),
              Icon(Icons.auto_awesome),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  for (final ancho in [360.0, 320.0]) {
    testWidgets('A $ancho dp ningun nombre de pantalla se corta', (
      tester,
    ) async {
      for (final titulo in largos) {
        await montar(tester, titulo, ancho);
        final parrafo = tester.renderObject<RenderParagraph>(find.text(titulo));
        expect(
          parrafo.didExceedMaxLines,
          isFalse,
          reason: '«$titulo» se corta a $ancho dp',
        );
        expect(
          parrafo.text.toPlainText(),
          titulo,
          reason: '«$titulo» no se pinta entero',
        );
      }
    });
  }

  testWidgets('El nombre largo encoge en vez de recortarse', (tester) async {
    // Ojo con como se mide: FittedBox escala con una transformacion y no
    // cambia el tamano de distribucion del hijo, asi que `getSize` del Text
    // devuelve el natural en los dos casos. Lo pintado se ve en `getRect`.
    await montar(tester, 'Inicio', 360);
    final corto = tester.getRect(find.text('Inicio')).height;

    const largo = 'Producción y grandes especies';
    await montar(tester, largo, 360);
    final largoAlto = tester.getRect(find.text(largo)).height;

    expect(
      largoAlto,
      lessThan(corto),
      reason: 'el nombre largo no se esta encogiendo para caber',
    );

    // Suelo de legibilidad. Hoy el peor caso cae en 12.3 px de alto a 360 dp,
    // que se lee pero es pequeno; queda anotado como el limite que toleramos.
    // Si un nombre nuevo baja de ahi, hay que partir el titulo en dos lineas
    // en vez de seguir encogiendo.
    for (final titulo in largos) {
      await montar(tester, titulo, 360);
      expect(
        tester.getRect(find.text(titulo)).height,
        greaterThanOrEqualTo(12),
        reason: '«$titulo» queda demasiado pequeno para leerse',
      );
    }
  });

  testWidgets('Sin sesion no se pinta una segunda linea vacia', (tester) async {
    tester.view.physicalSize = const Size(720, 1560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const ScreenTitle(screen: 'Agenda')),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Text), findsOneWidget);
  });
}

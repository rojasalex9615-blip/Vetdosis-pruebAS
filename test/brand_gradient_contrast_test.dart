import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/core/widgets/brand_gradient.dart';
import 'package:vetdosis_pro/core/widgets/contrast.dart';
import 'package:vetdosis_pro/core/widgets/neu_identity.dart';
import 'package:vetdosis_pro/vet_ui/vet_theme.dart';
import 'package:vetdosis_pro/vet_ui/vet_icons.dart';

/// El degradado de marca se usa de dos maneras distintas y cada una tiene su
/// propia trampa:
///
/// - En el icono de IA el degradado **es** el glifo, así que son sus propios
///   tonos los que tienen que destacar sobre la barra. Los tonos de marca son
///   claros, y sobre la barra casi blanca del tema neu el extremo turquesa se
///   quedaba en 1.52:1.
/// - En el botón flotante del escáner el degradado es el **relleno** y el
///   glifo va encima. Ahí el glifo iba en blanco fijo, que sobre el extremo
///   turquesa daba 1.79:1.
///
/// Ninguno de los dos lo cubría una prueba. El segundo no lo reportó ningún
/// revisor.
void main() {
  // Los fondos reales sobre los que puede apoyarse el icono, tomados del tema
  // y de la identidad neu, no copiados a mano aquí.
  const fondos = {
    'barra clara neu': neuBackground,
    'lienzo claro': VetColors.canvas,
    'grafito': VetColors.darkCanvas,
    'superficie oscura': VetColors.darkSurface,
  };

  group('Icono de IA: el degradado es el glifo', () {
    for (final (nombre, fondo) in fondos.entries.map((e) => (e.key, e.value))) {
      testWidgets('se ve sobre la $nombre', (tester) async {
        // Se pregunta por el fondo usando el mismo camino que usa el widget
        // al construirse, desde el contexto real donde vive el icono.
        late BuildContext contextoDelIcono;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              appBarTheme: AppBarTheme(backgroundColor: fondo),
              scaffoldBackgroundColor: fondo,
            ),
            home: Scaffold(
              appBar: AppBar(
                actions: [
                  Builder(
                    builder: (context) {
                      contextoDelIcono = context;
                      return const BrandGradientIcon(VetIcons.sparkles);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();

        final resuelto = BrandGradientIcon.backgroundOf(contextoDelIcono);
        expect(
          resuelto,
          fondo,
          reason: 'el widget no está midiendo contra la barra que se pinta',
        );

        // Y el ShaderMask existe de verdad en el árbol: si alguien cambia el
        // icono por uno plano, esta prueba deja de tener sentido y debe fallar.
        expect(find.byType(ShaderMask), findsOneWidget);

        for (final tono in brandPaletteOn(resuelto)) {
          expect(
            contrastRatio(tono, resuelto),
            greaterThanOrEqualTo(3),
            reason: 'un tramo del degradado se pierde sobre la $nombre',
          );
        }
      });
    }

    test('el recorrido sigue siendo el de marca, no colores nuevos', () {
      // Sobre el grafito ningún tono necesita retoque: debe salir intacto.
      expect(brandPaletteOn(VetColors.darkCanvas), brandGradientColors);
      // Y donde sí hace falta retoque, los tres tramos siguen siendo tres
      // tonos distintos en vez de aplanarse a uno solo.
      //
      // No se comprueba el orden de luminosidad: el recorrido que entregó Ale
      // (aqua → azul → lila) es deliberadamente parejo de claridad, y exigir
      // que fuera de claro a oscuro era una suposición de la paleta anterior,
      // no un requisito del diseño.
      final clara = brandPaletteOn(neuBackground);
      expect(clara.length, brandGradientColors.length);
      expect(
        clara.toSet().length,
        clara.length,
        reason: 'el degradado se aplanó: dos tramos acabaron en el mismo tono',
      );
      for (final (i, tono) in clara.indexed) {
        expect(
          HSLColor.fromColor(tono).hue,
          closeTo(HSLColor.fromColor(brandGradientColors[i]).hue, 2),
          reason: 'el tramo $i perdió el matiz de marca',
        );
      }
    });
  });

  group('Botón flotante del escáner: el degradado es el relleno', () {
    test('la tinta elegida aguanta el peor tramo del degradado', () {
      final tinta = inkOnGradient(brandGradientColors);
      for (final tramo in brandGradientColors) {
        expect(
          contrastRatio(tinta, tramo),
          greaterThanOrEqualTo(3),
          reason: 'el glifo se pierde sobre uno de los tramos',
        );
      }
    });

    test('el blanco fijo que había antes no habría pasado', () {
      // Se deja escrito para que nadie lo devuelva a blanco pensando que da
      // igual: sobre el turquesa daba 1.79:1.
      expect(
        brandGradientColors
            .map((tramo) => contrastRatio(Colors.white, tramo))
            .reduce((a, b) => a < b ? a : b),
        lessThan(3),
      );
    });

    testWidgets('el botón pintado usa esa tinta medida', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: brandGradient(),
              ),
              child: FloatingActionButton(
                backgroundColor: Colors.transparent,
                foregroundColor: inkOnGradient(brandGradientColors),
                elevation: 0,
                onPressed: () {},
                child: const Icon(VetIcons.documentScan),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final boton = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      final relleno = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox).first,
      );
      final tramos = ((relleno.decoration as BoxDecoration).gradient!
              as LinearGradient)
          .colors;
      for (final tramo in tramos) {
        expect(
          contrastRatio(boton.foregroundColor!, tramo),
          greaterThanOrEqualTo(3),
          reason: 'el glifo del botón no se lee sobre su propio relleno',
        );
      }
    });
  });
}

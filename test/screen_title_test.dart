import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/core/widgets/screen_title.dart';

/// Los titulos llegaban cortados al telefono: «Produccion y g...», «Calculos
/// clinic...».
///
/// La primera version de estas pruebas valia poco, y lo senalaron Qodo y
/// Greptile: comprobaba `didExceedMaxLines` y `toPlainText()` sobre un Text
/// dentro de un FittedBox, que recibe ancho sin limite y por tanto nunca
/// desborda ni recorta. Ademas montaba la barra con iconos pelados y sin
/// cajon, asi que le daba al titulo 280 dp de sitio que el telefono no tiene.
/// Con la barra real son unos 176 dp, y alli el nombre largo acababa pintado
/// a 7.7 px de alto.
///
/// Ahora se monta la barra como es —cajon, dos IconButton— y se mide la
/// geometria de lo pintado.
void main() {
  const largos = [
    'Producción y grandes especies',
    'Escanear etiqueta para dosis',
    'Administración y finanzas',
    'Estadísticas y respaldo',
    'Cálculos clínicos',
    'Inicio',
  ];

  Future<void> montar(WidgetTester tester, String titulo, double ancho) async {
    tester.view.physicalSize = Size(ancho * 2, 1560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // El cajon pone la hamburguesa a la izquierda: ocupa ancho real.
          drawer: const Drawer(),
          appBar: AppBar(
            toolbarHeight: 96,
            title: ScreenTitle(screen: titulo, clinic: 'vet prueba1'),
            actions: [
              IconButton(
                icon: const Icon(Icons.person_outline),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.auto_awesome),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  for (final ancho in [360.0, 320.0]) {
    testWidgets('A $ancho dp el titulo se lee y no invade los botones', (
      tester,
    ) async {
      for (final titulo in largos) {
        await montar(tester, titulo, ancho);
        final texto = tester.getRect(find.text(titulo));
        final primerBoton = tester.getRect(
          find.byIcon(Icons.person_outline),
        );

        // No se mete debajo de los botones de la derecha.
        expect(
          texto.right,
          lessThanOrEqualTo(primerBoton.left),
          reason: '«$titulo» se solapa con los botones a $ancho dp',
        );

        // Y se lee: el alto de una linea pintada no baja del suelo. Con dos
        // lineas el rectangulo mide el doble, asi que se divide.
        final lineas = screenTitleFit(
          titulo,
          primerBoton.left - texto.left,
          const TextStyle(fontSize: 22),
        ).lines;
        expect(
          texto.height / lineas,
          greaterThanOrEqualTo(13),
          reason: '«$titulo» queda demasiado pequeno para leerse a $ancho dp',
        );
      }
    });
  }

  testWidgets('Un nombre largo usa dos lineas en vez de encogerse a nada', (
    tester,
  ) async {
    await montar(tester, 'Inicio', 360);
    final corto = tester.getRect(find.text('Inicio'));

    const largo = 'Producción y grandes especies';
    await montar(tester, largo, 360);
    final alto = tester.getRect(find.text(largo));

    expect(
      alto.height,
      greaterThan(corto.height),
      reason: 'el nombre largo deberia ocupar dos lineas',
    );
  });

  test('La regla de ajuste parte en dos antes que encoger sin limite', () {
    const estilo = TextStyle(fontSize: 22);
    // Cabe de sobra: una linea, sin tocar.
    final corto = screenTitleFit('Inicio', 300, estilo);
    expect(corto.lines, 1);
    expect(corto.scale, 1);

    // No cabe: dos lineas, y nunca por debajo del suelo medido.
    final largo = screenTitleFit('Producción y grandes especies', 176, estilo);
    expect(largo.lines, 2);
    expect(largo.scale, greaterThanOrEqualTo(screenTitleMinScale));
    expect(largo.scale, lessThan(1));
  });

  testWidgets('Queda anotado que nombres siguen sin caber enteros', (
    tester,
  ) async {
    // Limite conocido y aceptado, no un descuido. Con la hamburguesa y los
    // dos botones, la barra deja unos 176 dp. A la escala minima legible
    // (0.62) caben unos 22 caracteres en dos lineas; por encima de eso el
    // nombre se recorta aunque ya no se encoja mas.
    //
    // Para que entraran enteros habria que darle sitio al titulo: quitar uno
    // de los dos botones de la derecha, o acortar los nombres. Las dos cosas
    // son decision de Ale, no mia. Mientras tanto esta lista deja constancia
    // de cuales son, y salta si alguien anade otro sin darse cuenta.
    const seCortan = {
      'Producción y grandes especies',
      'Escanear etiqueta para dosis',
      'Administración y finanzas',
      'Estadísticas y respaldo',
    };
    for (final titulo in largos) {
      await montar(tester, titulo, 360);
      final parrafo = tester.renderObject<RenderParagraph>(find.text(titulo));
      expect(
        parrafo.didExceedMaxLines,
        seCortan.contains(titulo),
        reason: seCortan.contains(titulo)
            ? '«$titulo» ya cabe entero: quitalo de la lista'
            : '«$titulo» empezo a cortarse y no estaba previsto',
      );
    }
  });

  testWidgets('Con el texto del sistema agrandado los nombres siguen enteros', (
    tester,
  ) async {
    // Lo encontro Greptile: la medida usaba TextPainter sin el factor de
    // texto del sistema, pero Text si lo aplica al pintar, asi que un nombre
    // medido como de una linea acababa recortado. Al comprobarlo salio peor
    // de lo que decia: con el texto al 160% hasta «Agenda» se cortaba.
    const cortos = ['Agenda', 'Pacientes', 'Cálculos clínicos'];
    for (final escala in [1.0, 1.3, 1.6, 2.0]) {
      for (final titulo in cortos) {
        tester.view.physicalSize = const Size(720, 1560);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, hijo) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(escala)),
              child: hijo!,
            ),
            home: Scaffold(
              drawer: const Drawer(),
              appBar: AppBar(
                toolbarHeight: 160,
                title: ScreenTitle(screen: titulo, clinic: 'vet prueba1'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.person_outline),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.auto_awesome),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          tester.renderObject<RenderParagraph>(find.text(titulo))
              .didExceedMaxLines,
          isFalse,
          reason: '«$titulo» se corta con el texto al ${escala}x',
        );
      }
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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetdosis_pro/core/app.dart';
import 'package:vetdosis_pro/modules/core/data/settings_repository.dart';
import 'package:vetdosis_pro/modules/core/presentation/core_view_model.dart';

/// El relieve de los botones entra por el TEMA, no caso por caso.
///
/// Antes solo cuatro accesos de Inicio lo llevaban, envueltos a mano en un
/// DecoratedBox. Los otros 155 FilledButton y 123 OutlinedButton seguian con
/// la elevacion de Material: una sombra sola hacia abajo, que no es relieve
/// neu. Estas pruebas miden el arbol que el tema produce, para que nadie
/// vuelva a dejar la mitad de los botones fuera del estilo.
///
/// No se mide con TestRecordingCanvas a proposito: es ciega a lo que pinta
/// Material con una capa en vez de con una orden de lienzo, y leer su cero
/// como «no hay relieve» daria el defecto por confirmado con una prueba
/// incapaz de verlo. Aqui se lee la decoracion del widget, que si esta.
Future<ThemeData> temaDe(WidgetTester tester, String style) async {
  SharedPreferences.setMockInitialValues({});
  final core = CoreViewModel(
    SettingsRepository(),
    AppSettings(visualStyle: style),
  );
  addTearDown(core.dispose);
  final app = VetDosisApp(model: core);
  return app.theme(Brightness.light);
}

/// Degradados que el tema mete bajo el contenido del boton.
Iterable<LinearGradient> degradados(WidgetTester tester, Finder boton) => tester
    .widgetList<DecoratedBox>(
      find.descendant(of: boton, matching: find.byType(DecoratedBox)),
    )
    .map((d) => d.decoration)
    .whereType<BoxDecoration>()
    .map((d) => d.gradient)
    .whereType<LinearGradient>();

Future<void> montar(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Column(
          children: [
            FilledButton(onPressed: () {}, child: const Text('Guardar')),
            OutlinedButton(onPressed: () {}, child: const Text('Cancelar')),
            TextButton(onPressed: () {}, child: const Text('Saber más')),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Neu da relieve al boton primario y al secundario', (
    tester,
  ) async {
    await montar(tester, await temaDe(tester, 'neu'));

    expect(
      degradados(tester, find.byType(FilledButton)),
      isNotEmpty,
      reason: 'el FilledButton debe recibir el degradado desde el tema',
    );
    expect(
      degradados(tester, find.byType(OutlinedButton)),
      isNotEmpty,
      reason: 'el OutlinedButton debe leerse como placa, no como trazo',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('El secundario pierde el trazo: se levanta, no se dibuja', (
    tester,
  ) async {
    final theme = await temaDe(tester, 'neu');
    final side = theme.outlinedButtonTheme.style?.side?.resolve(const {});
    expect(side, BorderSide.none);
  });

  testWidgets('El secundario se distingue del fondo sin necesitar trazo', (
    tester,
  ) async {
    // La trampa en la que cai al quitarle el borde: le puse de fondo la misma
    // superficie de la pagina. Sin trazo, sin sombra exterior y del color
    // exacto del fondo, el boton dejaba de verse como boton. La placa tiene
    // que ir mas clara que el fondo, que es como se levanta algo en neu.
    for (final brightness in Brightness.values) {
      SharedPreferences.setMockInitialValues({});
      final core = CoreViewModel(SettingsRepository(), const AppSettings());
      addTearDown(core.dispose);
      final theme = VetDosisApp(model: core).theme(brightness);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: OutlinedButton(
              onPressed: () {},
              child: const Text('Crear cuenta'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final placa = tester
          .widgetList<Material>(
            find.descendant(
              of: find.byType(OutlinedButton),
              matching: find.byType(Material),
            ),
          )
          .first
          .color;
      expect(
        placa,
        isNot(theme.scaffoldBackgroundColor),
        reason: 'en ${brightness.name} la placa se confunde con la pagina',
      );
    }
  });

  testWidgets('El degradado respeta la esquina redonda del boton', (
    tester,
  ) async {
    // Lo que se me escapo midiendo solo la forma: el Material resolvia a
    // radio 24, pero el degradado se pintaba encima en rectangulo y tapaba
    // las esquinas, asi que el boton se veia cuadrado en pantalla. La
    // documentacion de backgroundBuilder promete recortar a la forma del
    // boton y no basta. Se comprueba lo que se pinta, no lo que se declara.
    await montar(tester, await temaDe(tester, 'neu'));
    for (final t in [FilledButton, OutlinedButton]) {
      for (final g in tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(t),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.gradient != null)) {
        expect(
          g.borderRadius,
          isNotNull,
          reason: 'en $t el degradado se pinta cuadrado sobre una placa '
              'redonda y le come las esquinas',
        );
      }
    }
  });

  testWidgets('El TextButton se queda plano a proposito', (tester) async {
    await montar(tester, await temaDe(tester, 'neu'));
    // Es la accion de menor jerarquia; levantarla la igualaria con las otras
    // dos y se perderia la diferencia que el relieve sirve para marcar.
    expect(degradados(tester, find.byType(TextButton)), isEmpty);
  });

  testWidgets('El clasico no recibe nada de esto', (tester) async {
    final theme = await temaDe(tester, 'standard');
    expect(theme.filledButtonTheme.style, isNull);
    expect(theme.outlinedButtonTheme.style, isNull);
    await montar(tester, theme);
    expect(degradados(tester, find.byType(FilledButton)), isEmpty);
    expect(degradados(tester, find.byType(OutlinedButton)), isEmpty);
  });

  testWidgets('El boton deshabilitado no finge relieve', (tester) async {
    final theme = await temaDe(tester, 'neu');
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(
          body: FilledButton(onPressed: null, child: Text('Guardar')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(degradados(tester, find.byType(FilledButton)), isEmpty);
  });
}

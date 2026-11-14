import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetdosis_pro/core/app.dart';
import 'package:vetdosis_pro/modules/core/data/settings_repository.dart';
import 'package:vetdosis_pro/modules/core/presentation/core_view_model.dart';

/// El quinto hueco de la barra inferior.
///
/// «Más» abria SectionMenu, el MISMO widget que el cajon lateral: la barra
/// gastaba un hueco de cinco en repetir lo que el boton de hamburguesa ya
/// daba. Ale lo noto en el APK. Ese hueco pasa al asistente, que antes solo
/// se alcanzaba por un icono pequeño de la cabecera.
void main() {
  Future<CoreViewModel> abrir(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = SettingsRepository();
    final core = CoreViewModel(repo, await repo.load());
    addTearDown(core.dispose);
    await tester.pumpWidget(VetDosisApp(model: core));
    await tester.pumpAndSettle();
    return core;
  }

  testWidgets('La barra no repite el cajon', (tester) async {
    await abrir(tester);
    // Sin sesion el asistente no esta disponible, asi que el hueco vuelve a
    // «Más» en vez de quedarse vacio: cinco huecos siguen siendo cinco.
    final destinos = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((d) => d.label)
        .toList();
    expect(destinos, isNotEmpty);
    expect(
      destinos.where((l) => l == 'Más' || l == 'Asistente IA'),
      hasLength(1),
      reason: 'el quinto hueco es uno de los dos, nunca los dos ni ninguno',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Estar fuera de la barra no enciende el asistente', (
    tester,
  ) async {
    // Antes, cualquier pantalla ausente de la barra iluminaba el ULTIMO hueco,
    // que era «Más» y resultaba honesto: ahi se encontraba. Si el ultimo pasa
    // a ser el asistente, decir «estas en el asistente» mientras estas en
    // Hospitalizacion seria mentira.
    final core = await abrir(tester);
    core.navigate('Hospitalización');
    await tester.pumpAndSettle();
    final barra = tester.widgetList<NavigationBar>(find.byType(NavigationBar));
    if (barra.isEmpty) return;
    final destinos = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((d) => d.label)
        .toList();
    final elegido = destinos[barra.first.selectedIndex];
    expect(
      elegido,
      isNot('Asistente IA'),
      reason: 'una pantalla cualquiera no puede marcar el asistente',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

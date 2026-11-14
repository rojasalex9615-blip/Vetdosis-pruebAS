import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetdosis_pro/core/app.dart';
import 'package:vetdosis_pro/modules/core/data/settings_repository.dart';
import 'package:vetdosis_pro/modules/core/presentation/core_view_model.dart';

void main() {
  testWidgets('Navegación y apariencia en pantalla de celular', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final repository = SettingsRepository();
    final model = CoreViewModel(repository, await repository.load());
    await tester.pumpWidget(VetDosisApp(model: model));
    expect(find.text('Cálculo rápido'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gestión clínica').last);
    await tester.pumpAndSettle();
    expect(model.branch, ClinicalBranch.management);
    // Ajustes lives in the section menu, not an AppBar shortcut.
    expect(find.byTooltip('Ajustes'), findsNothing);
    model.navigate('Ajustes');
    await tester.pumpAndSettle();
    // Elegir un tono tiene que CAMBIAR el color, no solo guardar el indice.
    // Antes esta prueba solo comprobaba lo segundo, y por eso convivio con el
    // defecto: el chip quedaba marcado, el indice se guardaba y el tema seguia
    // igual, porque el estilo neu ignoraba la paleta.
    final antes = Theme.of(
      tester.element(find.byType(Scaffold).first),
    ).colorScheme.primary;
    await tester.ensureVisible(find.text('Amatista'));
    await tester.tap(find.text('Amatista'));
    await tester.pumpAndSettle();
    expect((await repository.load()).palette, 1);
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).colorScheme.primary,
      isNot(antes),
    );
    await model.updateSettings(brightness: 'dark');
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);
  });
}

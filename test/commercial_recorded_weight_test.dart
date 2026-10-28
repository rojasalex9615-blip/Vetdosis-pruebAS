import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/doses/presentation/commercial_package_dose_screen.dart';
import 'package:vetdosis_pro/modules/patients/domain/recorded_weight.dart';
import 'recorded_weight_calculation_test.dart' show measured;

Future<void> show(
  WidgetTester t,
  Future<bool> Function(RecordedPatientWeight)? validate,
) async {
  t.view.physicalSize = const Size(390, 1400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    MaterialApp(
      home: CommercialPackageDoseScreen(
        recordedWeight: measured(),
        validateRecordedWeight: validate,
      ),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> tap(WidgetTester t, String label) async {
  final target = find.text(label);
  await t.ensureVisible(target);
  await t.tap(target);
  await t.pumpAndSettle();
}

Future<void> fill(WidgetTester t) async {
  for (final entry in {
    'Nombre comercial': 'Producto ficticio',
    'Presentación / concentración del empaque': '100 mg/mL',
    'Especie indicada': 'Ficticia',
    'Posología literal del empaque': '1 mL por 10 kg',
    'Vía de administración indicada': 'Vía ficticia',
    'Intervalo o frecuencia indicada': 'Intervalo ficticio',
    'Cantidad indicada en el empaque': '1',
    'Por cada cuántos kg': '10',
  }.entries) {
    final field = find.widgetWithText(TextField, entry.key);
    await t.ensureVisible(field);
    await t.enterText(field, entry.value);
  }
  await t.ensureVisible(find.byType(CheckboxListTile).first);
  await t.tap(find.byType(CheckboxListTile).first);
  await t.pump();
}

void main() {
  testWidgets(
    'manufacturer calculation uses explicitly selected fresh weight and clears it after revocation',
    (t) async {
      var valid = true, checks = 0;
      await show(t, (_) async {
        checks++;
        return valid;
      });
      final weight = find.widgetWithText(TextField, 'Peso del animal (kg)');
      expect(t.widget<TextField>(weight).readOnly, true);
      await fill(t);
      await tap(t, 'Calcular cantidad según empaque');
      expect(checks, 0);
      await tap(t, 'Usar peso registrado');
      expect(t.widget<TextField>(weight).controller!.text, '10.25');
      await tap(t, 'Calcular cantidad según empaque');
      expect(checks, 2);
      expect(find.textContaining('1,025'), findsOneWidget);
      valid = false;
      await tap(t, 'Calcular cantidad según empaque');
      expect(checks, 3);
      expect(t.widget<TextField>(weight).controller!.text, isEmpty);
      expect(find.textContaining('1,025'), findsNothing);
    },
  );
  testWidgets(
    'changing package inputs during weight validation discards the pending calculation',
    (t) async {
      Completer<bool>? wait;
      await show(t, (_) async => wait == null ? true : wait.future);
      await fill(t);
      await tap(t, 'Usar peso registrado');
      wait = Completer<bool>();
      final button = find.text('Calcular cantidad según empaque');
      await t.ensureVisible(button);
      await t.tap(button);
      await t.pump();
      final amount = find.widgetWithText(
        TextField,
        'Cantidad indicada en el empaque',
      );
      await t.ensureVisible(amount);
      await t.enterText(amount, '2');
      wait.complete(true);
      await t.pumpAndSettle();
      expect(
        find.textContaining('Los datos cambiaron durante'),
        findsOneWidget,
      );
      expect(find.textContaining('1,025'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('missing validator never applies a recorded commercial weight', (
    t,
  ) async {
    await show(t, null);
    await tap(t, 'Usar peso registrado');
    expect(
      t
          .widget<TextField>(
            find.widgetWithText(TextField, 'Peso del animal (kg)'),
          )
          .controller!
          .text,
      isEmpty,
    );
    expect(
      find.textContaining('El peso registrado ya no se pudo comprobar'),
      findsOneWidget,
    );
  });
}

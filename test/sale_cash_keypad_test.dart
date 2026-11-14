import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/core/widgets/neu_pos.dart';
import 'package:vetdosis_pro/modules/inventory/presentation/sale_screen.dart';

import 'inventory_test.dart' show Repo, data;
import 'package:vetdosis_pro/vet_ui/vet_icons.dart';

/// Carpeta de captura opcional; sin ella la prueba solo comprueba.
const _shot = String.fromEnvironment('SALE_KEYPAD_SHOT');

Future<void> _addTwoUnits(WidgetTester tester) async {
  await tester.tap(find.byIcon(VetIcons.cart));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(DropdownButtonFormField<String>).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Lote ficticio · 2 · 2026-10-20').last);
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).last, '2');
  await tester.ensureVisible(find.text('Guardar'));
  await tester.tap(find.text('Guardar'));
  await tester.pumpAndSettle();
}

Future<void> _key(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey('keypad-$key'));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

void main() {
  testWidgets(
    'El teclado calcula el cambio y no altera lo que se envia al servidor',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = Repo();
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            home: SaleScreen(
              repository: repo,
              shift: 'test',
              products: (data()['products'] as List)
                  .cast<Map<String, dynamic>>(),
              prescriptions: const [],
              staff: const [],
              admin: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Sin renglones no hay nada que cobrar, asi que tampoco teclado.
      expect(find.byType(NeuKeypad), findsNothing);

      await _addTwoUnits(tester);
      expect(find.text('Total a pagar: \$0,20 MXN'), findsOneWidget);
      expect(find.byType(NeuKeypad), findsOneWidget);
      expect(_text(tester, 'cambio'), 'Teclea lo que entrega el cliente.');

      // 0.1 no alcanza para 0.20.
      await _key(tester, '.');
      await _key(tester, '1');
      expect(_text(tester, 'efectivo-recibido'), 'MXN 0.1');
      expect(_text(tester, 'cambio'), 'Faltan \$0,10 MXN');

      // Borrar y teclear 5.5: sobran 5.30. Un segundo punto y un tercer
      // decimal se ignoran.
      await _key(tester, '<');
      await _key(tester, '<');
      await _key(tester, '<');
      await _key(tester, '5');
      await _key(tester, '.');
      await _key(tester, '.');
      await _key(tester, '5');
      await _key(tester, '0');
      await _key(tester, '9');
      expect(_text(tester, 'efectivo-recibido'), 'MXN 5.50');
      expect(_text(tester, 'cambio'), 'Cambio: \$5,30 MXN');

      if (_shot.isNotEmpty) {
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(_shot).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      // Con tarjeta el efectivo recibido no aplica.
      await tester.ensureVisible(find.byKey(const ValueKey('metodo-tarjeta')));
      await tester.tap(find.byKey(const ValueKey('metodo-tarjeta')));
      await tester.pump();
      expect(find.byType(NeuKeypad), findsNothing);
      await tester.tap(find.byKey(const ValueKey('metodo-efectivo')));
      await tester.pump();

      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.ensureVisible(find.text('Registrar venta y pago'));
      await tester.tap(find.text('Registrar venta y pago'));
      await tester.pumpAndSettle();

      // Lo tecleado es ayuda de mostrador: el servidor recibe el total y el
      // metodo de siempre, y ningun campo con el efectivo recibido.
      final write = repo.writes.single;
      expect(write['p_expected_total'], '0.20');
      expect(write['p_method'], 'efectivo');
      expect(
        write.entries.where((e) => '${e.value}'.contains('5.50')),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Elegir otro metodo de pago viaja tal cual al servidor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = Repo();
    await tester.pumpWidget(
      MaterialApp(
        home: SaleScreen(
          repository: repo,
          shift: 'test',
          products: (data()['products'] as List).cast<Map<String, dynamic>>(),
          prescriptions: const [],
          staff: const [],
          admin: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _addTwoUnits(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('metodo-transferencia')),
    );
    await tester.tap(find.byKey(const ValueKey('metodo-transferencia')));
    await tester.pump();
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.ensureVisible(find.text('Registrar venta y pago'));
    await tester.tap(find.text('Registrar venta y pago'));
    await tester.pumpAndSettle();
    expect(repo.writes.single['p_method'], 'transferencia');
    expect(tester.takeException(), isNull);
  });
}

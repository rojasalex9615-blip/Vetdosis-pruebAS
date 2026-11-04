import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/prescribing/presentation/prescribing_screen.dart';
import 'package:vetdosis_pro/modules/prescribing/presentation/rx_entry_screen.dart';
import 'prescribing_test.dart' show RxFake, RxClinicalFake, auxiliary;
import 'forms_test.dart' show FakeForms;

class ClosedVialRepository extends RxFake {
  @override
  Future<dynamic> read(String command, Map<String, dynamic> args) async {
    if (command == 'rx_vials') {
      return [
        {
          'id': 'vial',
          'product_name': 'Producto ficticio',
          'lot': 'TEST',
          'balance': '8',
          'closed': true,
          'responsible_id': auxiliary.userId,
          'movements': [],
          'closure': {
            'expected': '10',
            'measured': '10',
            'difference': '0',
            'reason': 'Cierre previo',
          },
        },
      ];
    }
    return super.read(command, args);
  }
}

void main() {
  test('duplicate close explains that the original reconciliation remains', () {
    expect(
      rxError(StateError('vial_already_closed')),
      contains('no se creó otro cierre'),
    );
  });
  testWidgets(
    'current ledger and frozen measured closure remain distinct on a phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PrescribingScreen(
                repository: ClosedVialRepository(),
                clinical: RxClinicalFake(),
                forms: FakeForms(),
                member: auxiliary,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Frascos').last);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Saldo exacto registrado: 8 ml'),
        findsOneWidget,
      );
      expect(
        find.textContaining('saldo registrado 10 ml · medido 10 ml'),
        findsOneWidget,
      );
      expect(find.text('Conciliar y cerrar'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

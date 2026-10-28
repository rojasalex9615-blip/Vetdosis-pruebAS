import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';
import 'package:vetdosis_pro/modules/inventory/domain/inventory_repository.dart';
import 'package:vetdosis_pro/modules/inventory/domain/partial_return.dart';
import 'package:vetdosis_pro/modules/inventory/domain/inventory_models.dart';
import 'package:vetdosis_pro/modules/inventory/presentation/partial_return_screen.dart';

Map<String, dynamic> line({
  String quantity = '3',
  String total = '0.01',
  String previous = '0',
  String refunded = '0',
  String unit = 'unidad',
}) => {
  'commission': '0',
  'returned_commission': '0',
  'kind': 'producto',
  'id': 'line',
  'name': 'Producto de prueba',
  'lot': 'A',
  'unit': unit,
  'quantity': quantity,
  'total': total,
  'returned_quantity': previous,
  'returned_amount': refunded,
};

class ReturnRepository implements InventoryRepository {
  String actor = 'person';
  int schemaVersion = 3;
  int reads = 0;
  bool stale = false;
  final writes = <Map<String, dynamic>>[];
  @override
  Future<dynamic> read(String command, Map<String, dynamic> args) async {
    reads++;
    return {
      'schema_version': schemaVersion,
      'account': {
        'net_total': '30',
        'paid': '30',
        'refunded': '0',
        'balance': '0',
      },
      'clinic_id': 'clinic',
      'actor_id': actor,
      'lines': [line(total: '30')],
    };
  }

  @override
  Future<dynamic> write(String command, Map<String, dynamic> args) async {
    writes.add(args);
    throw StateError(
      stale ? 'return_workspace_changed' : 'Synthetic lost response',
    );
  }

  @override
  Future<void> photo(
    String clinic,
    String product,
    int version,
    Uint8List bytes,
    String extension,
  ) async {}
  @override
  Future<String> photoUrl(String path) async => '';
}

Widget app(ReturnRepository repo) => MaterialApp(
  home: PartialReturnScreen(
    repository: repo,
    member: const ClinicMembership(
      clinicId: 'clinic',
      clinicName: 'Clinic',
      userId: 'person',
      role: ClinicRole.admin,
    ),
    sale: 'sale',
    shift: 'shift',
  ),
);
void main() {
  testWidgets(
    'incompatible return schema explains upgrade without permitting writes',
    (tester) async {
      for (final version in [2, 4]) {
        final repo = ReturnRepository()..schemaVersion = version;
        await tester.pumpWidget(app(repo));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('La versión de devoluciones'),
          findsOneWidget,
        );
        expect(repo.writes, isEmpty);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
  test(
    'cumulative rounding distributes a cent without creating extra money',
    () {
      expect(partialReturnQuote(line(), '1').decimal, '0.00');
      expect(partialReturnQuote(line(previous: '1'), '1').decimal, '0.01');
      expect(
        partialReturnQuote(line(previous: '2', refunded: '0.01'), '1').decimal,
        '0.00',
      );
    },
  );
  test('quantity limits and whole-unit presentations are enforced', () {
    expect(
      () => partialReturnQuote(line(previous: '2'), '2'),
      throwsFormatException,
    );
    expect(() => partialReturnQuote(line(), '0'), throwsFormatException);
    expect(() => partialReturnQuote(line(), '-1'), throwsFormatException);
    expect(() => partialReturnQuote(line(), '0.5'), throwsFormatException);
    expect(
      partialReturnQuote(
        line(quantity: '1', total: '10', unit: 'g'),
        '0,25',
      ).decimal,
      '2.50',
    );
  });
  test('return CSV preserves recovered cost beside refund', () {
    final csv = cutCsv({
      'totals': <String, dynamic>{},
      'partial_returns': [
        {
          'id': 'return',
          'sale_id': 'sale',
          'amount': '10.00',
          'refund_amount': '5.00',
          'cost': '2.35',
          'commission_reduction': '1.00',
        },
      ],
    });
    expect(csv, contains('Costo de mercancía reingresada MXN'));
    expect(csv, contains('2.35'));
  });
  testWidgets('a workspace from a different actor cannot submit', (
    tester,
  ) async {
    final repo = ReturnRepository()..actor = 'other';
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();
    expect(find.text('Registrar devolución'), findsNothing);
    expect(repo.writes, isEmpty);
  });
  testWidgets('stale return asks for refresh and discards old confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = ReturnRepository()..stale = true;
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byType(DropdownButtonFormField<Map<String, dynamic>>),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Producto de prueba').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '1');
    await tester.enterText(find.byType(TextField).at(1), 'Damaged');
    await tester.tap(
      find.text(
        'Confirmo cantidad, motivo, saldo, comisión y dinero devuelto al cliente',
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Registrar devolución'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Actualiza venta y saldo antes'),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.text('Actualizar venta y saldo'));
    await tester.pumpAndSettle();
    expect(repo.reads, 2);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile).last).value,
      false,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      isEmpty,
    );
    expect(repo.writes, hasLength(1));
    expect(repo.writes.single['p_expected_returned_quantity'], '0');
  });
  testWidgets(
    'explicit confirmation, default no restock, and retry operation survive a lost response',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = ReturnRepository();
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byType(DropdownButtonFormField<Map<String, dynamic>>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Producto de prueba').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), '1');
      await tester.enterText(find.byType(TextField).at(1), 'Producto dañado');
      await tester.ensureVisible(find.text('Registrar devolución'));
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      final confirmation = find.text(
        'Confirmo cantidad, motivo, saldo, comisión y dinero devuelto al cliente',
      );
      await tester.ensureVisible(confirmation);
      await tester.tap(confirmation);
      await tester.pump();
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(repo.writes.single['p_restock'], false);
      expect(repo.writes.single['p_expected_amount'], '10.00');
      expect(repo.writes.single['p_actor'], 'person');
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(repo.writes.length, 2);
      expect(repo.writes[0]['p_operation'], repo.writes[1]['p_operation']);
    },
  );
}

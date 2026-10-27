import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';
import 'package:vetdosis_pro/modules/inventory/domain/inventory_repository.dart';
import 'package:vetdosis_pro/modules/inventory/domain/partial_return.dart';
import 'package:vetdosis_pro/modules/inventory/presentation/partial_return_screen.dart';

Map<String, dynamic> line({
  String quantity = '3',
  String total = '0.01',
  String previous = '0',
  String refunded = '0',
  String unit = 'unidad',
}) => {
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
  final writes = <Map<String, dynamic>>[];
  @override
  Future<dynamic> read(String command, Map<String, dynamic> args) async => {
    'clinic_id': 'clinic',
    'actor_id': actor,
    'lines': [line(total: '30')],
  };
  @override
  Future<dynamic> write(String command, Map<String, dynamic> args) async {
    writes.add(args);
    throw StateError('Synthetic lost response');
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
  testWidgets('a workspace from a different actor cannot submit', (
    tester,
  ) async {
    final repo = ReturnRepository()..actor = 'other';
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();
    expect(find.text('Registrar devolución'), findsNothing);
    expect(repo.writes, isEmpty);
  });
  testWidgets(
    'explicit confirmation, default no restock, and retry operation survive a lost response',
    (tester) async {
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
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      final confirmation = find.text(
        'Confirmo cantidad, motivo e importe que devolví al cliente',
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

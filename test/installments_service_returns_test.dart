import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';
import 'package:vetdosis_pro/modules/inventory/domain/inventory_repository.dart';
import 'package:vetdosis_pro/modules/inventory/domain/partial_return.dart';
import 'package:vetdosis_pro/modules/inventory/presentation/credit_accounts_screen.dart';
import 'package:vetdosis_pro/modules/inventory/presentation/partial_return_screen.dart';
import 'package:vetdosis_pro/modules/inventory/presentation/sale_screen.dart';

const member = ClinicMembership(
  clinicId: 'clinic',
  clinicName: 'Clinic',
  userId: 'person',
  role: ClinicRole.admin,
);
Map<String, dynamic> serviceLine() => {
  'id': 'line',
  'name': 'Servicio ficticio',
  'lot': null,
  'kind': 'servicio',
  'unit': 'servicio',
  'quantity': '1',
  'total': '300',
  'commission': '25',
  'returned_quantity': '0',
  'returned_amount': '0',
  'returned_commission': '0',
};

class InstallmentRepository implements InventoryRepository {
  final writes = <Map<String, dynamic>>[];
  final commands = <String>[];
  String actor = 'person';
  Completer<dynamic>? delayed;
  @override
  Future<dynamic> read(String command, Map<String, dynamic> args) async {
    if (delayed != null && args['p_clinic'] == 'clinic') return delayed!.future;
    if (command == 'inv_sale_return_workspace') {
      return {
        'schema_version': 2,
        'clinic_id': 'clinic',
        'actor_id': actor,
        'account': {
          'net_total': '310',
          'paid': '100',
          'refunded': '0',
          'balance': '210',
        },
        'lines': [serviceLine()],
      };
    }
    return {
      'clinic_id': args['p_clinic'],
      'actor_id': actor,
      'items': [
        {
          'sale_id': 'sale',
          'debtor': 'Titular ficticio',
          'account': {
            'net_total': '30',
            'paid': '10',
            'refunded': '0',
            'balance': '20',
          },
          'collections': [],
        },
      ],
    };
  }

  @override
  Future<dynamic> write(String command, Map<String, dynamic> args) async {
    commands.add(command);
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

Widget accounts(
  InstallmentRepository repo, {
  ClinicMembership person = member,
}) => MaterialApp(
  home: CreditAccountsScreen(
    repository: repo,
    member: person,
    shift: 'shift',
    canReturn: true,
  ),
);
void main() {
  test('unpaid amount is cancelled before any cash is refunded', () {
    final quote = saleReturnQuote(serviceLine(), '0.5', {
      'net_total': '310',
      'paid': '100',
      'refunded': '0',
    });
    expect(quote.credit.decimal, '150.00');
    expect(quote.refund.decimal, '0.00');
    expect(quote.balanceReduction.decimal, '150.00');
    expect(quote.commission.decimal, '12.50');
  });
  test(
    'only the overpaid portion is refunded and previous refunds are counted',
    () {
      final first = saleReturnQuote(serviceLine(), '0.5', {
        'net_total': '310',
        'paid': '200',
        'refunded': '0',
      });
      expect(first.refund.decimal, '40.00');
      expect(first.balanceReduction.decimal, '110.00');
      final second = saleReturnQuote(
        {
          ...serviceLine(),
          'returned_quantity': '0.5',
          'returned_amount': '150',
          'returned_commission': '12.50',
        },
        '0.25',
        {'net_total': '160', 'paid': '200', 'refunded': '40'},
      );
      expect(second.credit.decimal, '75.00');
      expect(second.refund.decimal, '75.00');
      expect(second.commission.decimal, '6.25');
    },
  );
  testWidgets(
    'installment needs confirmation, rejects excess, and canonical retry keeps operation',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = InstallmentRepository();
      await tester.pumpWidget(accounts(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar abono'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(0), '21');
      await tester.pump();
      await tester.enterText(
        find.byType(TextField).at(1),
        'Referencia ficticia',
      );
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      final confirm = find.text(
        'Confirmo el importe y medio del dinero recibido',
      );
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pump();
      await tester.ensureVisible(find.text('Confirmar abono'));
      await tester.tap(find.text('Confirmar abono'));
      await tester.pumpAndSettle();
      expect(repo.writes, isEmpty);
      await tester.ensureVisible(find.byType(TextField).first);
      await tester.enterText(find.byType(TextField).first, '5');
      await tester.pump();
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pump();
      await tester.ensureVisible(find.text('Confirmar abono'));
      await tester.tap(find.text('Confirmar abono'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextField).first);
      await tester.enterText(find.byType(TextField).first, '5.00');
      await tester.pump();
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pump();
      await tester.ensureVisible(find.text('Confirmar abono'));
      await tester.tap(find.text('Confirmar abono'));
      await tester.pumpAndSettle();
      expect(repo.commands, ['inv_sale_collect', 'inv_sale_collect']);
      expect(repo.writes[0]['p_amount'], '5.00');
      expect(repo.writes[0]['p_actor'], 'person');
      expect(repo.writes[0]['p_operation'], repo.writes[1]['p_operation']);
    },
  );
  testWidgets(
    'wrong actor cannot expose an account and stale clinic response is discarded',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = InstallmentRepository()..actor = 'other';
      await tester.pumpWidget(accounts(repo));
      await tester.pumpAndSettle();
      expect(find.textContaining('Titular ficticio'), findsNothing);
      repo.actor = 'person';
      repo.delayed = Completer<dynamic>();
      await tester.tap(find.text('Actualizar historial'));
      await tester.pump();
      await tester.pumpWidget(
        accounts(
          repo,
          person: const ClinicMembership(
            clinicId: 'new-clinic',
            clinicName: 'New',
            userId: 'person',
            role: ClinicRole.admin,
          ),
        ),
      );
      await tester.pumpAndSettle();
      repo.delayed!.complete({
        'clinic_id': 'clinic',
        'actor_id': 'person',
        'items': [
          {'debtor': 'PRIVATE OLD CLINIC'},
        ],
      });
      await tester.pumpAndSettle();
      expect(find.textContaining('PRIVATE OLD CLINIC'), findsNothing);
    },
  );
  testWidgets(
    'service return displays balance and commission separately and cannot restock',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = InstallmentRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: PartialReturnScreen(
            repository: repo,
            member: member,
            sale: 'sale',
            shift: 'shift',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byType(DropdownButtonFormField<Map<String, dynamic>>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Servicio ficticio').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), '0.5');
      await tester.pump();
      await tester.enterText(
        find.byType(TextField).at(1),
        'Devolución parcial acordada',
      );
      await tester.pump();
      await tester.pump();
      expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile).first)
            .onChanged,
        isNull,
      );
      await tester.ensureVisible(
        find.textContaining('Ajuste proporcional de comisión:'),
      );
      expect(
        find.text('Ajuste proporcional de comisión: \$12,50 MXN'),
        findsOneWidget,
      );
      final confirm = find.text(
        'Confirmo cantidad, motivo, saldo, comisión y dinero devuelto al cliente',
      );
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pump();
      await tester.ensureVisible(find.text('Registrar devolución'));
      await tester.tap(find.text('Registrar devolución'));
      await tester.pumpAndSettle();
      expect(repo.commands.single, 'inv_sale_return_v2');
      expect(repo.writes.single['p_expected_amount'], '150.00');
      expect(repo.writes.single['p_expected_refund'], '0.00');
      expect(repo.writes.single['p_expected_commission'], '12.50');
      expect(repo.writes.single['p_restock'], false);
    },
  );
  testWidgets(
    'credit sale sends only initial money and retains canonical retry identity',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = InstallmentRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: SaleScreen(
            repository: repo,
            shift: 'shift',
            products: [],
            prescriptions: [],
            staff: [],
            admin: false,
            creditSupported: true,
            actor: 'person',
            acts: [
              {
                'id': 'act',
                'name': 'Servicio ficticio',
                'price': '30',
                'paid': false,
              },
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(0), 'Titular ficticio');
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(1), '5');
      await tester.pump();
      final reviewed = find.byType(CheckboxListTile);
      await tester.ensureVisible(reviewed);
      await tester.tap(reviewed);
      await tester.pump();
      await tester.ensureVisible(find.text('Registrar venta con saldo'));
      await tester.tap(find.text('Registrar venta con saldo'));
      await tester.pumpAndSettle();
      expect(repo.commands.single, 'inv_sale_credit_post');
      expect(repo.writes.single['p_initial_amount'], '5.00');
      expect(repo.writes.single['p_expected_total'], '30.00');
      await tester.ensureVisible(find.byType(TextField).at(1));
      await tester.enterText(find.byType(TextField).at(1), '5.00');
      await tester.pump();
      await tester.ensureVisible(reviewed);
      await tester.tap(reviewed);
      await tester.pump();
      await tester.ensureVisible(find.text('Registrar venta con saldo'));
      await tester.tap(find.text('Registrar venta con saldo'));
      await tester.pumpAndSettle();
      expect(repo.writes.length, 2);
      expect(repo.writes[0]['p_operation'], repo.writes[1]['p_operation']);
    },
  );
  testWidgets('credit account fits a 320dp phone with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = InstallmentRepository();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
        home: CreditAccountsScreen(
          repository: repo,
          member: member,
          shift: 'shift',
          canReturn: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(repo.writes, isEmpty);
  });
}

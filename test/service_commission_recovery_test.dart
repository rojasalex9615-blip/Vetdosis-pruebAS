import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';
import 'package:vetdosis_pro/modules/operations/domain/operations_repository.dart';
import 'package:vetdosis_pro/modules/operations/presentation/service_commission_panel.dart';

class RecoveryRepository implements ServiceCommissionRepository {
  String recovered = '0.00';
  String? recoveryLimit;
  bool reversed = true;
  int writes = 0;
  bool failAfterWrite = false;
  final operations = <String>[];
  String? received, recordedReason;
  Completer<Map<String, dynamic>>? delayed;
  Map<String, dynamic> account(String clinic) => {
    'outstanding': '0',
    'awaiting_collection': '0',
    'recovery_supported': true,
    'items': [
      {
        'id': 'act',
        'professional_id': 'worker',
        'professional_name': 'Persona ficticia',
        'service_name': 'Servicio $clinic',
        'commission': '25.00',
        'settlement_id': 'settlement',
        'settled_amount': '25.00',
        'sale_collected': false,
        'settlement_sale_reversed': reversed,
        if (recoveryLimit != null) 'recovery_limit': recoveryLimit,
        'recovered_amount': recovered,
        'recoveries': [],
      },
    ],
  };
  @override
  Future<Map<String, dynamic>> commissionServiceAccount(
    String clinic, {
    int offset = 0,
  }) async =>
      clinic == 'a' && delayed != null ? delayed!.future : account(clinic);
  @override
  Future<void> settleServiceCommission(
    String clinic,
    String act,
    String method,
    String reference,
    String operation,
  ) async {
    fail('A reversed sale must not trigger another settlement');
  }

  @override
  Future<void> recordServiceCommissionRecovery(
    String clinic,
    String settlement,
    String amount,
    String method,
    String reference,
    String reason,
    String operation,
  ) async {
    operations.add(operation);
    writes++;
    received = amount;
    recordedReason = reason;
    recovered = amount;
    if (failAfterWrite) {
      failAfterWrite = false;
      throw StateError('Synthetic lost response');
    }
  }
}

ClinicMembership member(String clinic, {ClinicRole role = ClinicRole.admin}) =>
    ClinicMembership(
      clinicId: clinic,
      clinicName: clinic,
      userId: 'person',
      role: role,
    );
Widget app(RecoveryRepository repo, ClinicMembership person) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: ServiceCommissionPanel(repository: repo, member: person),
    ),
  ),
);

void main() {
  testWidgets(
    'worker can inspect recovery amount but cannot record a recovery',
    (tester) async {
      await tester.pumpWidget(
        app(RecoveryRepository(), member('a', role: ClinicRole.mvz)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Reintegros recibidos:'), findsOneWidget);
      expect(find.text('Registrar reintegro recibido'), findsNothing);
      expect(find.text('Registrar pago'), findsNothing);
    },
  );

  testWidgets(
    'admin records only an explicit amount with a reason; excessive amount is rejected',
    (tester) async {
      final repo = RecoveryRepository();
      await tester.pumpWidget(app(repo, member('a')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Registrar reintegro recibido'));
      await tester.tap(find.text('Registrar reintegro recibido'));
      await tester.pumpAndSettle();
      final amount = find.byWidgetPredicate(
        (w) =>
            w is TextField && w.decoration?.labelText == 'Importe recibido MXN',
      );
      final reason = find.byWidgetPredicate(
        (w) =>
            w is TextField && w.decoration?.labelText == 'Motivo del reintegro',
      );
      await tester.enterText(amount, '26');
      await tester.enterText(reason, 'Reintegro confirmado de prueba');
      await tester.tap(find.text('Confirmar reintegro recibido'));
      await tester.pumpAndSettle();
      expect(repo.writes, 0);
      expect(
        find.textContaining('importe positivo dentro del máximo'),
        findsOneWidget,
      );
      await tester.enterText(amount, '10,50');
      await tester.tap(find.text('Confirmar reintegro recibido'));
      await tester.pumpAndSettle();
      expect(repo.writes, 1);
      expect(repo.received, '10.50');
      expect(repo.recordedReason, 'Reintegro confirmado de prueba');
      expect(
        find.textContaining('Reintegros recibidos: \$10,50'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'retry after a lost response keeps its operation ID across decimal formatting',
    (tester) async {
      final repo = RecoveryRepository()..failAfterWrite = true;
      await tester.pumpWidget(app(repo, member('a')));
      await tester.pumpAndSettle();
      for (final value in ['10,50', '10.50']) {
        await tester.ensureVisible(find.text('Registrar reintegro recibido'));
        await tester.tap(find.text('Registrar reintegro recibido'));
        await tester.pumpAndSettle();
        final amount = find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.labelText == 'Importe recibido MXN',
        );
        final reason = find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.labelText == 'Motivo del reintegro',
        );
        await tester.enterText(amount, value);
        await tester.enterText(reason, 'Reintegro confirmado');
        await tester.tap(find.text('Confirmar reintegro recibido'));
        await tester.pumpAndSettle();
      }
      expect(repo.operations.length, 2);
      expect(repo.operations.first, repo.operations.last);
    },
  );

  testWidgets(
    'late response from previous clinic cannot replace new clinic account',
    (tester) async {
      final repo = RecoveryRepository()
        ..delayed = Completer<Map<String, dynamic>>();
      await tester.pumpWidget(app(repo, member('a')));
      await tester.pump();
      await tester.pumpWidget(app(repo, member('b')));
      await tester.pumpAndSettle();
      repo.delayed!.complete(repo.account('a'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Servicio b'), findsWidgets);
      expect(find.textContaining('Servicio a'), findsNothing);
    },
  );
  testWidgets(
    'partial return caps recovery at the adjustment, not the original payment',
    (tester) async {
      final repo = RecoveryRepository()
        ..recoveryLimit = '5.00'
        ..reversed = false;
      await tester.pumpWidget(app(repo, member('a')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar reintegro recibido'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Máximo sin registrar: \$5,00'),
        findsOneWidget,
      );
      final amount = find.byWidgetPredicate(
        (w) =>
            w is TextField && w.decoration?.labelText == 'Importe recibido MXN',
      );
      final reason = find.byWidgetPredicate(
        (w) =>
            w is TextField && w.decoration?.labelText == 'Motivo del reintegro',
      );
      await tester.enterText(amount, '6');
      await tester.enterText(reason, 'Synthetic partial adjustment');
      await tester.tap(find.text('Confirmar reintegro recibido'));
      await tester.pumpAndSettle();
      expect(repo.writes, 0);
      await tester.enterText(amount, '5');
      await tester.tap(find.text('Confirmar reintegro recibido'));
      await tester.pumpAndSettle();
      expect(repo.received, '5.00');
    },
  );
}

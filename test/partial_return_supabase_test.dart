import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';
import 'package:vetdosis_pro/modules/inventory/data/supabase_inventory_repository.dart';
import 'package:vetdosis_pro/modules/inventory/presentation/partial_return_screen.dart';
import 'partial_product_return_test.dart' show line;

Future<void> flushTransport(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    // The SDK decodes JSON on a real isolate; pump its event loop as well as UI.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(done(), isTrue);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Return screen reaches the real repository v3 RPC with exact quote and actor',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final writes = <Map<String, dynamic>>[];
      final client = (await tester.runAsync(
        () async => SupabaseClient(
          'https://synthetic.invalid',
          'synthetic',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            final path = request.url.path;
            if (path.endsWith('/inv_sale_return_workspace')) {
              return http.Response(
                jsonEncode({
                  'schema_version': 3,
                  'clinic_id': 'clinic',
                  'actor_id': 'person',
                  'account': {
                    'net_total': '30',
                    'paid': '30',
                    'refunded': '0',
                    'balance': '0',
                  },
                  'lines': [line(total: '30')],
                }),
                200,
                request: request,
                headers: {'content-type': 'application/json'},
              );
            }
            expect(path, '/rest/v1/rpc/inv_sale_return_v3');
            expect(request.method, 'POST');
            writes.add(
              Map<String, dynamic>.from(jsonDecode(request.body) as Map),
            );
            return http.Response(
              jsonEncode('synthetic-return'),
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      ))!;
      addTearDown(client.dispose);
      final repository = SupabaseInventoryRepository(client);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PartialReturnScreen(
                      repository: repository,
                      member: const ClinicMembership(
                        clinicId: 'clinic',
                        clinicName: 'Synthetic',
                        userId: 'person',
                        role: ClinicRole.admin,
                      ),
                      sale: 'sale',
                      shift: 'shift',
                    ),
                  ),
                ),
                child: const Text('Open return'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open return'));
      await tester.pump();
      await flushTransport(
        tester,
        () => find
            .byType(DropdownButtonFormField<Map<String, dynamic>>)
            .evaluate()
            .isNotEmpty,
      );
      await tester.tap(
        find.byType(DropdownButtonFormField<Map<String, dynamic>>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Producto de prueba · lote A').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '1');
      await tester.enterText(
        find.byType(TextField).last,
        'Synthetic returned item',
      );
      await tester.ensureVisible(find.byType(CheckboxListTile).last);
      await tester.tap(find.byType(CheckboxListTile).last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(FilledButton).last);
      await tester.tap(find.byType(FilledButton).last);
      await flushTransport(
        tester,
        () => find.byType(PartialReturnScreen).evaluate().isEmpty,
      );
      expect(writes, hasLength(1));
      expect(writes.single, containsPair('p_sale', 'sale'));
      expect(writes.single, containsPair('p_shift', 'shift'));
      expect(writes.single, containsPair('p_actor', 'person'));
      expect(writes.single, containsPair('p_quantity', '1'));
      expect(writes.single, containsPair('p_expected_returned_quantity', '0'));
      expect(writes.single, containsPair('p_expected_amount', '10.00'));
      expect(writes.single, containsPair('p_expected_refund', '10.00'));
      expect(writes.single, containsPair('p_expected_commission', '0.00'));
      expect(writes.single, containsPair('p_restock', false));
      expect(writes.single['p_operation'], isNotEmpty);
      expect(find.text('Open return'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final status in [403, 404]) {
    test(
      'Real repository propagates server refusal $status rather than bypassing it',
      () async {
        var calls = 0;
        final client = SupabaseClient(
          'https://synthetic.invalid',
          'synthetic',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            calls++;
            return http.Response(
              jsonEncode({
                'message': 'Synthetic server refusal',
                'code': status == 403 ? '42501' : 'PGRST202',
                'details': null,
                'hint': null,
              }),
              status,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        final repository = SupabaseInventoryRepository(client);
        await expectLater(
          repository.write('inv_sale_return_v3', {'p_sale': 'sale'}),
          throwsA(isA<PostgrestException>()),
        );
        expect(calls, 1);
        expect(
          () => repository.write('unreviewed_write', {}),
          throwsArgumentError,
        );
        expect(calls, 1);
        await client.dispose();
      },
    );
  }
}

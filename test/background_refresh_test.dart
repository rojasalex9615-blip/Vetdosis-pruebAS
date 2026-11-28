import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetdosis_pro/core/app.dart';
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';
import 'package:vetdosis_pro/modules/auth/presentation/auth_view_model.dart';
import 'package:vetdosis_pro/modules/core/data/settings_repository.dart';
import 'package:vetdosis_pro/modules/core/domain/module_access.dart';
import 'package:vetdosis_pro/modules/core/presentation/core_view_model.dart';
import 'package:vetdosis_pro/modules/dashboard/presentation/dashboard_screen.dart';
import 'package:vetdosis_pro/modules/doses/presentation/dose_label_scanner_screen.dart';
import 'module_navigation_dashboard_test.dart' show contract, InventoryProbe;
import 'inventory_test.dart' as inventory;
import 'support/fake_auth.dart';

class RefreshingAccess implements ModuleAccessRepository {
  Map<String, dynamic> response = contract(enabled: 'inventory');
  @override
  Future<Map<String, dynamic>> workspace(String clinic) async =>
      jsonDecode(jsonEncode(response)) as Map<String, dynamic>;
}

const _admin = ClinicMembership(
  clinicId: 'a',
  userId: 'user-a',
  role: ClinicRole.admin,
  clinicName: 'DEMO',
);
void main() {
  test(
    'equal capabilities have stable identity semantics and immutable maps',
    () {
      final raw = contract(enabled: 'inventory');
      final a = ModuleAccess.read(raw);
      final reordered = {
        ...raw,
        'modules': Map.fromEntries(
          (raw['modules'] as Map).entries.toList().reversed,
        ),
      };
      final b = ModuleAccess.read(reordered);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      (raw['modules'] as Map)['inventory'] = false;
      expect(a.module('inventory'), true);
      expect(() => a.modules['inventory'] = false, throwsUnsupportedError);
      expect(a, isNot(ModuleAccess.read(raw)));
    },
  );
  testWidgets(
    'periodic access revalidation preserves home state and search; revocation still clears it',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = FakeAuth()..rows = [_admin];
      final auth = AuthViewModel(
        repo,
        refreshInterval: const Duration(seconds: 30),
      );
      await auth.start();
      final core = CoreViewModel(SettingsRepository(), const AppSettings());
      final access = RefreshingAccess();
      final stock = InventoryProbe();
      await tester.pumpWidget(
        VetDosisApp(
          model: core,
          auth: auth,
          moduleAccess: access,
          inventory: stock,
        ),
      );
      await tester.pumpAndSettle();
      final initial = tester.state(find.byType(DashboardScreen));
      final reads = stock.reads;
      final search = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.labelText == 'Buscar producto por nombre o código',
      );
      await tester.ensureVisible(search);
      await tester.enterText(search, 'borrador conservado');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      await auth.refresh(background: true);
      await tester.pumpAndSettle();
      expect(
        identical(initial, tester.state(find.byType(DashboardScreen))),
        true,
      );
      expect(
        tester.widget<TextField>(search).controller!.text,
        'borrador conservado',
      );
      expect(stock.reads, reads);
      access.response = contract();
      await auth.refresh(background: true);
      await tester.pumpAndSettle();
      expect(search, findsNothing);
      expect(
        identical(initial, tester.state(find.byType(DashboardScreen))),
        false,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      core.dispose();
      auth.dispose();
      await repo.controller.close();
    },
  );
  testWidgets(
    'floating scanner and background refresh keep underlying inventory draft on return',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = FakeAuth()..rows = [_admin];
      final auth = AuthViewModel(repo);
      await auth.start();
      final core = CoreViewModel(SettingsRepository(), const AppSettings())
        ..navigate('Inventario');
      await tester.pumpWidget(
        VetDosisApp(model: core, auth: auth, inventory: inventory.Repo()),
      );
      await tester.pumpAndSettle();
      final search = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.labelText == 'Buscar nombre, presentación o código',
      );
      await tester.ensureVisible(search);
      await tester.enterText(search, 'captura pendiente');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await auth.refresh(background: true);
      await tester.pumpAndSettle();
      expect(find.byType(DoseLabelScannerScreen), findsOneWidget);
      expect(core.screen, 'Inventario');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(search).controller!.text,
        'captura pendiente',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      core.dispose();
      auth.dispose();
      await repo.controller.close();
    },
  );
}

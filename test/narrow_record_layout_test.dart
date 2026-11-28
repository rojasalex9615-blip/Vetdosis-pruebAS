import 'package:vetdosis_pro/modules/subscriptions/presentation/subscription_screen.dart';
import 'ai_plans_test.dart' show PlanFake;
import 'package:vetdosis_pro/modules/dashboard/presentation/statistics_screen.dart';
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';
import 'dashboard_round2_test.dart' show FixedDashboard;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/inventory/presentation/inventory_screen.dart';
import 'package:vetdosis_pro/modules/production/presentation/production_dashboard.dart';
import 'package:vetdosis_pro/vet_ui/vet_theme.dart';
import 'inventory_test.dart' show Repo, member, data;

void main() {
  setUpAll(() async {
    final fonts = FontLoader(VetTheme.fontFamily);
    for (final weight in [400, 500, 600, 700, 800]) {
      fonts.addFont(
        rootBundle.load('assets/fonts/PlusJakartaSans-$weight.ttf'),
      );
    }
    await fonts.load();
  });
  testWidgets(
    'Statistics keeps long lot expiry text inside a narrow enlarged layout',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final model = FixedDashboard(ClinicRole.admin)..stock = data();
      await tester.pumpWidget(
        MaterialApp(
          theme: VetTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: StatisticsPanel(model: model, statisticsOnly: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Producto ficticio'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      model.dispose();
    },
  );
  testWidgets('Plan and workspace badges wrap at narrow enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: VetTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: SubscriptionScreen(repository: PlanFake(), member: member),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Plan activo'), findsOneWidget);
    expect(find.text('Personal'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final scale in [1.0, 1.6]) {
    for (final inventory in [true, false]) {
      testWidgets(
        'Narrow ${inventory ? 'lot records' : 'production tools'} with real fonts and scale $scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MaterialApp(
              theme: VetTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: inventory
                      ? InventoryScreen(repository: Repo(), member: member)
                      : ProductionDashboard(onNavigate: (_) {}),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.textContaining(
              inventory ? 'Lote ficticio' : 'Registros Productivos',
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}

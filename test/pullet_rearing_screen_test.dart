import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'package:vetdosis_pro/vet_ui/vet_theme.dart';
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';
import 'package:vetdosis_pro/modules/aviculture/domain/pullet_guide.dart';
import 'package:vetdosis_pro/modules/aviculture/domain/rearing_project_repository.dart';
import 'package:vetdosis_pro/modules/aviculture/presentation/pullet_rearing_screen.dart';
import 'package:vetdosis_pro/modules/aviculture/presentation/rearing_projects_screen.dart';
import 'package:vetdosis_pro/modules/production/presentation/production_menu.dart';

final catalog = PulletGuideCatalog.parse(
  File('assets/clinical/aviculture/guia_linea.v1.json').readAsStringSync(),
);
const member = ClinicMembership(
  clinicId: 'c1',
  clinicName: 'Clínica',
  userId: 'u1',
  role: ClinicRole.mvz,
);
Widget host(Widget child) => MaterialApp(theme: VetTheme.light(), home: child);
Future<void> tab(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label).first);
  await tester.tap(find.text(label).first);
  await tester.pumpAndSettle();
}

class _Projects implements RearingProjectRepository {
  final saved = <RearingProject>[];
  final confirmation = Completer<void>();
  @override
  Future<void> save(String u, String c, RearingProject p) async {
    await confirmation.future;
    saved.add(p);
  }

  @override
  Future<List<RearingProject>> list(String u, String c) async => saved;
  @override
  Future<void> remove(String u, String c, String id) async =>
      saved.removeWhere((p) => p.id == id);
  @override
  Future<void> restoreCopies(
    String u,
    String c,
    List<RearingProject> p,
  ) async => saved.addAll(p);
}

void main() {
  testWidgets('cada marca tiene apartado y abre su guía elegida', (
    tester,
  ) async {
    await tester.pumpWidget(host(PulletRearingHub(catalog: catalog)));
    await tester.pumpAndSettle();
    expect(find.text('Bovans'), findsOneWidget);
    expect(find.text('Hy-Line'), findsOneWidget);
    expect(find.text('Lohmann'), findsOneWidget);
    await tester.tap(find.text('Bovans'));
    await tester.pumpAndSettle();
    expect(find.text('Bovans · crianza'), findsOneWidget);
    await tester.tap(find.text('Ver tabla y calcular').first);
    await tester.pumpAndSettle();
    expect(find.text('Calcular presupuesto'), findsOneWidget);
    expect(find.textContaining('L6230-1'), findsWidgets);
  });
  testWidgets(
    'rango, costo pendiente y edición invalidan resultados; cabe en teléfono',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        host(
          PulletRearingScreen(
            brand: 'Bovans',
            catalog: catalog,
            initialGuide: catalog.guides.first,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('birds')), '1000');
      await tester.tap(find.text('Calcular presupuesto'));
      await tester.pumpAndSettle();
      await tab(tester, 'Resumen');
      expect(find.text('Costo total'), findsOneWidget);
      expect(find.text('Sin costo completo'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tab(tester, 'Alimento');
      await tester.tap(find.text('Comparar referencias por semana'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Consumo:'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tab(tester, 'Equipo y vacunas');
      expect(tester.takeException(), isNull);
      await tab(tester, 'Desglose');
      expect(tester.takeException(), isNull);
      await tab(tester, 'Entradas');
      await tester.enterText(find.byKey(const ValueKey('birds')), '2000');
      await tester.pump();
      await tab(tester, 'Resumen');
      expect(
        find.text('Captura las entradas y pulsa Calcular presupuesto.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'guardar espera confirmación del repositorio; el proyecto se reabre',
    (tester) async {
      final repo = _Projects();
      await tester.pumpWidget(
        host(
          PulletRearingScreen(
            brand: 'Bovans',
            catalog: catalog,
            initialGuide: catalog.guides.first,
            member: member,
            projects: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('name')),
        'Crianza Norte',
      );
      await tester.enterText(find.byKey(const ValueKey('birds')), '4275');
      await tester.tap(find.byTooltip('Guardar proyecto'));
      await tester.pump();
      expect(find.text('Proyecto guardado en este dispositivo.'), findsNothing);
      expect(repo.saved, isEmpty);
      repo.confirmation.complete();
      await tester.pumpAndSettle();
      expect(repo.saved.single.plan.name, 'Crianza Norte');
      await tester.pumpWidget(
        host(
          RearingProjectsScreen(
            catalog: catalog,
            member: member,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reabrir'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('birds')))
            .controller!
            .text,
        '4275',
      );
    },
  );
  testWidgets('la calculadora aparece en Producción > Aves > Postura', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        Scaffold(
          body: SingleChildScrollView(
            child: ProductionMenu(
              member: member,
              onNavigate: (_) {},
              initialSpecies: 'Aves',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Postura'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Postura'));
    await tester.pumpAndSettle();
    final entry = find.text('Crianza de pollitas · Bovans, Hy-Line y Lohmann');
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.text('Crianza de aves de postura'), findsOneWidget);
  });
  testWidgets('auxiliar autorizado abre sanidad sin calculadoras clínicas', (
    tester,
  ) async {
    const auxiliary = ClinicMembership(
      clinicId: 'c1',
      clinicName: 'Clínica',
      userId: 'aux',
      role: ClinicRole.auxiliar,
    );
    await tester.pumpWidget(
      host(
        Scaffold(
          body: SingleChildScrollView(
            child: ProductionMenu(
              member: auxiliary,
              onNavigate: (_) {},
              initialSpecies: 'Aves',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Postura'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Postura'));
    await tester.pumpAndSettle();
    expect(
      find.text('Crianza de pollitas · Bovans, Hy-Line y Lohmann'),
      findsNothing,
    );
    final entry = find.text('Granjas, casetas y sanidad');
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.textContaining('Conecta tu cuenta'), findsOneWidget);
  });
}

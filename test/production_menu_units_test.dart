import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';
import 'package:vetdosis_pro/modules/production/domain/production_unit.dart';
import 'package:vetdosis_pro/modules/production/domain/production_unit_repository.dart';
import 'package:vetdosis_pro/modules/production/presentation/production_menu.dart';
import 'package:vetdosis_pro/modules/production/presentation/production_units_screen.dart';

class _RepoVacio implements ProductionUnitRepository {
  @override
  Future<List<ProductionUnit>> list(
    String userId,
    String clinicId, {
    String? species,
    String? activity,
  }) async => const [];

  @override
  Future<void> save(String userId, ProductionUnit unit) async {}

  @override
  Future<void> remove(String userId, String id) async {}
}

const _miembro = ClinicMembership(
  clinicId: 'c1',
  clinicName: 'Clínica 1',
  userId: 'ana',
  role: ClinicRole.mvz,
);

Widget _menu() => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: ProductionMenu(
        member: _miembro,
        units: _RepoVacio(),
        onNavigate: (_) {},
      ),
    ),
  ),
);

Future<void> _tocar(WidgetTester tester, String texto) async {
  final f = find.text(texto);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  // El menu pinta el detalle en cuanto se elige la especie, con la actividad
  // todavia sin elegir. Si la seccion de unidades usa `activity!` sin guarda,
  // la pantalla revienta (Null check operator) nada mas abrir la especie.
  testWidgets('Elegir la especie sin actividad no revienta con unidades', (
    tester,
  ) async {
    await tester.pumpWidget(_menu());
    await _tocar(tester, 'Porcinos');

    expect(tester.takeException(), isNull);
    expect(
      find.text('Elige una actividad para ver sus herramientas.'),
      findsOneWidget,
    );
    // Sin actividad elegida, la seccion de unidades aun no aparece.
    expect(find.text('Abrir unidades'), findsNothing);
  });

  testWidgets('Al elegir la actividad aparece Abrir unidades', (tester) async {
    await tester.pumpWidget(_menu());
    await _tocar(tester, 'Porcinos');
    await _tocar(tester, 'Maternidad y destete');
    await _tocar(tester, 'Registros');

    expect(tester.takeException(), isNull);
    expect(find.text('Abrir unidades'), findsOneWidget);
  });

  testWidgets('Sin almacen de unidades no se ofrece la seccion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProductionMenu(member: _miembro, onNavigate: (_) {}),
          ),
        ),
      ),
    );
    await _tocar(tester, 'Porcinos');
    await _tocar(tester, 'Maternidad y destete');
    await _tocar(tester, 'Registros');

    expect(tester.takeException(), isNull);
    expect(find.text('Abrir unidades'), findsNothing);
  });

  testWidgets('Abrir unidades lleva a la pantalla de unidades', (tester) async {
    await tester.pumpWidget(_menu());
    await _tocar(tester, 'Porcinos');
    await _tocar(tester, 'Maternidad y destete');
    await _tocar(tester, 'Registros');
    await _tocar(tester, 'Abrir unidades');

    expect(find.byType(ProductionUnitsScreen), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/production/domain/production_unit.dart';
import 'package:vetdosis_pro/modules/production/domain/production_unit_repository.dart';
import 'package:vetdosis_pro/modules/production/presentation/production_units_screen.dart';

/// Pruebas de la pantalla, no del almacen: lo que se comprueba es lo que ve y
/// hace quien la usa.
///
/// El repositorio es sincrono a proposito. Con sembast de verdad los temporizadores
/// no completan bajo el reloj falso de las pruebas de widget, y `pumpAndSettle`
/// se queda colgado; ya me paso montando las notificaciones.
class _RepoFalso implements ProductionUnitRepository {
  _RepoFalso([this.filas = const []]);

  List<ProductionUnit> filas;
  final guardadas = <({String userId, ProductionUnit unit})>[];
  bool falla = false;

  @override
  Future<List<ProductionUnit>> list(
    String userId,
    String clinicId, {
    String? species,
    String? activity,
  }) async {
    if (falla) throw StateError('almacén caído');
    return filas
        .where((u) => u.clinicId == clinicId)
        .where((u) => species == null || u.species == species)
        .where((u) => activity == null || u.activity == activity)
        .toList();
  }

  @override
  Future<void> save(String userId, ProductionUnit unit) async {
    guardadas.add((userId: userId, unit: unit));
    filas = [unit, ...filas];
  }

  @override
  Future<void> remove(String userId, String id) async {
    filas = filas.where((u) => u.id != id).toList();
  }
}

ProductionUnit _unidad({
  String id = 'u1',
  String name = 'Lote 3',
  int? headcount = 24,
  String? notes,
}) => ProductionUnit(
  id: id,
  clinicId: 'c1',
  species: 'Porcinos',
  activity: 'Maternidad y destete',
  name: name,
  headcount: headcount,
  notes: notes,
  createdAt: DateTime.utc(2026, 11, 7),
);

Widget _pantalla(_RepoFalso repo) => MaterialApp(
  home: ProductionUnitsScreen(
    repository: repo,
    userId: 'ana',
    clinicId: 'c1',
    species: 'Porcinos',
    activity: 'Maternidad y destete',
  ),
);

void main() {
  testWidgets('Sin unidades invita a registrar la primera', (tester) async {
    await tester.pumpWidget(_pantalla(_RepoFalso()));
    await tester.pump();
    expect(find.textContaining('Todavía no hay unidades'), findsOneWidget);
    expect(find.text('Registrar unidad'), findsOneWidget);
  });

  testWidgets('Muestra el nombre, el conteo y la nota', (tester) async {
    await tester.pumpWidget(
      _pantalla(_RepoFalso([_unidad(notes: 'Corral 2')])),
    );
    await tester.pump();
    expect(find.text('Lote 3'), findsOneWidget);
    expect(find.text('24'), findsOneWidget);
    expect(find.text('animales'), findsOneWidget);
    expect(find.text('Corral 2'), findsOneWidget);
  });

  testWidgets('Sin conteo no se inventa un numero', (tester) async {
    await tester.pumpWidget(_pantalla(_RepoFalso([_unidad(headcount: null)])));
    await tester.pump();
    expect(find.text('Lote 3'), findsOneWidget);
    expect(find.text('animales'), findsNothing);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('Registrar una unidad la guarda y la muestra', (tester) async {
    final repo = _RepoFalso();
    await tester.pumpWidget(_pantalla(repo));
    await tester.pump();

    await tester.tap(find.text('Registrar unidad'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Caseta nueva');
    await tester.enterText(find.byType(TextField).at(1), '18');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(repo.guardadas, hasLength(1));
    final guardada = repo.guardadas.single;
    expect(guardada.userId, 'ana');
    expect(guardada.unit.name, 'Caseta nueva');
    expect(guardada.unit.headcount, 18);
    // Y la especie y actividad salen de la pantalla, no se piden al usuario.
    expect(guardada.unit.species, 'Porcinos');
    expect(guardada.unit.activity, 'Maternidad y destete');
    expect(find.text('Caseta nueva'), findsOneWidget);
  });

  testWidgets('Sin nombre no se guarda y lo dice', (tester) async {
    final repo = _RepoFalso();
    await tester.pumpWidget(_pantalla(repo));
    await tester.pump();
    await tester.tap(find.text('Registrar unidad'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '   ');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(repo.guardadas, isEmpty);
    expect(find.text('Ponle un nombre a la unidad'), findsOneWidget);
  });

  testWidgets('Cancelar no guarda nada', (tester) async {
    final repo = _RepoFalso();
    await tester.pumpWidget(_pantalla(repo));
    await tester.pump();
    await tester.tap(find.text('Registrar unidad'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Algo');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(repo.guardadas, isEmpty);
  });

  testWidgets('Un conteo que no es numero no inventa un valor', (tester) async {
    final repo = _RepoFalso();
    await tester.pumpWidget(_pantalla(repo));
    await tester.pump();
    await tester.tap(find.text('Registrar unidad'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Lote raro');
    await tester.enterText(find.byType(TextField).at(1), 'muchos');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(repo.guardadas.single.unit.headcount, isNull);
  });

  testWidgets('Si el almacen falla se avisa sin detalle interno', (
    tester,
  ) async {
    final repo = _RepoFalso()..falla = true;
    await tester.pumpWidget(_pantalla(repo));
    await tester.pump();
    expect(find.text('No se pudieron leer las unidades.'), findsOneWidget);
    expect(find.textContaining('almacén caído'), findsNothing);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:vetdosis_pro/modules/production/data/local_production_unit_store.dart';
import 'package:vetdosis_pro/modules/production/domain/production_unit.dart';

/// Las unidades de produccion son el cimiento de los apartados que hoy dicen
/// «En preparacion»: el hato, el rebaño, la parvada, el lote o el apiario del
/// que luego cuelga todo lo demas.
///
/// Lo que se fija aqui es sobre todo el aislamiento entre cuentas y el
/// descarte de filas que no son de fiar, porque es lo que no se ve al usar la
/// app y lo que duele si falla.
void main() {
  late Database db;
  late LocalProductionUnitStore store;
  var contador = 0;

  setUp(() async {
    // Base propia por prueba: compartirla dejaba filas de una en otra.
    contador++;
    db = await newDatabaseFactoryMemory().openDatabase('unidades-$contador.db');
    store = LocalProductionUnitStore(db);
  });

  tearDown(() => db.close());

  ProductionUnit unidad({
    String id = 'u1',
    String clinicId = 'c1',
    String species = 'Porcinos',
    String activity = 'Maternidad y destete',
    String name = 'Lote 3',
    int? headcount = 24,
    String? notes,
    DateTime? createdAt,
  }) => ProductionUnit(
    id: id,
    clinicId: clinicId,
    species: species,
    activity: activity,
    name: name,
    headcount: headcount,
    notes: notes,
    createdAt: createdAt ?? DateTime.utc(2026, 11, 7, 10),
  );

  test('Lo guardado se recupera con sus datos', () async {
    await store.save('ana', unidad(notes: 'Corral 2'));
    final leidas = await store.list('ana', 'c1');
    expect(leidas, hasLength(1));
    expect(leidas.single.name, 'Lote 3');
    expect(leidas.single.headcount, 24);
    expect(leidas.single.notes, 'Corral 2');
    expect(leidas.single.species, 'Porcinos');
  });

  test('Una cuenta no ve las unidades de otra', () async {
    await store.save('ana', unidad(id: 'u1', name: 'Lote de Ana'));
    await store.save('beto', unidad(id: 'u2', name: 'Lote de Beto'));
    expect(
      (await store.list('ana', 'c1')).map((u) => u.name),
      ['Lote de Ana'],
    );
    expect(
      (await store.list('beto', 'c1')).map((u) => u.name),
      ['Lote de Beto'],
    );
  });

  test('Las unidades de otro espacio de trabajo no se mezclan', () async {
    await store.save('ana', unidad(id: 'u1', clinicId: 'c1', name: 'Granja A'));
    await store.save('ana', unidad(id: 'u2', clinicId: 'c2', name: 'Granja B'));
    expect((await store.list('ana', 'c1')).map((u) => u.name), ['Granja A']);
    expect((await store.list('ana', 'c2')).map((u) => u.name), ['Granja B']);
  });

  test('Se puede acotar por especie y por actividad', () async {
    await store.save('ana', unidad(id: 'u1'));
    await store.save(
      'ana',
      unidad(
        id: 'u2',
        species: 'Aves',
        activity: 'Postura',
        name: 'Caseta 1',
      ),
    );
    expect(
      (await store.list('ana', 'c1', species: 'Aves')).map((u) => u.name),
      ['Caseta 1'],
    );
    expect(
      (await store.list(
        'ana',
        'c1',
        activity: 'Maternidad y destete',
      )).map((u) => u.name),
      ['Lote 3'],
    );
  });

  test('Salen de la mas reciente a la mas antigua', () async {
    await store.save(
      'ana',
      unidad(id: 'u1', name: 'Vieja', createdAt: DateTime.utc(2026, 1, 1)),
    );
    await store.save(
      'ana',
      unidad(id: 'u2', name: 'Nueva', createdAt: DateTime.utc(2026, 11, 1)),
    );
    expect(
      (await store.list('ana', 'c1')).map((u) => u.name),
      ['Nueva', 'Vieja'],
    );
  });

  test('No se guarda una unidad fuera del catalogo', () async {
    await expectLater(
      store.save('ana', unidad(species: 'Dragones', activity: 'Vuelo')),
      throwsArgumentError,
    );
    expect(await store.list('ana', 'c1'), isEmpty);
  });

  test('No se guarda una unidad sin nombre', () async {
    await expectLater(
      store.save('ana', unidad(name: '   ')),
      throwsArgumentError,
    );
    expect(await store.list('ana', 'c1'), isEmpty);
  });

  test('Una fila manipulada se descarta, no se repara', () {
    final fila = unidad().toRow('ana');
    // De otra cuenta.
    expect(ProductionUnit.fromRow(fila, 'beto'), isNull);
    // Sin nombre.
    expect(
      ProductionUnit.fromRow({...fila, 'name': '  '}, 'ana'),
      isNull,
    );
    // Con una actividad que el catalogo no ofrece.
    expect(
      ProductionUnit.fromRow({...fila, 'activity': 'Inventada'}, 'ana'),
      isNull,
    );
    // Con una fecha ilegible.
    expect(
      ProductionUnit.fromRow({...fila, 'createdAt': 'ayer'}, 'ana'),
      isNull,
    );
  });

  test('Un conteo negativo no se acepta como dato', () {
    final fila = unidad(headcount: 5).toRow('ana');
    final leida = ProductionUnit.fromRow({...fila, 'headcount': -3}, 'ana');
    expect(leida, isNotNull);
    expect(leida!.headcount, isNull, reason: 'mejor sin dato que con uno falso');
  });

  test('Guardar otra vez el mismo identificador reemplaza, no duplica', () async {
    await store.save('ana', unidad(name: 'Lote 3'));
    await store.save('ana', unidad(name: 'Lote 3 bis', headcount: 30));
    final leidas = await store.list('ana', 'c1');
    expect(leidas, hasLength(1));
    expect(leidas.single.name, 'Lote 3 bis');
    expect(leidas.single.headcount, 30);
  });

  test('Borrar solo afecta a la cuenta dueña', () async {
    await store.save('ana', unidad(id: 'u1'));
    await store.save('beto', unidad(id: 'u1', name: 'De Beto'));
    // Beto intenta borrar usando el mismo identificador.
    await store.remove('beto', 'u1');
    expect(await store.list('ana', 'c1'), hasLength(1));
    expect(await store.list('beto', 'c1'), isEmpty);
  });

  test('Borrar algo que no existe no revienta', () async {
    await store.remove('ana', 'fantasma');
    expect(await store.list('ana', 'c1'), isEmpty);
  });

  test('copyWith conserva lo que identifica a la unidad', () {
    final original = unidad();
    final cambiada = original.copyWith(
      name: 'Lote 4',
      updatedAt: DateTime.utc(2026, 11, 8),
    );
    expect(cambiada.id, original.id);
    expect(cambiada.species, original.species);
    expect(cambiada.activity, original.activity);
    expect(cambiada.createdAt, original.createdAt);
    expect(cambiada.name, 'Lote 4');
    expect(cambiada.updatedAt, DateTime.utc(2026, 11, 8));
  });

  test('copyWith puede dejar vacios el conteo y la nota', () {
    final original = unidad(headcount: 10, notes: 'algo');
    final limpia = original.copyWith(clearHeadcount: true, clearNotes: true);
    expect(limpia.headcount, isNull);
    expect(limpia.notes, isNull);
  });
}

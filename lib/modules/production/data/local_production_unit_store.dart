import 'dart:convert';

import 'package:sembast/sembast.dart';

import '../domain/production_unit.dart';
import '../domain/production_unit_repository.dart';

/// Unidades de produccion guardadas en el telefono.
///
/// Es lo que permite que los apartados de produccion dejen de ser una lista
/// de nombres y empiecen a guardar de verdad, sin esperar a que existan las
/// tablas remotas. Cuando existan, este almacen sigue sirviendo de cache: el
/// contrato de [ProductionUnitRepository] es el mismo.
///
/// La clave incluye la cuenta, y ademas cada fila guarda su `userId` y se
/// comprueba al leer. Es redundante a proposito, igual que en el almacen de
/// notificaciones: si dos cuentas llegaran a compartir el archivo local, una
/// no puede acabar viendo los registros de la otra por un fallo de clave.
class LocalProductionUnitStore implements ProductionUnitRepository {
  LocalProductionUnitStore(this.database);

  /// Base local compartida con el resto del modo sin conexion.
  final Database database;

  final _store = stringMapStoreFactory.store('production-units-v1');

  String _key(String userId, String id) => jsonEncode([userId, id]);

  @override
  Future<List<ProductionUnit>> list(
    String userId,
    String clinicId, {
    String? species,
    String? activity,
  }) async {
    final rows = await _store.find(
      database,
      finder: Finder(
        filter: Filter.and([
          Filter.equals('userId', userId),
          Filter.equals('clinicId', clinicId),
        ]),
      ),
    );
    final items = <ProductionUnit>[];
    for (final row in rows) {
      final unit = ProductionUnit.fromRow(row.value, userId);
      // Una fila que no valida se descarta entera, no se repara.
      if (unit == null) continue;
      if (species != null && unit.species != species) continue;
      if (activity != null && unit.activity != activity) continue;
      items.add(unit);
    }
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  @override
  Future<void> save(String userId, ProductionUnit unit) async {
    // No se guarda una unidad colgada de una actividad que no existe: si el
    // catalogo cambia, el registro tiene que seguir significando algo.
    if (!isKnownProductionArea(unit.species, unit.activity)) {
      throw ArgumentError.value(
        '${unit.species} / ${unit.activity}',
        'unit',
        'La especie y la actividad no estan en el catalogo de produccion',
      );
    }
    if (unit.name.trim().isEmpty) {
      throw ArgumentError.value(unit.name, 'name', 'La unidad necesita nombre');
    }
    await _store.record(_key(userId, unit.id)).put(database, unit.toRow(userId));
  }

  @override
  Future<void> remove(String userId, String id) async {
    final record = _store.record(_key(userId, id));
    final row = await record.get(database);
    if (row == null) return;
    // Una fila de otra cuenta no se borra ni por error de clave.
    if (ProductionUnit.fromRow(row, userId) == null) return;
    await record.delete(database);
  }
}

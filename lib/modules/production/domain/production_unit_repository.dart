import 'production_unit.dart';

/// Donde se guardan las unidades de produccion.
///
/// Toda operacion lleva el `userId` de quien la pide. No es decoracion: el
/// almacen lo usa para la clave y vuelve a comprobarlo al leer cada fila, de
/// modo que una cuenta no pueda acabar viendo los registros de otra aunque
/// compartan el archivo local.
///
/// Hoy solo existe la implementacion local. Cuando haya tablas remotas, el
/// contrato no cambia y el almacen local sigue valiendo de cache.
abstract class ProductionUnitRepository {
  /// Las unidades de un espacio de trabajo, de la mas reciente a la mas vieja.
  ///
  /// Con [species] o [activity] se acota a esa parte del catalogo.
  Future<List<ProductionUnit>> list(
    String userId,
    String clinicId, {
    String? species,
    String? activity,
  });

  /// Guarda una unidad nueva o reemplaza la que tenga ese identificador.
  Future<void> save(String userId, ProductionUnit unit);

  /// Borra la unidad, si es de esa cuenta.
  Future<void> remove(String userId, String id);
}

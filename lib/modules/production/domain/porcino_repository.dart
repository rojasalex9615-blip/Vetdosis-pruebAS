/// Acceso a los catálogos y planes guardados de Porcinos.
///
/// La escritura es solo por RPC con recibo idempotente (`produccion_banda_guardar`
/// / `produccion_banda_eliminar`, migración 20261114000100): la tabla
/// `produccion_bandas_planes` solo concede `select`. El catálogo de bioseguridad
/// (33 filas), el de fases UPP (7) y sus avisos (15) son de solo lectura.
library;

/// Plan de flujo por bandas guardado en la clínica.
///
/// [entradas] y [resultados] conservan los mapas tal como los guardó el RPC:
/// son el contrato JSONB del servidor, no un modelo tipado.
class PorcinoBandPlan {
  const PorcinoBandPlan({
    required this.id,
    required this.name,
    required this.species,
    required this.inputs,
    required this.results,
    required this.version,
    required this.updatedAt,
  });

  final String id, name, species;
  final Map<String, dynamic> inputs, results;
  final int version;
  final DateTime? updatedAt;

  factory PorcinoBandPlan.read(Map<String, dynamic> row) => PorcinoBandPlan(
    id: row['id'] as String,
    name: row['nombre'] as String,
    species: (row['especie'] as String?) ?? 'cerdo',
    inputs: Map<String, dynamic>.from((row['entradas'] as Map?) ?? const {}),
    results: Map<String, dynamic>.from((row['resultados'] as Map?) ?? const {}),
    version: (row['version'] as num?)?.toInt() ?? 1,
    updatedAt: DateTime.tryParse('${row['updated_at'] ?? ''}'),
  );
}

abstract interface class PorcinoRepository {
  /// Planes de la clínica, del más reciente al más antiguo.
  Future<List<PorcinoBandPlan>> listBandPlans(String clinicId);

  /// Crea o actualiza un plan. Devuelve el id; [operation] da idempotencia.
  Future<String> saveBandPlan(
    String clinicId,
    Map<String, dynamic> data, {
    required String operation,
  });

  /// Elimina un plan. Devuelve `true` si el RPC lo confirmó.
  Future<bool> deleteBandPlan(
    String clinicId,
    String planId, {
    required String operation,
  });

  /// Catálogo de referencias de bioseguridad (solo lectura).
  Future<List<Map<String, dynamic>>> biosecurityRefs();

  /// Fases del ejemplo UPP y sus avisos de datos faltantes (solo lectura).
  Future<List<Map<String, dynamic>>> uppPhases();
  Future<List<Map<String, dynamic>>> uppWarnings();
}

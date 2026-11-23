import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/production_farm.dart';

/// Lectura de los datos reales de la granja para el Dashboard Pecuario.
///
/// Solo lee. Las calculadoras son las que escriben en `produccion_registros`
/// y los modulos de manejo las que escriben en `produccion_eventos`; el panel
/// nada mas refleja lo que ya hay.
///
/// Todas las consultas van acotadas por `clinic_id` ademas de por RLS: si una
/// politica se afloja, la consulta sigue sin cruzar datos de otra cuenta.
class SupabaseProductionFarmRepository implements ProductionFarmRepository {
  const SupabaseProductionFarmRepository(this.client);
  final SupabaseClient client;

  @override
  Future<FarmSnapshot> load(
    String clinicId, {
    required List<String> especies,
  }) async {
    // Pestaña sin especie en el catalogo (hoy, Equinos): no hay nada que
    // consultar y devolver vacio es la respuesta correcta, no un error.
    if (especies.isEmpty) return const FarmSnapshot();

    // Las dos lecturas no dependen entre si: se lanzan a la vez y se esperan
    // despues, asi el panel aguarda un viaje en lugar de dos encadenados.
    final lotesPendiente = _lotes(clinicId, especies);
    final defsPendiente = _metricas(especies);
    final lotes = await lotesPendiente;
    final defs = await defsPendiente;

    // Eventos y registros cuelgan de los lotes: sin lotes no hay nada que
    // pedir, y asi nos ahorramos dos consultas en el caso vacio, que hoy es
    // el habitual.
    if (lotes.isEmpty) {
      return FarmSnapshot(metricDefs: defs);
    }

    final ids = lotes.map((l) => l.id).toList();
    final eventosPendiente = _eventos(clinicId, ids);
    final registrosPendiente = _registros(clinicId, ids);

    return FarmSnapshot(
      batches: lotes,
      events: await eventosPendiente,
      records: await registrosPendiente,
      metricDefs: defs,
    );
  }

  Future<List<FarmBatch>> _lotes(
    String clinicId,
    List<String> especies,
  ) async {
    final rows = await client
        .from('lotes_produccion')
        .select(
          'id,codigo,nombre,especie,proposito,sistema,fecha_inicio,'
          'cabezas,identificador_hato,estado',
        )
        .eq('clinic_id', clinicId)
        .inFilter('especie', especies)
        .order('fecha_inicio', ascending: false);
    return rows.map((r) => FarmBatch.read(Map<String, dynamic>.from(r))).toList();
  }

  Future<List<FarmEvent>> _eventos(
    String clinicId,
    List<String> loteIds,
  ) async {
    final rows = await client
        .from('produccion_eventos')
        .select('id,lote_id,fecha,tipo,subtipo,animales_afectados,detalle')
        .eq('clinic_id', clinicId)
        .inFilter('lote_id', loteIds)
        .order('fecha');
    return rows.map((r) => FarmEvent.read(Map<String, dynamic>.from(r))).toList();
  }

  Future<List<FarmRecord>> _registros(
    String clinicId,
    List<String> loteIds,
  ) async {
    final rows = await client
        .from('produccion_registros')
        .select('id,lote_id,fecha,metricas')
        .eq('clinic_id', clinicId)
        .inFilter('lote_id', loteIds)
        .order('fecha');
    return rows.map((r) => FarmRecord.read(Map<String, dynamic>.from(r))).toList();
  }

  /// Catalogo de referencia: no lleva `clinic_id` porque es igual para todos.
  Future<List<FarmMetricDef>> _metricas(List<String> especies) async {
    final rows = await client
        .from('produccion_metricas')
        .select('especie,clave,etiqueta,unidad,minimo,maximo')
        .inFilter('especie', especies)
        .order('clave');
    return rows
        .map((r) => FarmMetricDef.read(Map<String, dynamic>.from(r)))
        .toList();
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/feed_inventory.dart';

/// Lectura del inventario de alimento sobre Supabase.
///
/// Las existencias y la eficiencia por lote vienen de dos vistas y no de sumar
/// movimientos aquí: una granja escribe miles de líneas al año y traerlas al
/// teléfono para sumarlas deja de funcionar el primer año.
///
/// Todas las consultas van acotadas por `clinic_id` además de por RLS: si una
/// política se afloja, la consulta sigue sin cruzar datos de otra cuenta.
class SupabaseFeedInventoryRepository implements FeedInventoryRepository {
  const SupabaseFeedInventoryRepository(this.client);
  final SupabaseClient client;

  @override
  Future<FeedSnapshot> load(String clinicId) async {
    // Ninguna depende de otra: se lanzan las cinco a la vez.
    final alimentosPendiente = _alimentos(clinicId);
    final silosPendiente = _silos(clinicId);
    final existenciasPendiente = _existencias(clinicId);
    final eficienciasPendiente = _eficiencias(clinicId);
    final movimientosPendiente = _movimientos(clinicId);

    return FeedSnapshot(
      alimentos: await alimentosPendiente,
      silos: await silosPendiente,
      existencias: await existenciasPendiente,
      eficiencias: await eficienciasPendiente,
      movimientos: await movimientosPendiente,
    );
  }

  Future<List<FeedItem>> _alimentos(String clinicId) async {
    final rows = await client
        .from('produccion_alimentos')
        .select(
          'id,nombre,tipo,unidad,kg_por_unidad,materia_seca_pct,'
          'proteina_pct,activo,notas,version',
        )
        .eq('clinic_id', clinicId)
        .order('nombre')
        .limit(300);
    return rows.map(FeedItem.read).toList();
  }

  Future<List<FeedStore>> _silos(String clinicId) async {
    final rows = await client
        .from('produccion_silos')
        .select('id,nombre,tipo,capacidad_kg,alimento_id,activo,notas,version')
        .eq('clinic_id', clinicId)
        .order('nombre')
        .limit(200);
    return rows.map(FeedStore.read).toList();
  }

  Future<List<FeedStock>> _existencias(String clinicId) async {
    final rows = await client
        .from('produccion_alimento_existencias')
        .select(
          'alimento_id,silo_id,kg,valor,kg_salida_30d,'
          'primera_salida_30d,ultimo_movimiento',
        )
        .eq('clinic_id', clinicId)
        .limit(1000);
    return rows.map(FeedStock.read).toList();
  }

  Future<List<BatchEfficiency>> _eficiencias(String clinicId) async {
    final rows = await client
        .from('produccion_lote_eficiencia')
        .select(
          'lote_id,codigo,nombre,especie,proposito,cabezas,estado,'
          'kg_alimento,kg_materia_seca,costo_alimento,primera_carga,'
          'ultima_carga,leche_l,huevos,miel_kg,dias_con_registro,'
          'peso_inicial_kg,peso_final_kg',
        )
        .eq('clinic_id', clinicId)
        .order('codigo')
        .limit(300);
    return rows.map(BatchEfficiency.read).toList();
  }

  /// Solo el último tramo del libro: es para revisar lo de ayer, no un archivo
  /// histórico. Lo acumulado ya viene sumado en las vistas.
  Future<List<FeedMovement>> _movimientos(String clinicId) async {
    final rows = await client
        .from('produccion_alimento_movimientos')
        .select(
          'id,alimento_id,silo_id,lote_id,fecha,tipo,kg,costo_kg,'
          'proveedor,referencia,nota',
        )
        .eq('clinic_id', clinicId)
        .order('fecha', ascending: false)
        .order('created_at', ascending: false)
        .limit(200);
    return rows.map(FeedMovement.read).toList();
  }
}

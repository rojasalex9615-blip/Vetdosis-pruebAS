import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/porcino_repository.dart';

/// Implementación sobre Supabase de los catálogos y planes de Porcinos.
///
/// Lectura directa por RLS (`authenticated`); escritura solo por los RPC
/// idempotentes de la migración 15P. No consulta ni escribe datos clínicos.
class SupabasePorcinoRepository implements PorcinoRepository {
  const SupabasePorcinoRepository(this.client);
  final SupabaseClient client;

  @override
  Future<List<PorcinoBandPlan>> listBandPlans(String clinicId) async {
    final rows = await client
        .from('produccion_bandas_planes')
        .select('id,nombre,especie,entradas,resultados,version,updated_at')
        .eq('clinic_id', clinicId)
        .order('updated_at', ascending: false);
    return rows.map(PorcinoBandPlan.read).toList();
  }

  @override
  Future<String> saveBandPlan(
    String clinicId,
    Map<String, dynamic> data, {
    required String operation,
  }) async {
    final result = await client.rpc(
      'produccion_banda_guardar',
      params: {'p_clinic': clinicId, 'p_data': data, 'p_operation': operation},
    );
    return result as String;
  }

  @override
  Future<bool> deleteBandPlan(
    String clinicId,
    String planId, {
    required String operation,
  }) async {
    final result = await client.rpc(
      'produccion_banda_eliminar',
      params: {'p_clinic': clinicId, 'p_id': planId, 'p_operation': operation},
    );
    return result == true;
  }

  @override
  Future<List<Map<String, dynamic>>> biosecurityRefs() async {
    final rows = await client
        .from('produccion_bioseguridad_refs')
        .select(
          'id,categoria,dato,valor,unidad,nota,confianza,fuente,'
          'pagina_o_seccion,orden',
        )
        .order('categoria')
        .order('orden');
    return rows.map(Map<String, dynamic>.from).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> uppPhases() async {
    final rows = await client
        .from('produccion_upp_fases')
        .select('id,fase,orden')
        .order('orden');
    return rows.map(Map<String, dynamic>.from).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> uppWarnings() async {
    final rows = await client
        .from('produccion_upp_avisos')
        .select('id,tipo,tema,detalle,donde_conseguirlo,orden')
        .order('orden');
    return rows.map(Map<String, dynamic>.from).toList();
  }
}

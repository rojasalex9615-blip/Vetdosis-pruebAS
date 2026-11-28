import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/production_write_repository.dart';

/// Escritura del Dashboard Pecuario sobre Supabase.
///
/// Los tres RPC ya existían; esta clase es el camino que faltaba desde la app.
/// No hay un solo `insert` directo: igual que en el resto del proyecto, las
/// escrituras pasan por funciones `SECURITY DEFINER` que comprueban el rol,
/// validan la entrada y dejan rastro en `audit_log`.
class SupabaseProductionWriteRepository implements ProductionWriteRepository {
  const SupabaseProductionWriteRepository(this.client);
  final SupabaseClient client;

  Future<String> _llamar(String funcion, Map<String, dynamic> params) async {
    try {
      final resultado = await client.rpc(funcion, params: params);
      return '$resultado';
    } catch (e) {
      throw traducirErrorProduccion(e);
    }
  }

  /// Las fechas de calendario no llevan hora: convertirlas a UTC podría
  /// correrlas un día según la zona horaria.
  String _dia(DateTime valor) => valor.toIso8601String().substring(0, 10);

  @override
  Future<String> guardarLote({
    required String clinicId,
    required Map<String, dynamic> data,
    required String operation,
  }) => _llamar('produccion_lote_guardar', {
    'p_clinic': clinicId,
    'p_data': data,
    'p_operation': operation,
  });

  @override
  Future<String> guardarRegistro({
    required String clinicId,
    required String loteId,
    required DateTime fecha,
    required Map<String, double> metricas,
    String? notas,
    required String operation,
  }) => _llamar('produccion_registro_guardar', {
    'p_clinic': clinicId,
    'p_lote': loteId,
    'p_fecha': _dia(fecha),
    // El servidor exige que cada valor sea un numero JSON, no una cadena:
    // private.produccion_metricas_ok rechaza cualquier otra cosa.
    'p_metricas': metricas,
    'p_notas': notas,
    'p_operation': operation,
  });

  @override
  Future<String> guardarEvento({
    required String clinicId,
    required String loteId,
    required DateTime fecha,
    required String tipo,
    String? subtipo,
    int? animales,
    Map<String, dynamic>? detalle,
    required String operation,
  }) => _llamar('produccion_evento_guardar', {
    'p_clinic': clinicId,
    'p_lote': loteId,
    'p_fecha': _dia(fecha),
    'p_tipo': tipo,
    'p_subtipo': subtipo,
    'p_animales': animales,
    'p_detalle': detalle ?? const <String, dynamic>{},
    'p_operation': operation,
  });

  @override
  Future<List<SpeciesPurpose>> propositosPorEspecie() async {
    final rows = await client
        .from('produccion_especies_propositos')
        .select('especie,proposito')
        .order('especie')
        .order('proposito');
    return rows
        .map(
          (r) => SpeciesPurpose('${r['especie'] ?? ''}', '${r['proposito'] ?? ''}'),
        )
        .toList();
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/feed_write_repository.dart';

/// Escritura del inventario de alimento sobre Supabase.
///
/// Ni un `insert` directo: todo pasa por los tres RPC `SECURITY DEFINER`, que
/// comprueban el rol, validan la entrada, valoran las salidas al promedio
/// ponderado y dejan rastro en `audit_log`.
class SupabaseFeedWriteRepository implements FeedWriteRepository {
  const SupabaseFeedWriteRepository(this.client);
  final SupabaseClient client;

  Future<String> _llamar(String funcion, Map<String, dynamic> params) async {
    try {
      final resultado = await client.rpc(funcion, params: params);
      return '$resultado';
    } catch (e) {
      throw traducirErrorAlimento(e);
    }
  }

  /// Fecha de calendario sin hora: convertirla a UTC podría correrla un día.
  String _dia(DateTime valor) => valor.toIso8601String().substring(0, 10);

  @override
  Future<String> guardarAlimento({
    required String clinicId,
    required Map<String, dynamic> data,
    required String operation,
  }) => _llamar('produccion_alimento_guardar', {
    'p_clinic': clinicId,
    'p_data': data,
    'p_operation': operation,
  });

  @override
  Future<String> guardarSilo({
    required String clinicId,
    required Map<String, dynamic> data,
    required String operation,
  }) => _llamar('produccion_silo_guardar', {
    'p_clinic': clinicId,
    'p_data': data,
    'p_operation': operation,
  });

  @override
  Future<String> moverAlimento({
    required String clinicId,
    required String alimentoId,
    String? siloId,
    String? loteId,
    required DateTime fecha,
    required String tipo,
    required double kg,
    double? costoKg,
    String? proveedor,
    String? referencia,
    String? nota,
    required String operation,
  }) => _llamar('produccion_alimento_movimiento', {
    'p_clinic': clinicId,
    'p_alimento': alimentoId,
    'p_silo': siloId,
    'p_lote': loteId,
    'p_fecha': _dia(fecha),
    'p_tipo': tipo,
    'p_kg': kg,
    'p_costo': costoKg,
    'p_proveedor': proveedor,
    'p_referencia': referencia,
    'p_nota': nota,
    'p_operation': operation,
  });
}

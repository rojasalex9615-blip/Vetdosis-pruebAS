import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/gestation_write_repository.dart';

/// Escritura de gestaciones sobre Supabase.
///
/// Ni un `insert` directo: todo pasa por los dos RPC `SECURITY DEFINER`, que
/// comprueban el rol, validan la entrada y dejan rastro en `audit_log`.
class SupabaseGestationWriteRepository implements GestationWriteRepository {
  const SupabaseGestationWriteRepository(this.client);
  final SupabaseClient client;

  Future<String> _llamar(String funcion, Map<String, dynamic> params) async {
    try {
      final resultado = await client.rpc(funcion, params: params);
      return '$resultado';
    } catch (e) {
      throw traducirErrorGestacion(e);
    }
  }

  /// Fecha de calendario sin hora: convertirla a UTC podría correrla un día.
  String? _dia(DateTime? valor) =>
      valor?.toIso8601String().substring(0, 10);

  @override
  Future<String> guardarGestacion({
    required String clinicId,
    String? id,
    required String patientId,
    String? loteId,
    required String especie,
    required DateTime servicio,
    required String metodo,
    String? semental,
    int? dias,
    required String diagnostico,
    DateTime? diagnosticoEl,
    String? notas,
    required String operation,
  }) => _llamar('reproduccion_gestacion_guardar', {
    'p_clinic': clinicId,
    'p_id': id,
    'p_patient': patientId,
    'p_lote': loteId,
    'p_especie': especie,
    'p_servicio': _dia(servicio),
    'p_metodo': metodo,
    'p_semental': semental,
    'p_dias': dias,
    'p_diagnostico': diagnostico,
    'p_diagnostico_el': _dia(diagnosticoEl),
    'p_notas': notas,
    'p_operation': operation,
  });

  @override
  Future<String> cerrarGestacion({
    required String clinicId,
    required String id,
    required String estado,
    DateTime? parto,
    int? vivas,
    int? muertas,
    String? notas,
    required String operation,
  }) => _llamar('reproduccion_gestacion_cerrar', {
    'p_clinic': clinicId,
    'p_id': id,
    'p_estado': estado,
    'p_parto': _dia(parto),
    'p_vivas': vivas,
    'p_muertas': muertas,
    'p_notas': notas,
    'p_operation': operation,
  });

  @override
  Future<List<BreedingFemale>> hembras(String clinicId) async {
    // Se piden las hembras y las que nadie especifico: dejar fuera estas
    // ultimas escondería animales cuyo sexo no se llego a capturar, que en
    // una granja es de lo mas comun.
    final rows = await client
        .from('vet_patients')
        .select('id,name,species,sex')
        .eq('clinic_id', clinicId)
        .inFilter('sex', ['hembra', 'sin especificar'])
        .order('name')
        .limit(1000);
    return rows
        .map(
          (r) => BreedingFemale(
            id: '${r['id']}',
            nombre: '${r['name'] ?? 'Sin nombre'}',
            especie: '${r['species'] ?? ''}',
          ),
        )
        .toList();
  }
}

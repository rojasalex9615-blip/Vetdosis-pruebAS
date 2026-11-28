import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/gestation.dart';

/// Lectura de las gestaciones sobre Supabase.
///
/// Todas las consultas van acotadas por `clinic_id` además de por RLS: si una
/// política se afloja, la consulta sigue sin cruzar datos de otra cuenta.
class SupabaseGestationRepository implements GestationRepository {
  const SupabaseGestationRepository(this.client);
  final SupabaseClient client;

  @override
  Future<GestationSnapshot> load(String clinicId) async {
    // Las dos primeras no dependen entre si: se lanzan a la vez.
    final gestacionesPendiente = _gestaciones(clinicId);
    final catalogoPendiente = _catalogo();
    final gestaciones = await gestacionesPendiente;
    final catalogo = await catalogoPendiente;

    // Los nombres solo hacen falta si hay gestaciones, y solo los de las
    // hembras que aparecen: pedir todo el padron seria traer de mas.
    final ids = {for (final g in gestaciones) g.patientId};
    final nombres = ids.isEmpty
        ? <String, String>{}
        : await _nombres(clinicId, ids.toList());

    return GestationSnapshot(
      gestaciones: gestaciones,
      catalogo: catalogo,
      nombresDePaciente: nombres,
    );
  }

  Future<List<Gestation>> _gestaciones(String clinicId) async {
    final rows = await client
        .from('reproduccion_gestaciones')
        .select(
          'id,patient_id,lote_id,especie,servicio_el,metodo,semental,'
          'dias_gestacion,parto_estimado,diagnostico,diagnostico_el,estado,'
          'parto_el,crias_vivas,crias_muertas,notas',
        )
        .eq('clinic_id', clinicId)
        .order('servicio_el', ascending: false)
        .limit(500);
    return rows.map(Gestation.read).toList();
  }

  Future<List<GestationDays>> _catalogo() async {
    final rows = await client
        .from('reproduccion_gestacion_dias')
        .select('especie,nombre,grupo,dias_min,dias_prom,dias_max')
        .eq('activo', true)
        .order('nombre');
    return rows.map(GestationDays.read).toList();
  }

  Future<Map<String, String>> _nombres(
    String clinicId,
    List<String> ids,
  ) async {
    final rows = await client
        .from('vet_patients')
        .select('id,name')
        .eq('clinic_id', clinicId)
        .inFilter('id', ids);
    return {
      for (final r in rows) '${r['id']}': '${r['name'] ?? 'Sin nombre'}',
    };
  }
}

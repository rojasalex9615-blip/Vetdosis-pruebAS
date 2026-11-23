import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/exotic_dashboard.dart';

/// Lectura de los ejemplares exóticos y su historia.
///
/// Solo lee. Quien da de alta pacientes, registra pesos o abre una estancia es
/// el módulo clínico; el panel nada más refleja lo que ya hay.
///
/// Todas las consultas van acotadas por `clinic_id` además de por RLS: si una
/// política se afloja, la consulta sigue sin cruzar datos de otra cuenta.
class SupabaseExoticRepository implements ExoticDashboardRepository {
  const SupabaseExoticRepository(this.client);
  final SupabaseClient client;

  @override
  Future<ExoticSnapshot> load(String clinicId) async {
    final ejemplares = await _ejemplares(clinicId);
    if (ejemplares.isEmpty) return const ExoticSnapshot();

    final ids = ejemplares.map((e) => e.id).toList();
    // Las dos lecturas no dependen entre si: se lanzan a la vez.
    final eventosPendiente = _eventos(clinicId, ids);
    final estanciasPendiente = _estancias(clinicId, ids);
    final eventos = await eventosPendiente;
    final estancias = await estanciasPendiente;

    return ExoticSnapshot(
      specimens: ejemplares,
      weights: _pesosDe(eventos),
      stays: estancias,
      events: eventos,
    );
  }

  Future<List<ExoticSpecimen>> _ejemplares(String clinicId) async {
    final rows = await client
        .from('vet_patients')
        .select('id,name,species,breed,sex,birth_date')
        .eq('clinic_id', clinicId)
        .order('created_at', ascending: false);
    return rows.map((r) {
      final especie = '${r['species'] ?? ''}';
      return ExoticSpecimen(
        id: '${r['id']}',
        nombre: '${r['name'] ?? ''}',
        especie: especie,
        taxon: taxonDeEspecie(especie),
        raza: '${r['breed'] ?? ''}',
        sexo: '${r['sex'] ?? ''}',
        fechaNacimiento: DateTime.tryParse('${r['birth_date'] ?? ''}'),
      );
    }).toList();
  }

  Future<List<ExoticEvent>> _eventos(
    String clinicId,
    List<String> ids,
  ) async {
    final rows = await client
        .from('vet_patient_events')
        .select('id,patient_id,kind,payload,created_at')
        .eq('clinic_id', clinicId)
        .inFilter('patient_id', ids)
        .order('created_at');
    return rows.map((r) {
      final payload = r['payload'];
      final mapa = payload is Map
          ? payload.map((k, v) => MapEntry('$k', v))
          : const <String, dynamic>{};
      return ExoticEvent(
        id: '${r['id']}',
        specimenId: '${r['patient_id']}',
        tipo: '${r['kind'] ?? ''}',
        fecha: DateTime.tryParse('${r['created_at'] ?? ''}') ?? DateTime.now(),
        datos: mapa,
      );
    }).toList();
  }

  Future<List<ExoticStay>> _estancias(
    String clinicId,
    List<String> ids,
  ) async {
    // Solo las abiertas: una estancia ya dada de alta no ocupa jaula ni
    // cuenta como ejemplar en cuarentena.
    final rows = await client
        .from('hospital_stays')
        .select('id,patient_id,cage,admitted_at,discharged_at')
        .eq('clinic_id', clinicId)
        .inFilter('patient_id', ids)
        .isFilter('discharged_at', null)
        .order('admitted_at', ascending: false);
    return rows
        .map(
          (r) => ExoticStay(
            id: '${r['id']}',
            specimenId: '${r['patient_id']}',
            ingreso:
                DateTime.tryParse('${r['admitted_at'] ?? ''}') ?? DateTime.now(),
            recinto: '${r['cage'] ?? ''}',
          ),
        )
        .toList();
  }

  /// Los pesos salen de los eventos de tipo `weight`, que es donde los guarda
  /// el expediente. El payload trae kilos; aquí se pasan a gramos porque en
  /// exóticos es la unidad que deja ver los cambios que importan.
  List<ExoticWeight> _pesosDe(List<ExoticEvent> eventos) {
    final pesos = <ExoticWeight>[];
    for (final e in eventos) {
      if (e.tipo != 'weight') continue;
      final g = _gramosDe(e);
      if (g == null) continue;
      pesos.add(
        ExoticWeight(specimenId: e.specimenId, fecha: e.fecha, gramos: g),
      );
    }
    return pesos;
  }

  /// El expediente guarda el peso en kilos y como texto (admite coma), tal
  /// como lo valida `patient_models`. Aqui se normaliza y se pasa a gramos.
  double? _gramosDe(ExoticEvent e) {
    final crudo = e.datos['kg'];
    if (crudo == null) return null;
    final n = crudo is num
        ? crudo.toDouble()
        : double.tryParse('$crudo'.replaceAll(',', '.'));
    return n == null ? null : n * 1000;
  }
}

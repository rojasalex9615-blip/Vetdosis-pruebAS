import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/exotic_dashboard.dart';

/// Lectura de los ejemplares exóticos, su ambiente y su historia.
///
/// Solo lee. Las escrituras entran por los RPC `exotic_*` del servidor, que
/// validan y dejan rastro en `audit_log`; en estas tablas `authenticated` no
/// tiene INSERT ni UPDATE a propósito.
///
/// Todas las consultas van acotadas por `clinic_id` además de por RLS: si una
/// política se afloja, la consulta sigue sin cruzar datos de otra cuenta.
class SupabaseExoticRepository implements ExoticDashboardRepository {
  const SupabaseExoticRepository(this.client);
  final SupabaseClient client;

  @override
  Future<ExoticSnapshot> load(String clinicId) async {
    // Los recintos no dependen de que haya pacientes: un criadero puede tener
    // terrarios montados antes de dar de alta al primer ejemplar.
    final (recintos, lecturas, nidadas, ejemplares) = await (
      _recintos(clinicId),
      _lecturas(clinicId),
      _nidadas(clinicId),
      _ejemplares(clinicId),
    ).wait;

    if (ejemplares.isEmpty) {
      return ExoticSnapshot(
        enclosures: recintos,
        readings: lecturas,
        clutches: nidadas,
      );
    }

    final ids = ejemplares.map((e) => e.id).toList();
    // Ninguna de estas lecturas depende de las otras: se lanzan a la vez.
    final (eventos, estancias, marcajes, legal, tomas, fisio) = await (
      _eventos(clinicId, ids),
      _estancias(clinicId, ids),
      _marcajes(clinicId, ids),
      _legal(clinicId, ids),
      _tomas(clinicId, ids),
      _fisiologicos(clinicId, ids),
    ).wait;

    return ExoticSnapshot(
      specimens: ejemplares,
      weights: _pesosDe(eventos),
      stays: estancias,
      events: eventos,
      enclosures: recintos,
      readings: lecturas,
      identifiers: marcajes,
      legal: legal,
      feedings: tomas,
      clutches: nidadas,
      physioEvents: fisio,
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

  Future<List<ExoticEnclosure>> _recintos(String clinicId) async {
    final rows = await client
        .from('exotic_enclosures')
        .select(
          'id,nombre,tipo,especie,temp_caliente_min,temp_caliente_max,'
          'temp_fria_min,temp_fria_max,humedad_min,humedad_max,uv_min,uv_max,'
          'ph_min,ph_max,amoniaco_max,nitrito_max,salinidad_min,salinidad_max',
        )
        .eq('clinic_id', clinicId)
        .eq('activo', true)
        .order('nombre');
    return rows
        .map(
          (r) => ExoticEnclosure(
            id: '${r['id']}',
            nombre: '${r['nombre'] ?? ''}',
            tipo: '${r['tipo'] ?? ''}',
            especie: '${r['especie'] ?? ''}',
            tempCalienteMin: _num(r['temp_caliente_min']),
            tempCalienteMax: _num(r['temp_caliente_max']),
            tempFriaMin: _num(r['temp_fria_min']),
            tempFriaMax: _num(r['temp_fria_max']),
            humedadMin: _num(r['humedad_min']),
            humedadMax: _num(r['humedad_max']),
            uvMin: _num(r['uv_min']),
            uvMax: _num(r['uv_max']),
            phMin: _num(r['ph_min']),
            phMax: _num(r['ph_max']),
            amoniacoMax: _num(r['amoniaco_max']),
            nitritoMax: _num(r['nitrito_max']),
            salinidadMin: _num(r['salinidad_min']),
            salinidadMax: _num(r['salinidad_max']),
          ),
        )
        .toList();
  }

  /// Las lecturas recientes de todos los recintos.
  ///
  /// Se limita a 400: el panel solo necesita la última de cada recinto, y
  /// traer el histórico entero haría lenta la pantalla sin aportar nada.
  Future<List<ExoticReading>> _lecturas(String clinicId) async {
    final rows = await client
        .from('exotic_enclosure_readings')
        .select(
          'enclosure_id,medido_en,temp_caliente,temp_fria,humedad,uv_index,'
          'ph,amoniaco,nitrito,salinidad',
        )
        .eq('clinic_id', clinicId)
        .order('medido_en', ascending: false)
        .limit(400);
    return rows
        .map(
          (r) => ExoticReading(
            enclosureId: '${r['enclosure_id']}',
            medidoEn: DateTime.parse('${r['medido_en'] ?? ''}'),
            tempCaliente: _num(r['temp_caliente']),
            tempFria: _num(r['temp_fria']),
            humedad: _num(r['humedad']),
            uvIndex: _num(r['uv_index']),
            ph: _num(r['ph']),
            amoniaco: _num(r['amoniaco']),
            nitrito: _num(r['nitrito']),
            salinidad: _num(r['salinidad']),
          ),
        )
        .toList();
  }

  Future<List<ExoticClutch>> _nidadas(String clinicId) async {
    final rows = await client
        .from('exotic_clutches')
        .select(
          'id,especie,puesta_el,huevos,fertiles,temp_objetivo,'
          'humedad_objetivo,eclosion_estimada,estado',
        )
        .eq('clinic_id', clinicId)
        .order('eclosion_estimada');
    return rows
        .map(
          (r) => ExoticClutch(
            id: '${r['id']}',
            especie: '${r['especie'] ?? ''}',
            puestaEl: DateTime.parse('${r['puesta_el'] ?? ''}'),
            huevos: (r['huevos'] as num?)?.toInt() ?? 0,
            estado: '${r['estado'] ?? ''}',
            fertiles: (r['fertiles'] as num?)?.toInt(),
            tempObjetivo: _num(r['temp_objetivo']),
            humedadObjetivo: _num(r['humedad_objetivo']),
            eclosionEstimada: DateTime.tryParse(
              '${r['eclosion_estimada'] ?? ''}',
            ),
          ),
        )
        .toList();
  }

  Future<List<ExoticEvent>> _eventos(String clinicId, List<String> ids) async {
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
          : <String, dynamic>{};
      return ExoticEvent(
        id: '${r['id']}',
        specimenId: '${r['patient_id']}',
        tipo: '${r['kind'] ?? ''}',
        fecha: DateTime.parse('${r['created_at'] ?? ''}'),
        datos: mapa,
      );
    }).toList();
  }

  Future<List<ExoticStay>> _estancias(String clinicId, List<String> ids) async {
    // Solo las abiertas: una estancia ya dada de alta no ocupa jaula ni
    // cuenta como ejemplar en cuarentena.
    final rows = await client
        .from('hospital_stays')
        .select('id,patient_id,cage,admitted_at,discharged_at')
        .eq('clinic_id', clinicId)
        .inFilter('patient_id', ids)
        .isFilter('discharged_at', null)
        .order('admitted_at', ascending: false);
    if (rows.isEmpty) return const [];

    // Los días previstos de aislamiento viven en su propia tabla, porque
    // `hospital_stays` es del módulo de hospital y no sabe de cuarentenas.
    final planes = await client
        .from('exotic_quarantine_plans')
        .select('stay_id,dias')
        .eq('clinic_id', clinicId)
        .inFilter('stay_id', rows.map((r) => '${r['id']}').toList());
    final diasPorEstancia = <String, int>{
      for (final p in planes)
        '${p['stay_id']}': (p['dias'] as num?)?.toInt() ?? 0,
    };

    return rows
        .map(
          (r) => ExoticStay(
            id: '${r['id']}',
            specimenId: '${r['patient_id']}',
            ingreso: DateTime.parse('${r['admitted_at'] ?? ''}'),
            recinto: '${r['cage'] ?? ''}',
            diasAislamiento: diasPorEstancia['${r['id']}'],
          ),
        )
        .toList();
  }

  Future<List<ExoticIdentifier>> _marcajes(
    String clinicId,
    List<String> ids,
  ) async {
    final rows = await client
        .from('exotic_identifiers')
        .select('patient_id,tipo,codigo')
        .eq('clinic_id', clinicId)
        .eq('activo', true)
        .inFilter('patient_id', ids);
    return rows
        .map(
          (r) => ExoticIdentifier(
            specimenId: '${r['patient_id']}',
            tipo: '${r['tipo'] ?? ''}',
            codigo: '${r['codigo'] ?? ''}',
          ),
        )
        .toList();
  }

  Future<List<ExoticLegalStatus>> _legal(
    String clinicId,
    List<String> ids,
  ) async {
    final rows = await client
        .from('exotic_legal_status')
        .select('patient_id,regimen,numero_registro,vigencia_hasta,documentada')
        .eq('clinic_id', clinicId)
        .inFilter('patient_id', ids);
    return rows
        .map(
          (r) => ExoticLegalStatus(
            specimenId: '${r['patient_id']}',
            regimen: '${r['regimen'] ?? ''}',
            numeroRegistro: '${r['numero_registro'] ?? ''}',
            vigenciaHasta: DateTime.tryParse('${r['vigencia_hasta'] ?? ''}'),
            documentada: r['documentada'] == true,
          ),
        )
        .toList();
  }

  /// Las tomas recientes. Interesa la racha de rechazos del final, no el
  /// histórico completo de alimentación del ejemplar.
  Future<List<ExoticFeeding>> _tomas(String clinicId, List<String> ids) async {
    final rows = await client
        .from('exotic_feedings')
        .select('patient_id,ofrecido_en,alimento,aceptado')
        .eq('clinic_id', clinicId)
        .inFilter('patient_id', ids)
        .order('ofrecido_en', ascending: false)
        .limit(400);
    return rows
        .map(
          (r) => ExoticFeeding(
            specimenId: '${r['patient_id']}',
            ofrecidoEn: DateTime.parse('${r['ofrecido_en'] ?? ''}'),
            alimento: '${r['alimento'] ?? ''}',
            aceptado: r['aceptado'] == true,
          ),
        )
        .toList();
  }

  Future<List<ExoticPhysioEvent>> _fisiologicos(
    String clinicId,
    List<String> ids,
  ) async {
    final rows = await client
        .from('exotic_events')
        .select('patient_id,tipo,ocurrio_en,detalle')
        .eq('clinic_id', clinicId)
        .inFilter('patient_id', ids)
        .order('ocurrio_en', ascending: false)
        .limit(100);
    return rows
        .map(
          (r) => ExoticPhysioEvent(
            specimenId: '${r['patient_id']}',
            tipo: '${r['tipo'] ?? ''}',
            ocurrioEn: DateTime.parse('${r['ocurrio_en'] ?? ''}'),
            detalle: '${r['detalle'] ?? ''}',
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

  /// PostgREST devuelve los `numeric` como texto para no perder precisión.
  double? _num(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse('$v');
  }
}

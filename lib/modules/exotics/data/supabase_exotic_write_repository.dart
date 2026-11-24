import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/exotic_write_repository.dart';

/// Escritura del módulo de exóticos sobre Supabase.
///
/// No hay un solo `insert` ni `update` directo: en la base `authenticated`
/// solo tiene `SELECT`, así que todo pasa por los ocho RPC `SECURITY DEFINER`,
/// que son los que comprueban el rol, validan la entrada y dejan rastro en
/// `audit_log`.
///
/// Cada método traduce el error de Postgres antes de dejarlo salir, para que
/// los formularios no tengan que conocer los códigos crudos.
class SupabaseExoticWriteRepository implements ExoticWriteRepository {
  const SupabaseExoticWriteRepository(this.client);
  final SupabaseClient client;

  /// Llama al RPC y convierte cualquier fallo en [ExoticWriteException].
  Future<String> _llamar(String funcion, Map<String, dynamic> params) async {
    try {
      final resultado = await client.rpc(funcion, params: params);
      return '$resultado';
    } catch (e) {
      throw traducirErrorExotico(e);
    }
  }

  /// Los RPC reciben los rangos como objeto JSON. Las claves ausentes o nulas
  /// se omiten: en la base un rango nulo significa «este recinto no declara
  /// este parámetro», y el panel no juzga lo que no se declara. Mandar `null`
  /// explícito y no mandar la clave acaban igual, pero omitirla deja el
  /// registro de auditoría más limpio.
  Map<String, dynamic> _soloConValor(Map<String, double?> origen) => {
    for (final e in origen.entries)
      if (e.value != null) e.key: e.value,
  };

  /// Las fechas viajan en ISO 8601. Se manda UTC para que dos equipos en husos
  /// distintos no discrepen sobre cuándo se midió algo.
  String? _instante(DateTime? valor) => valor?.toUtc().toIso8601String();

  /// Las fechas de calendario (puesta, vigencia) no llevan hora: convertirlas
  /// a UTC podría correrlas un día según la zona horaria.
  String? _dia(DateTime? valor) =>
      valor?.toIso8601String().substring(0, 10);

  @override
  Future<String> guardarRecinto({
    required String clinicId,
    String? id,
    required String nombre,
    required String tipo,
    String? especie,
    required Map<String, double?> rangos,
    String? notas,
    required String operation,
  }) => _llamar('exotic_enclosure_save', {
    'p_clinic': clinicId,
    'p_id': id,
    'p_nombre': nombre,
    'p_tipo': tipo,
    'p_especie': especie,
    'p_rangos': _soloConValor(rangos),
    'p_notas': notas,
    'p_operation': operation,
  });

  @override
  Future<String> registrarLectura({
    required String clinicId,
    required String enclosureId,
    DateTime? medidoEn,
    required Map<String, double?> valores,
    String? nota,
    required String operation,
  }) => _llamar('exotic_reading_log', {
    'p_clinic': clinicId,
    'p_enclosure': enclosureId,
    'p_medido_en': _instante(medidoEn),
    'p_valores': _soloConValor(valores),
    'p_nota': nota,
    'p_operation': operation,
  });

  @override
  Future<String> registrarToma({
    required String clinicId,
    required String patientId,
    DateTime? ofrecidoEn,
    required String alimento,
    required bool aceptado,
    double? cantidadG,
    String? nota,
    required String operation,
  }) => _llamar('exotic_feeding_log', {
    'p_clinic': clinicId,
    'p_patient': patientId,
    'p_ofrecido_en': _instante(ofrecidoEn),
    'p_alimento': alimento,
    'p_aceptado': aceptado,
    'p_cantidad': cantidadG,
    'p_nota': nota,
    'p_operation': operation,
  });

  @override
  Future<String> registrarEvento({
    required String clinicId,
    required String patientId,
    required String tipo,
    DateTime? ocurrioEn,
    String? detalle,
    required String operation,
  }) => _llamar('exotic_event_log', {
    'p_clinic': clinicId,
    'p_patient': patientId,
    'p_tipo': tipo,
    'p_ocurrio_en': _instante(ocurrioEn),
    'p_detalle': detalle,
    'p_operation': operation,
  });

  @override
  Future<String> guardarMarcaje({
    required String clinicId,
    required String patientId,
    required String tipo,
    required String codigo,
    DateTime? colocadoEl,
    String? ubicacion,
    required String operation,
  }) => _llamar('exotic_identifier_save', {
    'p_clinic': clinicId,
    'p_patient': patientId,
    'p_tipo': tipo,
    'p_codigo': codigo,
    'p_colocado_el': _dia(colocadoEl),
    'p_ubicacion': ubicacion,
    'p_operation': operation,
  });

  @override
  Future<String> guardarEstatusLegal({
    required String clinicId,
    String? id,
    required String patientId,
    required String regimen,
    String? apendice,
    String? numero,
    DateTime? desde,
    DateTime? hasta,
    String? procedencia,
    required bool documentada,
    String? notas,
    required String operation,
  }) => _llamar('exotic_legal_save', {
    'p_clinic': clinicId,
    'p_id': id,
    'p_patient': patientId,
    'p_regimen': regimen,
    'p_apendice': apendice,
    'p_numero': numero,
    'p_desde': _dia(desde),
    'p_hasta': _dia(hasta),
    'p_procedencia': procedencia,
    'p_documentada': documentada,
    'p_notas': notas,
    'p_operation': operation,
  });

  @override
  Future<String> guardarNidada({
    required String clinicId,
    String? id,
    String? enclosureId,
    String? patientId,
    required String especie,
    required DateTime puesta,
    required int huevos,
    int? fertiles,
    double? temp,
    double? humedad,
    int? dias,
    required String estado,
    String? notas,
    required String operation,
  }) => _llamar('exotic_clutch_save', {
    'p_clinic': clinicId,
    'p_id': id,
    'p_enclosure': enclosureId,
    'p_patient': patientId,
    'p_especie': especie,
    'p_puesta': _dia(puesta),
    'p_huevos': huevos,
    'p_fertiles': fertiles,
    'p_temp': temp,
    'p_humedad': humedad,
    'p_dias': dias,
    'p_estado': estado,
    'p_notas': notas,
    'p_operation': operation,
  });

  @override
  Future<String> fijarCuarentena({
    required String clinicId,
    required String stayId,
    required int dias,
    String? motivo,
    required String operation,
  }) => _llamar('exotic_quarantine_set', {
    'p_clinic': clinicId,
    'p_stay': stayId,
    'p_dias': dias,
    'p_motivo': motivo,
    'p_operation': operation,
  });
}

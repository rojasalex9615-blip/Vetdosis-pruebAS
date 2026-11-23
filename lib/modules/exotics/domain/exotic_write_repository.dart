/// Lo que el módulo de exóticos puede **escribir**.
///
/// Se separa de [ExoticDashboardRepository] a propósito: el panel solo lee, y
/// mezclar ambas cosas obligaría a que cualquier pantalla de consulta cargara
/// con la capacidad de escribir. Quien solo mira, solo lee.
///
/// Las ocho operaciones corresponden a los ocho RPC `SECURITY DEFINER` de las
/// migraciones `2026112310*`. En la base `authenticated` solo tiene `SELECT`,
/// así que este es el único camino para guardar.
library;

/// Error de escritura ya traducido a algo que una persona entienda.
///
/// Los RPC lanzan códigos secos (`codigo_duplicado`, `invalid_nombre`…). Que
/// la traducción viva aquí, y no en cada formulario, evita que el mismo código
/// se explique de tres maneras distintas en tres pantallas.
class ExoticWriteException implements Exception {
  const ExoticWriteException(this.codigo, this.mensaje);

  /// El código tal cual lo lanzó Postgres. Útil para pruebas y registro.
  final String codigo;

  /// La frase que se le enseña a quien está capturando.
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Traduce el error crudo de Postgres a una frase en español.
///
/// Si el código no se reconoce se devuelve un aviso genérico en lugar de
/// enseñar el volcado de Postgres: a quien captura no le sirve, y a veces
/// incluye nombres de tablas que no tiene por qué ver.
ExoticWriteException traducirErrorExotico(Object error) {
  final crudo = error.toString();

  // El mensaje de PostgrestException trae el codigo dentro de una frase, asi
  // que se busca por contenido y no por igualdad.
  String? hallado;
  for (final c in _mensajes.keys) {
    if (crudo.contains(c)) {
      // Se queda con el mas largo: 'invalid_dias' no debe ganarle a
      // 'invalid_diametro' si algun dia existiera.
      if (hallado == null || c.length > hallado.length) hallado = c;
    }
  }
  if (hallado != null) {
    return ExoticWriteException(hallado, _mensajes[hallado]!);
  }
  return ExoticWriteException(
    'desconocido',
    'No se pudo guardar. Revisa la conexión e inténtalo de nuevo.',
  );
}

const _mensajes = <String, String>{
  'authentication_required': 'Tu sesión expiró. Vuelve a entrar.',
  'exotic_write_required':
      'No tienes permiso para registrar en exóticos. Lo pueden hacer '
      'administrador, MVZ y auxiliar.',
  'exotic_legal_write_required':
      'El estatus legal solo lo puede firmar un administrador o un MVZ.',
  'patient_wrong_clinic': 'Ese ejemplar no pertenece a esta clínica.',
  'enclosure_not_found': 'Ese recinto ya no existe. Actualiza y vuelve a '
      'elegirlo.',
  'stay_not_found': 'Esa hospitalización ya no está abierta.',
  'clutch_not_found': 'Esa nidada ya no existe.',
  'legal_status_not_found': 'Ese registro legal ya no existe.',
  'codigo_duplicado':
      'Ese código ya está activo en otro ejemplar de la clínica. Revisa '
      'si es el mismo animal o si hay un error de captura.',
  'operation_payload_changed':
      'Los datos cambiaron a mitad del guardado. Revisa y vuelve a intentarlo.',
  'invalid_operation': 'Error interno al preparar el guardado. Inténtalo otra '
      'vez.',
  'invalid_nombre': 'El nombre no puede quedar vacío y admite 80 caracteres.',
  'invalid_tipo': 'Elige un tipo válido.',
  'invalid_rangos': 'Los rangos no se pudieron leer.',
  'invalid_valores': 'Las lecturas no se pudieron leer.',
  'invalid_medido_en': 'La fecha de la lectura no puede estar en el futuro.',
  'invalid_ofrecido_en': 'La fecha de la toma no puede estar en el futuro.',
  'invalid_ocurrio_en': 'La fecha del evento no puede estar en el futuro.',
  'invalid_colocado_el': 'La fecha de colocación no puede estar en el futuro.',
  'invalid_alimento': 'Escribe qué se le ofreció.',
  'invalid_aceptado': 'Indica si lo aceptó o lo rechazó.',
  'invalid_cantidad': 'La cantidad no parece válida.',
  'invalid_codigo': 'El código no puede quedar vacío.',
  'invalid_regimen': 'Elige un régimen válido.',
  'invalid_vigencia': 'La fecha de inicio no puede ser posterior a la de fin.',
  'numero_too_long': 'El número de registro es demasiado largo.',
  'detalle_too_long': 'El detalle es demasiado largo.',
  'invalid_especie': 'Escribe la especie de la nidada.',
  'invalid_puesta': 'La fecha de puesta no puede estar en el futuro.',
  'invalid_huevos': 'El número de huevos debe ser al menos 1.',
  'invalid_fertiles': 'Los fértiles no pueden superar al total de huevos.',
  'invalid_dias': 'Los días deben estar entre 1 y 365.',
  'invalid_estado': 'Elige un estado válido.',
};

/// Las ocho escrituras del módulo.
///
/// Todas reciben `operation`: el recibo de idempotencia del proyecto. Si la
/// misma operación se repite con el mismo contenido, el servidor devuelve el
/// id que ya creó en lugar de duplicar el registro. Por eso el formulario debe
/// conservar el mismo `operation` mientras reintenta, y generar uno nuevo solo
/// cuando empieza una captura distinta.
abstract class ExoticWriteRepository {
  /// Alta o edición de un recinto. `id` nulo da de alta.
  Future<String> guardarRecinto({
    required String clinicId,
    String? id,
    required String nombre,
    required String tipo,
    String? especie,
    required Map<String, double?> rangos,
    String? notas,
    required String operation,
  });

  /// Una lectura ambiental de un recinto.
  Future<String> registrarLectura({
    required String clinicId,
    required String enclosureId,
    DateTime? medidoEn,
    required Map<String, double?> valores,
    String? nota,
    required String operation,
  });

  /// Una toma de alimento, aceptada o rechazada.
  Future<String> registrarToma({
    required String clinicId,
    required String patientId,
    DateTime? ofrecidoEn,
    required String alimento,
    required bool aceptado,
    double? cantidadG,
    String? nota,
    required String operation,
  });

  /// Un evento fisiológico: ecdisis, postura, conducta.
  Future<String> registrarEvento({
    required String clinicId,
    required String patientId,
    required String tipo,
    DateTime? ocurrioEn,
    String? detalle,
    required String operation,
  });

  /// Un marcaje: microchip, anillo, muesca, tatuaje o foto.
  Future<String> guardarMarcaje({
    required String clinicId,
    required String patientId,
    required String tipo,
    required String codigo,
    DateTime? colocadoEl,
    String? ubicacion,
    required String operation,
  });

  /// El estatus legal del ejemplar. Reservado a administrador y MVZ.
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
  });

  /// Una nidada en incubación.
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
  });

  /// Los días previstos de aislamiento de una hospitalización.
  Future<String> fijarCuarentena({
    required String clinicId,
    required String stayId,
    required int dias,
    String? motivo,
    required String operation,
  });
}

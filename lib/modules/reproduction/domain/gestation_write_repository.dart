/// Lo que se puede escribir de una gestación.
library;

/// Error de escritura ya traducido.
class GestationWriteException implements Exception {
  const GestationWriteException(this.codigo, this.mensaje);
  final String codigo;
  final String mensaje;
  @override
  String toString() => mensaje;
}

/// Traduce el error crudo de Postgres a una frase en español.
GestationWriteException traducirErrorGestacion(Object error) {
  if (error is GestationWriteException) return error;
  final crudo = error.toString();
  String? hallado;
  for (final c in _mensajes.keys) {
    if (crudo.contains(c)) {
      if (hallado == null || c.length > hallado.length) hallado = c;
    }
  }
  if (hallado != null) {
    return GestationWriteException(hallado, _mensajes[hallado]!);
  }
  return const GestationWriteException(
    'desconocido',
    'No se pudo guardar. Revisa la conexión e inténtalo de nuevo.',
  );
}

const _mensajes = <String, String>{
  'authentication_required': 'Tu sesión expiró. Vuelve a entrar.',
  'reproduccion_write_required':
      'No tienes permiso para registrar reproducción. Lo pueden hacer '
      'administrador, MVZ y auxiliar.',
  'patient_not_found':
      'Esa hembra ya no está en el padrón. Actualiza y vuelve a elegirla.',
  'lote_not_found': 'Ese lote ya no existe. Actualiza y vuelve a elegirlo.',
  'gestacion_not_found': 'Esta gestación ya no existe.',
  'invalid_especie': 'Falta la especie.',
  'invalid_servicio':
      'La fecha del servicio no puede quedar vacía ni estar en el futuro.',
  'invalid_metodo': 'Elige un método de servicio válido.',
  'semental_too_long': 'El semental admite 80 caracteres.',
  'invalid_dias': 'Los días de gestación deben ir entre 1 y 400.',
  'invalid_diagnostico': 'Elige un resultado de diagnóstico válido.',
  'diagnostico_antes_del_servicio':
      'El diagnóstico no puede ser anterior al servicio.',
  'invalid_diagnostico_fecha': 'El diagnóstico no puede estar en el futuro.',
  'invalid_estado': 'Elige un cierre válido.',
  'parto_requerido': 'Para cerrar como parida hace falta la fecha del parto.',
  'crias_requeridas': 'Para cerrar como parida hace falta el número de crías.',
  'parto_antes_del_servicio': 'El parto no puede ser anterior al servicio.',
  'invalid_parto': 'La fecha del parto no puede estar en el futuro.',
  'invalid_crias': 'El número de crías no parece válido.',
  'notas_too_long': 'Las notas admiten 2000 caracteres.',
  'operation_payload_changed':
      'Los datos cambiaron a mitad del guardado. Revisa y vuelve a intentarlo.',
  'invalid_operation':
      'Error interno al preparar el guardado. Inténtalo otra vez.',
};

/// Una hembra elegible, con lo justo para poder nombrarla en un desplegable.
class BreedingFemale {
  const BreedingFemale({
    required this.id,
    required this.nombre,
    required this.especie,
  });
  final String id;
  final String nombre;
  final String especie;
}

/// Las dos escrituras de gestación.
abstract class GestationWriteRepository {
  /// Alta o edición. `id` nulo significa alta.
  ///
  /// `partoEstimado` no se manda: lo deriva el servidor desde `servicio` y
  /// `dias`, para que no dependa del reloj del teléfono.
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
  });

  /// Cerrar la gestación: parto, aborto, vacía o cancelada.
  Future<String> cerrarGestacion({
    required String clinicId,
    required String id,
    required String estado,
    DateTime? parto,
    int? vivas,
    int? muertas,
    String? notas,
    required String operation,
  });

  /// Las hembras del padrón que pueden entrar en una gestación.
  Future<List<BreedingFemale>> hembras(String clinicId);
}

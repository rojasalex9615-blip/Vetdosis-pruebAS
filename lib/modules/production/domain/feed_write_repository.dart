/// Lo que se puede escribir del inventario de alimento.
library;

/// Error de escritura ya traducido.
class FeedWriteException implements Exception {
  const FeedWriteException(this.codigo, this.mensaje);
  final String codigo;
  final String mensaje;
  @override
  String toString() => mensaje;
}

/// Traduce el error crudo de Postgres a una frase en español.
///
/// Gana la coincidencia más larga: `invalid_kg_por_unidad` contiene
/// `invalid_kg`, y el mensaje bueno es el específico.
FeedWriteException traducirErrorAlimento(Object error) {
  if (error is FeedWriteException) return error;
  final crudo = error.toString();
  String? hallado;
  for (final c in _mensajes.keys) {
    if (crudo.contains(c)) {
      if (hallado == null || c.length > hallado.length) hallado = c;
    }
  }
  if (hallado != null) {
    return FeedWriteException(hallado, _mensajes[hallado]!);
  }
  return const FeedWriteException(
    'desconocido',
    'No se pudo guardar. Revisa la conexión e inténtalo de nuevo.',
  );
}

const _mensajes = <String, String>{
  'authentication_required': 'Tu sesión expiró. Vuelve a entrar.',
  'admin_or_mvz_required':
      'Solo administrador y MVZ pueden dar de alta alimentos y silos.',
  'produccion_write_required':
      'No tienes permiso para mover alimento. Lo pueden hacer administrador, '
      'MVZ y auxiliar.',
  'invalid_data': 'Los datos no tienen el formato que espera el servidor.',
  'invalid_fields': 'Se mandó un campo que el servidor no reconoce.',
  'nombre_required': 'Hace falta el nombre, y admite hasta 120 caracteres.',
  'invalid_tipo': 'Elige un tipo válido.',
  'invalid_unidad': 'Elige una unidad de compra válida.',
  'invalid_kg_por_unidad':
      'Los kilos por unidad deben ser un número mayor que cero.',
  'invalid_materia_seca': 'La materia seca va entre 0 y 100 %.',
  'invalid_proteina': 'La proteína va entre 0 y 100 %.',
  'invalid_capacidad': 'La capacidad debe ser un número mayor que cero.',
  'notas_too_long': 'Las notas admiten 2000 caracteres.',
  'alimento_duplicado': 'Ya tienes un alimento con ese nombre.',
  'silo_duplicado': 'Ya tienes un silo con ese nombre.',
  'alimento_not_found':
      'Ese alimento ya no existe. Actualiza y vuelve a elegirlo.',
  'silo_not_found': 'Ese silo ya no existe. Actualiza y vuelve a elegirlo.',
  'lote_not_found': 'Ese lote ya no existe. Actualiza y vuelve a elegirlo.',
  'lote_closed':
      'Ese lote está cerrado: no se le puede cargar más alimento. '
      'Si hace falta, vuelve a abrirlo desde el lote.',
  'lote_required': 'Para registrar consumo hay que decir qué lote se lo comió.',
  'costo_required': 'Una compra necesita su precio por kilo.',
  'invalid_costo': 'El precio por kilo va entre 0 y 1 000 000.',
  'invalid_kg': 'La cantidad debe ser un número distinto de cero.',
  'invalid_fecha': 'La fecha no puede quedar vacía ni estar en el futuro.',
  'proveedor_too_long': 'El proveedor admite 120 caracteres.',
  'referencia_too_long': 'La referencia admite 60 caracteres.',
  'nota_too_long': 'La nota admite 2000 caracteres.',
  'version_required': 'Falta la versión del registro que estás editando.',
  'version_conflict_or_not_found':
      'Alguien más lo cambió mientras lo editabas. Vuelve a abrirlo para ver '
      'cómo quedó.',
  'operation_payload_changed':
      'Este envío ya se había guardado con otros datos. Vuelve a abrir el '
      'formulario.',
};

/// Las tres escrituras del inventario de alimento.
abstract class FeedWriteRepository {
  /// Alta o edición de un alimento del catálogo. Administrador y MVZ.
  ///
  /// `data` viaja tal cual al RPC, que solo admite las claves que conoce:
  /// id, nombre, tipo, unidad, kg_por_unidad, materia_seca_pct,
  /// proteina_pct, activo, notas y version.
  Future<String> guardarAlimento({
    required String clinicId,
    required Map<String, dynamic> data,
    required String operation,
  });

  /// Alta o edición de un silo, bodega o tolva. Administrador y MVZ.
  Future<String> guardarSilo({
    required String clinicId,
    required Map<String, dynamic> data,
    required String operation,
  });

  /// Una línea del libro: compra, consumo, merma o ajuste.
  ///
  /// `kg` va siempre en kilogramos y en positivo salvo en el ajuste: el signo
  /// lo pone el servidor según el tipo, para que nadie reste por escribir mal
  /// un menos. El costo solo se manda en la compra; en las salidas lo calcula
  /// el servidor al promedio ponderado del momento.
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
  });
}

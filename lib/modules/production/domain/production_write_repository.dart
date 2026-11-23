/// Lo que el Dashboard Pecuario puede **escribir**.
///
/// Se separa de [ProductionFarmRepository] igual que en exóticos: el panel
/// solo lee, y mezclar ambas cosas obligaría a que cualquier pantalla de
/// consulta cargara con la capacidad de escribir.
///
/// Los tres RPC ya existían en la base desde antes; lo que faltaba era una
/// pantalla que los llamara. Aquí está el camino.
library;

/// Error de escritura ya traducido a algo que una persona entienda.
class ProductionWriteException implements Exception {
  const ProductionWriteException(this.codigo, this.mensaje);

  /// El código tal cual lo lanzó Postgres. Útil para pruebas y registro.
  final String codigo;

  /// La frase que se le enseña a quien está capturando.
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Traduce el error crudo de Postgres a una frase en español.
ProductionWriteException traducirErrorProduccion(Object error) {
  final crudo = error.toString();
  String? hallado;
  for (final c in _mensajes.keys) {
    if (crudo.contains(c)) {
      if (hallado == null || c.length > hallado.length) hallado = c;
    }
  }
  if (hallado != null) {
    return ProductionWriteException(hallado, _mensajes[hallado]!);
  }
  return ProductionWriteException(
    'desconocido',
    'No se pudo guardar. Revisa la conexión e inténtalo de nuevo.',
  );
}

const _mensajes = <String, String>{
  'authentication_required': 'Tu sesión expiró. Vuelve a entrar.',
  'admin_or_mvz_required':
      'Dar de alta o editar un lote solo lo puede hacer un administrador o '
      'un MVZ.',
  'produccion_write_required':
      'No tienes permiso para registrar en producción. Lo pueden hacer '
      'administrador, MVZ y auxiliar.',
  'lote_not_found': 'Ese lote ya no existe. Actualiza y vuelve a elegirlo.',
  'lote_fields_required':
      'Faltan datos del lote: código, nombre, especie, propósito y cabezas '
      'son obligatorios.',
  'invalid_fields': 'El lote trae un campo que el servidor no reconoce.',
  'invalid_data': 'Los datos del lote no se pudieron leer.',
  'invalid_atributos': 'Los atributos del lote no se pudieron leer.',
  'invalid_fecha': 'La fecha no puede quedar vacía ni estar en el futuro.',
  'invalid_tipo': 'Elige un tipo de evento válido.',
  'subtipo_required':
      'Un evento sanitario necesita decir de qué se trata (vacuna, '
      'desparasitación…).',
  'subtipo_too_long': 'El subtipo admite 60 caracteres.',
  'invalid_animales': 'El número de animales no parece válido.',
  'invalid_detalle': 'El detalle del evento no se pudo leer.',
  'metricas_required': 'Captura al menos una métrica.',
  // La mas importante de explicar: el servidor rechaza metricas que no estan
  // en el catalogo de la especie o que caen fuera del rango definido.
  'metricas_invalidas':
      'Alguna métrica quedó fuera del rango que el catálogo define para esta '
      'especie. Revisa los valores marcados.',
  'notas_too_long': 'Las notas admiten 2000 caracteres.',
  'operation_payload_changed':
      'Los datos cambiaron a mitad del guardado. Revisa y vuelve a intentarlo.',
  'invalid_operation':
      'Error interno al preparar el guardado. Inténtalo otra vez.',
};

/// Un propósito válido para una especie, tal como lo lista
/// `produccion_especies_propositos`.
class SpeciesPurpose {
  const SpeciesPurpose(this.especie, this.proposito);
  final String especie;
  final String proposito;
}

/// Las tres escrituras del Dashboard Pecuario.
abstract class ProductionWriteRepository {
  /// Alta o edición de un lote. Reservado a administrador y MVZ.
  ///
  /// `data` viaja tal cual al RPC, que solo admite las claves que conoce:
  /// id, codigo, nombre, especie, proposito, sistema, fecha_inicio,
  /// fecha_fin, cabezas, identificador_hato, estado, atributos y version.
  Future<String> guardarLote({
    required String clinicId,
    required Map<String, dynamic> data,
    required String operation,
  });

  /// Un registro productivo. Las métricas deben existir en el catálogo de la
  /// especie del lote y caer dentro de su rango, o el servidor las rechaza.
  Future<String> guardarRegistro({
    required String clinicId,
    required String loteId,
    required DateTime fecha,
    required Map<String, double> metricas,
    String? notas,
    required String operation,
  });

  /// Un evento de manejo: sanitario, mortalidad, pesaje, traslado, sacrificio.
  Future<String> guardarEvento({
    required String clinicId,
    required String loteId,
    required DateTime fecha,
    required String tipo,
    String? subtipo,
    int? animales,
    Map<String, dynamic>? detalle,
    required String operation,
  });

  /// Los pares especie/propósito que el catálogo admite.
  ///
  /// Hace falta para el alta de lote: elegir «bovino» y «engorda» sería una
  /// combinación que el catálogo no reconoce, y más vale no ofrecerla.
  Future<List<SpeciesPurpose>> propositosPorEspecie();
}

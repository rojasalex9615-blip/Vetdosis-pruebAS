/// Los datos reales de la granja que alimentan el Dashboard Pecuario.
///
/// Hasta ahora el panel se pintaba con un catalogo fijo de ejemplo: una granja
/// inventada de 480 vacas con silos al 71 %. Eso enseñaba cifras que no eran
/// de nadie. Lo que aqui se modela es lo que de verdad existe en Supabase:
///
///   * `lotes_produccion`     -> los lotes que da de alta el usuario
///   * `produccion_registros` -> lo que van dejando las calculadoras
///   * `produccion_eventos`   -> vacunas, resguardos y partos
///
/// Cuando esas tablas estan vacias el panel debe decirlo, no rellenar el hueco.
library;

/// Un lote de la granja, tal como vive en `lotes_produccion`.
class FarmBatch {
  const FarmBatch({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.especie,
    required this.proposito,
    required this.estado,
    required this.cabezas,
    required this.fechaInicio,
    this.sistema,
    this.identificadorHato,
  });

  final String id;
  final String codigo;
  final String nombre;
  final String especie;
  final String proposito;
  final String estado;
  final int cabezas;
  final DateTime fechaInicio;
  final String? sistema;
  final String? identificadorHato;

  /// Dias que lleva el lote desde que arranco, para la columna de etapa.
  int diasEnEtapa(DateTime ahora) => ahora.difference(fechaInicio).inDays;

  static FarmBatch read(Map<String, dynamic> row) => FarmBatch(
    id: '${row['id']}',
    codigo: '${row['codigo'] ?? ''}',
    nombre: '${row['nombre'] ?? ''}',
    especie: '${row['especie'] ?? ''}',
    proposito: '${row['proposito'] ?? ''}',
    estado: '${row['estado'] ?? ''}',
    cabezas: _entero(row['cabezas']) ?? 0,
    fechaInicio: _fechaObligatoria(row['fecha_inicio']),
    sistema: row['sistema'] as String?,
    identificadorHato: row['identificador_hato'] as String?,
  );
}

/// Un evento de `produccion_eventos`: vacuna, resguardo, parto, baja.
class FarmEvent {
  const FarmEvent({
    required this.id,
    required this.loteId,
    required this.fecha,
    required this.tipo,
    required this.subtipo,
    required this.detalle,
    this.animalesAfectados,
  });

  final String id;
  final String loteId;
  final DateTime fecha;
  final String tipo;
  final String subtipo;
  final Map<String, dynamic> detalle;
  final int? animalesAfectados;

  /// Dias que faltan para la fecha del evento. Negativo si ya paso.
  int diasRestantes(DateTime ahora) {
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final dia = DateTime(fecha.year, fecha.month, fecha.day);
    return dia.difference(hoy).inDays;
  }

  static FarmEvent read(Map<String, dynamic> row) => FarmEvent(
    id: '${row['id']}',
    loteId: '${row['lote_id']}',
    fecha: _fechaObligatoria(row['fecha']),
    tipo: '${row['tipo'] ?? ''}',
    subtipo: '${row['subtipo'] ?? ''}',
    detalle: _mapa(row['detalle']),
    animalesAfectados: _entero(row['animales_afectados']),
  );
}

/// Un registro productivo de `produccion_registros`.
///
/// `metricas` es el jsonb que dejan las calculadoras: cada clave es una de las
/// que describe `produccion_metricas` para esa especie.
class FarmRecord {
  const FarmRecord({
    required this.id,
    required this.loteId,
    required this.fecha,
    required this.metricas,
  });

  final String id;
  final String loteId;
  final DateTime fecha;
  final Map<String, dynamic> metricas;

  /// El valor numerico de una metrica, si viene y si es un numero.
  double? valor(String clave) {
    final crudo = metricas[clave];
    if (crudo is num) return crudo.toDouble();
    if (crudo is String) return double.tryParse(crudo);
    return null;
  }

  static FarmRecord read(Map<String, dynamic> row) => FarmRecord(
    id: '${row['id']}',
    loteId: '${row['lote_id']}',
    fecha: _fechaObligatoria(row['fecha']),
    metricas: _mapa(row['metricas']),
  );
}

/// Definicion de una metrica en `produccion_metricas`.
///
/// Esto si es catalogo de referencia y no dato de nadie: da la etiqueta, la
/// unidad y el rango normal con el que se compara lo que miden las
/// calculadoras.
class FarmMetricDef {
  const FarmMetricDef({
    required this.especie,
    required this.clave,
    required this.etiqueta,
    required this.unidad,
    this.minimo,
    this.maximo,
  });

  final String especie;
  final String clave;
  final String etiqueta;
  final String unidad;
  final double? minimo;
  final double? maximo;

  /// El rango escrito como lo espera la tabla de constantes.
  String get rango {
    if (minimo == null && maximo == null) return 'Sin rango definido';
    if (minimo == null) return '≤ ${_numero(maximo!)}';
    if (maximo == null) return '≥ ${_numero(minimo!)}';
    return '${_numero(minimo!)} - ${_numero(maximo!)}';
  }

  static FarmMetricDef read(Map<String, dynamic> row) => FarmMetricDef(
    especie: '${row['especie'] ?? ''}',
    clave: '${row['clave'] ?? ''}',
    etiqueta: '${row['etiqueta'] ?? ''}',
    unidad: '${row['unidad'] ?? ''}',
    minimo: _decimal(row['minimo']),
    maximo: _decimal(row['maximo']),
  );
}

/// Todo lo que el panel necesita de una especie, en una sola lectura.
class FarmSnapshot {
  const FarmSnapshot({
    this.batches = const [],
    this.events = const [],
    this.records = const [],
    this.metricDefs = const [],
  });

  final List<FarmBatch> batches;
  final List<FarmEvent> events;
  final List<FarmRecord> records;
  final List<FarmMetricDef> metricDefs;

  /// Instantanea sin nada del usuario. El catalogo de metricas no cuenta:
  /// es referencia, existe siempre y no dice nada de esta granja.
  bool get sinDatos => batches.isEmpty && events.isEmpty && records.isEmpty;

  /// Cabezas sumadas de los lotes activos.
  int get totalCabezas => batches
      .where((b) => b.estado != 'cerrado')
      .fold(0, (suma, b) => suma + b.cabezas);

  /// Los eventos que todavia no han pasado, del mas proximo al mas lejano.
  List<FarmEvent> proximos(DateTime ahora) {
    final lista = events.where((e) => e.diasRestantes(ahora) >= 0).toList()
      ..sort((a, b) => a.fecha.compareTo(b.fecha));
    return lista;
  }

  /// Los registros de un lote, del mas viejo al mas nuevo, para la curva.
  List<FarmRecord> serieDe(String loteId) {
    final lista = records.where((r) => r.loteId == loteId).toList()
      ..sort((a, b) => a.fecha.compareTo(b.fecha));
    return lista;
  }
}

/// Las especies que nombra el panel, traducidas a los codigos de la base.
///
/// No coinciden: el selector dice «Aves» y `produccion_especies` guarda
/// `gallina` y `pavo` por separado; dice «Porcinos» y la tabla guarda `cerdo`.
/// Sin esta traduccion las consultas filtrarian por un valor que no existe y
/// el panel se veria vacio incluso con lotes dados de alta.
///
/// «Equinos» no aparece: no es una especie de produccion en el catalogo, asi
/// que para esa pestaña no hay nada que leer y el panel lo dice.
const Map<String, List<String>> codigosDeEspecie = {
  'Bovinos': ['bovino'],
  'Porcinos': ['cerdo'],
  'Aves': ['gallina', 'pavo'],
  'Ovinos / caprinos': ['ovino', 'caprino'],
  'Peces': ['tilapia', 'langostino'],
  'Abejas': ['abeja'],
  'Equinos': [],
};

/// De donde salen los datos de la granja.
///
/// Hoy solo hay implementacion sobre Supabase. El panel recibe el repositorio
/// por constructor para que las pruebas puedan darle uno falso sin red.
abstract class ProductionFarmRepository {
  /// Lee de una vez los lotes, eventos, registros y catalogo de una especie.
  ///
  /// [especies] son los codigos de `produccion_especies`, no la etiqueta que
  /// se ve en pantalla: se obtienen de [codigosDeEspecie].
  Future<FarmSnapshot> load(String clinicId, {required List<String> especies});
}

int? _entero(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double? _decimal(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

DateTime _fechaObligatoria(Object? value) {
  if (value is DateTime) return value;
  return DateTime.parse('$value');
}

Map<String, dynamic> _mapa(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.map((k, value) => MapEntry('$k', value));
  return const {};
}

/// Numero corto: sin decimales si es entero, con uno si no.
String _numero(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

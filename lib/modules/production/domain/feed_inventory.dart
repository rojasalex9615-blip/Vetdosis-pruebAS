/// Inventario de alimento: catálogo, silos, movimientos y lo que se deduce.
///
/// Todo se guarda y se calcula en kilogramos. La unidad de compra (saco, paca,
/// tonelada) solo existe para capturar cómodo y se convierte antes de guardar.
library;

/// Tipo de alimento. El código es el que valida la base.
enum FeedKind {
  concentrado('concentrado', 'Concentrado'),
  forraje('forraje', 'Forraje'),
  ensilado('ensilado', 'Ensilado'),
  mineral('mineral', 'Sales y minerales'),
  aditivo('aditivo', 'Aditivo'),
  leche('leche', 'Leche o sustituto'),
  medicado('medicado', 'Alimento medicado'),
  otro('otro', 'Otro');

  const FeedKind(this.code, this.label);
  final String code, label;

  static FeedKind desdeCodigo(String? code) {
    for (final v in FeedKind.values) {
      if (v.code == code) return v;
    }
    return FeedKind.otro;
  }
}

/// Unidad con la que se compra. Internamente todo son kilogramos.
enum FeedUnit {
  kg('kg', 'Kilogramos', 1),
  ton('ton', 'Toneladas', 1000),
  saco('saco', 'Sacos', 40),
  costal('costal', 'Costales', 50),
  paca('paca', 'Pacas', 20),
  litro('l', 'Litros', 1);

  const FeedUnit(this.code, this.label, this.kgSugeridos);
  final String code, label;

  /// Equivalencia habitual, solo como punto de partida: el peso real del saco
  /// lo escribe quien da de alta el alimento.
  final int kgSugeridos;

  static FeedUnit desdeCodigo(String? code) {
    for (final v in FeedUnit.values) {
      if (v.code == code) return v;
    }
    return FeedUnit.kg;
  }
}

/// Movimiento del libro. El signo lo pone el servidor según el tipo.
enum FeedMoveKind {
  compra('compra', 'Compra', 'Entró alimento'),
  consumo('consumo', 'Consumo', 'Se lo comió un lote'),
  merma('merma', 'Merma', 'Se echó a perder o se derramó'),
  ajuste('ajuste', 'Ajuste', 'Cuadrar con lo que hay de verdad');

  const FeedMoveKind(this.code, this.label, this.ayuda);
  final String code, label, ayuda;

  static FeedMoveKind desdeCodigo(String? code) {
    for (final v in FeedMoveKind.values) {
      if (v.code == code) return v;
    }
    return FeedMoveKind.ajuste;
  }
}

/// Dónde se guarda el alimento.
enum StoreKind {
  silo('silo', 'Silo'),
  bodega('bodega', 'Bodega'),
  tolva('tolva', 'Tolva'),
  trinchera('trinchera', 'Trinchera'),
  otro('otro', 'Otro');

  const StoreKind(this.code, this.label);
  final String code, label;

  static StoreKind desdeCodigo(String? code) {
    for (final v in StoreKind.values) {
      if (v.code == code) return v;
    }
    return StoreKind.otro;
  }
}

double? _num(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse('$v');
}

DateTime? _fecha(Object? v) {
  if (v == null) return null;
  return DateTime.tryParse('$v');
}

/// Un alimento del catálogo de la granja.
class FeedItem {
  const FeedItem({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.unidad,
    required this.kgPorUnidad,
    this.materiaSecaPct,
    this.proteinaPct,
    required this.activo,
    this.notas,
    required this.version,
  });

  final String id;
  final String nombre;
  final FeedKind tipo;
  final FeedUnit unidad;

  /// Cuántos kilos trae una unidad de compra. Un saco de 40, una paca de 22.
  final double kgPorUnidad;

  /// Materia seca. Sin ella no se puede dar una conversión en kg MS, y se dice
  /// en vez de suponer que el ensilado es 100 % seco.
  final double? materiaSecaPct;
  final double? proteinaPct;
  final bool activo;
  final String? notas;
  final int version;

  /// Kilos que corresponden a una cantidad escrita en la unidad de compra.
  double aKilos(double cantidad) => cantidad * kgPorUnidad;

  bool get seCompraEnKilos => unidad == FeedUnit.kg;

  static FeedItem read(Map<String, dynamic> row) => FeedItem(
    id: '${row['id']}',
    nombre: '${row['nombre'] ?? ''}',
    tipo: FeedKind.desdeCodigo(row['tipo'] as String?),
    unidad: FeedUnit.desdeCodigo(row['unidad'] as String?),
    kgPorUnidad: _num(row['kg_por_unidad']) ?? 1,
    materiaSecaPct: _num(row['materia_seca_pct']),
    proteinaPct: _num(row['proteina_pct']),
    activo: row['activo'] == true,
    notas: (row['notas'] as String?)?.trim().isEmpty ?? true
        ? null
        : '${row['notas']}',
    version: (row['version'] as num?)?.toInt() ?? 1,
  );
}

/// Un silo, bodega o tolva.
class FeedStore {
  const FeedStore({
    required this.id,
    required this.nombre,
    required this.tipo,
    this.capacidadKg,
    this.alimentoId,
    required this.activo,
    this.notas,
    required this.version,
  });

  final String id;
  final String nombre;
  final StoreKind tipo;
  final double? capacidadKg;

  /// El alimento que suele contener. Opcional: una bodega guarda de todo.
  final String? alimentoId;
  final bool activo;
  final String? notas;
  final int version;

  static FeedStore read(Map<String, dynamic> row) => FeedStore(
    id: '${row['id']}',
    nombre: '${row['nombre'] ?? ''}',
    tipo: StoreKind.desdeCodigo(row['tipo'] as String?),
    capacidadKg: _num(row['capacidad_kg']),
    alimentoId: row['alimento_id'] == null ? null : '${row['alimento_id']}',
    activo: row['activo'] == true,
    notas: (row['notas'] as String?)?.trim().isEmpty ?? true
        ? null
        : '${row['notas']}',
    version: (row['version'] as num?)?.toInt() ?? 1,
  );
}

/// Una línea del libro de movimientos.
class FeedMovement {
  const FeedMovement({
    required this.id,
    required this.alimentoId,
    this.siloId,
    this.loteId,
    required this.fecha,
    required this.tipo,
    required this.kg,
    required this.costoKg,
    this.proveedor,
    this.referencia,
    this.nota,
  });

  final String id;
  final String alimentoId;
  final String? siloId;
  final String? loteId;
  final DateTime fecha;
  final FeedMoveKind tipo;

  /// Con signo: la compra suma, el consumo y la merma restan.
  final double kg;

  /// Congelado al momento del movimiento, para que un cambio de precio no
  /// reescriba lo que ya costó.
  final double costoKg;
  final String? proveedor;
  final String? referencia;
  final String? nota;

  double get importe => kg.abs() * costoKg;

  static FeedMovement read(Map<String, dynamic> row) => FeedMovement(
    id: '${row['id']}',
    alimentoId: '${row['alimento_id']}',
    siloId: row['silo_id'] == null ? null : '${row['silo_id']}',
    loteId: row['lote_id'] == null ? null : '${row['lote_id']}',
    fecha: _fecha(row['fecha']) ?? DateTime.now(),
    tipo: FeedMoveKind.desdeCodigo(row['tipo'] as String?),
    kg: _num(row['kg']) ?? 0,
    costoKg: _num(row['costo_kg']) ?? 0,
    proveedor: (row['proveedor'] as String?)?.trim().isEmpty ?? true
        ? null
        : '${row['proveedor']}',
    referencia: (row['referencia'] as String?)?.trim().isEmpty ?? true
        ? null
        : '${row['referencia']}',
    nota: (row['nota'] as String?)?.trim().isEmpty ?? true
        ? null
        : '${row['nota']}',
  );
}

/// Lo que hay, por alimento y silo. Lo suma la base, no el teléfono.
class FeedStock {
  const FeedStock({
    required this.alimentoId,
    this.siloId,
    required this.kg,
    required this.valor,
    required this.kgSalida30d,
    this.primeraSalida30d,
    this.ultimoMovimiento,
  });

  final String alimentoId;
  final String? siloId;
  final double kg;

  /// Lo que vale lo que queda, al promedio ponderado con que se fue cargando.
  final double valor;
  final double kgSalida30d;
  final DateTime? primeraSalida30d;
  final DateTime? ultimoMovimiento;

  /// Existencia negativa: faltan entradas por capturar, no es que el silo deba
  /// alimento. Se enseña en vez de recortarla a cero.
  bool get enNumerosRojos => kg < 0;

  double? get costoPromedioKg => kg > 0 ? valor / kg : null;

  /// Consumo diario medido sobre los días que de verdad se observaron, no
  /// sobre 30 fijos: una granja que empezó antier no consume un treintavo.
  double? kgPorDia(DateTime ahora) {
    if (kgSalida30d <= 0) return null;
    final desde = primeraSalida30d;
    if (desde == null) return null;
    final dias = ahora.difference(desde).inDays + 1;
    return kgSalida30d / (dias < 1 ? 1 : dias);
  }

  /// Días que aguanta lo que queda al ritmo de los últimos 30 días.
  double? diasQueAguanta(DateTime ahora) {
    final ritmo = kgPorDia(ahora);
    if (ritmo == null || ritmo <= 0 || kg <= 0) return null;
    return kg / ritmo;
  }

  static FeedStock read(Map<String, dynamic> row) => FeedStock(
    alimentoId: '${row['alimento_id']}',
    siloId: row['silo_id'] == null ? null : '${row['silo_id']}',
    kg: _num(row['kg']) ?? 0,
    valor: _num(row['valor']) ?? 0,
    kgSalida30d: _num(row['kg_salida_30d']) ?? 0,
    primeraSalida30d: _fecha(row['primera_salida_30d']),
    ultimoMovimiento: _fecha(row['ultimo_movimiento']),
  );
}

/// Resultado de un cálculo que puede no tener respuesta.
///
/// Un número inventado es peor que un hueco, así que cuando falta un dato se
/// devuelve el motivo y la pantalla lo escribe tal cual.
class FeedRatio {
  const FeedRatio.dato(double this.valor, this.unidad, this.detalle)
    : motivo = null;
  const FeedRatio.sinDato(this.motivo)
    : valor = null,
      unidad = '',
      detalle = '';

  final double? valor;
  final String unidad;

  /// Qué se dividió entre qué, para que el número se pueda discutir.
  final String detalle;
  final String? motivo;

  bool get hayDato => valor != null;
}

/// Un lote con su alimento y su producción, que es de donde salen la
/// conversión y el costo reales.
class BatchEfficiency {
  const BatchEfficiency({
    required this.loteId,
    required this.codigo,
    required this.nombre,
    required this.especie,
    required this.proposito,
    required this.cabezas,
    required this.estado,
    required this.kgAlimento,
    this.kgMateriaSeca,
    required this.costoAlimento,
    this.primeraCarga,
    this.ultimaCarga,
    required this.lecheL,
    required this.huevos,
    required this.mielKg,
    required this.diasConRegistro,
    this.pesoInicialKg,
    this.pesoFinalKg,
  });

  final String loteId;
  final String codigo;
  final String nombre;
  final String especie;
  final String proposito;
  final int cabezas;
  final String estado;
  final double kgAlimento;

  /// Nulo a propósito si algún alimento del lote no tiene materia seca.
  final double? kgMateriaSeca;
  final double costoAlimento;
  final DateTime? primeraCarga;
  final DateTime? ultimaCarga;
  final double lecheL;
  final double huevos;
  final double mielKg;
  final int diasConRegistro;
  final double? pesoInicialKg;
  final double? pesoFinalKg;

  bool get tieneAlimento => kgAlimento > 0;

  /// Lo que engordó el lote entero, de la primera a la última pesada.
  double? get pesoGanadoKg {
    final a = pesoInicialKg, b = pesoFinalKg;
    if (a == null || b == null) return null;
    final d = b - a;
    return d > 0 ? d : null;
  }

  /// Lo que produjo el lote, según para qué es.
  double get produccion {
    if (especie == 'abeja') return mielKg;
    switch (proposito) {
      case 'leche':
        return lecheL;
      case 'postura':
        return huevos;
      case 'engorda':
      case 'carne':
        return pesoGanadoKg ?? 0;
      default:
        if (lecheL > 0) return lecheL;
        return pesoGanadoKg ?? 0;
    }
  }

  String get unidadProducida {
    if (especie == 'abeja') return 'kg de miel';
    switch (proposito) {
      case 'leche':
        return 'L';
      case 'postura':
        return 'huevos';
      default:
        return 'kg';
    }
  }

  /// Conversión alimenticia. En leche se da en materia seca cuando se conoce,
  /// porque es como se compara con cualquier tabla; si no, se dice que va en
  /// kilos tal cual en vez de cambiar la etiqueta sin avisar.
  FeedRatio get conversion {
    if (!tieneAlimento) {
      return const FeedRatio.sinDato('Aún no se ha cargado alimento al lote.');
    }
    final salida = produccion;
    if (salida <= 0) {
      return FeedRatio.sinDato(
        'El lote todavía no tiene producción registrada en '
        '${unidadProducida == 'L' ? 'litros' : unidadProducida}.',
      );
    }
    if (proposito == 'leche') {
      final ms = kgMateriaSeca;
      if (ms != null && ms > 0) {
        return FeedRatio.dato(
          ms / salida,
          'kg MS / L',
          '${_n(ms)} kg de materia seca entre ${_n(salida)} L',
        );
      }
      return FeedRatio.dato(
        kgAlimento / salida,
        'kg / L',
        'Sin materia seca en el catálogo: ${_n(kgAlimento)} kg tal cual '
            'entre ${_n(salida)} L',
      );
    }
    if (proposito == 'postura') {
      return FeedRatio.dato(
        kgAlimento * 1000 / salida,
        'g / huevo',
        '${_n(kgAlimento)} kg entre ${_n(salida)} huevos',
      );
    }
    return FeedRatio.dato(
      kgAlimento / salida,
      'kg / kg',
      '${_n(kgAlimento)} kg de alimento entre ${_n(salida)} kg producidos',
    );
  }

  /// Costo del alimento por unidad producida. Es alimento, no costo total:
  /// la pantalla lo dice para que nadie lo confunda con el costo de la granja.
  FeedRatio get costoPorUnidad {
    if (costoAlimento <= 0) {
      return const FeedRatio.sinDato(
        'Falta capturar el precio de las compras.',
      );
    }
    final salida = produccion;
    if (salida <= 0) {
      return const FeedRatio.sinDato('El lote todavía no tiene producción.');
    }
    return FeedRatio.dato(
      costoAlimento / salida,
      '\$ / ${unidadProducida == 'huevos' ? 'huevo' : unidadProducida}',
      '${_n(costoAlimento)} de alimento entre ${_n(salida)} '
          '$unidadProducida',
    );
  }

  static BatchEfficiency read(Map<String, dynamic> row) => BatchEfficiency(
    loteId: '${row['lote_id']}',
    codigo: '${row['codigo'] ?? ''}',
    nombre: '${row['nombre'] ?? ''}',
    especie: '${row['especie'] ?? ''}',
    proposito: '${row['proposito'] ?? ''}',
    cabezas: (row['cabezas'] as num?)?.toInt() ?? 0,
    estado: '${row['estado'] ?? 'activo'}',
    kgAlimento: _num(row['kg_alimento']) ?? 0,
    kgMateriaSeca: _num(row['kg_materia_seca']),
    costoAlimento: _num(row['costo_alimento']) ?? 0,
    primeraCarga: _fecha(row['primera_carga']),
    ultimaCarga: _fecha(row['ultima_carga']),
    lecheL: _num(row['leche_l']) ?? 0,
    huevos: _num(row['huevos']) ?? 0,
    mielKg: _num(row['miel_kg']) ?? 0,
    diasConRegistro: (row['dias_con_registro'] as num?)?.toInt() ?? 0,
    pesoInicialKg: _num(row['peso_inicial_kg']),
    pesoFinalKg: _num(row['peso_final_kg']),
  );
}

String _n(double v) {
  if (v == v.roundToDouble() && v.abs() < 1000000) {
    return v.toStringAsFixed(0);
  }
  return v.toStringAsFixed(1);
}

/// Todo lo que la pantalla de alimento necesita de una sola carga.
class FeedSnapshot {
  const FeedSnapshot({
    required this.alimentos,
    required this.silos,
    required this.existencias,
    required this.eficiencias,
    required this.movimientos,
  });

  const FeedSnapshot.vacio()
    : alimentos = const [],
      silos = const [],
      existencias = const [],
      eficiencias = const [],
      movimientos = const [];

  final List<FeedItem> alimentos;
  final List<FeedStore> silos;
  final List<FeedStock> existencias;
  final List<BatchEfficiency> eficiencias;
  final List<FeedMovement> movimientos;

  bool get sinDatos => alimentos.isEmpty && silos.isEmpty;

  Iterable<FeedItem> get alimentosActivos => alimentos.where((a) => a.activo);
  Iterable<FeedStore> get silosActivos => silos.where((s) => s.activo);

  FeedItem? alimento(String? id) {
    if (id == null) return null;
    for (final a in alimentos) {
      if (a.id == id) return a;
    }
    return null;
  }

  FeedStore? silo(String? id) {
    if (id == null) return null;
    for (final s in silos) {
      if (s.id == id) return s;
    }
    return null;
  }

  String nombreDeAlimento(String? id) => alimento(id)?.nombre ?? 'Sin alimento';
  String nombreDeSilo(String? id) => silo(id)?.nombre ?? 'Sin silo';

  /// Kilos de un alimento sumando todos sus silos.
  double kgDeAlimento(String alimentoId) {
    var total = 0.0;
    for (final e in existencias) {
      if (e.alimentoId == alimentoId) total += e.kg;
    }
    return total;
  }

  /// Lo que hay en un silo. Un silo puede tener más de un alimento si se
  /// reutilizó, así que se suman todas sus líneas.
  double kgEnSilo(String siloId) {
    var total = 0.0;
    for (final e in existencias) {
      if (e.siloId == siloId) total += e.kg;
    }
    return total;
  }

  List<FeedStock> existenciasDeSilo(String siloId) =>
      existencias.where((e) => e.siloId == siloId).toList();

  /// Lo que vale todo el inventario.
  double get valorTotal {
    var total = 0.0;
    for (final e in existencias) {
      total += e.valor;
    }
    return total;
  }

  /// Silos que se vacían antes de [dias], de los más urgentes primero.
  List<FeedStore> silosPorAgotarse(DateTime ahora, {int dias = 14}) {
    final urgentes = <FeedStore, double>{};
    for (final s in silos) {
      if (!s.activo) continue;
      double? menor;
      for (final e in existenciasDeSilo(s.id)) {
        final d = e.diasQueAguanta(ahora);
        if (d == null) continue;
        if (menor == null || d < menor) menor = d;
      }
      if (menor != null && menor <= dias) urgentes[s] = menor;
    }
    final lista = urgentes.keys.toList()
      ..sort((a, b) => urgentes[a]!.compareTo(urgentes[b]!));
    return lista;
  }

  /// Existencias en rojo: hay consumo capturado sin la entrada que lo respalda.
  List<FeedStock> get existenciasNegativas =>
      existencias.where((e) => e.enNumerosRojos).toList();
}

/// Lectura del inventario de alimento.
abstract class FeedInventoryRepository {
  Future<FeedSnapshot> load(String clinicId);
}

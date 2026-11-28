/// Lo que el Dashboard de Fauna Exótica sabe de los ejemplares reales.
///
/// En exóticos la unidad no es el lote sino el individuo: cada ejemplar tiene
/// su peso, su recinto y su expediente. Por eso todo lo de aquí cuelga del
/// paciente, no de un grupo.
///
/// Lo que se lee sale de tablas reales. Tres venían del expediente clínico:
///
///   * `vet_patients`       -> los ejemplares
///   * `hospital_stays`     -> cuarentena y hospitalización
///   * `vet_patient_events` -> pesos (`weight`) y demás eventos
///
/// y ocho se crearon para este módulo (migraciones `2026112310*`):
///
///   * `exotic_enclosures` / `exotic_enclosure_readings` -> microclimas
///   * `exotic_identifiers`      -> microchip, anillo, muesca
///   * `exotic_legal_status`     -> CITES / SEMARNAT
///   * `exotic_feedings`         -> tomas aceptadas y rechazadas
///   * `exotic_clutches`         -> incubadoras y nidadas
///   * `exotic_events`           -> ecdisis, postura, conducta
///   * `exotic_quarantine_plans` -> días previstos de aislamiento
///
/// Nada se inventa: cuando una tabla está vacía el panel lo dice, y eso es
/// distinto de estar cargando o de no haber podido leer.
library;

import 'exotic_taxon.dart';

/// Un ejemplar, con el grupo al que pertenece.
class ExoticSpecimen {
  const ExoticSpecimen({
    required this.id,
    required this.nombre,
    required this.especie,
    required this.taxon,
    this.raza = '',
    this.sexo = '',
    this.fechaNacimiento,
  });

  final String id;
  final String nombre;
  final String especie;

  /// Grupo deducido de la especie. `null` cuando no se reconoce.
  final ExoticTaxon? taxon;

  final String raza;
  final String sexo;
  final DateTime? fechaNacimiento;

  /// Como se nombra en pantalla cuando no tiene nombre propio.
  String get titulo => nombre.trim().isEmpty ? especie : nombre;
}

/// Un peso registrado, para la curva individual.
class ExoticWeight {
  const ExoticWeight({
    required this.specimenId,
    required this.fecha,
    required this.gramos,
  });

  final String specimenId;
  final DateTime fecha;

  /// Siempre en gramos: en exóticos el kilo esconde lo que importa. Un ave de
  /// 32 g que baja a 29 ha perdido casi el 10 % y en kilos no se ve.
  final double gramos;
}

/// Un ejemplar aislado u hospitalizado.
class ExoticStay {
  const ExoticStay({
    required this.id,
    required this.specimenId,
    required this.ingreso,
    this.recinto = '',
    this.diasAislamiento,
  });

  final String id;
  final String specimenId;
  final DateTime ingreso;
  final String recinto;

  /// Duración prevista del aislamiento, si se fijó.
  final int? diasAislamiento;

  int diasDentro(DateTime ahora) => ahora.difference(ingreso).inDays;

  /// Días que faltan para terminar el aislamiento. `null` si no se fijó.
  int? diasRestantes(DateTime ahora) =>
      diasAislamiento == null ? null : diasAislamiento! - diasDentro(ahora);
}

/// Un evento fisiológico o de manejo del ejemplar.
class ExoticEvent {
  const ExoticEvent({
    required this.id,
    required this.specimenId,
    required this.tipo,
    required this.fecha,
    this.datos = const {},
  });

  final String id;
  final String specimenId;

  /// `weight`, `soap`, `preventive`… tal como los nombra `EventKind`.
  final String tipo;
  final DateTime fecha;

  /// El payload tal cual lo guardo el expediente. En un peso trae `kg`.
  final Map<String, dynamic> datos;

  /// Una linea corta para el feed de eventos.
  String get detalle {
    if (tipo == 'weight') {
      final kg = datos['kg'];
      return kg == null ? '' : '$kg kg';
    }
    final nota = datos['nota'] ?? datos['note'] ?? datos['detalle'];
    return nota == null ? '' : '$nota';
  }
}

/// Una pérdida de peso que merece aviso.
///
/// La regla clínica del módulo: una caída del 5 % enciende la precaución y una
/// del 10 % es alerta. Se mide contra el peso más alto registrado, no contra
/// el anterior, porque un descenso lento y sostenido no se ve comparando solo
/// dos pesadas seguidas.
class WeightAlert {
  const WeightAlert({
    required this.specimen,
    required this.pesoMaximo,
    required this.pesoActual,
    required this.caidaPct,
  });

  final ExoticSpecimen specimen;
  final double pesoMaximo;
  final double pesoActual;
  final double caidaPct;

  bool get esCritica => caidaPct >= 10;
}

/// Un recinto con el rango que deberia mantener.
///
/// El gradiente se guarda entero (punto caliente y punto frio) porque en un
/// ectotermo son dos exigencias distintas: con la media, un terrario sin zona
/// fria parece correcto.
class ExoticEnclosure {
  const ExoticEnclosure({
    required this.id,
    required this.nombre,
    required this.tipo,
    this.especie = '',
    this.tempCalienteMin,
    this.tempCalienteMax,
    this.tempFriaMin,
    this.tempFriaMax,
    this.humedadMin,
    this.humedadMax,
    this.uvMin,
    this.uvMax,
    this.phMin,
    this.phMax,
    this.amoniacoMax,
    this.nitritoMax,
    this.salinidadMin,
    this.salinidadMax,
  });

  final String id;
  final String nombre;

  /// terrario, aviario, acuaterrario, acuario, encierro o incubadora.
  final String tipo;
  final String especie;

  final double? tempCalienteMin, tempCalienteMax;
  final double? tempFriaMin, tempFriaMax;
  final double? humedadMin, humedadMax;
  final double? uvMin, uvMax;
  final double? phMin, phMax;
  final double? amoniacoMax, nitritoMax;

  /// Solo tiene sentido en acuarios y acuaterrarios; en un terrario viene nulo
  /// y `desviaciones()` ni lo mira.
  final double? salinidadMin, salinidadMax;
}

/// Una lectura ambiental: lo que el recinto ES.
class ExoticReading {
  const ExoticReading({
    required this.enclosureId,
    required this.medidoEn,
    this.tempCaliente,
    this.tempFria,
    this.humedad,
    this.uvIndex,
    this.ph,
    this.amoniaco,
    this.nitrito,
    this.salinidad,
  });

  final String enclosureId;
  final DateTime medidoEn;
  final double? tempCaliente, tempFria, humedad, uvIndex;
  final double? ph, amoniaco, nitrito, salinidad;
}

/// Una desviacion concreta entre lo medido y el rango objetivo.
class EnclosureDeviation {
  const EnclosureDeviation({
    required this.enclosure,
    required this.parametro,
    required this.valor,
    required this.esperado,
    required this.unidad,
  });

  final ExoticEnclosure enclosure;
  final String parametro;
  final double valor;
  final String esperado;
  final String unidad;

  String get texto => '$parametro ${_num(valor)} $unidad (objetivo $esperado)';
}

/// Marcaje de un ejemplar: microchip, anillo, muesca.
class ExoticIdentifier {
  const ExoticIdentifier({
    required this.specimenId,
    required this.tipo,
    required this.codigo,
  });

  final String specimenId;
  final String tipo;
  final String codigo;
}

/// Estatus legal del ejemplar (CITES / SEMARNAT).
class ExoticLegalStatus {
  const ExoticLegalStatus({
    required this.specimenId,
    required this.regimen,
    this.numeroRegistro = '',
    this.vigenciaHasta,
    this.documentada = false,
  });

  final String specimenId;
  final String regimen;
  final String numeroRegistro;
  final DateTime? vigenciaHasta;
  final bool documentada;

  /// Dias que faltan para que caduque. Negativo si ya vencio.
  int? diasParaVencer(DateTime ahora) {
    final hasta = vigenciaHasta;
    if (hasta == null) return null;
    return DateTime(
      hasta.year,
      hasta.month,
      hasta.day,
    ).difference(DateTime(ahora.year, ahora.month, ahora.day)).inDays;
  }

  bool vencido(DateTime ahora) => (diasParaVencer(ahora) ?? 1) < 0;

  /// Se avisa con un mes de antelacion: renovar un registro lleva tiempo.
  bool porVencer(DateTime ahora) {
    final d = diasParaVencer(ahora);
    return d != null && d >= 0 && d <= 30;
  }
}

/// Una toma de alimento ofrecida al ejemplar.
class ExoticFeeding {
  const ExoticFeeding({
    required this.specimenId,
    required this.ofrecidoEn,
    required this.alimento,
    required this.aceptado,
  });

  final String specimenId;
  final DateTime ofrecidoEn;
  final String alimento;
  final bool aceptado;
}

/// Una nidada en incubacion.
class ExoticClutch {
  const ExoticClutch({
    required this.id,
    required this.especie,
    required this.puestaEl,
    required this.huevos,
    required this.estado,
    this.fertiles,
    this.tempObjetivo,
    this.humedadObjetivo,
    this.eclosionEstimada,
  });

  final String id;
  final String especie;
  final DateTime puestaEl;
  final int huevos;
  final String estado;
  final int? fertiles;
  final double? tempObjetivo;
  final double? humedadObjetivo;
  final DateTime? eclosionEstimada;

  /// Cuenta regresiva a la eclosion. Negativa si ya paso la fecha prevista.
  int? diasParaEclosion(DateTime ahora) {
    final e = eclosionEstimada;
    if (e == null) return null;
    return DateTime(
      e.year,
      e.month,
      e.day,
    ).difference(DateTime(ahora.year, ahora.month, ahora.day)).inDays;
  }
}

/// Un evento fisiologico propio de exoticos (ecdisis, postura, conducta).
class ExoticPhysioEvent {
  const ExoticPhysioEvent({
    required this.specimenId,
    required this.tipo,
    required this.ocurrioEn,
    this.detalle = '',
  });

  final String specimenId;
  final String tipo;
  final DateTime ocurrioEn;
  final String detalle;

  /// Como se lee el tipo en pantalla.
  String get etiqueta => switch (tipo) {
    'ecdisis' => 'Muda',
    'ecdisis_retenida' => 'Muda retenida',
    'postura' => 'Postura',
    'vocalizacion' => 'Vocalización',
    'actividad_anormal' => 'Actividad anormal',
    'enriquecimiento' => 'Enriquecimiento',
    _ => 'Otro',
  };

  /// La muda retenida estrangula dedos y cola: es la que hay que destacar.
  bool get urgente => tipo == 'ecdisis_retenida';
}

String _num(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// Todo lo que el panel lee de una vez.
class ExoticSnapshot {
  const ExoticSnapshot({
    this.specimens = const [],
    this.weights = const [],
    this.stays = const [],
    this.events = const [],
    this.enclosures = const [],
    this.readings = const [],
    this.identifiers = const [],
    this.legal = const [],
    this.feedings = const [],
    this.clutches = const [],
    this.physioEvents = const [],
  });

  final List<ExoticSpecimen> specimens;
  final List<ExoticWeight> weights;
  final List<ExoticStay> stays;
  final List<ExoticEvent> events;
  final List<ExoticEnclosure> enclosures;
  final List<ExoticReading> readings;
  final List<ExoticIdentifier> identifiers;
  final List<ExoticLegalStatus> legal;
  final List<ExoticFeeding> feedings;
  final List<ExoticClutch> clutches;
  final List<ExoticPhysioEvent> physioEvents;

  bool get sinDatos => specimens.isEmpty;

  /// Los marcajes de un ejemplar, para mostrarlos junto a su nombre.
  List<ExoticIdentifier> marcajesDe(String specimenId) =>
      identifiers.where((i) => i.specimenId == specimenId).toList();

  /// Los ejemplares de un grupo. Sin grupo, todos.
  List<ExoticSpecimen> delTaxon(ExoticTaxon? taxon) => taxon == null
      ? specimens
      : specimens.where((e) => e.taxon == taxon).toList();

  /// Las estancias todavía abiertas.
  List<ExoticStay> enCurso() => stays;

  /// La serie de pesos de un ejemplar, del más viejo al más nuevo.
  List<ExoticWeight> serieDe(String specimenId) {
    final lista = weights.where((w) => w.specimenId == specimenId).toList()
      ..sort((a, b) => a.fecha.compareTo(b.fecha));
    return lista;
  }

  /// Los ejemplares que han perdido al menos [umbralPct] desde su peso máximo.
  List<WeightAlert> alertasDePeso({double umbralPct = 5}) {
    final avisos = <WeightAlert>[];
    for (final e in specimens) {
      final serie = serieDe(e.id);
      if (serie.length < 2) continue;
      var maximo = serie.first.gramos;
      for (final p in serie) {
        if (p.gramos > maximo) maximo = p.gramos;
      }
      final actual = serie.last.gramos;
      if (maximo <= 0 || actual >= maximo) continue;
      final caida = (maximo - actual) / maximo * 100;
      if (caida >= umbralPct) {
        avisos.add(
          WeightAlert(
            specimen: e,
            pesoMaximo: maximo,
            pesoActual: actual,
            caidaPct: caida,
          ),
        );
      }
    }
    avisos.sort((a, b) => b.caidaPct.compareTo(a.caidaPct));
    return avisos;
  }

  /// La ultima lectura de cada recinto.
  ExoticReading? ultimaLecturaDe(String enclosureId) {
    ExoticReading? mejor;
    for (final r in readings) {
      if (r.enclosureId != enclosureId) continue;
      if (mejor == null || r.medidoEn.isAfter(mejor.medidoEn)) mejor = r;
    }
    return mejor;
  }

  /// Todas las desviaciones del ambiente respecto al rango objetivo.
  ///
  /// Se comparan solo los parametros que el recinto declara: un terrario sin
  /// rango de pH no genera aviso por no tener agua, no por estar bien.
  List<EnclosureDeviation> desviaciones() {
    final fuera = <EnclosureDeviation>[];
    for (final e in enclosures) {
      final r = ultimaLecturaDe(e.id);
      if (r == null) continue;

      void revisar(
        String nombre,
        double? valor,
        double? min,
        double? max,
        String unidad,
      ) {
        if (valor == null) return;
        if (min == null && max == null) return;
        final bajo = min != null && valor < min;
        final alto = max != null && valor > max;
        if (!bajo && !alto) return;
        final esperado = min != null && max != null
            ? '${_num(min)}-${_num(max)}'
            : min != null
            ? '≥ ${_num(min)}'
            : '≤ ${_num(max!)}';
        fuera.add(
          EnclosureDeviation(
            enclosure: e,
            parametro: nombre,
            valor: valor,
            esperado: esperado,
            unidad: unidad,
          ),
        );
      }

      revisar(
        'Punto caliente',
        r.tempCaliente,
        e.tempCalienteMin,
        e.tempCalienteMax,
        '°C',
      );
      revisar('Punto frío', r.tempFria, e.tempFriaMin, e.tempFriaMax, '°C');
      revisar('Humedad', r.humedad, e.humedadMin, e.humedadMax, '%');
      revisar('Índice UV', r.uvIndex, e.uvMin, e.uvMax, '');
      revisar('pH', r.ph, e.phMin, e.phMax, '');
      // El amoniaco y el nitrito solo tienen techo: cualquier cantidad por
      // encima de cero ya es toxica, el limite marca lo intolerable.
      revisar('Amoniaco', r.amoniaco, null, e.amoniacoMax, 'mg/L');
      revisar('Nitrito', r.nitrito, null, e.nitritoMax, 'mg/L');
      revisar('Salinidad', r.salinidad, e.salinidadMin, e.salinidadMax, 'ppt');
    }
    return fuera;
  }

  /// Registros legales vencidos o a punto de vencer.
  List<ExoticLegalStatus> legalEnRiesgo(DateTime ahora) =>
      legal.where((l) => l.vencido(ahora) || l.porVencer(ahora)).toList()
        ..sort((a, b) {
          final da = a.diasParaVencer(ahora) ?? 9999;
          final db = b.diasParaVencer(ahora) ?? 9999;
          return da.compareTo(db);
        });

  /// Ejemplares sin ningun marcaje registrado.
  List<ExoticSpecimen> sinMarcaje() {
    final marcados = identifiers.map((i) => i.specimenId).toSet();
    return specimens.where((e) => !marcados.contains(e.id)).toList();
  }

  /// Rechazos de alimento seguidos de cada ejemplar, de mas a menos.
  ///
  /// Se cuentan los rechazos consecutivos mas recientes: dos seguidos ya
  /// merecen una mirada, y en reptiles y aves suelen preceder al resto de
  /// signos clinicos.
  List<({ExoticSpecimen specimen, int rechazos, DateTime desde})>
  rachaDeRechazos() {
    final salida =
        <({ExoticSpecimen specimen, int rechazos, DateTime desde})>[];
    for (final e in specimens) {
      final tomas = feedings.where((f) => f.specimenId == e.id).toList()
        ..sort((a, b) => b.ofrecidoEn.compareTo(a.ofrecidoEn));
      if (tomas.isEmpty) continue;
      var n = 0;
      DateTime? desde;
      for (final t in tomas) {
        if (t.aceptado) break;
        n++;
        desde = t.ofrecidoEn;
      }
      if (n > 0 && desde != null) {
        salida.add((specimen: e, rechazos: n, desde: desde));
      }
    }
    salida.sort((a, b) => b.rechazos.compareTo(a.rechazos));
    return salida;
  }

  /// Nidadas todavia en incubacion, las mas proximas a eclosionar primero.
  List<ExoticClutch> incubando() {
    final activas = clutches.where((c) => c.estado == 'incubando').toList()
      ..sort((a, b) {
        final ea = a.eclosionEstimada;
        final eb = b.eclosionEstimada;
        if (ea == null && eb == null) return 0;
        if (ea == null) return 1;
        if (eb == null) return -1;
        return ea.compareTo(eb);
      });
    return activas;
  }

  /// Busca por nombre, especie o raza. Sin texto, no devuelve nada: una lista
  /// completa disfrazada de resultado solo estorba.
  List<ExoticSpecimen> buscar(String texto) {
    final q = texto.trim().toLowerCase();
    if (q.isEmpty) return const [];
    // Un microchip o un anillo identifican al ejemplar mejor que su nombre:
    // se buscan tambien por codigo de marcaje.
    final porMarcaje = identifiers
        .where((i) => i.codigo.toLowerCase().contains(q))
        .map((i) => i.specimenId)
        .toSet();
    return specimens.where((e) {
      return porMarcaje.contains(e.id) ||
          e.nombre.toLowerCase().contains(q) ||
          e.especie.toLowerCase().contains(q) ||
          e.raza.toLowerCase().contains(q) ||
          e.id.toLowerCase().contains(q);
    }).toList();
  }
}

/// De donde salen los ejemplares y su historia.
abstract class ExoticDashboardRepository {
  Future<ExoticSnapshot> load(String clinicId);
}

/// Deduce el grupo taxonómico a partir del texto de especie del expediente.
///
/// El campo `species` de `vet_patients` es texto libre, así que no hay
/// garantía de nada: se reconoce lo que se puede y lo demás queda sin grupo,
/// que es más honesto que colocarlo por defecto en uno.
ExoticTaxon? taxonDeEspecie(String especie) {
  final s = especie.toLowerCase().trim();
  if (s.isEmpty) return null;

  bool tiene(List<String> claves) => claves.any(
    (clave) => RegExp(
      r'(?<![\p{L}\p{N}])' +
          RegExp.escape(clave) +
          r'(?:s|es)?(?![\p{L}\p{N}])',
      unicode: true,
    ).hasMatch(s),
  );

  if (tiene([
    'ave',
    'aves',
    'avestruz',
    'avestruces',
    'loro',
    'perico',
    'guacamaya',
    'cotorra',
    'ninfa',
    'agapornis',
    'canario',
    'periquito',
    'cacatua',
    'cacatúa',
    'halcon',
    'halcón',
    'aguila',
    'águila',
    'lechuza',
    'buho',
    'búho',
    'gallina',
    'pato',
    'ganso',
    'paloma',
  ])) {
    return ExoticTaxon.aves;
  }
  if (tiene([
    'reptil',
    'iguana',
    'gecko',
    'geco',
    'serpiente',
    'boa',
    'piton',
    'pitón',
    'tortuga',
    'camaleon',
    'camaleón',
    'dragon barbudo',
    'dragón barbudo',
    'pogona',
    'lagarto',
    'lagartija',
  ])) {
    return ExoticTaxon.reptiles;
  }
  if (tiene([
    'anfibio',
    'rana',
    'sapo',
    'ajolote',
    'axolotl',
    'salamandra',
    'triton',
    'tritón',
  ])) {
    return ExoticTaxon.anfibios;
  }
  if (tiene([
    'pez',
    'peces',
    'goldfish',
    'carpa',
    'koi',
    'betta',
    'guppy',
    'ciclido',
    'cíclido',
    'tetra',
  ])) {
    return ExoticTaxon.pecesOrnamentales;
  }
  if (tiene([
    'conejo',
    'cobayo',
    'cuyo',
    'cuy',
    'hamster',
    'hámster',
    'jerbo',
    'raton',
    'ratón',
    'rata',
    'chinchilla',
    'huron',
    'hurón',
    'erizo',
    'petauro',
    'ardilla',
  ])) {
    return ExoticTaxon.mamiferosPequenos;
  }
  if (tiene([
    'silvestre',
    'mapache',
    'tlacuache',
    'zarigueya',
    'coati',
    'coatí',
    'venado',
    'mono',
  ])) {
    return ExoticTaxon.faunaSilvestre;
  }
  return null;
}

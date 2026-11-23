/// Lo que el Dashboard de Fauna Exótica sabe de los ejemplares reales.
///
/// En exóticos la unidad no es el lote sino el individuo: cada ejemplar tiene
/// su peso, su recinto y su expediente. Por eso todo lo de aquí cuelga del
/// paciente, no de un grupo.
///
/// Lo que se lee sale de tablas que ya existen:
///
///   * `vet_patients`       -> los ejemplares
///   * `hospital_stays`     -> cuarentena y hospitalización
///   * `vet_patient_events` -> pesos (`weight`) y demás eventos
///
/// Lo que **no** tiene tabla todavía —microclimas, estatus CITES/SEMARNAT,
/// incubadoras— no se inventa: el panel lo dice y queda pendiente de modelar.
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

/// Todo lo que el panel lee de una vez.
class ExoticSnapshot {
  const ExoticSnapshot({
    this.specimens = const [],
    this.weights = const [],
    this.stays = const [],
    this.events = const [],
  });

  final List<ExoticSpecimen> specimens;
  final List<ExoticWeight> weights;
  final List<ExoticStay> stays;
  final List<ExoticEvent> events;

  bool get sinDatos => specimens.isEmpty;

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

  /// Busca por nombre, especie o raza. Sin texto, no devuelve nada: una lista
  /// completa disfrazada de resultado solo estorba.
  List<ExoticSpecimen> buscar(String texto) {
    final q = texto.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return specimens.where((e) {
      return e.nombre.toLowerCase().contains(q) ||
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

  bool tiene(List<String> claves) => claves.any(s.contains);

  if (tiene([
    'ave',
    'aves',
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
  if (tiene(['anfibio', 'rana', 'sapo', 'ajolote', 'axolotl', 'salamandra', 'triton', 'tritón'])) {
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
  if (tiene(['silvestre', 'mapache', 'tlacuache', 'zarigueya', 'coati', 'coatí', 'venado', 'mono'])) {
    return ExoticTaxon.faunaSilvestre;
  }
  return null;
}

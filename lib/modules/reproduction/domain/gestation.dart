/// Gestación: un solo modelo para toda la app.
///
/// Vive en `lib/modules/reproduction/` y no dentro de producción ni de
/// exóticos, porque no es de ninguno de los dos. La razón es estructural: una
/// gestación es un hecho de una hembra concreta, y producción no tiene
/// animales individuales — `lotes_produccion` cuenta `cabezas`, que es un
/// número. Los animales individuales viven en `vet_patients`, que es la tabla
/// que los dos módulos ya comparten.
///
/// El precedente estaba puesto por `exotic_clutches`, que cuelga de
/// `vet_patients` con un vínculo opcional al recinto. Esta es su gemela
/// vivípara, con un vínculo opcional al lote.
///
/// Lo único que cambia entre la gestación de una vaca y la de un hámster es
/// el número de días, y eso es catálogo (`reproduccion_gestacion_dias`), no
/// código.
library;

/// Cómo se produjo el servicio.
enum MatingMethod {
  montaNatural('monta_natural', 'Monta natural'),
  inseminacion('inseminacion_artificial', 'Inseminación artificial'),
  transferencia('transferencia_embrion', 'Transferencia de embrión'),
  desconocido('desconocido', 'Desconocido');

  const MatingMethod(this.code, this.label);
  final String code, label;

  static MatingMethod? desdeCodigo(String? code) {
    for (final m in values) {
      if (m.code == code) return m;
    }
    return null;
  }
}

/// Resultado del diagnóstico de preñez.
enum PregnancyCheck {
  pendiente('pendiente', 'Sin diagnosticar'),
  gestante('gestante', 'Gestante'),
  vacia('vacia', 'Vacía'),
  dudosa('dudosa', 'Dudosa');

  const PregnancyCheck(this.code, this.label);
  final String code, label;

  static PregnancyCheck desdeCodigo(String? code) {
    for (final d in values) {
      if (d.code == code) return d;
    }
    return PregnancyCheck.pendiente;
  }
}

/// En qué acabó (o no) la gestación.
enum GestationState {
  enCurso('en_curso', 'En curso'),
  parida('parida', 'Parida'),
  aborto('aborto', 'Aborto'),
  vacia('vacia', 'Vacía'),
  cancelada('cancelada', 'Cancelada');

  const GestationState(this.code, this.label);
  final String code, label;

  static GestationState desdeCodigo(String? code) {
    for (final e in values) {
      if (e.code == code) return e;
    }
    return GestationState.enCurso;
  }

  /// Una gestación abierta es la que todavía puede terminar en algo.
  bool get abierta => this == GestationState.enCurso;
}

/// Una gestación, tal como vive en `reproduccion_gestaciones`.
class Gestation {
  const Gestation({
    required this.id,
    required this.patientId,
    required this.especie,
    required this.servicio,
    required this.metodo,
    required this.diagnostico,
    required this.estado,
    this.loteId,
    this.semental,
    this.diasGestacion,
    this.partoEstimado,
    this.diagnosticoEl,
    this.partoEl,
    this.criasVivas,
    this.criasMuertas,
    this.notas,
  });

  final String id;
  final String patientId;
  final String? loteId;
  final String especie;
  final DateTime servicio;
  final MatingMethod metodo;
  final String? semental;
  final int? diasGestacion;

  /// Lo calcula el servidor como `servicio + diasGestacion`. No se recalcula
  /// aquí: si dependiera del reloj del teléfono, dos móviles en husos
  /// distintos mostrarían fechas de parto distintas para el mismo animal.
  final DateTime? partoEstimado;

  final PregnancyCheck diagnostico;
  final DateTime? diagnosticoEl;
  final GestationState estado;
  final DateTime? partoEl;
  final int? criasVivas;
  final int? criasMuertas;
  final String? notas;

  /// Días que faltan para el parto previsto. Negativo si ya se pasó.
  ///
  /// `null` cuando no se sabe cuántos días dura la gestación de esa especie
  /// y nadie los escribió: entonces no hay cuenta regresiva que enseñar, y
  /// es mejor no enseñar ninguna que inventar una.
  int? diasParaParto(DateTime ahora) {
    final e = partoEstimado;
    if (e == null) return null;
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    return e.difference(hoy).inDays;
  }

  /// Días transcurridos desde el servicio.
  int diasDesdeServicio(DateTime ahora) {
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    return hoy.difference(servicio).inDays;
  }

  /// Si está abierta, pasó la fecha prevista y nadie la ha cerrado.
  ///
  /// Es el aviso que de verdad importa: una vaca que debió parir hace cinco
  /// días y sigue «en curso» es o un parto sin registrar o un problema.
  bool vencida(DateTime ahora) {
    if (!estado.abierta) return false;
    final d = diasParaParto(ahora);
    return d != null && d < 0;
  }

  /// Total de crías nacidas, vivas y muertas.
  int? get criasTotales {
    if (criasVivas == null && criasMuertas == null) return null;
    return (criasVivas ?? 0) + (criasMuertas ?? 0);
  }

  static Gestation read(Map<String, dynamic> row) => Gestation(
    id: '${row['id']}',
    patientId: '${row['patient_id']}',
    loteId: row['lote_id'] as String?,
    especie: '${row['especie'] ?? ''}',
    servicio: _fecha(row['servicio_el']) ?? DateTime.now(),
    metodo:
        MatingMethod.desdeCodigo(row['metodo'] as String?) ??
        MatingMethod.desconocido,
    semental: row['semental'] as String?,
    diasGestacion: _entero(row['dias_gestacion']),
    partoEstimado: _fecha(row['parto_estimado']),
    diagnostico: PregnancyCheck.desdeCodigo(row['diagnostico'] as String?),
    diagnosticoEl: _fecha(row['diagnostico_el']),
    estado: GestationState.desdeCodigo(row['estado'] as String?),
    partoEl: _fecha(row['parto_el']),
    criasVivas: _entero(row['crias_vivas']),
    criasMuertas: _entero(row['crias_muertas']),
    notas: row['notas'] as String?,
  );
}

/// Días de gestación de una especie, de `reproduccion_gestacion_dias`.
///
/// Es un catálogo que **sugiere**, no que obliga. El servidor acepta
/// cualquier especie, porque producción usa códigos cerrados y
/// `vet_patients.species` es texto libre: exigir que coincidieran impediría
/// registrar la gestación de algo que no hubiéramos previsto.
class GestationDays {
  const GestationDays({
    required this.especie,
    required this.nombre,
    required this.grupo,
    required this.min,
    required this.promedio,
    required this.max,
  });

  final String especie;
  final String nombre;
  final String grupo;
  final int min, promedio, max;

  String get rango => min == max ? '$min días' : '$min - $max días';

  static GestationDays read(Map<String, dynamic> row) => GestationDays(
    especie: '${row['especie'] ?? ''}',
    nombre: '${row['nombre'] ?? ''}',
    grupo: '${row['grupo'] ?? ''}',
    min: _entero(row['dias_min']) ?? 0,
    promedio: _entero(row['dias_prom']) ?? 0,
    max: _entero(row['dias_max']) ?? 0,
  );
}

/// Normaliza un nombre de especie para poder compararlo con el catálogo.
///
/// Hace falta porque `vet_patients.species` lo escribe una persona: puede
/// llegar «Hámster», «hamster» o «HAMSTER». Se baja a minúscula, se quitan
/// los acentos y se colapsan los espacios.
String normalizarEspecie(String texto) {
  const con = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const sin = 'aaaaaeeeeiiiiooooouuuunc';
  final b = StringBuffer();
  for (final ch in texto.toLowerCase().trim().split('')) {
    final i = con.indexOf(ch);
    b.write(i >= 0 ? sin[i] : ch);
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ');
}

/// Busca en el catálogo los días que corresponden a una especie.
///
/// Primero intenta la coincidencia exacta y, si no la hay, la más específica
/// que esté contenida en el texto: así «Hámster sirio macho» encuentra
/// «hamster sirio» antes que «hamster».
GestationDays? diasDeEspecie(List<GestationDays> catalogo, String especie) {
  final clave = normalizarEspecie(especie);
  if (clave.isEmpty) return null;
  for (final d in catalogo) {
    if (d.especie == clave) return d;
  }
  GestationDays? mejor;
  for (final d in catalogo) {
    if (clave.contains(d.especie)) {
      if (mejor == null || d.especie.length > mejor.especie.length) mejor = d;
    }
  }
  return mejor;
}

/// Todo lo que una pantalla de reproducción necesita, en una sola lectura.
class GestationSnapshot {
  const GestationSnapshot({
    this.gestaciones = const [],
    this.catalogo = const [],
    this.nombresDePaciente = const {},
  });

  final List<Gestation> gestaciones;
  final List<GestationDays> catalogo;

  /// `patientId` → nombre, para no tener que resolverlo en cada tarjeta.
  final Map<String, String> nombresDePaciente;

  bool get sinDatos => gestaciones.isEmpty;

  /// Las abiertas, de la que pare antes a la que pare después.
  ///
  /// Las que no tienen fecha prevista van al final: no se puede ordenar por
  /// una fecha que no existe, y ponerlas primero daría a entender una
  /// urgencia que nadie ha calculado.
  List<Gestation> abiertas() {
    final lista = gestaciones.where((g) => g.estado.abierta).toList()
      ..sort((a, b) {
        final x = a.partoEstimado, y = b.partoEstimado;
        if (x == null && y == null) return a.servicio.compareTo(b.servicio);
        if (x == null) return 1;
        if (y == null) return -1;
        return x.compareTo(y);
      });
    return lista;
  }

  /// Las que debieron parir y siguen sin cerrarse.
  List<Gestation> vencidas(DateTime ahora) =>
      abiertas().where((g) => g.vencida(ahora)).toList();

  /// Las que paren dentro de [dias] días, sin contar las vencidas.
  List<Gestation> proximas(DateTime ahora, {int dias = 30}) =>
      abiertas().where((g) {
        final d = g.diasParaParto(ahora);
        return d != null && d >= 0 && d <= dias;
      }).toList();

  /// El historial de una hembra, de lo más reciente a lo más antiguo.
  List<Gestation> dePaciente(String patientId) {
    final lista = gestaciones.where((g) => g.patientId == patientId).toList()
      ..sort((a, b) => b.servicio.compareTo(a.servicio));
    return lista;
  }

  /// Las gestaciones de un lote de producción.
  List<Gestation> deLote(String loteId) =>
      gestaciones.where((g) => g.loteId == loteId).toList();
}

/// De dónde salen las gestaciones. Solo lectura.
abstract class GestationRepository {
  Future<GestationSnapshot> load(String clinicId);
}

int? _entero(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

DateTime? _fecha(Object? v) {
  if (v is DateTime) return DateTime(v.year, v.month, v.day);
  if (v is String && v.isNotEmpty) {
    final d = DateTime.tryParse(v);
    if (d != null) return DateTime(d.year, d.month, d.day);
  }
  return null;
}

import 'catalog.dart' show normalizeDoseSearch;
import 'manufacturer_pauta.dart';
import 'pauta_farmacologica.dart';

/// De dónde sale una fila. La tabla acumulada no mezcla las dos: cada fila
/// dice si viene del vademécum de principios o del de marcas.
enum OrigenDosis {
  principio('Principio activo'),
  marca('Marca comercial');

  const OrigenDosis(this.etiqueta);
  final String etiqueta;
}

/// Una fila de la tabla acumulativa de dosis, con sus 15 columnas.
///
/// Es una vista de lectura sobre los dos catálogos: no guarda dosis propias ni
/// promedia autores. Cada fila repite lo que dice su fuente.
class FilaDosis {
  const FilaDosis({
    required this.origen,
    required this.especie,
    required this.grupos,
    required this.principioActivo,
    required this.nombreComercial,
    required this.presentacion,
    required this.indicacion,
    required this.dosis,
    required this.via,
    required this.intervalo,
    required this.duracion,
    required this.condiciones,
    required this.edadPeso,
    required this.fuente,
    required this.anio,
    required this.estado,
    required this.id,
  });

  final String id;

  /// Grupos de especie para filtrar (Bovinos, Aves…). La columna Especie
  /// conserva el texto literal del catálogo, que es libre y a veces larguísimo.
  final List<String> grupos;
  final OrigenDosis origen;
  final String especie, principioActivo, nombreComercial, presentacion;
  final String indicacion, dosis, via, intervalo, duracion, condiciones;
  final String edadPeso, fuente;
  final String? anio;
  final String estado;

  /// Las 15 columnas en el orden en que se leen y se exportan.
  Map<String, String> get columnas => {
    'Tipo': origen.etiqueta,
    'Especie': especie,
    'Principio activo': principioActivo,
    'Nombre comercial': nombreComercial,
    'Presentación': presentacion,
    'Indicación': indicacion,
    'Dosis': dosis,
    'Vía': via,
    'Intervalo': intervalo,
    'Duración': duracion,
    'Condiciones': condiciones,
    'Edad y peso': edadPeso,
    'Fuente': fuente,
    'Año': anio ?? '—',
    'Estado': estado,
  };

  bool get calculable => origen == OrigenDosis.principio;

  String get titulo =>
      origen == OrigenDosis.principio ? principioActivo : nombreComercial;
}

/// Grupos de especie reconocidos en el texto libre de los dos catálogos.
const gruposEspecie = <String>[
  'Bovinos',
  'Equinos',
  'Porcinos',
  'Ovinos',
  'Caprinos',
  'Aves',
  'Perros',
  'Gatos',
  'Conejos',
  'Peces',
  'Reptiles',
];

/// Normaliza el texto de especie a los grupos que se usan para filtrar.
///
/// Un texto puede caer en varios grupos («perros y gatos»); se devuelven todos
/// y, si no coincide ninguno, queda «Otros» para no esconder la fila.
List<String> gruposDeEspecie(List<String> textos) {
  final texto = normalizeDoseSearch(textos.join(' '));
  final salida = <String>[];
  bool tiene(List<String> claves) =>
      claves.any((clave) => texto.contains(clave));
  if (tiene(['bovino', 'vacuno', 'vaca', 'becerro', 'ternero'])) {
    salida.add('Bovinos');
  }
  if (tiene(['equino', 'caballo', 'yegua', 'potro', 'mular', 'asnal'])) {
    salida.add('Equinos');
  }
  if (tiene(['porcino', 'cerdo', 'lechon', 'marrano', 'cochino'])) {
    salida.add('Porcinos');
  }
  if (tiene(['ovino', 'oveja', 'cordero', 'borrego'])) salida.add('Ovinos');
  if (tiene(['caprino', 'cabra', 'cabrito'])) salida.add('Caprinos');
  if (tiene([
    'ave',
    'aviar',
    'pollo',
    'gallina',
    'pavo',
    'pato',
    'paloma',
    'codorniz',
  ])) {
    salida.add('Aves');
  }
  if (tiene(['perro', 'canino', 'canid'])) salida.add('Perros');
  if (tiene(['gato', 'felino', 'felid'])) salida.add('Gatos');
  if (tiene(['conejo', 'cunicula'])) salida.add('Conejos');
  if (tiene(['pez', 'peces', 'acuicultura', 'tilapia', 'salmon'])) {
    salida.add('Peces');
  }
  if (tiene(['reptil', 'serpiente', 'iguana', 'tortuga', 'gecko'])) {
    salida.add('Reptiles');
  }
  return salida.isEmpty ? const ['Otros'] : List.unmodifiable(salida);
}

/// Tabla acumulativa: una sola lista con todo lo que hoy está en los dos
/// vademécums, sin crear un tercer catálogo que se desincronice.
class TablaDosis {
  TablaDosis({required this.filas, required this.version, required this.nota});

  final List<FilaDosis> filas;
  final String version, nota;

  /// Texto de cada fila ya normalizado: buscar en 2 000 filas no debe
  /// reconstruir la cadena en cada tecla.
  late final List<String> _indices = [
    for (final fila in filas) normalizar(fila.columnas.values.join(' ')),
  ];

  static String normalizar(String valor) => normalizeDoseSearch(valor);

  int get dePrincipios =>
      filas.where((f) => f.origen == OrigenDosis.principio).length;

  int get deMarcas => filas.where((f) => f.origen == OrigenDosis.marca).length;

  List<String> get especies {
    final vistas = <String>{};
    for (final fila in filas) {
      vistas.addAll(fila.grupos);
    }
    final lista = vistas.toList()..sort();
    return List.unmodifiable(lista);
  }

  List<FilaDosis> buscar(
    String texto, {
    OrigenDosis? origen,
    String? especie,
  }) {
    final consulta = normalizar(texto);
    final salida = <FilaDosis>[];
    for (var i = 0; i < filas.length; i++) {
      final fila = filas[i];
      if (origen != null && fila.origen != origen) continue;
      if (especie != null && !fila.grupos.contains(especie)) continue;
      if (consulta.isEmpty || _indices[i].contains(consulta)) salida.add(fila);
    }
    return List.unmodifiable(salida);
  }

  /// Arma la tabla desde los dos catálogos ya cargados.
  ///
  /// Las pautas de principios aportan la cita del libro; las marcas aportan su
  /// presentación y el registro sanitario. Nunca se funden en una sola fila:
  /// una marca y un principio son dos cosas distintas.
  static TablaDosis desde({
    required FarmacologicoCatalog principios,
    required List<ManufacturerPauta> marcas,
  }) {
    final porId = {for (final p in principios.principios) p.id: p};
    final filas = <FilaDosis>[
      for (final pauta in principios.pautas)
        FilaDosis(
          id: 'P-${pauta.id}',
          origen: OrigenDosis.principio,
          especie: _texto(pauta.especie),
          grupos: gruposDeEspecie([pauta.especie, ...pauta.especies]),
          principioActivo: porId[pauta.idFarmaco]?.nombre ?? pauta.idFarmaco,
          nombreComercial: '—',
          presentacion: '—',
          indicacion: pauta.indicacion,
          dosis: pauta.dosisTexto,
          via: _texto(pauta.via),
          intervalo: _texto(pauta.intervalo),
          duracion: _texto(pauta.duracion),
          condiciones: _texto(pauta.contraindicaciones),
          edadPeso: '—',
          fuente: _texto(pauta.cita),
          anio: pauta.anio?.toString(),
          estado: _texto(pauta.estado ?? 'sin verificar'),
        ),
      for (final pauta in marcas)
        FilaDosis(
          id: 'M-${pauta.id}',
          origen: OrigenDosis.marca,
          especie: _texto(pauta.species),
          grupos: gruposDeEspecie([pauta.species]),
          principioActivo: _ingredientes(pauta),
          nombreComercial: _texto(pauta.productName),
          presentacion: _texto(pauta.presentation),
          indicacion: _texto(pauta.indication),
          dosis: pauta.literal.trim().isEmpty
              ? _texto(_dosisCorta(pauta))
              : pauta.literal.trim(),
          via: _texto(pauta.route),
          intervalo: _texto(pauta.interval),
          duracion: _texto(pauta.duration),
          condiciones: _texto(pauta.contraindications),
          edadPeso: _texto(pauta.ageWeightLimits),
          fuente: _texto(pauta.manufacturer),
          anio: _anio(pauta.consultedAt, pauta.evidenceSection),
          estado: pauta.state.trim().isEmpty
              ? (pauta.trustworthy ? 'sin verificar' : 'revisar')
              : pauta.state,
        ),
    ];
    return TablaDosis(
      filas: List.unmodifiable(filas),
      version: '${principios.version} · ${marcas.length} marcas',
      nota:
          'Tabla de lectura: reúne las ${principios.pautas.length} pautas de '
          'principios activos y las ${marcas.length} pautas de marcas. No es '
          'validación clínica ni sustituye a la fuente citada.',
    );
  }

  static String _texto(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty || texto == '--' || texto == 'no especificado') return '—';
    return texto;
  }

  static String _ingredientes(ManufacturerPauta pauta) {
    final partes = <String>[
      _texto(pauta.ingredients),
      if (pauta.ingredientAmount.trim().isNotEmpty)
        '${pauta.ingredientAmount.trim()} ${pauta.ingredientUnit.trim()} '
            '${pauta.ingredientBase.trim()}',
    ];
    return partes.where((p) => p != '—').join(' · ');
  }

  static String _dosisCorta(ManufacturerPauta pauta) {
    final partes = <String>[
      pauta.doseAmount.trim(),
      pauta.doseUnit.trim(),
      pauta.doseReference.trim(),
    ].where((p) => p.isNotEmpty && p != 'no especificado');
    return partes.join(' ');
  }

  static String? _anio(String consultado, String seccion) {
    for (final texto in [consultado, seccion]) {
      final match = RegExp(r'(19|20)\d{2}').firstMatch(texto);
      if (match != null) return match.group(0);
    }
    return null;
  }
}

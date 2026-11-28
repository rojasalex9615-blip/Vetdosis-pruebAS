import 'dart:convert';

import 'package:flutter/services.dart';

import 'catalog.dart' show normalizeDoseSearch;
import 'quantity.dart';

/// Vademécum farmacológico: principios activos y pautas bibliográficas.
///
/// Cada pauta conserva su procedencia (autor, título, edición, año, página) y
/// su expresión literal. No se promedian dosis de autores distintos ni se
/// convierten en un rango: dos recomendaciones son dos pautas.
class PrincipioActivo {
  const PrincipioActivo({
    required this.id,
    required this.nombre,
    required this.sinonimos,
    required this.grupo,
    required this.grupoFuente,
  });

  final String id, nombre;
  final String? sinonimos, grupo, grupoFuente;

  String get clave => normalizeDoseSearch(nombre);
  bool get clasificado => grupo != null;

  factory PrincipioActivo.read(Map<String, dynamic> row) {
    final id = (row['id'] as String?)?.trim() ?? '';
    final nombre = (row['principio_activo'] as String?)?.trim() ?? '';
    if (id.isEmpty || nombre.isEmpty) {
      throw const FormatException('Principio activo sin id o sin nombre.');
    }
    final grupo = (row['grupo_clasificacion'] as String?)?.trim();
    if (grupo != null && !const {'I', 'II', 'III'}.contains(grupo)) {
      throw FormatException('Grupo de clasificación inválido en $id: $grupo');
    }
    return PrincipioActivo(
      id: id,
      nombre: nombre,
      sinonimos: (row['sinonimos'] as String?)?.trim(),
      grupo: grupo,
      grupoFuente: (row['grupo_fuente'] as String?)?.trim(),
    );
  }
}

/// Pauta de un libro, tal como la publica su autor.
class PautaFarmacologica {
  const PautaFarmacologica({
    required this.id,
    required this.idFarmaco,
    required this.especie,
    required this.especies,
    required this.indicacion,
    required this.dosisMin,
    required this.dosisMax,
    required this.baseCalculo,
    required this.dosisOriginal,
    required this.unidadOriginal,
    required this.via,
    required this.intervalo,
    required this.duracion,
    required this.contraindicaciones,
    required this.autor,
    required this.titulo,
    required this.edicion,
    required this.anio,
    required this.pagina,
    required this.seccion,
    required this.estado,
    required this.motivo,
    required this.grupo,
  });

  final String id, idFarmaco;
  final String especie;
  final List<String> especies;
  final String indicacion;
  final Quantity? dosisMin, dosisMax;

  /// `masa` calcula mg a partir del peso; `volumen` calcula mL. Null cuando la
  /// unidad publicada no se puede convertir al peso del paciente (mg/m², gotas).
  final String? baseCalculo;

  final String? dosisOriginal, unidadOriginal;
  final String? via, intervalo, duracion, contraindicaciones;
  final String? autor, titulo, edicion, pagina, seccion;
  final int? anio;
  final String? estado, motivo, grupo;

  /// La calculadora solo actúa si el autor publicó un rango numérico en una
  /// unidad convertible. Que falte no impide leer la pauta.
  bool get calculable => dosisMin != null && baseCalculo != null;
  bool get porMasa => baseCalculo == 'masa';
  bool get porVolumen => baseCalculo == 'volumen';

  /// Referencia bibliográfica en una línea.
  String get cita {
    final partes = <String>[
      ?autor,
      ?titulo,
      ?edicion,
      if (anio != null) '$anio',
      if (pagina != null) 'p. $pagina',
      ?seccion,
    ];
    return partes.join(' · ');
  }

  /// Lo que escribió el autor, con su unidad. Nunca se sustituye por el rango
  /// normalizado: el MVZ tiene que poder leer la fuente.
  String get dosisTexto {
    final literal = dosisOriginal?.trim();
    final unidad = unidadOriginal?.trim();
    if (literal == null || literal.isEmpty) {
      if (dosisMin == null) return '—';
      final max = dosisMax;
      final rango = max == null || max.compareTo(dosisMin!) == 0
          ? dosisMin!.display()
          : '${dosisMin!.display()}–${max.display()}';
      return unidad == null || unidad.isEmpty ? rango : '$rango $unidad';
    }
    return unidad == null || unidad.isEmpty ? literal : '$literal $unidad';
  }

  factory PautaFarmacologica.read(Map<String, dynamic> row) {
    final id = (row['id'] as String?)?.trim() ?? '';
    final idFarmaco = (row['id_farmaco'] as String?)?.trim() ?? '';
    if (id.isEmpty || idFarmaco.isEmpty) {
      throw FormatException('Pauta sin id o sin principio activo: $row');
    }
    final especies =
        (row['especies'] as List?)
            ?.map((e) => '$e'.trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];
    final base = (row['base_calculo'] as String?)?.trim();
    if (base != null && base != 'masa' && base != 'volumen') {
      throw FormatException('Base de cálculo inválida en $id: $base');
    }
    final minimo = _decimal(row['dosis_min'], id, 'dosis_min');
    final maximo = _decimal(row['dosis_max'], id, 'dosis_max');
    if (minimo != null && maximo != null && minimo.compareTo(maximo) > 0) {
      throw FormatException('Rango invertido en $id.');
    }
    final anio = row['anio'];
    return PautaFarmacologica(
      id: id,
      idFarmaco: idFarmaco,
      especie: (row['especie'] as String?)?.trim() ?? '',
      especies: especies,
      indicacion: (row['indicacion'] as String?)?.trim() ?? '',
      dosisMin: minimo,
      dosisMax: maximo,
      baseCalculo: base,
      dosisOriginal: (row['dosis_original'] as String?)?.trim(),
      unidadOriginal: (row['unidad_original'] as String?)?.trim(),
      via: (row['via'] as String?)?.trim(),
      intervalo: (row['intervalo'] as String?)?.trim(),
      duracion: (row['duracion'] as String?)?.trim(),
      contraindicaciones: (row['condiciones_contraindicaciones'] as String?)
          ?.trim(),
      autor: (row['autor'] as String?)?.trim(),
      titulo: (row['titulo'] as String?)?.trim(),
      edicion: (row['edicion'] as String?)?.trim(),
      anio: anio is int ? anio : int.tryParse('$anio'),
      pagina: (row['edicion_pagina'] as String?)?.trim(),
      seccion: (row['seccion'] as String?)?.trim(),
      estado: (row['estado_normalizacion'] as String?)?.trim(),
      motivo: (row['motivo_no_normalizado'] as String?)?.trim(),
      grupo: (row['grupo_clasificacion'] as String?)?.trim(),
    );
  }

  static Quantity? _decimal(Object? valor, String id, String campo) {
    if (valor == null) return null;
    final texto = '$valor'.trim();
    if (texto.isEmpty) return null;
    try {
      final cantidad = Quantity.parse(texto);
      return cantidad.positive ? cantidad : null;
    } on FormatException {
      throw FormatException('$campo inválido en $id: "$texto".');
    }
  }
}

class FarmacologicoCatalog {
  FarmacologicoCatalog({
    required this.version,
    required this.principios,
    required this.pautas,
  });

  final String version;
  final List<PrincipioActivo> principios;
  final List<PautaFarmacologica> pautas;

  static Future<FarmacologicoCatalog> load() async => parse(
    await rootBundle.loadString('assets/clinical/farmacologico.v1.json'),
  );

  static FarmacologicoCatalog parse(String text) {
    final raw = jsonDecode(text) as Map<String, dynamic>;
    if (raw['schema_version'] != 1) {
      throw const FormatException('Vademécum farmacológico incompatible.');
    }
    final farmacos = raw['farmacos'];
    final dosis = raw['dosis'];
    if (farmacos is! List || dosis is! List) {
      throw const FormatException('Vademécum farmacológico incompleto.');
    }
    final principios = farmacos
        .map((r) => PrincipioActivo.read(r as Map<String, dynamic>))
        .toList(growable: false);
    final pautas = dosis
        .map((r) => PautaFarmacologica.read(r as Map<String, dynamic>))
        .toList(growable: false);

    if (principios.map((p) => p.id).toSet().length != principios.length) {
      throw const FormatException('Principios activos duplicados.');
    }
    if (pautas.map((p) => p.id).toSet().length != pautas.length) {
      throw const FormatException('Pautas duplicadas.');
    }
    final ids = principios.map((p) => p.id).toSet();
    if (pautas.any((p) => !ids.contains(p.idFarmaco))) {
      throw const FormatException('Hay pautas sin principio activo.');
    }
    return FarmacologicoCatalog(
      version: '${raw['version'] ?? ''}',
      principios: List.unmodifiable(principios),
      pautas: List.unmodifiable(pautas),
    );
  }

  /// Especies con al menos una pauta, en orden alfabético.
  List<String> get especies {
    final vistas = <String>{for (final p in pautas) ...p.especies};
    final ordenadas = vistas.toList()..sort();
    return List.unmodifiable(ordenadas);
  }

  Map<String, PrincipioActivo> get porId => {
    for (final p in principios) p.id: p,
  };

  /// Pautas de un principio, opcionalmente filtradas por especie. El filtro es
  /// por lista, así que una pauta de «perro y gato» aparece en las dos.
  List<PautaFarmacologica> pautasDe(String idFarmaco, {String? especie}) {
    final filtro = especie == null || especie.isEmpty;
    return pautas
        .where(
          (p) =>
              p.idFarmaco == idFarmaco &&
              (filtro || p.especies.contains(especie)),
        )
        .toList(growable: false);
  }

  /// Búsqueda por nombre, sin acentos. Coincide por nombre o por sinónimo.
  List<PrincipioActivo> buscar(String consulta, {String? especie}) {
    final aguja = normalizeDoseSearch(consulta);
    final filtrar = especie != null && especie.isNotEmpty;
    final conPauta = filtrar
        ? {
            for (final p in pautas)
              if (p.especies.contains(especie)) p.idFarmaco,
          }
        : const <String>{};
    return principios
        .where((p) {
          if (filtrar && !conPauta.contains(p.id)) return false;
          if (aguja.isEmpty) return true;
          return normalizeDoseSearch(
            '${p.nombre} ${p.sinonimos ?? ''}',
          ).contains(aguja);
        })
        .toList(growable: false);
  }
}

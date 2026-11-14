/// Resultados de laboratorio y su lectura contra un rango de referencia.
/// Puro y sin estado. Regla de seguridad: si no hay un rango con fuente para
/// la especie, o la unidad no coincide, NO se emite un juicio (ni «normal» ni
/// «alto»); el valor se guarda y se muestra tal cual.
FormatException _invalid(String message) => FormatException(message);

/// Rango de referencia por especie. [source] es obligatoria: un rango sin
/// fuente no entra al sistema.
class LabReferenceRange {
  LabReferenceRange({
    required this.analyteKey,
    required this.species,
    required this.unit,
    required this.low,
    required this.high,
    required this.source,
  }) {
    if (analyteKey.trim().isEmpty) throw _invalid('Analito vacío.');
    if (species.trim().isEmpty) throw _invalid('Especie vacía.');
    if (unit.trim().isEmpty) throw _invalid('Unidad vacía.');
    if (source.trim().isEmpty) {
      throw _invalid('Un rango de referencia exige una fuente.');
    }
    if (!low.isFinite || !high.isFinite || low < 0 || high < low) {
      throw _invalid('Rango inválido: el límite alto no puede ser menor que el bajo.');
    }
  }
  final String analyteKey, species, unit, source;
  final double low, high;
}

enum LabFlag {
  /// Dentro del rango (límites incluidos).
  withinRange,
  below,
  above,

  /// No hay rango con fuente para esa especie: no se juzga.
  noReference,

  /// La unidad del resultado no coincide con la del rango: no se convierte
  /// ni se juzga.
  unitMismatch,
}

String _norm(String s) => s.trim().toLowerCase();

class LabResult {
  LabResult({
    required this.analyteKey,
    required this.value,
    required this.unit,
  }) {
    if (analyteKey.trim().isEmpty) throw _invalid('Analito vacío.');
    if (!value.isFinite || value < 0 || value > 1e9) {
      throw _invalid('Valor fuera de rango.');
    }
    if (unit.trim().isEmpty) throw _invalid('Indica la unidad del resultado.');
  }
  final String analyteKey, unit;
  final double value;

  /// Lee un texto con punto decimal. La coma NO se acepta, a proposito.
  ///
  /// En Mexico el separador de miles es la coma y el decimal el punto, asi
  /// que «1,200» son mil doscientos. Tomando la coma como decimal, ese valor
  /// entraba como 1.2: mil veces menos, en silencio y en un dato clinico.
  /// Entre rechazar la entrada y adivinarla, en laboratorio se rechaza: el
  /// aviso cuesta dos segundos y el error de mil no se ve.
  static double parseValue(String raw) {
    final text = raw.trim();
    if (text.contains(',')) {
      throw _invalid(
        'Valor: usa punto decimal y sin separadores de miles, por ejemplo '
        '4.5 o 1200.',
      );
    }
    if (!RegExp(r'^\d+(?:\.\d+)?$').hasMatch(text)) {
      throw _invalid('Valor: usa números sin separadores de miles.');
    }
    return double.parse(text);
  }

  /// Una lectura del valor contra UN rango, con el rango que la produjo.
  ///
  /// [range] es nulo cuando no hubo contra que leer: sin rango de la especie
  /// o con la unidad distinta.
  ///
  /// Lee contra CADA rango que aplica, sin juntarlos.
  ///
  /// Antes, con dos fuentes para el mismo analito y unidad, se tomaba el
  /// rango mas amplio: el minimo de los minimos y el maximo de los maximos.
  /// Eso decide por el veterinario y ademas en la direccion permisiva, un
  /// valor que una fuente llama bajo se presentaba como normal, y la union
  /// de los dos rangos no es un rango que ninguna fuente publique. Por
  /// indicacion de Ale: se muestran los dos datos con su referencia y el
  /// profesional elige. Es la misma regla que ya siguen las referencias
  /// porcinas con la lactancia de 21 y 28 dias.
  List<LabReading> readings(String species, List<LabReferenceRange> ranges) {
    final matches = [
      for (final r in ranges)
        if (_norm(r.analyteKey) == _norm(analyteKey) &&
            _norm(r.species) == _norm(species))
          r,
    ];
    if (matches.isEmpty) {
      return const [LabReading(flag: LabFlag.noReference)];
    }
    final sameUnit = [
      for (final r in matches)
        if (_norm(r.unit) == _norm(unit)) r,
    ];
    if (sameUnit.isEmpty) {
      return const [LabReading(flag: LabFlag.unitMismatch)];
    }
    return [
      for (final r in sameUnit)
        LabReading(
          flag: value < r.low
              ? LabFlag.below
              : value > r.high
              ? LabFlag.above
              : LabFlag.withinRange,
          range: r,
        ),
    ];
  }

  /// La lectura unica, SOLO si todas las fuentes coinciden; nulo si no.
  ///
  /// Nulo no es un fallo: significa que las fuentes no dicen lo mismo y que
  /// la pantalla debe mostrarlas todas en vez de resumirlas.
  LabFlag? agreedFlag(String species, List<LabReferenceRange> ranges) {
    final all = readings(species, ranges);
    final first = all.first.flag;
    return all.every((r) => r.flag == first) ? first : null;
  }

  /// Fuentes de los rangos aplicados, para mostrarlas junto al resultado.
  List<String> sourcesFor(String species, List<LabReferenceRange> ranges) => [
    for (final r in ranges)
      if (_norm(r.analyteKey) == _norm(analyteKey) &&
          _norm(r.species) == _norm(species) &&
          _norm(r.unit) == _norm(unit))
        r.source,
  ];
}

/// Lo que una fuente dice de un valor: su juicio y el rango que lo produjo.
class LabReading {
  const LabReading({required this.flag, this.range});
  final LabFlag flag;

  /// Nulo cuando no hubo rango contra que leer.
  final LabReferenceRange? range;

  bool get judged =>
      flag != LabFlag.noReference && flag != LabFlag.unitMismatch;
}

/// Conjunto de resultados de una misma toma de muestra.
class LabPanel {
  LabPanel({
    required this.patientId,
    required this.species,
    required this.collectedAt,
    required this.results,
  }) {
    if (patientId.trim().isEmpty) throw _invalid('Falta el paciente.');
    if (species.trim().isEmpty) throw _invalid('Falta la especie.');
    if (results.isEmpty) throw _invalid('Agrega al menos un resultado.');
    final keys = <String>{};
    for (final r in results) {
      if (!keys.add(_norm(r.analyteKey))) {
        throw _invalid('Analito repetido en la misma toma: ${r.analyteKey}.');
      }
    }
  }
  final String patientId, species;
  final DateTime collectedAt;
  final List<LabResult> results;

  /// Todas las lecturas de cada analito: una por fuente que aplique.
  Map<String, List<LabReading>> evaluate(List<LabReferenceRange> ranges) => {
    for (final r in results) r.analyteKey: r.readings(species, ranges),
  };

  /// Cuántos resultados quedaron sin juicio por falta de rango o de unidad.
  int unjudged(List<LabReferenceRange> ranges) => evaluate(
    ranges,
  ).values.where((lecturas) => !lecturas.any((l) => l.judged)).length;

  /// Analitos cuyas fuentes no dicen lo mismo. La pantalla debe mostrarlos
  /// con las dos lecturas y su referencia, para que el profesional elija.
  List<String> disputed(List<LabReferenceRange> ranges) => [
    for (final r in results)
      if (r.agreedFlag(species, ranges) == null) r.analyteKey,
  ];
}

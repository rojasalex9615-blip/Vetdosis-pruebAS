import 'lab_repository.dart';

/// Un valor candidato extraído por OCR de un reporte de laboratorio.
///
/// Es solo una ayuda de captura: no verifica nada, no inventa rangos y no
/// guarda nada. El profesional revisa y corrige antes de registrar la toma.
class LabReportCandidate {
  const LabReportCandidate({
    required this.analyte,
    required this.value,
    required this.unit,
    required this.line,
  });

  final String analyte, value, unit;

  /// La línea original de la que salió, para poder contrastarla.
  final String line;

  bool get complete =>
      analyte.trim().isNotEmpty && value.trim().isNotEmpty;
}

final _number = RegExp(r'\d{1,9}(?:\.\d{1,6})?');

// Una coma entre dígitos es separador de miles, no decimal (misma regla que
// LabResult.parseValue). No se adivina: la línea se descarta.
final _ambiguousComma = RegExp(r'\d,\d');

// «Página 1 de 3», «3 de 3»: no es un analito con valor.
final _pageLike = RegExp(r'\d\s+de\s+\d');

final _hasLetter = RegExp(r'[A-Za-zÁÉÍÓÚÑáéíóúñ]');

/// Extrae valores candidatos del texto reconocido por OCR.
///
/// Cuando el analito coincide con uno que la biblioteca conoce para la
/// especie del paciente, se toma SU nombre y SU unidad: son las dos mitades
/// que hacen que el rango de referencia aparezca. Si no coincide, se usa el
/// texto tal como se leyó, para que el profesional lo corrija.
///
/// Es determinista y no toca red ni estado. Las líneas sin número, sin letras
/// antes del número (años, folios) o con coma ambigua se descartan.
List<LabReportCandidate> parseLabReportRows(
  String text, {
  List<LabAnalyte> catalog = const [],
}) {
  final out = <LabReportCandidate>[];
  for (final rawLine in text.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    if (_ambiguousComma.hasMatch(line)) continue;
    if (_pageLike.hasMatch(line)) continue;

    final match = _number.firstMatch(line);
    if (match == null) continue;

    final before = line.substring(0, match.start).trim();
    // Sin letras antes del número es un año, una página o un folio.
    if (!_hasLetter.hasMatch(before)) continue;

    final known = _knownAnalyte(line, catalog);
    final analyte = known?.analyteKey ?? _cleanLabel(before);
    if (analyte.isEmpty) continue;

    final after = line.substring(match.end).trim();
    final leida = _firstToken(after);
    // La unidad impresa manda: reetiquetar un valor en mmol/L como mg/dL lo
    // volveria un dato clinico equivocado con aspecto de correcto. El catalogo
    // solo rellena cuando el reporte no imprime unidad.
    final unit = leida.isNotEmpty
        ? leida
        : (known != null ? known.unit.trim() : '');

    out.add(
      LabReportCandidate(
        analyte: analyte,
        value: match.group(0)!,
        unit: unit,
        line: line,
      ),
    );
  }
  return List.unmodifiable(out);
}

/// El analito conocido cuyo nombre aparece en la línea, el más largo si hay
/// varios (para no confundir «Glucosa» con «Glucosa-6-fosfato»).
///
/// La clave debe aparecer como palabra completa: con `contains` a secas, «Na»
/// coincide dentro de «Creatinina» y «Ca» dentro de «Calcio», y la línea se
/// reetiqueta con el analito equivocado.
LabAnalyte? _knownAnalyte(String line, List<LabAnalyte> catalog) {
  LabAnalyte? best;
  for (final entry in catalog) {
    final key = entry.analyteKey.trim();
    if (key.isEmpty) continue;
    if (!_apareceComoPalabra(line, key)) continue;
    if (best == null || key.length > best.analyteKey.trim().length) {
      best = entry;
    }
  }
  return best;
}

bool _apareceComoPalabra(String line, String key) {
  final patron = RegExp(
    '(?<![\\p{L}\\p{N}])${RegExp.escape(key)}(?![\\p{L}\\p{N}])',
    unicode: true,
    caseSensitive: false,
  );
  return patron.hasMatch(line);
}

String _cleanLabel(String text) {
  final clean = text
      .replaceAll(RegExp(r'[:\-–=]+$'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  // Una etiqueta más larga que esto es una frase, no un analito.
  if (clean.length > 40) return '';
  return clean;
}

String _firstToken(String text) {
  if (text.isEmpty) return '';
  return text
      .split(RegExp(r'\s+'))
      .first
      .replaceAll(RegExp(r'[.,;:]+$'), '');
}

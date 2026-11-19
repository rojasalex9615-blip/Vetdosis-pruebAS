import '../../calculations/data/reference_library_repository.dart';
import 'lab_result.dart';

/// Resuelve los rangos de referencia que aplican a un analito de una especie.
///
/// Es solo lectura y de consulta: alimenta el indicador en vivo de la captura.
/// No interviene en el guardado; el servidor sigue resolviendo los rangos que
/// se anexan al resultado.
abstract interface class LabReferenceResolver {
  Future<List<LabReferenceRange>> rangesFor({
    required String species,
    required String analyte,
    required String unit,
  });
}

/// Resuelve contra la biblioteca de referencias de la clínica (RPC de lectura
/// `reference_review_list`, sección «laboratorio»).
///
/// Las filas sin fuente o sin intervalo numérico se descartan: un rango sin
/// fuente no entra al sistema. Las que aún no revisó un MVZ entran marcadas
/// como no verificadas, igual que en la vista de resultados.
class ReferenceLibraryLabResolver implements LabReferenceResolver {
  const ReferenceLibraryLabResolver(this.repository, this.clinicId);

  final ReferenceLibraryRepository repository;
  final String clinicId;

  @override
  Future<List<LabReferenceRange>> rangesFor({
    required String species,
    required String analyte,
    required String unit,
  }) async {
    if (species.trim().isEmpty || analyte.trim().isEmpty) return const [];
    final page = await repository.list(clinicId, 'laboratorio', analyte.trim(), 0);
    final out = <LabReferenceRange>[];
    for (final row in page.items) {
      if (!_same('${row['parameter']}', analyte)) continue;
      if (!_same('${row['species']}', species)) continue;
      final low = double.tryParse('${row['min_value']}');
      final high = double.tryParse('${row['max_value']}');
      final rowUnit = '${row['unit']}'.trim();
      final source = '${row['source_title']}'.trim();
      if (low == null || high == null || rowUnit.isEmpty || source.isEmpty) {
        continue;
      }
      try {
        out.add(
          LabReferenceRange(
            analyteKey: analyte.trim(),
            species: species.trim(),
            unit: rowUnit,
            low: low,
            high: high,
            source: source,
            verified: row['review_state'] == 'aprobada_mvz',
          ),
        );
      } on FormatException {
        // Rango inválido en la fuente: no entra al sistema.
      }
    }
    return List.unmodifiable(out);
  }

  static bool _same(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();
}

import 'quantity.dart';
import 'pauta_farmacologica.dart';

/// Resultado de aplicar una pauta al peso del paciente.
///
/// La cuenta es exacta: la dosis publicada se multiplica por el peso sin pasar
/// por coma flotante. El rango se conserva como rango; no se elige un punto
/// medio.
class DosisCalculada {
  const DosisCalculada({
    required this.minimas,
    required this.maximas,
    required this.unidad,
  });

  final Quantity minimas, maximas;

  /// `mg` cuando la pauta está en masa por kilo, `mL` cuando está en volumen.
  final String unidad;

  bool get esRango => minimas.compareTo(maximas) != 0;

  String get texto {
    if (!esRango) return '${minimas.display()} $unidad';
    return '${minimas.display()}–${maximas.display()} $unidad';
  }
}

/// Calcula la dosis de una pauta para un peso.
///
/// Devuelve null cuando la pauta no se puede calcular: sin rango numérico, en
/// una unidad que no se convierte al peso (mg/m², gotas) o con un peso que no
/// es mayor que cero. Nunca inventa un valor.
DosisCalculada? calcularDosisFarmacologica({
  required PautaFarmacologica pauta,
  required Quantity peso,
}) {
  if (!pauta.calculable || !peso.positive) return null;
  final minimas = pauta.dosisMin! * peso;
  final maximas = (pauta.dosisMax ?? pauta.dosisMin!) * peso;
  return DosisCalculada(
    minimas: minimas,
    maximas: maximas.compareTo(minimas) < 0 ? minimas : maximas,
    unidad: pauta.porMasa ? 'mg' : 'mL',
  );
}

/// Estimado de inversión en equipos y materiales. Puro y sin estado: no
/// consulta la red ni guarda nada. Los precios llegan ya normalizados a MXN
/// por la unidad del concepto (pieza, m², plaza); quien los obtiene (búsqueda
/// web o captura manual) es responsable de esa normalización.
FormatException _invalid(String message) => FormatException(message);

/// Un precio encontrado, en centavos de MXN por la unidad del concepto.
class PriceSample {
  const PriceSample(this.cents, {required this.source});
  final int cents;
  final String source;
}

double _quantile(List<int> sorted, double q) {
  if (sorted.length == 1) return sorted.first.toDouble();
  final pos = (sorted.length - 1) * q;
  final lo = pos.floor();
  final hi = pos.ceil();
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo);
}

/// Mediana y rango intercuartil de varios precios. Con 4 o más datos se
/// descartan los que quedan fuera de 1.5 × el rango intercuartil, que suelen
/// ser otra unidad, un accesorio o un error de captura.
class PriceEstimate {
  PriceEstimate._({
    required this.medianCents,
    required this.lowCents,
    required this.highCents,
    required this.used,
    required this.discarded,
    required this.sources,
  });

  /// Mínimo de precios para considerar confiable el estimado.
  static const minReliableSamples = 3;

  factory PriceEstimate.fromSamples(List<PriceSample> samples) {
    final valid = [
      for (final s in samples)
        if (s.cents > 0 && s.cents < 100000000000) s,
    ];
    if (valid.isEmpty) {
      throw _invalid('No hay precios válidos para estimar.');
    }
    final all = [for (final s in valid) s.cents]..sort();
    var kept = valid;
    if (all.length >= 4) {
      final q1 = _quantile(all, 0.25);
      final q3 = _quantile(all, 0.75);
      final iqr = q3 - q1;
      final lo = q1 - 1.5 * iqr;
      final hi = q3 + 1.5 * iqr;
      kept = [
        for (final s in valid)
          if (s.cents >= lo && s.cents <= hi) s,
      ];
    }
    final sorted = [for (final s in kept) s.cents]..sort();
    return PriceEstimate._(
      medianCents: _quantile(sorted, 0.5).round(),
      lowCents: _quantile(sorted, 0.25).round(),
      highCents: _quantile(sorted, 0.75).round(),
      used: sorted.length,
      discarded: valid.length - kept.length,
      sources: {for (final s in kept) s.source}.length,
    );
  }

  final int medianCents, lowCents, highCents;
  final int used, discarded, sources;

  bool get isReliable => used >= minReliableSamples && sources >= 2;
}

/// Un concepto de la lista de compras: «ventilador de 36 pulgadas», pieza.
class InvestmentItem {
  InvestmentItem({
    required this.concept,
    required this.unit,
    required this.quantity,
    this.manualUnitCents,
    this.estimate,
  }) {
    if (concept.trim().isEmpty) throw _invalid('El concepto no puede ir vacío.');
    if (unit.trim().isEmpty) throw _invalid('Indica la unidad del concepto.');
    if (!quantity.isFinite || quantity <= 0 || quantity > 1e9) {
      throw _invalid('Cantidad: mayor que 0.');
    }
    if (manualUnitCents != null &&
        (manualUnitCents! <= 0 || manualUnitCents! > 100000000000)) {
      throw _invalid('Precio manual: mayor que 0.');
    }
  }
  final String concept, unit;
  final double quantity;

  /// Cotización real o precio capturado por el usuario; manda sobre la búsqueda.
  final int? manualUnitCents;
  final PriceEstimate? estimate;

  bool get hasPrice => manualUnitCents != null || estimate != null;
  bool get isManual => manualUnitCents != null;

  /// Con precio manual el rango se cierra en ese precio.
  int? get unitLowCents => manualUnitCents ?? estimate?.lowCents;
  int? get unitMidCents => manualUnitCents ?? estimate?.medianCents;
  int? get unitHighCents => manualUnitCents ?? estimate?.highCents;

  int? _sub(int? unit) => unit == null ? null : (unit * quantity).round();
  int? get lowCents => _sub(unitLowCents);
  int? get midCents => _sub(unitMidCents);
  int? get highCents => _sub(unitHighCents);

  /// Estimado hecho con pocos precios o pocas fuentes.
  bool get isWeak => !isManual && estimate != null && !estimate!.isReliable;
}

class InvestmentPlan {
  InvestmentPlan(this.items) {
    if (items.isEmpty) throw _invalid('Agrega al menos un concepto.');
  }
  final List<InvestmentItem> items;

  int _sum(int? Function(InvestmentItem) pick) =>
      items.fold(0, (acc, i) => acc + (pick(i) ?? 0));

  int get lowCents => _sum((i) => i.lowCents);
  int get midCents => _sum((i) => i.midCents);
  int get highCents => _sum((i) => i.highCents);

  /// Conceptos sin precio: el total NO los incluye.
  List<InvestmentItem> get unpriced => [
    for (final i in items)
      if (!i.hasPrice) i,
  ];
  List<InvestmentItem> get weak => [
    for (final i in items)
      if (i.isWeak) i,
  ];
  bool get isComplete => unpriced.isEmpty;
}

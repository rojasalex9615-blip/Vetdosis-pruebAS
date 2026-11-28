import '../../doses/domain/quantity.dart';
import 'pullet_guide.dart';

Quantity q(String text) => Quantity.parse(text);
Quantity addQ(Quantity a, Quantity b) =>
    Quantity(a.n * b.d + b.n * a.d, a.d * b.d);
Quantity sumQ(Iterable<Quantity> values) => values.fold(q('0'), addQ);
BigInt roundQ(Quantity v) => v.nearestStep(q('1')).n ~/ v.nearestStep(q('1')).d;
BigInt ceilQ(Quantity v) => (v.n + v.d - BigInt.one) ~/ v.d;
Quantity intQ(BigInt n) => Quantity(n, BigInt.one);

/// Ambos extremos pertenecen a la misma guía y sistema; no se elige un promedio.
class QuantityBand {
  const QuantityBand(this.low, this.high);
  factory QuantityBand.single(Quantity value) => QuantityBand(value, value);
  final Quantity low, high;
  QuantityBand times(Quantity value) => QuantityBand(low * value, high * value);
}

class CountBand {
  const CountBand(this.low, this.high);
  final BigInt low, high;
}

class RearingStage {
  const RearingStage({
    required this.name,
    required this.firstWeek,
    required this.lastWeek,
    this.price = '',
    this.density = '',
  });
  final String name, price, density;
  final int firstWeek, lastWeek;
  Map<String, dynamic> toJson() => {
    'name': name,
    'firstWeek': firstWeek,
    'lastWeek': lastWeek,
    'price': price,
    'density': density,
  };
  factory RearingStage.read(Map<String, dynamic> r) => RearingStage(
    name: r['name'] as String,
    firstWeek: r['firstWeek'] as int,
    lastWeek: r['lastWeek'] as int,
    price: r['price'] as String,
    density: r['density'] as String,
  );
}

/// Equipo y vacunas comparten aritmética, no recomendaciones de aplicación.
class RearingItem {
  const RearingItem({
    required this.name,
    required this.basis,
    required this.coverage,
    this.price = '',
    this.applications = 1,
    this.source = '',
    this.enabled = true,
  });
  final String name, basis, coverage, price, source;
  final int applications;
  final bool enabled;
  Map<String, dynamic> toJson() => {
    'name': name,
    'basis': basis,
    'coverage': coverage,
    'price': price,
    'applications': applications,
    'source': source,
    'enabled': enabled,
  };
  factory RearingItem.read(Map<String, dynamic> r) => RearingItem(
    name: r['name'] as String,
    basis: r['basis'] as String,
    coverage: r['coverage'] as String,
    price: r['price'] as String,
    applications: r['applications'] as int,
    source: r['source'] as String,
    enabled: r['enabled'] as bool,
  );
}

class PulletRearingPlan {
  const PulletRearingPlan({
    required this.name,
    required this.brand,
    required this.system,
    required this.birds,
    required this.weeks,
    required this.stages,
    this.guide,
    this.waste = '0',
    this.feedOverrides = const {},
    this.mortalityOverrides = const {},
    this.weightOverrides = const {},
    this.lightOverrides = const {},
    this.adjustMortality = false,
    this.equipment = const [],
    this.vaccines = const [],
    this.chickPrice = '',
    this.gasPerBird = '',
    this.beddingKgPerBird = '',
    this.beddingPriceKg = '',
    this.electricityPrice = '',
    this.electricityPeriods = '',
    this.electricityPerBird = false,
    this.linearMetres = '',
    this.margin = '',
  });
  final String name,
      brand,
      system,
      birds,
      waste,
      chickPrice,
      gasPerBird,
      beddingKgPerBird,
      beddingPriceKg,
      electricityPrice,
      electricityPeriods,
      linearMetres,
      margin;
  final int weeks;
  final List<RearingStage> stages;
  final PulletGuide? guide;
  final Map<int, String> feedOverrides,
      mortalityOverrides,
      weightOverrides,
      lightOverrides;
  final bool adjustMortality, electricityPerBird;
  final List<RearingItem> equipment, vaccines;

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'name': name,
    'brand': brand,
    'system': system,
    'birds': birds,
    'weeks': weeks,
    'stages': stages.map((s) => s.toJson()).toList(),
    'guide': guide?.toJson(),
    'waste': waste,
    'feedOverrides': feedOverrides.map((k, v) => MapEntry('$k', v)),
    'mortalityOverrides': mortalityOverrides.map((k, v) => MapEntry('$k', v)),
    'weightOverrides': weightOverrides.map((k, v) => MapEntry('$k', v)),
    'lightOverrides': lightOverrides.map((k, v) => MapEntry('$k', v)),
    'adjustMortality': adjustMortality,
    'equipment': equipment.map((e) => e.toJson()).toList(),
    'vaccines': vaccines.map((e) => e.toJson()).toList(),
    'chickPrice': chickPrice,
    'gasPerBird': gasPerBird,
    'beddingKgPerBird': beddingKgPerBird,
    'beddingPriceKg': beddingPriceKg,
    'electricityPrice': electricityPrice,
    'electricityPeriods': electricityPeriods,
    'electricityPerBird': electricityPerBird,
    'linearMetres': linearMetres,
    'margin': margin,
  };
  factory PulletRearingPlan.read(Map<String, dynamic> r) {
    if (r['schemaVersion'] != 1) {
      throw const FormatException('Proyecto de versión desconocida.');
    }
    Map<int, String> overrides(String key) => (r[key] as Map? ?? {}).map(
      (k, v) => MapEntry(int.parse('$k'), v as String),
    );
    return PulletRearingPlan(
      name: r['name'] as String,
      brand: r['brand'] as String,
      system: r['system'] as String,
      birds: r['birds'] as String,
      weeks: r['weeks'] as int,
      stages: (r['stages'] as List)
          .map((s) => RearingStage.read(Map<String, dynamic>.from(s as Map)))
          .toList(),
      guide: r['guide'] == null
          ? null
          : PulletGuide(Map<String, dynamic>.from(r['guide'] as Map)),
      waste: r['waste'] as String,
      feedOverrides: overrides('feedOverrides'),
      mortalityOverrides: overrides('mortalityOverrides'),
      weightOverrides: overrides('weightOverrides'),
      lightOverrides: overrides('lightOverrides'),
      adjustMortality: r['adjustMortality'] as bool,
      equipment: (r['equipment'] as List)
          .map((e) => RearingItem.read(Map<String, dynamic>.from(e as Map)))
          .toList(),
      vaccines: (r['vaccines'] as List)
          .map((e) => RearingItem.read(Map<String, dynamic>.from(e as Map)))
          .toList(),
      chickPrice: r['chickPrice'] as String,
      gasPerBird: r['gasPerBird'] as String,
      beddingKgPerBird: r['beddingKgPerBird'] as String,
      beddingPriceKg: r['beddingPriceKg'] as String,
      electricityPrice: r['electricityPrice'] as String,
      electricityPeriods: r['electricityPeriods'] as String,
      electricityPerBird: r['electricityPerBird'] as bool,
      linearMetres: r['linearMetres'] as String,
      margin: r['margin'] as String,
    );
  }
}

class WeeklyRearingBudget {
  const WeeklyRearingBudget({
    required this.week,
    required this.stage,
    required this.feed,
    required this.alive,
    required this.consumption,
    required this.purchase,
    required this.cost,
    required this.source,
    required this.edited,
    required this.mortalitySource,
  });
  final int week;
  final RearingStage stage;
  final QuantityBand? feed, consumption;
  final Quantity? alive;
  final CountBand? purchase, cost;
  final String source, mortalitySource;
  final bool edited;
}

class StageRearingBudget {
  const StageRearingBudget(this.stage, this.purchase, this.cost, this.area);
  final RearingStage stage;
  final CountBand? purchase, cost;
  final BigInt? area;
}

class ItemRearingBudget {
  const ItemRearingBudget(this.item, this.count, this.cost);
  final RearingItem item;
  final BigInt? count, cost;
}

class PulletRearingResult {
  const PulletRearingResult({
    required this.plan,
    required this.weekly,
    required this.stages,
    required this.equipment,
    required this.vaccines,
    required this.categories,
    required this.consumption,
    required this.purchase,
    required this.total,
    required this.knownSubtotal,
    required this.costPerBird,
    required this.salePrice,
    required this.beddingKg,
    required this.warnings,
  });
  final PulletRearingPlan plan;
  final List<WeeklyRearingBudget> weekly;
  final List<StageRearingBudget> stages;
  final List<ItemRearingBudget> equipment, vaccines;
  final Map<String, CountBand?> categories;
  final QuantityBand? consumption;
  final CountBand? purchase, total, knownSubtotal, costPerBird, salePrice;
  final Quantity? beddingKg;
  final List<String> warnings;
  bool get complete => total != null;
  BigInt? get area => stages.any((s) => s.area == null)
      ? null
      : stages.map((s) => s.area!).reduce((a, b) => a > b ? a : b);
}

/// Entradas decimales exactas. Vacío es desconocido; cero debe ser explícito.
Quantity? _optional(
  String raw,
  String label, {
  bool positive = false,
  bool price = false,
}) {
  if (raw.trim().isEmpty) return null;
  Quantity value;
  try {
    value = q(raw);
  } on FormatException {
    throw FormatException('$label: número no válido.');
  }
  if (positive && !value.positive) {
    throw FormatException('$label debe ser mayor que cero.');
  }
  if (price && (value.n * BigInt.from(100)) % value.d != BigInt.zero) {
    throw FormatException('$label admite hasta dos decimales.');
  }
  return value;
}

Quantity _percent(String raw, String label) {
  final v = _optional(raw, label) ?? q('0');
  if (v.compareTo(q('100')) > 0) {
    throw FormatException('$label debe estar entre 0 y 100 %.');
  }
  return v;
}

CountBand? sumBands(Iterable<CountBand?> input) {
  final values = input.toList();
  if (values.any((v) => v == null)) return null;
  return CountBand(
    values.fold(BigInt.zero, (a, b) => a + b!.low),
    values.fold(BigInt.zero, (a, b) => a + b!.high),
  );
}

CountBand moneyBand(QuantityBand values) =>
    CountBand(roundQ(values.low * q('100')), roundQ(values.high * q('100')));

PulletRearingResult calculatePulletRearing(PulletRearingPlan plan) {
  final birds = _optional(plan.birds, 'Pollitas', positive: true);
  if (birds == null || birds.n % birds.d != BigInt.zero) {
    throw const FormatException(
      'Captura un número entero de pollitas mayor que cero.',
    );
  }
  if (plan.weeks < 1 || plan.weeks > 104) {
    throw const FormatException(
      'La duración debe estar entre 1 y 104 semanas.',
    );
  }
  if (!['piso', 'jaula'].contains(plan.system)) {
    throw const FormatException('Elige piso o jaula.');
  }
  if (plan.guide != null &&
      (plan.guide!.system != plan.system || plan.guide!.brand != plan.brand)) {
    throw const FormatException(
      'La guía no corresponde a la marca y sistema elegidos.',
    );
  }
  if (plan.stages.isEmpty) {
    throw const FormatException('Define las etapas de crianza.');
  }
  var next = 1;
  for (final s in plan.stages) {
    if (s.name.trim().isEmpty ||
        s.firstWeek != next ||
        s.lastWeek < s.firstWeek ||
        s.lastWeek > plan.weeks) {
      throw const FormatException(
        'Las etapas deben cubrir todas las semanas, sin huecos ni traslapes.',
      );
    }
    next = s.lastWeek + 1;
    _optional(s.price, 'Precio de ${s.name}', price: true);
    _optional(s.density, 'Densidad de ${s.name}', positive: true);
  }
  if (next != plan.weeks + 1) {
    throw const FormatException('Las etapas no cubren toda la crianza.');
  }
  final waste = _percent(plan.waste, 'Merma');
  final wasteFactor = addQ(q('1'), waste / q('100'));
  final warnings = <String>[
    if (plan.weeks > 18)
      'La crianza supera 18 semanas. Revisa el periodo y las semanas sin datos de la guía.',
  ];
  final weekly = <WeeklyRearingBudget>[];
  Quantity lastMortality = q('0');
  for (var w = 1; w <= plan.weeks; w++) {
    final stage = plan.stages.firstWhere(
      (s) => w >= s.firstWeek && w <= s.lastWeek,
    );
    final row = plan.guide?.week(w);
    _optional(plan.weightOverrides[w] ?? '', 'Peso semana $w', positive: true);
    final light = _optional(plan.lightOverrides[w] ?? '', 'Luz semana $w');
    if (light != null && light.compareTo(q('24')) > 0) {
      throw FormatException('Luz semana $w: máximo 24 horas por día.');
    }
    final raw = plan.feedOverrides[w]?.trim() ?? '';
    final edited = raw.isNotEmpty;
    QuantityBand? feed;
    if (edited) {
      feed = QuantityBand.single(
        _optional(raw, 'Consumo semana $w', positive: true)!,
      );
    } else if (row?['feedMin'] != null) {
      feed = QuantityBand(q('${row!['feedMin']}'), q('${row['feedMax']}'));
    }
    Quantity? alive = birds;
    var mortalitySource = 'Consumo calculado con las pollitas alojadas.';
    if (plan.adjustMortality) {
      final custom = plan.mortalityOverrides[w]?.trim() ?? '';
      final mortality = custom.isNotEmpty
          ? _percent(custom, 'Mortalidad semana $w')
          : row?['mortality'] == null
          ? null
          : _percent('${row!['mortality']}', 'Mortalidad de guía');
      if (mortality == null) {
        alive = null;
        mortalitySource = 'Sin mortalidad acumulada para esta semana.';
      } else {
        if (mortality.compareTo(lastMortality) < 0) {
          throw const FormatException(
            'La mortalidad acumulada no puede disminuir.',
          );
        }
        lastMortality = mortality;
        alive =
            birds *
            Quantity(
              q('100').n * mortality.d - mortality.n,
              q('100').d * mortality.d,
            ) /
            q('100');
        mortalitySource = custom.isNotEmpty
            ? 'Mortalidad editada por el usuario'
            : plan.guide!.source(w);
      }
    }
    final consumption = feed == null || alive == null
        ? null
        : feed.times(alive * q('7') / q('1000'));
    final purchase = consumption == null
        ? null
        : CountBand(
            roundQ(consumption.low * wasteFactor),
            roundQ(consumption.high * wasteFactor),
          );
    final price = _optional(stage.price, 'Precio ${stage.name}', price: true);
    final cost = purchase == null || price == null
        ? null
        : moneyBand(
            QuantityBand(
              intQ(purchase.low) * price,
              intQ(purchase.high) * price,
            ),
          );
    weekly.add(
      WeeklyRearingBudget(
        week: w,
        stage: stage,
        feed: feed,
        alive: alive,
        consumption: consumption,
        purchase: purchase,
        cost: cost,
        source: edited
            ? 'Editado por el usuario'
            : row?['feedMin'] == null
            ? 'Sin datos de guía para esta línea/semana.'
            : plan.guide!.source(w),
        edited: edited,
        mortalitySource: mortalitySource,
      ),
    );
  }
  final stages = <StageRearingBudget>[];
  for (final s in plan.stages) {
    final lines = weekly.where((w) => identical(w.stage, s));
    final density = _optional(s.density, 'Densidad ${s.name}', positive: true);
    stages.add(
      StageRearingBudget(
        s,
        sumBands(lines.map((w) => w.purchase)),
        sumBands(lines.map((w) => w.cost)),
        density == null ? null : ceilQ(birds / density),
      ),
    );
  }
  final area = stages.any((s) => s.area == null)
      ? null
      : stages.map((s) => s.area!).reduce((a, b) => a > b ? a : b);
  List<ItemRearingBudget> itemBudgets(List<RearingItem> items) =>
      items.where((i) => i.enabled).map((i) {
        if (i.name.trim().isEmpty ||
            !['birds', 'area', 'linear'].contains(i.basis) ||
            i.applications < 1) {
          throw const FormatException(
            'Revisa nombre, base y aplicaciones de equipo o vacunas.',
          );
        }
        final coverage = _optional(
          i.coverage,
          'Razón de ${i.name}',
          positive: true,
        );
        final base = i.basis == 'birds'
            ? birds
            : i.basis == 'area'
            ? (area == null ? null : intQ(area))
            : _optional(plan.linearMetres, 'Metros lineales', positive: true);
        final count = coverage == null || base == null
            ? null
            : ceilQ(base / coverage) * BigInt.from(i.applications);
        final price = _optional(i.price, 'Precio de ${i.name}', price: true);
        final cost = count == null || price == null
            ? null
            : roundQ(intQ(count) * price * q('100'));
        return ItemRearingBudget(i, count, cost);
      }).toList();
  final equipment = itemBudgets(plan.equipment),
      vaccines = itemBudgets(plan.vaccines);
  CountBand? itemTotal(List<ItemRearingBudget> items) =>
      items.any((i) => i.cost == null)
      ? null
      : CountBand(
          items.fold(BigInt.zero, (a, b) => a + b.cost!),
          items.fold(BigInt.zero, (a, b) => a + b.cost!),
        );
  CountBand? perBird(String raw, String label) {
    final price = _optional(raw, label, price: true);
    return price == null ? null : moneyBand(QuantityBand.single(price * birds));
  }

  final bedKg = _optional(plan.beddingKgPerBird, 'Cama kg/ave');
  final beddingKg = bedKg == null ? null : birds * bedKg;
  final bedPrice = _optional(
    plan.beddingPriceKg,
    'Precio de cama',
    price: true,
  );
  final electricity = _optional(
    plan.electricityPrice,
    'Precio de luz',
    price: true,
  );
  final periods = plan.electricityPerBird
      ? birds
      : _optional(plan.electricityPeriods, 'Bimestres');
  final categories = <String, CountBand?>{
    'Alimento': sumBands(weekly.map((w) => w.cost)),
    'Pollitas': perBird(plan.chickPrice, 'Precio de pollita'),
    'Equipo': itemTotal(equipment),
    'Vacunas': itemTotal(vaccines),
    'Gas': perBird(plan.gasPerBird, 'Gas por ave'),
    'Cama': beddingKg == null || bedPrice == null
        ? null
        : moneyBand(QuantityBand.single(beddingKg * bedPrice)),
    'Luz': electricity == null || periods == null
        ? null
        : moneyBand(QuantityBand.single(electricity * periods)),
  };
  final total = sumBands(categories.values);
  final known = sumBands(categories.values.where((v) => v != null));
  final costPerBird = total == null
      ? null
      : CountBand(
          roundQ(intQ(total.low) / birds),
          roundQ(intQ(total.high) / birds),
        );
  final margin = plan.margin.trim().isEmpty
      ? null
      : _optional(plan.margin, 'Margen');
  // Apply the markup to the exact cost per bird, round only the displayed cents.
  final sale = total == null || margin == null
      ? null
      : CountBand(
          roundQ(intQ(total.low) / birds * addQ(q('1'), margin / q('100'))),
          roundQ(intQ(total.high) / birds * addQ(q('1'), margin / q('100'))),
        );
  QuantityBand? consumption;
  if (weekly.every((w) => w.consumption != null)) {
    consumption = QuantityBand(
      sumQ(weekly.map((w) => w.consumption!.low)),
      sumQ(weekly.map((w) => w.consumption!.high)),
    );
  }
  final missing = weekly
      .where((w) => w.consumption == null)
      .map((w) => w.week)
      .join(', ');
  if (missing.isNotEmpty) {
    warnings.add(
      'Faltan consumo o mortalidad en semanas: $missing. No se completa el total de alimento.',
    );
  }
  final missingCosts = categories.entries
      .where((e) => e.value == null)
      .map((e) => e.key)
      .join(', ');
  if (missingCosts.isNotEmpty) {
    warnings.add(
      'Costo pendiente en: $missingCosts. El subtotal capturado no es el costo total.',
    );
  }
  if (plan.weeks == 17 && consumption != null) {
    final ref = plan.guide?.week(17);
    if (ref?['cumulativeMin'] != null) {
      final lo = q('${ref!['cumulativeMin']}') / q('1000'),
          hi = q('${ref['cumulativeMax']}') / q('1000');
      if ((consumption.low / birds).compareTo(lo) < 0 ||
          (consumption.high / birds).compareTo(hi) > 0) {
        warnings.add(
          'El consumo calculado por ave a 17 semanas sale total o parcialmente del rango acumulado publicado '
          '(${lo.display()}–${hi.display()} kg/ave; ${plan.guide!.source(17)}). Compara consumo sin merma, no compra.',
        );
      }
    }
  }
  return PulletRearingResult(
    plan: plan,
    weekly: weekly,
    stages: stages,
    equipment: equipment,
    vaccines: vaccines,
    categories: categories,
    consumption: consumption,
    purchase: sumBands(weekly.map((w) => w.purchase)),
    total: total,
    knownSubtotal: known,
    costPerBird: costPerBird,
    salePrice: sale,
    beddingKg: beddingKg,
    warnings: warnings,
  );
}

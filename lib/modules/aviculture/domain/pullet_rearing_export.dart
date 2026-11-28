import '../../../vet_ui/vet_format.dart';
import 'pullet_rearing.dart';

String rearingMoney(CountBand? v) {
  if (v == null) return 'Sin costo completo';
  final lo = VetFormat.moneyFromCents(v.low),
      hi = VetFormat.moneyFromCents(v.high);
  return v.low == v.high ? lo : '$lo – $hi';
}

String rearingCount(CountBand? v, {String unit = 'kg'}) => v == null
    ? 'Sin datos completos'
    : '${VetFormat.thousands(v.low)}${v.low == v.high ? '' : '–${VetFormat.thousands(v.high)}'} $unit';
String rearingQuantity(QuantityBand? v, {int places = 1, String unit = 'kg'}) =>
    v == null
    ? 'Sin datos completos'
    : '${v.low.display(places: places)}${v.low.compareTo(v.high) == 0 ? '' : '–${v.high.display(places: places)}'} $unit';

List<List<String>> pulletRearingExportRows(PulletRearingResult result) {
  final p = result.plan;
  final rows = <List<String>>[
    ['Sección', 'Dato', 'Mínimo', 'Máximo', 'Unidad', 'Fuente / captura'],
    [
      'Proyecto',
      p.name,
      p.brand,
      p.system,
      '',
      'Presupuesto de crianza; no es registro de granja',
    ],
    ['Entrada', 'Pollitas alojadas', p.birds, '', 'aves', 'Usuario'],
    ['Entrada', 'Duración', '${p.weeks}', '', 'semanas', 'Usuario'],
    ['Entrada', 'Merma', p.waste, '', '%', 'Usuario'],
    [
      'Entrada',
      'Ajustar consumo por mortalidad',
      p.adjustMortality ? 'Sí' : 'No',
      '',
      '',
      'Usuario',
    ],
    [
      'Referencia',
      p.guide?.citation ?? 'Captura propia',
      p.guide?.url ?? '',
      '',
      '',
      p.guide?.data['sha256'] as String? ?? '',
    ],
    [
      'Referencia',
      'Alcance',
      'Se conserva la guía del proyecto; no se mezclan ediciones.',
      '',
      '',
      '',
    ],
  ];
  for (final row in <List<String>>[
    ['Precio pollita', p.chickPrice, 'MXN/ave'],
    ['Gas', p.gasPerBird, 'MXN/ave'],
    ['Cama', p.beddingKgPerBird, 'kg/ave'],
    ['Precio cama', p.beddingPriceKg, 'MXN/kg'],
    [
      'Luz',
      p.electricityPrice,
      p.electricityPerBird ? 'MXN/ave' : 'MXN/bimestre',
    ],
    ['Bimestres', p.electricityPeriods, 'bimestres'],
    ['Longitud de divisiones', p.linearMetres, 'm'],
    ['Margen sobre costo', p.margin, '%'],
  ]) {
    rows.add([
      'Entrada',
      row[0],
      row[1].isEmpty ? 'Sin capturar' : row[1],
      '',
      row[2],
      'Usuario',
    ]);
  }
  void cost(
    String section,
    String label,
    CountBand? v,
    String origin,
  ) => rows.add([
    section,
    label,
    v == null
        ? 'Pendiente'
        : VetFormat.amount(
            '${v.low ~/ BigInt.from(100)}.${(v.low % BigInt.from(100)).toString().padLeft(2, '0')}',
          ),
    v == null
        ? 'Pendiente'
        : VetFormat.moneyFromCents(v.high).replaceAll(' MXN', ''),
    'MXN',
    origin,
  ]);
  cost(
    'Resumen',
    'Costo total',
    result.total,
    'Incluye todos los rubros solo si están capturados',
  );
  cost(
    'Resumen',
    'Subtotal capturado',
    result.knownSubtotal,
    'Excluye rubros pendientes',
  );
  cost(
    'Resumen',
    'Costo por pollona alojada',
    result.costPerBird,
    'Dividido entre las pollitas alojadas',
  );
  cost(
    'Resumen',
    'Precio de venta',
    result.salePrice,
    'Margen sobre costo: ${p.margin}%',
  );
  rows.add([
    'Resumen',
    'Compra de alimento',
    result.purchase?.low.toString() ?? 'Pendiente',
    result.purchase?.high.toString() ?? 'Pendiente',
    'kg',
    'Redondeo semanal al kg más cercano',
  ]);
  for (final s in result.stages) {
    rows.add([
      'Etapa',
      s.stage.name,
      '${s.stage.firstWeek}',
      '${s.stage.lastWeek}',
      'semanas',
      'Precio ${s.stage.price} MXN/kg; densidad ${s.stage.density} aves/m²',
    ]);
    rows.add([
      'Espacio',
      s.stage.name,
      s.area?.toString() ?? 'Pendiente',
      '',
      'm²',
      'Redondeado hacia arriba',
    ]);
    cost('Etapa', s.stage.name, s.cost, 'Suma de costos semanales de la etapa');
  }
  for (final w in result.weekly) {
    rows.add([
      'Consumo diario',
      'Semana ${w.week}',
      w.feed?.low.display() ?? 'Sin datos',
      w.feed?.high.display() ?? 'Sin datos',
      'g/ave/día',
      w.source,
    ]);
    rows.add([
      'Consumo semanal',
      'Semana ${w.week}',
      w.consumption?.low.display(places: 1) ?? 'Sin datos',
      w.consumption?.high.display(places: 1) ?? 'Sin datos',
      'kg',
      w.mortalitySource,
    ]);
    rows.add([
      'Compra semanal',
      'Semana ${w.week}',
      w.purchase?.low.toString() ?? 'Sin datos',
      w.purchase?.high.toString() ?? 'Sin datos',
      'kg',
      w.source,
    ]);
    for (final field in ['weight', 'light', 'cumulative']) {
      final reference = p.guide?.week(w.week);
      final override = field == 'weight'
          ? p.weightOverrides[w.week]
          : field == 'light'
          ? p.lightOverrides[w.week]
          : null;
      rows.add([
        'Referencia semanal',
        field == 'weight'
            ? 'Peso semana ${w.week}'
            : field == 'light'
            ? 'Luz semana ${w.week}'
            : 'Consumo acumulado semana ${w.week}',
        override ?? '${reference?['${field}Min'] ?? 'Sin datos'}',
        override ?? '${reference?['${field}Max'] ?? 'Sin datos'}',
        field == 'weight'
            ? 'g'
            : field == 'light'
            ? 'h/día'
            : 'g/ave',
        override != null
            ? 'Editado por el usuario'
            : p.guide?.source(w.week, field: field) ?? 'Sin guía',
      ]);
    }
    cost(
      'Costo semanal',
      'Semana ${w.week}',
      w.cost,
      '${w.stage.name} · ${w.stage.price} MXN/kg',
    );
  }
  for (final e in [...result.equipment, ...result.vaccines]) {
    rows.add([
      'Piezas / frascos',
      e.item.name,
      e.count?.toString() ?? 'Pendiente',
      '',
      'piezas',
      'Razón ${e.item.coverage}; ${e.item.applications} aplicaciones; ${e.item.source}',
    ]);
    cost(
      'Equipo / vacunas',
      e.item.name,
      e.cost == null ? null : CountBand(e.cost!, e.cost!),
      'Precio ${e.item.price} MXN/pieza',
    );
  }
  for (final e in result.categories.entries) {
    cost('Desglose', e.key, e.value, 'Capturado por el usuario');
  }
  for (final v in result.warnings) {
    rows.add(['Aviso', v, '', '', '', '']);
  }
  for (final note in p.guide?.notes ?? <String>[]) {
    rows.add(['Nota de guía', note, '', '', '', p.guide!.citation]);
  }
  return rows;
}

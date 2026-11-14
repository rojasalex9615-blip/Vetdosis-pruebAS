import 'package:flutter/material.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_theme.dart';
import '../../finance/domain/investment_estimate.dart';
import '../domain/porcino_calculators.dart';
import '../domain/porcino_capacity.dart';
import '../domain/porcino_reference.dart';
import 'growth_panel.dart';
import '../../../vet_ui/vet_icons.dart';

/// Paneles del módulo Porcinos para cada actividad. Cálculos de sesión: no
/// guardan registros de granja ni consultan Supabase.
List<Widget> porcinoPanelsFor(String activity, {required bool showCosts}) {
  const notice = VetNotice(
    text:
        'Cálculos de sesión con valores de referencia de clase. No guardan registros de granja y no son metas de rendimiento.',
    icon: VetIcons.clipboardChecks,
  );
  return switch (activity) {
    'Reproducción y gestación' => [
      notice,
      const PorcinoFlowPanel(),
      const _Gap(),
      const PorcinoInverseCapacityPanel(),
      const _Gap(),
      PorcinoVentilationPanel(stages: _ventStages(['Gestación'])),
      const _Gap(),
      const PorcinoSiloPanel(
        title: 'Silo para gestación',
        phases: porcinoGestationFeed,
      ),
      const _Gap(),
      const PorcinoReferenceCard(
        title: 'Referencias de reproducción',
        rows: porcinoReproductionReference,
      ),
    ],
    'Maternidad y destete' => [
      notice,
      PorcinoVentilationPanel(stages: _ventStages(['Maternidad', 'Destete'])),
      const _Gap(),
      const PorcinoSpacePanel(
        title: 'Espacio en destete',
        weights: porcinoNurseryWeights,
        icon: VetIcons.grid,
      ),
      const _Gap(),
      const PorcinoSiloPanel(
        title: 'Silo para maternidad y destete',
        phases: [...porcinoMaternityFeed, ...porcinoNurseryFeed],
      ),
      const _Gap(),
      const PorcinoReferenceCard(
        title: 'Referencias de maternidad y destete',
        rows: porcinoMaternityReference,
      ),
    ],
    'Crecimiento y engorda' => [
      notice,
      GrowthPanel(showCosts: showCosts),
      const _Gap(),
      PorcinoVentilationPanel(
        stages: _ventStages(['Engorda', 'Destete a finalización (WTF)']),
      ),
      const _Gap(),
      const PorcinoSpacePanel(
        title: 'Espacio en engorda',
        weights: porcinoFinishingWeights,
        icon: VetIcons.grid,
      ),
      const _Gap(),
      const PorcinoSiloPanel(
        title: 'Silo para desarrollo y finalización',
        phases: porcinoGrowingFeed,
      ),
      const _Gap(),
      const PorcinoReferenceCard(
        title: 'Referencias de crecimiento y engorda',
        rows: porcinoGrowingReference,
      ),
    ],
    'Planeación financiera' => [
      notice,
      if (showCosts)
        const PorcinoInvestmentPanel()
      else
        const VetNotice(
          text:
              'La estimación de inversión requiere el permiso de Planeación financiera.',
          icon: VetIcons.lock,
          kind: VetBadgeKind.warning,
        ),
    ],
    'Bioseguridad y ambiente' => [
      notice,
      const PorcinoBiosecurityPanel(),
      const _Gap(),
      const PorcinoNitrogenPanel(),
    ],
    _ => const <Widget>[],
  };
}

List<VentStage> _ventStages(List<String> names) => [
  for (final n in names) ventilationStages.firstWhere((s) => s.name == n),
];

class _Gap extends StatelessWidget {
  const _Gap();
  @override
  Widget build(BuildContext context) => const SizedBox(height: 16);
}

double _decimal(TextEditingController c, String label) {
  final raw = c.text.trim();
  if (!RegExp(r'^\d+(?:[.,]\d+)?$').hasMatch(raw)) {
    throw FormatException('$label: usa números sin separadores de miles.');
  }
  return double.parse(raw.replaceAll(',', '.'));
}

int _whole(TextEditingController c, String label) {
  final value = int.tryParse(c.text.trim());
  if (value == null) throw FormatException('$label: debe ser un número entero.');
  return value;
}

String _fmt(double v, [int decimals = 2]) {
  final fixed = v.toStringAsFixed(decimals);
  if (!fixed.contains('.')) return fixed;
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title, subtitle;
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VetIconBox(icon: icon, accent: VetColors.pink, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.onChanged,
    this.helper,
    this.decimal = false,
  });
  final TextEditingController controller;
  final String label;
  final String? helper;
  final bool decimal;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      decoration: InputDecoration(labelText: label, helperText: helper),
      onChanged: (_) => onChanged(),
    ),
  );
}

class _Results extends StatelessWidget {
  const _Results(this.rows);
  final List<(String, String)> rows;
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VetColors.recessed,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VetColors.softShadow),
      ),
      child: Column(
        children: [
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(label, style: textTheme.bodyMedium)),
                  const SizedBox(width: 12),
                  Text(
                    value,
                    textAlign: TextAlign.right,
                    style: textTheme.titleSmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Vientres → partos por semana, lechones destetados y espacios por etapa.
class PorcinoFlowPanel extends StatefulWidget {
  const PorcinoFlowPanel({super.key});
  @override
  State<PorcinoFlowPanel> createState() => _PorcinoFlowPanelState();
}

class _PorcinoFlowPanelState extends State<PorcinoFlowPanel> {
  final sows = TextEditingController();
  final weaned = TextEditingController();
  final factor = TextEditingController(text: '25');
  final maternityWeeks = TextEditingController(text: '4');
  final nurseryWeeks = TextEditingController(text: '8');
  final finishingWeeks = TextEditingController(text: '16');
  SwineFlowPlan? result;
  String? error;

  @override
  void dispose() {
    for (final c in [
      sows,
      weaned,
      factor,
      maternityWeeks,
      nurseryWeeks,
      finishingWeeks,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void reset() => setState(() {
    result = null;
    error = null;
  });

  void example() {
    sows.text = '2400';
    weaned.text = '10';
    factor.text = '25';
    maternityWeeks.text = '4';
    nurseryWeeks.text = '8';
    finishingWeeks.text = '16';
    calculate();
  }

  void calculate() {
    setState(() {
      result = null;
      error = null;
      try {
        result = SwineFlowPlan(
          sows: _whole(sows, 'Vientres'),
          weanedPerLitter: _decimal(weaned, 'Destetados por parto'),
          factor: _decimal(factor, 'Factor'),
          maternityWeeks: _whole(maternityWeeks, 'Semanas en maternidad'),
          nurseryWeeks: _whole(nurseryWeeks, 'Semanas en destete'),
          finishingWeeks: _whole(finishingWeeks, 'Semanas en engorda'),
        );
      } on FormatException catch (e) {
        error = e.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = result;
    return VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelHeader(
            icon: VetIcons.hierarchy,
            title: 'Flujo de bandas y capacidad',
            subtitle: 'De vientres a partos por semana, lechones y espacios.',
          ),
          _Field(
            controller: sows,
            label: 'Vientres productivos',
            onChanged: reset,
          ),
          _Field(
            controller: weaned,
            label: 'Lechones destetados por parto',
            decimal: true,
            helper: 'Clase: 9.0 promedio · 10.0 Top 10 %',
            onChanged: reset,
          ),
          _Field(
            controller: factor,
            label: 'Factor (vientres por parto semanal)',
            decimal: true,
            helper: 'Sistema simple de clase: 25',
            onChanged: reset,
          ),
          Row(
            children: [
              Expanded(
                child: _Field(
                  controller: maternityWeeks,
                  label: 'Sem. maternidad',
                  onChanged: reset,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Field(
                  controller: nurseryWeeks,
                  label: 'Sem. destete',
                  onChanged: reset,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Field(
                  controller: finishingWeeks,
                  label: 'Sem. engorda',
                  onChanged: reset,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          VetActionButton(
            icon: VetIcons.calculator,
            label: 'Calcular flujo',
            onPressed: calculate,
          ),
          TextButton(
            onPressed: example,
            child: const Text('Usar ejemplo Modelo 2400'),
          ),
          if (error != null)
            VetNotice(
              text: error!,
              icon: VetIcons.alertOctagon,
              kind: VetBadgeKind.danger,
            ),
          if (r != null) ...[
            _Results([
              ('Partos por semana', _fmt(r.farrowingsPerWeek)),
              ('Lechones destetados por semana', _fmt(r.pigletsPerWeek, 1)),
              ('Jaulas de maternidad', '${r.maternityCrates}'),
              ('Lugares de destete', '${r.nurseryPlaces}'),
              ('Lugares de engorda', '${r.finishingPlaces}'),
            ]),
            const SizedBox(height: 10),
            Text(
              'Procedimiento: partos/semana = vientres ÷ factor; lechones/semana = partos × destetados por parto; espacios = lechones/semana × semanas de ocupación (la semana «+1» de limpieza va incluida en cada cifra).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// Capacidad de silo = animales × consumo diario × días de inventario.
class PorcinoSiloPanel extends StatefulWidget {
  const PorcinoSiloPanel({
    super.key,
    required this.title,
    required this.phases,
  });
  final String title;
  final List<PorcinoFeedPhase> phases;
  @override
  State<PorcinoSiloPanel> createState() => _PorcinoSiloPanelState();
}

class _PorcinoSiloPanelState extends State<PorcinoSiloPanel> {
  final animals = TextEditingController();
  final days = TextEditingController();
  late final consumption = TextEditingController(
    text: _fmt(widget.phases.first.kgPerHeadDay, 1),
  );
  int phase = 0;
  SiloSizing? result;
  String? error;

  @override
  void dispose() {
    animals.dispose();
    days.dispose();
    consumption.dispose();
    super.dispose();
  }

  void reset() => setState(() {
    result = null;
    error = null;
  });

  void calculate() {
    setState(() {
      result = null;
      error = null;
      try {
        result = SiloSizing(
          animals: _whole(animals, 'Animales'),
          kgPerHeadDay: _decimal(consumption, 'Consumo diario'),
          inventoryDays: _whole(days, 'Días de inventario'),
        );
      } on FormatException catch (e) {
        error = e.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = result;
    return VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(
            icon: VetIcons.box,
            title: widget.title,
            subtitle:
                'Animales × consumo diario × días de inventario deseado.',
          ),
          if (widget.phases.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (i, p) in widget.phases.indexed)
                    ChoiceChip(
                      label: Text(p.name),
                      selected: phase == i,
                      onSelected: (_) => setState(() {
                        phase = i;
                        consumption.text = _fmt(p.kgPerHeadDay, 1);
                        result = null;
                        error = null;
                      }),
                    ),
                ],
              ),
            ),
          _Field(controller: animals, label: 'Animales', onChanged: reset),
          _Field(
            controller: consumption,
            label: 'Consumo diario (kg/cabeza/día)',
            decimal: true,
            helper:
                'Referencia de clase para ${widget.phases[phase].name.toLowerCase()}: ${_fmt(widget.phases[phase].kgPerHeadDay, 1)}. Edítalo con el dato de tu granja.',
            onChanged: reset,
          ),
          _Field(
            controller: days,
            label: 'Días de inventario deseado',
            onChanged: reset,
          ),
          const SizedBox(height: 8),
          VetActionButton(
            icon: VetIcons.calculator,
            label: 'Calcular silo',
            onPressed: calculate,
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: VetNotice(
                text: error!,
                icon: VetIcons.alertOctagon,
                kind: VetBadgeKind.danger,
              ),
            ),
          if (r != null)
            _Results([
              ('Alimento por día', '${_fmt(r.dailyKg, 1)} kg'),
              ('Capacidad requerida', '${_fmt(r.totalKg, 0)} kg'),
              ('Equivale a', '${_fmt(r.totalTons, 2)} t'),
            ]),
        ],
      ),
    );
  }
}

/// Superficie por animal según peso y tipo de piso (tabla de clase, Gonyou 2006).
class PorcinoSpacePanel extends StatefulWidget {
  const PorcinoSpacePanel({
    super.key,
    required this.title,
    required this.weights,
    required this.icon,
  });
  final String title;
  final List<int> weights;
  final IconData icon;
  @override
  State<PorcinoSpacePanel> createState() => _PorcinoSpacePanelState();
}

class _PorcinoSpacePanelState extends State<PorcinoSpacePanel> {
  final animals = TextEditingController();
  int weightIndex = 0;
  PorcinoFloor floor = PorcinoFloor.partial;
  SpaceEstimate? result;
  String? error;

  @override
  void dispose() {
    animals.dispose();
    super.dispose();
  }

  double get density =>
      porcinoSpaceM2[widget.weights[weightIndex]]![floor]!;

  void reset() => setState(() {
    result = null;
    error = null;
  });

  void calculate() {
    setState(() {
      result = null;
      error = null;
      try {
        result = SpaceEstimate(
          animals: _whole(animals, 'Animales'),
          m2PerAnimal: density,
        );
      } on FormatException catch (e) {
        error = e.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = result;
    final textTheme = Theme.of(context).textTheme;
    return VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(
            icon: widget.icon,
            title: widget.title,
            subtitle: 'Superficie según peso del animal y tipo de piso.',
          ),
          Text('Peso del animal', style: textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (i, w) in widget.weights.indexed)
                ChoiceChip(
                  label: Text('$w kg'),
                  selected: weightIndex == i,
                  onSelected: (_) => setState(() {
                    weightIndex = i;
                    result = null;
                    error = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Tipo de piso', style: textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in PorcinoFloor.values)
                ChoiceChip(
                  label: Text('${f.label} (k=${f.k})'),
                  selected: floor == f,
                  onSelected: (_) => setState(() {
                    floor = f;
                    result = null;
                    error = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _Field(
            controller: animals,
            label: 'Animales en el corral o sala',
            helper: 'Densidad de clase: ${_fmt(density)} m² por animal',
            onChanged: reset,
          ),
          const SizedBox(height: 4),
          VetActionButton(
            icon: VetIcons.calculator,
            label: 'Calcular superficie',
            onPressed: calculate,
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: VetNotice(
                text: error!,
                icon: VetIcons.alertOctagon,
                kind: VetBadgeKind.danger,
              ),
            ),
          if (r != null)
            _Results([
              ('Densidad usada', '${_fmt(r.m2PerAnimal)} m²/animal'),
              ('Superficie total', '${_fmt(r.totalM2, 1)} m²'),
            ]),
        ],
      ),
    );
  }
}

/// Referencias de clase, con la cita pegada a cada dato.
///
/// Usa el componente compartido VetReferenceCard para que esta tarjeta se vea
/// y se lea igual que las de cualquier otro modulo. Una fila con varias
/// referencias las muestra todas con su fuente; una fila con una sola hereda
/// la cita del bloque.
class PorcinoReferenceCard extends StatelessWidget {
  const PorcinoReferenceCard({
    super.key,
    required this.title,
    required this.rows,
  });
  final String title;
  final List<PorcinoReferenceRow> rows;
  @override
  Widget build(BuildContext context) => VetReferenceCard(
    title: title,
    badge: 'Referencia de clase',
    rows: [
      for (final row in rows)
        VetReferenceRow(
          label: row.label,
          note: row.note,
          values:
              row.referencias ??
              [VetReferenceValue(row.value, source: porcinoReferenceSource)],
        ),
    ],
  );
}

String _int(double v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

/// Caudal de aire de una sala = animales × tasa de diseño por animal.
class PorcinoVentilationPanel extends StatefulWidget {
  const PorcinoVentilationPanel({super.key, required this.stages});
  final List<VentStage> stages;
  @override
  State<PorcinoVentilationPanel> createState() =>
      _PorcinoVentilationPanelState();
}

class _PorcinoVentilationPanelState extends State<PorcinoVentilationPanel> {
  final animals = TextEditingController();
  int stage = 0;
  VentClimate climate = VentClimate.mild;
  VentTable table = VentTable.imperial;
  VentilationEstimate? result;
  String? error;

  @override
  void dispose() {
    animals.dispose();
    super.dispose();
  }

  VentStage get current => widget.stages[stage];

  void reset() => setState(() {
    result = null;
    error = null;
  });

  void calculate() {
    setState(() {
      result = null;
      error = null;
      try {
        result = VentilationEstimate(
          stage: current,
          climate: climate,
          animals: _whole(animals, 'Animales'),
          table: table,
        );
      } on FormatException catch (e) {
        error = e.message;
      }
    });
  }

  String _range(double lo, double hi, {bool minimum = false}) {
    if (minimum) return '≥ ${_int(lo)}';
    return lo.round() == hi.round() ? _int(lo) : '${_int(lo)} – ${_int(hi)}';
  }

  @override
  Widget build(BuildContext context) {
    final r = result;
    final hasMetric = current.metricM3h != null;
    return VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelHeader(
            icon: VetIcons.wind,
            title: 'Ventilación de la sala',
            subtitle: 'Caudal de aire = animales × tasa de diseño por animal.',
          ),
          if (widget.stages.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (i, s) in widget.stages.indexed)
                    ChoiceChip(
                      label: Text(s.name),
                      selected: stage == i,
                      onSelected: (_) => setState(() {
                        stage = i;
                        if (s.metricM3h == null) table = VentTable.imperial;
                        result = null;
                        error = null;
                      }),
                    ),
                ],
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in VentClimate.values)
                ChoiceChip(
                  label: Text(c.label),
                  selected: climate == c,
                  onSelected: (_) => setState(() {
                    climate = c;
                    result = null;
                    error = null;
                  }),
                ),
            ],
          ),
          if (hasMetric)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text('Tabla en CFM (${current.weightNote})'),
                    selected: table == VentTable.imperial,
                    onSelected: (_) => setState(() {
                      table = VentTable.imperial;
                      result = null;
                    }),
                  ),
                  ChoiceChip(
                    label: Text('Tabla en m³/h (${current.metricWeightNote})'),
                    selected: table == VentTable.metric,
                    onSelected: (_) => setState(() {
                      table = VentTable.metric;
                      result = null;
                    }),
                  ),
                ],
              ),
            ),
          _Field(
            controller: animals,
            label: 'Animales en la sala',
            helper: 'Peso de la etapa: ${current.weightNote}',
            onChanged: reset,
          ),
          const SizedBox(height: 8),
          VetActionButton(
            icon: VetIcons.calculator,
            label: 'Calcular caudal',
            onPressed: calculate,
          ),
          if (error != null)
            VetNotice(
              text: error!,
              icon: VetIcons.alertOctagon,
              kind: VetBadgeKind.danger,
            ),
          if (r != null) ...[
            _Results([
              (
                'Por animal (m³/h)',
                _range(
                  r.perAnimalMinM3h,
                  r.perAnimalMaxM3h,
                  minimum: r.isMinimumOnly,
                ),
              ),
              (
                'Sala completa (m³/h)',
                _range(r.totalMinM3h, r.totalMaxM3h, minimum: r.isMinimumOnly),
              ),
              (
                'Sala completa (CFM)',
                _range(r.totalMinCfm, r.totalMaxCfm, minimum: r.isMinimumOnly),
              ),
            ]),
            const SizedBox(height: 10),
            Text(
              r.isMinimumOnly
                  ? 'La tabla de origen marca «>» para este clima: es un mínimo, no un valor de diseño. Consulta el dato del fabricante de los ventiladores.'
                  : 'Referencia de clase; no sustituye el cálculo del proyecto de ventilación.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 10),
          Text(
            hasMetric
                ? 'Las dos tablas de destete y engorda no coinciden entre sí (por ejemplo, engorda en clima cálido: más de 150 CFM ≈ 255 m³/h contra 200 m³/h). Se muestran ambas tal como están en el material.'
                : 'Conversión: 1 CFM = 1.699 m³/h.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(ventilationSource, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// De cerdos por semana (o de metros cuadrados) a vientres necesarios.
class PorcinoInverseCapacityPanel extends StatefulWidget {
  const PorcinoInverseCapacityPanel({super.key});
  @override
  State<PorcinoInverseCapacityPanel> createState() =>
      _PorcinoInverseCapacityPanelState();
}

class _PorcinoInverseCapacityPanelState
    extends State<PorcinoInverseCapacityPanel> {
  final pigs = TextEditingController();
  final m2 = TextEditingController();
  final density = TextEditingController();
  final cycle = TextEditingController(text: '24');
  final weaned = TextEditingController(text: '30');
  bool fromSpaces = false;
  InverseCapacity? result;
  String? error;

  @override
  void dispose() {
    for (final c in [pigs, m2, density, cycle, weaned]) {
      c.dispose();
    }
    super.dispose();
  }

  void reset() => setState(() {
    result = null;
    error = null;
  });

  void calculate() {
    setState(() {
      result = null;
      error = null;
      try {
        final w = _decimal(weaned, 'Destetados por vientre al año');
        result = fromSpaces
            ? InverseCapacity.fromSpaces(
                totalM2: _decimal(m2, 'Superficie'),
                m2PerPig: _decimal(density, 'm² por cerdo'),
                cycleWeeks: _whole(cycle, 'Semanas de ciclo'),
                weanedPerSowYear: w,
              )
            : InverseCapacity(
                pigsPerWeek: _decimal(pigs, 'Cerdos por semana'),
                weanedPerSowYear: w,
              );
      } on FormatException catch (e) {
        error = e.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = result;
    return VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelHeader(
            icon: VetIcons.swapVert,
            title: 'Capacidad inversa: de la producción a los vientres',
            subtitle:
                'Para remodelar o redimensionar: cuántos vientres sostiene una producción semanal.',
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Tengo cerdos por semana'),
                selected: !fromSpaces,
                onSelected: (_) => setState(() {
                  fromSpaces = false;
                  result = null;
                  error = null;
                }),
              ),
              ChoiceChip(
                label: const Text('Tengo metros cuadrados'),
                selected: fromSpaces,
                onSelected: (_) => setState(() {
                  fromSpaces = true;
                  result = null;
                  error = null;
                }),
              ),
            ],
          ),
          if (!fromSpaces)
            _Field(
              controller: pigs,
              label: 'Cerdos producidos por semana',
              decimal: true,
              onChanged: reset,
            )
          else ...[
            _Field(
              controller: m2,
              label: 'Superficie total de engorda (m²)',
              decimal: true,
              onChanged: reset,
            ),
            _Field(
              controller: density,
              label: 'm² por cerdo',
              decimal: true,
              helper: 'Ejemplo de clase: 1.2 en piso sólido (sistema WTF)',
              onChanged: reset,
            ),
            _Field(
              controller: cycle,
              label: 'Semanas de ciclo',
              helper: 'Ejemplo de clase: 24',
              onChanged: reset,
            ),
          ],
          _Field(
            controller: weaned,
            label: 'Destetados por vientre al año',
            decimal: true,
            helper: 'Referencia de clase: 30 o 35',
            onChanged: reset,
          ),
          const SizedBox(height: 8),
          VetActionButton(
            icon: VetIcons.calculator,
            label: 'Calcular vientres',
            onPressed: calculate,
          ),
          if (error != null)
            VetNotice(
              text: error!,
              icon: VetIcons.alertOctagon,
              kind: VetBadgeKind.danger,
            ),
          if (r != null) ...[
            _Results([
              ('Cerdos por semana', _fmt(r.pigsPerWeek, 1)),
              ('Factor semanal', _fmt(r.weeklyFactor, 3)),
              ('Vientres necesarios', '${r.sows}'),
            ]),
            const SizedBox(height: 10),
            Text(
              'Procedimiento: vientres = cerdos por semana ÷ (destetados por vientre al año ÷ 52). Se redondea hacia arriba; la hoja de clase redondea el factor a tres decimales y puede diferir en una unidad.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Fuente: Remodelaciones y redimensionamiento, Pork School ago-2026 (Carlos Alberto Félix Rosas). Sin validación externa.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

const _biosecurityCrossings = [
  'Duchas / banco',
  'Sala de desinfección',
  'Cámara de luz UV / ventana',
  'Extracción de mortalidad',
  'Embarcadero',
];

const _biosecurityRoutes = [
  'Fauna, insectos, polvo y aerosol',
  'Personas',
  'Transporte',
  'Alimento',
  'Gestión de mortalidad',
  'Materiales y equipos',
  'Reposición y semen',
  'Manejo de purines',
];

const _biosecurityKeys = [
  'Localización ideal',
  'Filtración de aire (signo de interrogación en el original)',
  'Flujo de reemplazo y lechones',
  'Edificación compacta',
  'Área limpia definida y contenida',
  'Mínimos puntos cómodos de entrada y salida',
  'Interacción adecuada con servicios externos',
];

const biosecuritySource =
    'Concepto, manejo y diseño de bioseguridad (Jean Paul Cano), Pork School ago-2026. Sin validación externa.';

/// Lista de revisión de bioseguridad de una granja: el avance se guarda solo
/// en pantalla; no es un registro ni una auditoría.
class PorcinoBiosecurityPanel extends StatefulWidget {
  const PorcinoBiosecurityPanel({super.key});
  @override
  State<PorcinoBiosecurityPanel> createState() =>
      _PorcinoBiosecurityPanelState();
}

class _PorcinoBiosecurityPanelState extends State<PorcinoBiosecurityPanel> {
  final checked = <String>{};
  final distance = TextEditingController();
  DistanceBand? band;
  String? error;

  int get total =>
      _biosecurityRoutes.length +
      _biosecurityCrossings.length +
      _biosecurityKeys.length;

  @override
  void dispose() {
    distance.dispose();
    super.dispose();
  }

  void classify() {
    setState(() {
      band = null;
      error = null;
      try {
        band = classifyFarmDistance(_decimal(distance, 'Distancia'));
      } on FormatException catch (e) {
        error = e.message;
      }
    });
  }

  Widget _group(String title, String prefix, List<String> items, String ask) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 2),
          child: Text(title, style: textTheme.titleSmall),
        ),
        for (final item in items)
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              ask.isEmpty ? item : '$ask: $item',
              style: textTheme.bodyMedium,
            ),
            value: checked.contains('$prefix$item'),
            onChanged: (v) => setState(() {
              v == true
                  ? checked.add('$prefix$item')
                  : checked.remove('$prefix$item');
            }),
          ),
      ],
    );
  }

  String _bandText(DistanceBand b) => switch (b) {
    DistanceBand.veryClose =>
      'Menos de 0.5 km: mismo sitio o granja contigua, riesgo alto de transmisión por roedores, insectos, polvo y personas.',
    DistanceBand.risk =>
      'Menos de 3 km: hay riesgo de transmisión por moscas (PRRS se describe a 2.4 km), aerosol (M. hyopneumoniae a 3.2 km) o polvo (PEDV).',
    DistanceBand.intermediate =>
      'Entre 3 y 10 km: el material no fija un umbral en este tramo. Se citan PRRS a 9.1 km y M. hyopneumoniae a 9.2 km.',
    DistanceBand.far =>
      'Más de 10 km: se minimiza el riesgo de transmisión de PRRS y M. hyopneumoniae.',
  };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelHeader(
            icon: VetIcons.shield,
            title: 'Revisión de bioseguridad',
            subtitle:
                'Marca lo que la granja ya tiene definido. Es una guía de revisión, no una auditoría.',
          ),
          Row(
            children: [
              VetStatusBadge(
                label: '${checked.length} de $total revisados',
                kind: checked.length == total
                    ? VetBadgeKind.success
                    : VetBadgeKind.unverified,
              ),
            ],
          ),
          _group(
            'Rutas de entrada de enfermedades',
            'ruta:',
            _biosecurityRoutes,
            '¿Hay control definido para',
          ),
          _group(
            'Puntos de cruce del área limpia',
            'cruce:',
            _biosecurityCrossings,
            '¿Está definido y se controla',
          ),
          _group(
            'Siete claves de diseño',
            'clave:',
            _biosecurityKeys,
            '',
          ),
          const SizedBox(height: 8),
          Text(
            'Áreas: limpia = caseta, pasillo, oficina y chute · intermedia = entre la caseta y la cerca · sucia = fuera de la cerca.',
            style: textTheme.bodySmall,
          ),
          const Divider(height: 28),
          Text('Distancia a otra granja porcina', style: textTheme.titleSmall),
          _Field(
            controller: distance,
            label: 'Distancia a la granja más cercana (km)',
            decimal: true,
            onChanged: () => setState(() {
              band = null;
              error = null;
            }),
          ),
          VetActionButton(
            icon: VetIcons.navigation,
            label: 'Ubicar en la escala',
            onPressed: classify,
          ),
          if (error != null)
            VetNotice(
              text: error!,
              icon: VetIcons.alertOctagon,
              kind: VetBadgeKind.danger,
            ),
          if (band != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_bandText(band!), style: textTheme.bodyMedium),
            ),
          const SizedBox(height: 10),
          Text(biosecuritySource, style: textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Carga de nitrógeno, huella hídrica gris y nivel de contaminación del agua.
/// Las constantes por defecto son las del Dictamen de Yucatán.
class PorcinoNitrogenPanel extends StatefulWidget {
  const PorcinoNitrogenPanel({super.key});
  @override
  State<PorcinoNitrogenPanel> createState() => _PorcinoNitrogenPanelState();
}

class _PorcinoNitrogenPanelState extends State<PorcinoNitrogenPanel> {
  final pigs = TextEditingController();
  final load = TextEditingController(text: '18');
  final cNat = TextEditingController(text: '1.5');
  final cMax = TextEditingController(text: '3.0');
  final area = TextEditingController();
  final recharge = TextEditingController(text: '175336');
  NitrogenFootprint? result;
  String? error;

  @override
  void dispose() {
    for (final c in [pigs, load, cNat, cMax, area, recharge]) {
      c.dispose();
    }
    super.dispose();
  }

  void reset() => setState(() {
    result = null;
    error = null;
  });

  void calculate() {
    setState(() {
      result = null;
      error = null;
      try {
        final hasArea = area.text.trim().isNotEmpty;
        result = NitrogenFootprint(
          pigs: _whole(pigs, 'Cerdos'),
          kgNPerPigYear: _decimal(load, 'Carga de N por cerdo'),
          cNaturalMgL: _decimal(cNat, 'Concentración natural'),
          cMaxMgL: _decimal(cMax, 'Cmax'),
          areaKm2: hasArea ? _decimal(area, 'Superficie') : null,
          unitRechargeM3Km2: hasArea ? _decimal(recharge, 'Recarga unitaria') : null,
        );
      } on FormatException catch (e) {
        error = e.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = result;
    return VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelHeader(
            icon: VetIcons.drop,
            title: 'Nitrógeno y huella hídrica gris',
            subtitle: 'Cuánta agua haría falta para diluir el nitrógeno que excretan los cerdos.',
          ),
          const VetNotice(
            text:
                'Los valores precargados son de Yucatán (Dictamen SEMARNAT, 2023). Para otra región cambia la concentración natural, Cmax y la recarga con datos locales.',
            icon: VetIcons.pin,
          ),
          const SizedBox(height: 8),
          _Field(controller: pigs, label: 'Cerdos', onChanged: reset),
          _Field(
            controller: load,
            label: 'Nitrógeno excretado (kg N/cerdo/año)',
            decimal: true,
            helper: 'Dictamen: 18, según DEFRA 2007',
            onChanged: reset,
          ),
          Row(
            children: [
              Expanded(
                child: _Field(
                  controller: cNat,
                  label: 'Cnat (mg/L)',
                  decimal: true,
                  helper: 'Yucatán: 1.5',
                  onChanged: reset,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Field(
                  controller: cMax,
                  label: 'Cmax (mg/L)',
                  decimal: true,
                  helper: 'Yucatán: 3.0 o 10.0',
                  onChanged: reset,
                ),
              ),
            ],
          ),
          _Field(
            controller: area,
            label: 'Superficie del municipio o zona (km²), opcional',
            decimal: true,
            helper: 'Solo para calcular el NCA',
            onChanged: reset,
          ),
          _Field(
            controller: recharge,
            label: 'Recarga unitaria (m³/km²/año)',
            decimal: true,
            helper: 'Yucatán: 175 336 (21 813 Hm³ ÷ 124 409 km²)',
            onChanged: reset,
          ),
          const SizedBox(height: 8),
          VetActionButton(
            icon: VetIcons.calculator,
            label: 'Calcular huella',
            onPressed: calculate,
          ),
          if (error != null)
            VetNotice(
              text: error!,
              icon: VetIcons.alertOctagon,
              kind: VetBadgeKind.danger,
            ),
          if (r != null) ...[
            _Results([
              ('Nitrógeno excretado (kg N/año)', _int(r.loadKgNYear)),
              ('Huella hídrica gris (m³/año)', _int(r.greyWaterM3Year)),
              if (r.nca != null) ('NCA', _fmt(r.nca!, 2)),
              if (r.nca != null) ('Lectura', r.ncaReading!),
            ]),
            const SizedBox(height: 10),
            Text(
              'HHGris = carga ÷ (Cmax − Cnat); NCA = HHGris ÷ recarga disponible. NCA mayor que 1 indica no sustentabilidad y mayor que 2, condiciones críticas. La recarga disponible se toma como recarga unitaria × superficie; confirma esa lectura con el dictamen antes de usar el resultado en un trámite.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Fuente: Dictamen Diagnóstico Ambiental de la Actividad Porcícola en Yucatán (SEMARNAT, marzo 2023), p. 84-86. Método de Mekonnen y Hoekstra (2016).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Precios cotizados de un concepto, en centavos de MXN.
///
/// Se separan con punto y coma y no con coma porque la coma ya vale como
/// separador decimal: «1,5» es uno y medio.
///
/// Por eso aqui el decimal se limita a dos cifras, que es lo que tiene el
/// dinero. Sin ese limite «1200,1350» —dos cotizaciones escritas con coma—
/// casaba como un solo numero con cuatro decimales y entraba en silencio
/// como 1 200.14 pesos. Ahora se rechaza y se dice como escribirlo.
List<int> parseQuotedPrices(String raw) {
  final out = <int>[];
  for (final piece in raw.split(';')) {
    final trimmed = piece.trim();
    if (trimmed.isEmpty) continue;
    if (!RegExp(r'^\d+(?:[.,]\d{1,2})?$').hasMatch(trimmed)) {
      throw FormatException(
        'Precios: un número por cotización, con hasta dos decimales y '
        'separados por punto y coma, por ejemplo 1200; 1350.50',
      );
    }
    final pesos = double.parse(trimmed.replaceAll(',', '.'));
    if (pesos <= 0) throw const FormatException('Precios: mayores que 0.');
    out.add((pesos * 100).round());
  }
  return out;
}

String _money(int cents) {
  final pesos = cents / 100;
  final entero = _int(pesos.truncateToDouble());
  final centavos = (cents.abs() % 100).toString().padLeft(2, '0');
  return '$entero.$centavos MXN';
}

/// Estimado de inversión en equipo y materiales para la granja.
///
/// Los precios se capturan a mano: no hay búsqueda de precios en la app, y
/// mientras no la haya este panel no la finge. Con una sola cotización por
/// concepto el precio es ese y el rango se cierra; con varias se toma la
/// mediana y el rango intercuartil, y con cuatro o más se descartan los
/// valores muy alejados, que suelen ser otra unidad o un error de captura.
class PorcinoInvestmentPanel extends StatefulWidget {
  const PorcinoInvestmentPanel({super.key});
  @override
  State<PorcinoInvestmentPanel> createState() => _PorcinoInvestmentPanelState();
}

class _PorcinoInvestmentPanelState extends State<PorcinoInvestmentPanel> {
  final concept = TextEditingController();
  final unit = TextEditingController(text: 'pieza');
  final quantity = TextEditingController(text: '1');
  final prices = TextEditingController();
  final items = <InvestmentItem>[];
  String? error;

  @override
  void dispose() {
    for (final c in [concept, unit, quantity, prices]) {
      c.dispose();
    }
    super.dispose();
  }

  void add() {
    setState(() {
      error = null;
      try {
        final quoted = parseQuotedPrices(prices.text);
        items.add(
          InvestmentItem(
            concept: concept.text.trim(),
            unit: unit.text.trim(),
            quantity: _decimal(quantity, 'Cantidad'),
            manualUnitCents: quoted.length == 1 ? quoted.single : null,
            estimate: quoted.length > 1
                ? PriceEstimate.fromSamples([
                    for (final (i, c) in quoted.indexed)
                      PriceSample(c, source: 'Cotización ${i + 1}'),
                  ])
                : null,
          ),
        );
        concept.clear();
        prices.clear();
        quantity.text = '1';
      } on FormatException catch (e) {
        error = e.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final plan = items.isEmpty ? null : InvestmentPlan(items);
    return VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelHeader(
            icon: VetIcons.clipboardDollar,
            title: 'Estimado de inversión en equipo',
            subtitle:
                'Lista de compras con los precios que tú cotices. No consulta precios en línea.',
          ),
          _Field(
            controller: concept,
            label: 'Concepto',
            helper: 'Por ejemplo: ventilador de 36 pulgadas',
            onChanged: () {},
          ),
          Row(
            children: [
              Expanded(
                child: _Field(
                  controller: unit,
                  label: 'Unidad',
                  onChanged: () {},
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Field(
                  controller: quantity,
                  label: 'Cantidad',
                  decimal: true,
                  onChanged: () {},
                ),
              ),
            ],
          ),
          _Field(
            controller: prices,
            label: 'Precios cotizados por unidad (MXN)',
            decimal: true,
            helper:
                'Separa varias cotizaciones con punto y coma: 1200; 1350; 1290. '
                'Déjalo vacío si todavía no tienes precio.',
            onChanged: () {},
          ),
          const SizedBox(height: 8),
          VetActionButton(
            icon: VetIcons.add,
            label: 'Agregar concepto',
            onPressed: add,
          ),
          if (error != null)
            VetNotice(
              text: error!,
              icon: VetIcons.alertOctagon,
              kind: VetBadgeKind.danger,
            ),
          for (final (i, item) in items.indexed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.concept, style: textTheme.titleSmall),
              // El renglon muestra de donde sale su subtotal, no solo el
              // numero: con un concepto suelto el subtotal y el total valen
              // lo mismo y, sin el desglose, no se sabe cual es cual.
              subtitle: Text(
                item.hasPrice
                    ? '${_fmt(item.quantity, 2)} ${item.unit} × '
                          '${_money(item.unitMidCents!)}'
                          '${item.isManual ? '' : ' (mediana de ${item.estimate!.used})'}'
                          ' = ${_money(item.midCents!)}'
                    : '${_fmt(item.quantity, 2)} ${item.unit} · sin precio',
                style: textTheme.bodySmall,
              ),
              trailing: IconButton(
                icon: const Icon(VetIcons.trash),
                tooltip: 'Quitar concepto',
                onPressed: () => setState(() => items.removeAt(i)),
              ),
            ),
          if (plan != null) ...[
            _Results([
              ('Total estimado', _money(plan.midCents)),
              if (plan.lowCents != plan.highCents)
                ('Rango', '${_money(plan.lowCents)} – ${_money(plan.highCents)}'),
              ('Conceptos', '${items.length}'),
            ]),
            if (!plan.isComplete)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: VetNotice(
                  text:
                      'El total NO incluye ${plan.unpriced.length} concepto(s) sin precio: '
                      '${plan.unpriced.map((i) => i.concept).join(', ')}.',
                  icon: VetIcons.clipboardDollar,
                  kind: VetBadgeKind.warning,
                ),
              ),
            if (plan.weak.isNotEmpty)
              VetNotice(
                text:
                    'Con menos de ${PriceEstimate.minReliableSamples} cotizaciones el estimado es débil: '
                    '${plan.weak.map((i) => i.concept).join(', ')}.',
                icon: VetIcons.help,
                kind: VetBadgeKind.unverified,
              ),
          ],
          const SizedBox(height: 10),
          Text(
            'Cada precio que captures cuenta como una cotización distinta. Es un '
            'estimado de planeación con tus propios precios, no una cotización '
            'formal ni un precio de mercado verificado.',
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

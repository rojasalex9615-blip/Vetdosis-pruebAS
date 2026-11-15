import 'package:flutter/material.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_theme.dart';
import '../../finance/domain/investment_estimate.dart';
import '../domain/porcino_bandas.dart';
import '../domain/porcino_biosecurity.dart';
import '../domain/porcino_calculators.dart';
import '../domain/porcino_capacity.dart';
import '../domain/porcino_facilities.dart';
import '../domain/porcino_reference.dart';
import '../domain/porcino_productive_models.dart';
import '../domain/porcino_environment.dart';
import '../domain/porcino_feeding.dart';
import '../domain/porcino_repository.dart';
import '../domain/porcino_upp.dart';
import 'growth_panel.dart';
import '../../../vet_ui/vet_icons.dart';
import '../../patients/presentation/patient_view_model.dart' show newOperationId;
import 'porcino_semen_panel.dart';

/// Paneles del módulo Porcinos para cada actividad. Los cálculos son de sesión;
/// si se pasa [repository] se ofrecen además los planes guardados y los
/// catálogos remotos (bioseguridad). Nunca guarda datos clínicos.
List<Widget> porcinoPanelsFor(
  String activity, {
  required bool showCosts,
  PorcinoRepository? repository,
  String? clinicId,
}) {
  const notice = VetNotice(
    text:
        'Cálculos de sesión con valores de referencia de clase. No guardan registros de granja y no son metas de rendimiento.',
    icon: VetIcons.clipboardChecks,
  );
  return switch (activity) {
    'Reproducción y gestación' => [
      notice,
      const PorcinoBandFlowPanel(),
      const _Gap(),
      const PorcinoFlowPanel(),
      const _Gap(),
      const PorcinoSemenPanel(),
      const _Gap(),
      const PorcinoInverseCapacityPanel(),
      const _Gap(),
      const PorcinoPenCapacityPanel(),
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
      const _Gap(),
      const PorcinoProductiveModelsPanel(),
      if (repository != null) ...[
        const _Gap(),
        PorcinoBandPlanPanel(repository: repository, clinicId: clinicId!),
      ],
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
      const PorcinoFacilitySizingPanel(),
      const _Gap(),
      const PorcinoSiloPanel(
        title: 'Silo para maternidad y destete',
        phases: [...porcinoMaternityFeed, ...porcinoNurseryFeed],
      ),
      const _Gap(),
      const PorcinoInventoryPanel(),
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
      const PorcinoAreaBalancePanel(),
      const _Gap(),
      const PorcinoStageCapacityPanel(),
      const _Gap(),
      const PorcinoGrowthProjectionPanel(),
      const _Gap(),
      const PorcinoSiloPanel(
        title: 'Silo para desarrollo y finalización',
        phases: porcinoGrowingFeed,
      ),
      const _Gap(),
      const PorcinoFeedingSystemsPanel(),
      const _Gap(),
      const PorcinoStagePerformancePanel(),
      const _Gap(),
      const PorcinoYieldPanel(),
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
      const PorcinoKpiImpactPanel(),
      const _Gap(),
      const PorcinoUppPanel(),
      const _Gap(),
      const PorcinoNitrogenPanel(),
      const _Gap(),
      const PorcinoEnvironmentPanel(),
      if (repository != null) ...[
        const _Gap(),
        PorcinoBiosecurityRefsPanel(repository: repository),
      ],
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

/// Formatea una diferencia con su signo explícito: «+22.5», «-3», «0».
String _signed(double v, [int decimals = 2]) {
  final rounded = double.parse(v.toStringAsFixed(decimals));
  final body = _fmt(rounded.abs(), decimals);
  if (rounded > 0) return '+$body';
  if (rounded < 0) return '-$body';
  return body;
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

/// Impacto económico de los KPIs de bioseguridad (€/cerdo y €/lechón).
///
/// Los importes son de la diapositiva de clase: sirven para ordenar prioridades,
/// no son cotizaciones ni un resultado contable.
class PorcinoKpiImpactPanel extends StatefulWidget {
  const PorcinoKpiImpactPanel({super.key});
  @override
  State<PorcinoKpiImpactPanel> createState() => _PorcinoKpiImpactPanelState();
}

class _PorcinoKpiImpactPanelState extends State<PorcinoKpiImpactPanel> {
  final _controllers = <String, TextEditingController>{
    for (final k in porcinoKpiImpacts) k.label: TextEditingController(),
  };
  PorcinoEconomicImpact? result;
  String? error;

  @override
  void dispose() {
    for (final c in _controllers.values) {
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
        final changes = <String, double>{};
        for (final k in porcinoKpiImpacts) {
          final raw = _controllers[k.label]!.text.trim();
          if (raw.isEmpty) continue;
          changes[k.label] = _decimal(_controllers[k.label]!, k.label);
        }
        if (changes.isEmpty) {
          throw const FormatException('Escribe al menos un cambio de KPI.');
        }
        result = PorcinoEconomicImpact(changes: changes);
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
          const _PanelHeader(
            icon: VetIcons.coins,
            title: 'Impacto económico de los KPIs',
            subtitle:
                'Cuánto vale cada punto de mortalidad, de conversión, cada '
                'lechón destetado y cada día no productivo (importes en € de la '
                'diapositiva).',
          ),
          for (final k in porcinoKpiImpacts)
            _Field(
              controller: _controllers[k.label]!,
              label: '${k.label} (${k.unit})',
              decimal: true,
              helper:
                  '${k.basis} Aporte de la fuente: '
                  '${_fmt(k.perUnitLow, 2)}–${_fmt(k.perUnitHigh, 2)} €.',
              onChanged: reset,
            ),
          const SizedBox(height: 8),
          VetActionButton(
            icon: VetIcons.calculator,
            label: 'Calcular impacto',
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
              ('Impacto escenario bajo', '${_fmt(r.totalLowEur, 2)} €/cerdo'),
              ('Impacto escenario alto', '${_fmt(r.totalHighEur, 2)} €/cerdo'),
            ]),
          const SizedBox(height: 10),
          Text(
            'Referencia de clase (Pork School, ago-2026): la instalación de '
            'filtros de aire se asocia a ${porcinoPrrsFilterReductionFactor.toStringAsFixed(0)} veces menos '
            'probabilidad de brote de PRRS. Las distancias de '
            '${porcinoDistanceReferences.map((d) => '${d.toStringAsFixed(0)} km').join(' y ')} '
            'aparecen como valores de referencia, sin fijar un umbral.',
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// UPP de ejemplo (Rancho La Huamuchilera, proyecto 2022): alimento, agua,
/// espacio, costo y balance de N y P por fase.
///
/// Inventario y repartos son del proyecto 2022 y **no están confirmados** con el
/// productor; proteína y fósforo de la dieta son referencias típicas. El
/// resultado es un orden de magnitud, no una medición.
class PorcinoUppPanel extends StatefulWidget {
  const PorcinoUppPanel({super.key});
  @override
  State<PorcinoUppPanel> createState() => _PorcinoUppPanelState();
}

class _PorcinoUppPanelState extends State<PorcinoUppPanel> {
  static const _defaultAnimals = <String, int>{
    'Gestación (cerda)': 87,
    'Lactancia (cerda)': 13,
    'Lechón predestete': 20,
    'Destete / Posdestete': 0,
    'Desarrollo / Crecimiento': 60,
    'Finalización / Engorde': 60,
    'Sementales': 20,
  };

  final _controllers = <String, TextEditingController>{
    for (final p in porcinoUppPhases)
      p.name: TextEditingController(
        text: '${_defaultAnimals[p.name] ?? 0}',
      ),
  };
  PorcinoUppBalance? result;
  String? error;

  @override
  void initState() {
    super.initState();
    calculate();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void calculate() {
    setState(() {
      result = null;
      error = null;
      try {
        final lines = <PorcinoUppLine>[];
        for (final p in porcinoUppPhases) {
          final animals = _whole(_controllers[p.name]!, p.name);
          if (animals == 0) continue;
          lines.add(PorcinoUppLine(phase: p, animals: animals));
        }
        if (lines.isEmpty) {
          throw const FormatException('Escribe animales en al menos una fase.');
        }
        result = PorcinoUppBalance(lines: lines);
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
          const _PanelHeader(
            icon: VetIcons.homePaw,
            title: 'UPP de ejemplo: alimento, agua y balance de N y P',
            subtitle:
                'Tablas base del proyecto 2022 (Rancho La Huamuchilera). '
                'Inventario y dieta sin confirmar: caso ilustrativo.',
          ),
          for (final p in porcinoUppPhases)
            _Field(
              controller: _controllers[p.name]!,
              label: 'Animales en ${p.name}',
              onChanged: () {},
            ),
          const SizedBox(height: 8),
          VetActionButton(
            icon: VetIcons.calculator,
            label: 'Calcular balance',
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
          if (r != null) ...[
            _Results([
              ('Animales', '${r.totalAnimals}'),
              ('Alimento', '${_fmt(r.totalFeedPerDayKg)} kg/día'),
              ('Alimento para completar fases', '${_int(r.totalFeedToCompletePhaseKg)} kg'),
              ('Costo de alimento', '${_money((r.totalFeedCostPerDay * 100).round())}/día'),
              ('Agua de bebida', '${_int(r.totalWaterPerDayL)} L/día'),
              ('Superficie requerida', '${_int(r.totalAreaM2)} m²'),
              ('Excreta fresca', '${_int(r.totalExcretaFreshKgDay)} kg/día'),
              ('N excretado', '${_int(r.totalNExcretedKgYear)} kg/año'),
              ('P excretado', '${_int(r.totalPExcretedKgYear)} kg/año'),
              ('P2O5 excretado', '${_int(r.pExcretedAsP2O5KgYear)} kg/año'),
              ('Efluente (excreta + agua + lavado)', '${_int(r.effluentM3Year)} m³/año'),
              ('Superficie agrícola para el N', '${_fmt(r.agriculturalAreaHa)} ha'),
              if (r.finishingPigNKgPhase != null)
                ('N por cerdo de finalización (fase)', '${_fmt(r.finishingPigNKgPhase!, 3)} kg'),
            ]),
          ],
          const SizedBox(height: 10),
          Text(
            'Balance: excretado = ingerido − retenido. Proteína y fósforo de la '
            'dieta son de dietas comerciales; con la mezcla de granos real el N '
            'puede ser menor. La superficie agrícola usa el límite de '
            '${_int(r?.assumptions.nLimitKgHaYear ?? 170)} kg N/ha/año.',
            style: textTheme.bodySmall,
          ),
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

/// Capacidad de corral: cuántos animales caben y qué superficie hace falta.
///
/// La densidad de referencia sale de la tabla de clase por peso y tipo de
/// piso; no se interpola. El resultado no es dictamen normativo.
class PorcinoPenCapacityPanel extends StatefulWidget {
  const PorcinoPenCapacityPanel({super.key});
  @override
  State<PorcinoPenCapacityPanel> createState() =>
      _PorcinoPenCapacityPanelState();
}

class _PorcinoPenCapacityPanelState extends State<PorcinoPenCapacityPanel> {
  final available = TextEditingController();
  final animals = TextEditingController();
  int? weightKg;
  PorcinoFloor floor = PorcinoFloor.partial;
  PenCapacity? result;
  String? error;

  @override
  void dispose() {
    available.dispose();
    animals.dispose();
    super.dispose();
  }

  double? get density =>
      weightKg == null ? null : swineDensityFor(weightKg!, floor);

  void reset() => setState(() {
    result = null;
    error = null;
  });

  void calculate() {
    setState(() {
      result = null;
      error = null;
      try {
        final reference = density;
        if (reference == null) {
          throw const FormatException(
            'Elige un peso con densidad publicada en la tabla de clase.',
          );
        }
        result = PenCapacity(
          availableM2: _decimal(available, 'Superficie disponible'),
          m2PerAnimal: reference,
          animals: _whole(animals, 'Número de animales'),
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
    final reference = density;
    return VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelHeader(
            icon: VetIcons.grid,
            title: 'Capacidad de corral',
            subtitle:
                'Cuántos animales caben en la superficie disponible, según peso y piso.',
          ),
          Text('Peso del animal', style: textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final w in swineDensityWeights)
                ChoiceChip(
                  label: Text('$w kg'),
                  selected: weightKg == w,
                  onSelected: (_) => setState(() {
                    weightKg = w;
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
                  label: Text(f.label),
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
            controller: available,
            label: 'Superficie disponible (m²)',
            decimal: true,
            helper: reference == null
                ? 'Elige peso y piso para ver la densidad de referencia'
                : 'Densidad de referencia: ${_fmt(reference)} m² por animal',
            onChanged: reset,
          ),
          _Field(
            controller: animals,
            label: 'Número de animales',
            helper: 'Se compara contra la capacidad calculada',
            onChanged: reset,
          ),
          const SizedBox(height: 4),
          VetActionButton(
            icon: VetIcons.calculator,
            label: 'Calcular capacidad',
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
          if (r != null) ...[
            _Results([
              ('Capacidad estimada', '${_int(r.capacity.toDouble())} animales'),
              ('Superficie requerida', '${_fmt(r.requiredM2, 2)} m²'),
              (
                'Diferencia de superficie',
                '${_signed(r.differenceM2, 2)} m²',
              ),
            ]),
            if (!r.fits)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: VetNotice(
                  text:
                      'No caben los animales declarados: falta superficie o sobra densidad.',
                  icon: VetIcons.alertOctagon,
                  kind: VetBadgeKind.warning,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Dimensionamiento de instalaciones: superficie necesaria para una cantidad
/// de animales en una etapa concreta.
class PorcinoFacilitySizingPanel extends StatefulWidget {
  const PorcinoFacilitySizingPanel({super.key});
  @override
  State<PorcinoFacilitySizingPanel> createState() =>
      _PorcinoFacilitySizingPanelState();
}

class _PorcinoFacilitySizingPanelState
    extends State<PorcinoFacilitySizingPanel> {
  final animals = TextEditingController();
  int? weightKg;
  PorcinoFloor floor = PorcinoFloor.partial;
  FacilitySizing? result;
  String? error;

  @override
  void dispose() {
    animals.dispose();
    super.dispose();
  }

  double? get density =>
      weightKg == null ? null : swineDensityFor(weightKg!, floor);

  void calculate() {
    setState(() {
      result = null;
      error = null;
      try {
        final reference = density;
        if (reference == null) {
          throw const FormatException(
            'Elige un peso con densidad publicada en la tabla de clase.',
          );
        }
        result = FacilitySizing(
          animals: _whole(animals, 'Animales'),
          m2PerAnimal: reference,
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
          const _PanelHeader(
            icon: VetIcons.clipboardChecks,
            title: 'Dimensionamiento de instalaciones',
            subtitle: 'Superficie necesaria para alojar una cantidad de animales.',
          ),
          Text('Peso del animal', style: textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final w in swineDensityWeights)
                ChoiceChip(
                  label: Text('$w kg'),
                  selected: weightKg == w,
                  onSelected: (_) => setState(() {
                    weightKg = w;
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
                  label: Text(f.label),
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
            label: 'Animales a alojar',
            onChanged: () => setState(() {
              result = null;
              error = null;
            }),
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
              ('Superficie necesaria', '${_fmt(r.requiredM2, 2)} m²'),
              ('Densidad usada', '${_fmt(r.m2PerAnimal)} m²/animal'),
            ]),
        ],
      ),
    );
  }
}

/// Distribución de UPP: compara lo que existe contra lo requerido y separa
/// déficit de sobrante.
class PorcinoAreaBalancePanel extends StatefulWidget {
  const PorcinoAreaBalancePanel({super.key});
  @override
  State<PorcinoAreaBalancePanel> createState() =>
      _PorcinoAreaBalancePanelState();
}

class _PorcinoAreaBalancePanelState extends State<PorcinoAreaBalancePanel> {
  final existing = TextEditingController();
  final required = TextEditingController();
  AreaBalance? result;
  String? error;

  @override
  void dispose() {
    existing.dispose();
    required.dispose();
    super.dispose();
  }

  void calculate() {
    setState(() {
      result = null;
      error = null;
      try {
        result = AreaBalance(
          existingM2: _decimal(existing, 'Superficie existente'),
          requiredM2: _decimal(required, 'Superficie requerida'),
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
            title: 'Distribución de UPP y déficit',
            subtitle:
                'Compara la superficie existente contra la requerida. Separa lo que falta de lo que sobra.',
          ),
          _Field(
            controller: existing,
            label: 'Superficie existente (m²)',
            decimal: true,
            onChanged: () => setState(() {
              result = null;
              error = null;
            }),
          ),
          _Field(
            controller: required,
            label: 'Superficie requerida (m²)',
            decimal: true,
            helper: 'Puede salir del dimensionamiento o de tu propio cálculo',
            onChanged: () => setState(() {
              result = null;
              error = null;
            }),
          ),
          const SizedBox(height: 4),
          VetActionButton(
            icon: VetIcons.calculator,
            label: 'Comparar superficies',
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
              ('Diferencia', '${_signed(r.differenceM2, 2)} m²'),
              if (r.hasDeficit)
                ('Déficit de infraestructura', '${_fmt(r.deficitM2, 2)} m²')
              else
                ('Superficie que sobra', '${_fmt(r.surplusM2, 2)} m²'),
            ]),
        ],
      ),
    );
  }
}

/// Capacidad productiva y balance entre etapas: cuántos animales aloja cada
/// etapa y cuál limita al conjunto.
class PorcinoStageCapacityPanel extends StatefulWidget {
  const PorcinoStageCapacityPanel({super.key});
  @override
  State<PorcinoStageCapacityPanel> createState() =>
      _PorcinoStageCapacityPanelState();
}

class _PorcinoStageCapacityPanelState
    extends State<PorcinoStageCapacityPanel> {
  final stage = TextEditingController();
  final area = TextEditingController();
  final density = TextEditingController();
  final stages = <StageArea>[];
  String? error;

  @override
  void dispose() {
    for (final c in [stage, area, density]) {
      c.dispose();
    }
    super.dispose();
  }

  void add() {
    setState(() {
      error = null;
      try {
        stages.add(
          StageArea(
            stage: stage.text.trim(),
            areaM2: _decimal(area, 'Superficie'),
            m2PerAnimal: _decimal(density, 'Densidad'),
          ),
        );
        stage.clear();
        area.clear();
        density.clear();
      } on FormatException catch (e) {
        error = e.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final plan = stages.isEmpty ? null : StageCapacityPlan(stages);
    return VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelHeader(
            icon: VetIcons.hierarchy,
            title: 'Capacidad productiva y balance',
            subtitle:
                'Animales que aloja cada etapa y la etapa que limita al conjunto.',
          ),
          _Field(
            controller: stage,
            label: 'Etapa',
            helper: 'Maternidad, destete, engorda…',
            onChanged: () {},
          ),
          Row(
            children: [
              Expanded(
                child: _Field(
                  controller: area,
                  label: 'Superficie (m²)',
                  decimal: true,
                  onChanged: () {},
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Field(
                  controller: density,
                  label: 'Densidad (m²/animal)',
                  decimal: true,
                  onChanged: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          VetActionButton(
            icon: VetIcons.add,
            label: 'Agregar etapa',
            onPressed: add,
          ),
          if (error != null)
            VetNotice(
              text: error!,
              icon: VetIcons.alertOctagon,
              kind: VetBadgeKind.danger,
            ),
          for (final (i, s) in stages.indexed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.stage, style: textTheme.titleSmall),
              subtitle: Text(
                '${_fmt(s.areaM2, 2)} m² ÷ ${_fmt(s.m2PerAnimal)} m²/animal = '
                '${_int((s.areaM2 / s.m2PerAnimal + 1e-9).floorToDouble())} animales',
                style: textTheme.bodySmall,
              ),
              trailing: IconButton(
                icon: const Icon(VetIcons.trash),
                tooltip: 'Quitar etapa',
                onPressed: () => setState(() => stages.removeAt(i)),
              ),
            ),
          if (plan != null) ...[
            _Results([
              ('Capacidad total', '${_int(plan.totalCapacity.toDouble())} animales'),
              (
                'Cuello de botella',
                '${plan.bottleneckStage.stage} (${_int(plan.bottleneckCapacity.toDouble())})',
              ),
            ]),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: VetNotice(
                text:
                    'La etapa con menos lugares limita al conjunto: la capacidad real es la del cuello de botella, no la suma.',
                icon: VetIcons.info,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Proyección de crecimiento: infraestructura necesaria para subir el
/// inventario. Si la meta no crece, no pide superficie.
class PorcinoGrowthProjectionPanel extends StatefulWidget {
  const PorcinoGrowthProjectionPanel({super.key});
  @override
  State<PorcinoGrowthProjectionPanel> createState() =>
      _PorcinoGrowthProjectionPanelState();
}

class _PorcinoGrowthProjectionPanelState
    extends State<PorcinoGrowthProjectionPanel> {
  final current = TextEditingController();
  final target = TextEditingController();
  int? weightKg;
  PorcinoFloor floor = PorcinoFloor.partial;
  GrowthProjection? result;
  String? error;

  @override
  void dispose() {
    current.dispose();
    target.dispose();
    super.dispose();
  }

  double? get density =>
      weightKg == null ? null : swineDensityFor(weightKg!, floor);

  void calculate() {
    setState(() {
      result = null;
      error = null;
      try {
        final reference = density;
        if (reference == null) {
          throw const FormatException(
            'Elige un peso con densidad publicada en la tabla de clase.',
          );
        }
        result = GrowthProjection(
          currentAnimals: _whole(current, 'Inventario actual'),
          targetAnimals: _whole(target, 'Meta de inventario'),
          m2PerAnimal: reference,
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
          const _PanelHeader(
            icon: VetIcons.trendingUp,
            title: 'Proyección de crecimiento',
            subtitle:
                'Superficie adicional necesaria para aumentar el inventario.',
          ),
          Text('Peso del animal', style: textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final w in swineDensityWeights)
                ChoiceChip(
                  label: Text('$w kg'),
                  selected: weightKg == w,
                  onSelected: (_) => setState(() {
                    weightKg = w;
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
                  label: Text(f.label),
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
          Row(
            children: [
              Expanded(
                child: _Field(
                  controller: current,
                  label: 'Inventario actual',
                  onChanged: () => setState(() {
                    result = null;
                    error = null;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Field(
                  controller: target,
                  label: 'Meta de inventario',
                  onChanged: () => setState(() {
                    result = null;
                    error = null;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          VetActionButton(
            icon: VetIcons.calculator,
            label: 'Proyectar superficie',
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
              ('Animales que se suman', _int(r.additionalAnimals.toDouble())),
              ('Superficie adicional', '${_fmt(r.additionalM2, 2)} m²'),
              ('Superficie actual', '${_fmt(r.currentM2, 2)} m²'),
              ('Superficie de la meta', '${_fmt(r.targetM2, 2)} m²'),
            ]),
        ],
      ),
    );
  }
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

/// Flujo por bandas: de vientres a partos, lechones, jaulas y reemplazos.
///
/// Reproduce la hoja de clase «Flujo_produccion_bandas.xlsx» (550 vientres,
/// banda de 14 días). Es una calculadora de sesión: no guarda registros.
class PorcinoBandFlowPanel extends StatefulWidget {
  const PorcinoBandFlowPanel({super.key});
  @override
  State<PorcinoBandFlowPanel> createState() => _PorcinoBandFlowPanelState();
}

class _PorcinoBandFlowPanelState extends State<PorcinoBandFlowPanel> {
  final sows = TextEditingController(text: '550');
  final gestation = TextEditingController(text: '114');
  final lactation = TextEditingController(text: '28');
  final open = TextEditingController(text: '7');
  final interval = TextEditingController(text: '14');
  final infertility = TextEditingController(text: '15');
  final bornAlive = TextEditingController(text: '12.5');
  final pigletMortality = TextEditingController(text: '10');
  final nursingBands = TextEditingController(text: '2');
  final washBands = TextEditingController(text: '1');
  final replacement = TextEditingController(text: '45');
  PorcinoBandFlow? result;
  String? error;

  @override
  void dispose() {
    for (final c in [
      sows,
      gestation,
      lactation,
      open,
      interval,
      infertility,
      bornAlive,
      pigletMortality,
      nursingBands,
      washBands,
      replacement,
    ]) {
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
        result = PorcinoBandFlow(
          sows: _whole(sows, 'Vientres'),
          gestationDays: _whole(gestation, 'Días de gestación'),
          lactationDays: _whole(lactation, 'Días de lactancia'),
          openDays: _whole(open, 'Días abiertos'),
          bandIntervalDays: _whole(interval, 'Intervalo entre bandas'),
          infertility: _decimal(infertility, '% de infertilidad') / 100,
          bornAlivePerLitter: _decimal(
            bornAlive,
            'Lechones nacidos vivos por parto',
          ),
          pigletMortality:
              _decimal(pigletMortality, '% mortalidad de lechones') / 100,
          nursingBands: _whole(nursingBands, 'Bandas de lactancia'),
          washBands: _whole(washBands, 'Bandas de lavado'),
          annualReplacement:
              _decimal(replacement, '% de reemplazo anual') / 100,
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
            icon: VetIcons.grid,
            title: 'Flujo de producción por bandas',
            subtitle:
                'Ciclo, servicios, partos, lechones, jaulas y reemplazos. '
                'Ejemplo de clase: 550 vientres, banda de 14 días.',
          ),
          _Field(controller: sows, label: 'Vientres', onChanged: reset),
          _Field(
            controller: gestation,
            label: 'Días de gestación',
            onChanged: reset,
          ),
          _Field(
            controller: lactation,
            label: 'Días de lactancia',
            onChanged: reset,
          ),
          _Field(
            controller: open,
            label: 'Días abiertos',
            onChanged: reset,
          ),
          _Field(
            controller: interval,
            label: 'Intervalo entre bandas (días)',
            onChanged: reset,
          ),
          _Field(
            controller: infertility,
            label: '% de infertilidad',
            decimal: true,
            helper: 'En porcentaje; 15 equivale a 15 %.',
            onChanged: reset,
          ),
          _Field(
            controller: bornAlive,
            label: 'Lechones nacidos vivos por parto',
            decimal: true,
            onChanged: reset,
          ),
          _Field(
            controller: pigletMortality,
            label: '% mortalidad de lechones',
            decimal: true,
            helper: 'En porcentaje; 10 equivale a 10 %.',
            onChanged: reset,
          ),
          _Field(
            controller: nursingBands,
            label: 'Bandas de lactancia ocupando jaula',
            onChanged: reset,
          ),
          _Field(
            controller: washBands,
            label: 'Bandas de lavado y desinfección',
            onChanged: reset,
          ),
          _Field(
            controller: replacement,
            label: '% de reemplazo anual',
            decimal: true,
            helper: 'En porcentaje; 45 equivale a 45 %.',
            onChanged: reset,
          ),
          const SizedBox(height: 8),
          VetActionButton(
            icon: VetIcons.calculator,
            label: 'Calcular flujo',
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
              ('Duración del ciclo productivo', '${r.cycleDays} días'),
              ('Bandas del ciclo', _fmt(r.cycleBands, 2)),
              ('Servicios por banda', _fmt(r.servicesPerBand, 2)),
              ('Partos por banda', _fmt(r.farrowingsPerBand, 2)),
              ('Lechones nacidos vivos por banda', _fmt(r.bornAlivePerBand, 2)),
              ('Lechones destetados por banda', _fmt(r.weanedPerBand, 2)),
              ('Jaulas de lactancia necesarias', _fmt(r.nursingCrates, 2)),
              ('Reemplazos al año', _fmt(r.annualReplacements, 2)),
              ('Reemplazos por mes', _fmt(r.replacementsPerMonth, 2)),
            ]),
        ],
      ),
    );
  }
}

/// Inventario por etapa: población por semana y total, encadenando etapas.
class PorcinoInventoryPanel extends StatefulWidget {
  const PorcinoInventoryPanel({super.key});
  @override
  State<PorcinoInventoryPanel> createState() => _PorcinoInventoryPanelState();
}

class _PorcinoInventoryPanelState extends State<PorcinoInventoryPanel> {
  final weanedPerBand = TextEditingController(text: '494.17');
  final bandInterval = TextEditingController(text: '14');
  PorcinoStageInventory? result;
  String? error;

  @override
  void dispose() {
    weanedPerBand.dispose();
    bandInterval.dispose();
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
        final interval = _whole(bandInterval, 'Intervalo entre bandas');
        if (interval <= 0) {
          throw const FormatException('Intervalo entre bandas: mayor que 0.');
        }
        final perWeek = _decimal(weanedPerBand, 'Lechones destetados por banda');
        result = PorcinoStageInventory(weanedPerWeek: perWeek / (interval / 7));
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
            icon: VetIcons.clipboardChecks,
            title: 'Inventario por etapa',
            subtitle:
                'Pre-iniciación, iniciación, crecimiento y finalización. '
                'Cada etapa hereda la población final de la anterior.',
          ),
          _Field(
            controller: weanedPerBand,
            label: 'Lechones destetados por banda',
            decimal: true,
            helper: 'Sale del flujo por bandas; edítalo si tienes tu dato.',
            onChanged: reset,
          ),
          _Field(
            controller: bandInterval,
            label: 'Intervalo entre bandas (días)',
            onChanged: reset,
          ),
          const SizedBox(height: 8),
          VetActionButton(
            icon: VetIcons.calculator,
            label: 'Calcular inventario',
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
          if (r != null) ...[
            const SizedBox(height: 12),
            for (final stage in r.stages)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stage.name, style: textTheme.titleSmall),
                    Text(
                      '${stage.weeks} sem · inicial ${_fmt(stage.initialPerWeek, 2)} · '
                      'mortalidad ${_fmt(stage.mortality * 100, 1)} % · '
                      'final ${_fmt(stage.finalPerWeek, 2)} · '
                      'total ${_fmt(stage.total, 2)}',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            _Results([
              ('Inventario total', _fmt(r.total, 2)),
            ]),
          ],
        ],
      ),
    );
  }
}

/// Ganancia diaria de peso y conversión alimenticia de una etapa.
class PorcinoStagePerformancePanel extends StatefulWidget {
  const PorcinoStagePerformancePanel({super.key});
  @override
  State<PorcinoStagePerformancePanel> createState() =>
      _PorcinoStagePerformancePanelState();
}

class _PorcinoStagePerformancePanelState
    extends State<PorcinoStagePerformancePanel> {
  final start = TextEditingController(text: '15');
  final end = TextEditingController(text: '30');
  final days = TextEditingController(text: '23');
  final feed = TextEditingController(text: '0.9');
  PorcinoStagePerformance? result;
  String? error;

  @override
  void dispose() {
    for (final c in [start, end, days, feed]) {
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
        result = PorcinoStagePerformance(
          startKg: _decimal(start, 'Peso inicial'),
          endKg: _decimal(end, 'Peso final'),
          days: _whole(days, 'Días de la etapa'),
          dailyFeedKg: _decimal(feed, 'Consumo diario'),
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
            icon: VetIcons.chartGrowth,
            title: 'Ganancia diaria y conversión',
            subtitle:
                'Ejemplo de clase: 15–30 kg en 23 días con 0.9 kg/día. '
                'Verifica las cifras del pizarrón antes de usarlas.',
          ),
          _Field(controller: start, label: 'Peso inicial (kg)', decimal: true, onChanged: reset),
          _Field(controller: end, label: 'Peso final (kg)', decimal: true, onChanged: reset),
          _Field(controller: days, label: 'Días de la etapa', onChanged: reset),
          _Field(
            controller: feed,
            label: 'Consumo diario de alimento (kg/día)',
            decimal: true,
            onChanged: reset,
          ),
          const SizedBox(height: 8),
          VetActionButton(
            icon: VetIcons.calculator,
            label: 'Calcular etapa',
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
              ('Ganancia diaria de peso (GDP)', '${_fmt(r.dailyGain, 3)} kg/día'),
              ('Peso promedio de la etapa', '${_fmt(r.averageKg, 2)} kg'),
              ('Consumo total de la etapa', '${_fmt(r.totalFeed, 2)} kg/animal'),
              ('Conversión alimenticia', '${_fmt(r.feedConversion, 2)} kg alim./kg'),
            ]),
        ],
      ),
    );
  }
}

/// Rendimiento de transformación = producto final ÷ materia prima × 100.
class PorcinoYieldPanel extends StatefulWidget {
  const PorcinoYieldPanel({super.key});
  @override
  State<PorcinoYieldPanel> createState() => _PorcinoYieldPanelState();
}

class _PorcinoYieldPanelState extends State<PorcinoYieldPanel> {
  final input = TextEditingController(text: '90');
  final output = TextEditingController(text: '67.5');
  PorcinoYield? result;
  String? error;

  @override
  void dispose() {
    input.dispose();
    output.dispose();
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
        result = PorcinoYield(
          inputKg: _decimal(input, 'Materia prima inicial'),
          outputKg: _decimal(output, 'Producto final'),
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
            icon: VetIcons.chartGrowth,
            title: 'Rendimiento de canal',
            subtitle:
                'Producto final ÷ materia prima × 100. Ejemplo: canal 75 % '
                'de 90 kg. Ajusta con los datos de tu UPP.',
          ),
          _Field(
            controller: input,
            label: 'Peso de materia prima inicial (kg)',
            decimal: true,
            onChanged: reset,
          ),
          _Field(
            controller: output,
            label: 'Peso producto final / transformado (kg)',
            decimal: true,
            onChanged: reset,
          ),
          const SizedBox(height: 8),
          VetActionButton(
            icon: VetIcons.calculator,
            label: 'Calcular rendimiento',
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
              ('Rendimiento', '${_fmt(r.percent, 2)} %'),
            ]),
        ],
      ),
    );
  }
}


/// Panel del catálogo ambiental: muestra los dictámenes por región. Con más de
/// una región aparece un selector; hoy solo hay Yucatán. Solo lectura: los
/// datos ya están fijados en el dominio, el panel no recalcula nada.
class PorcinoEnvironmentPanel extends StatefulWidget {
  const PorcinoEnvironmentPanel({super.key});

  @override
  State<PorcinoEnvironmentPanel> createState() => _PorcinoEnvironmentPanelState();
}

class _PorcinoEnvironmentPanelState extends State<PorcinoEnvironmentPanel> {
  String studyId = porcinoEnvironmentStudies.first.id;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final study = porcinoEnvironmentStudy(studyId) ??
        porcinoEnvironmentStudies.first;
    final categories = <String, List<PorcinoEnvironmentRef>>{};
    for (final ref in study.refs) {
      categories.putIfAbsent(ref.category, () => []).add(ref);
    }
    final municipal = study.municipal;
    return VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(
            icon: VetIcons.leaf,
            title: study.title,
            subtitle:
                'Nivel de contaminación del agua (NCA) y huella hídrica gris '
                'del sector porcícola en ${study.region}.',
          ),
          if (porcinoEnvironmentStudies.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in porcinoEnvironmentStudies)
                    ChoiceChip(
                      label: Text(s.region),
                      selected: s.id == study.id,
                      onSelected: (_) => setState(() => studyId = s.id),
                    ),
                ],
              ),
            ),
          VetNotice(
            text:
                'Valores publicados del dictamen para ${study.region}. No son '
                'mediciones de esta granja ni límites aplicables a otra región. '
                'Para otro estado, elige su dictamen cuando esté cargado.',
            icon: VetIcons.pin,
          ),
          for (final entry in categories.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 4),
              child: Text(entry.key, style: textTheme.titleSmall),
            ),
            for (final ref in entry.value)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ref.dato, style: textTheme.bodyMedium),
                          if (ref.nota.isNotEmpty)
                            Text(ref.nota, style: textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (ref.valor.isNotEmpty)
                      Text(
                        ref.unidad.isEmpty
                            ? ref.valor
                            : '${ref.valor} ${ref.unidad}',
                        textAlign: TextAlign.right,
                        style: textTheme.titleSmall,
                      ),
                  ],
                ),
              ),
          ],
          if (municipal != null) ...[
            const SizedBox(height: 14),
            Text(
              'Reparto de municipios con actividad porcícola (Cmax = 3.0 mg/L)',
              style: textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            _Results([
              ('NCA > 2 (crítico)', '${municipal.critical} municipios'),
              ('1 < NCA ≤ 2 (urgente)', '${municipal.urgent} municipios'),
              ('NCA ≤ 1 (sustentable)', '${municipal.sustainable} municipios'),
              ('Total', '${municipal.total} municipios'),
            ]),
          ],
          const SizedBox(height: 10),
          Text(
            'Fuente: ${study.source}'
            '${study.pageRange.isEmpty ? '' : ', p. ${study.pageRange}'}. '
            'Método de Mekonnen y Hoekstra (2016). El NCA compara el agua '
            'necesaria para diluir el nitrógeno con la recarga del acuífero; '
            'confirma las cifras con el dictamen antes de usarlas en un trámite.',
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Modelos productivos (Pork School): el «Modelo 2400» en tres escenarios
/// (promedio, Top 30 %, Top 10 %) y los KPIs históricos de los años 60 y antes.
/// Solo lectura: los valores ya están fijados en el dominio.
class PorcinoProductiveModelsPanel extends StatefulWidget {
  const PorcinoProductiveModelsPanel({super.key});

  @override
  State<PorcinoProductiveModelsPanel> createState() =>
      _PorcinoProductiveModelsPanelState();
}

class _PorcinoProductiveModelsPanelState
    extends State<PorcinoProductiveModelsPanel> {
  String scenarioName = porcinoModel2400Scenarios.first.name;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scenario = porcinoModel2400Scenarios.firstWhere(
      (s) => s.name == scenarioName,
      orElse: () => porcinoModel2400Scenarios.first,
    );
    return VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelHeader(
            icon: VetIcons.barChart,
            title: 'Modelos productivos: Modelo 2400',
            subtitle:
                'Tres escenarios de referencia de la clase. La misma granja '
                '(2 400 vientres) con distinto nivel de manejo.',
          ),
          const VetNotice(
            text:
                'Valores de referencia de la clase (Pork School, ago-2026), no '
                'metas de rendimiento ni límites de operación. Sin validación '
                'externa.',
            icon: VetIcons.clipboardChecks,
          ),
          const SizedBox(height: 10),
          Text('Comparación de escenarios', style: textTheme.titleSmall),
          const SizedBox(height: 6),
          _Model2400Table(),
          const SizedBox(height: 14),
          Text('Detalle del escenario', style: textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in porcinoModel2400Scenarios)
                ChoiceChip(
                  label: Text(s.name),
                  selected: s.name == scenario.name,
                  onSelected: (_) => setState(() => scenarioName = s.name),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _Results([
            ('Partos por semana', _fmt(scenario.farrowingsPerWeek, 0)),
            (
              'Partos por hembra al año',
              _fmt(scenario.farrowingsPerSowPerYear, 2),
            ),
            ('Tasa de fertilidad', '${_fmt(scenario.fertility * 100, 0)} %'),
            ('Vientres productivos', _int(scenario.productiveSows)),
            if (scenario.servicesPerWeek case final services?)
              ('Servicios por semana', _fmt(services, 0)),
            ('Destetados por parto', _fmt(scenario.weanedPerLitter, 1)),
            (
              'Destetados por hembra servida al año',
              _fmt(scenario.weanedPigsPerServedSowPerYear, 1),
            ),
            (
              'Lechones destetados por semana',
              _fmt(scenario.weanedPigsPerWeek, 0),
            ),
            (
              'Objetivo de sobreproducción',
              '${_fmt(scenario.overproductionTargetPct, 0)} %',
            ),
          ]),
          const SizedBox(height: 10),
          Text(
            'Comprobación: destetados/parto × partos/hembra/año = '
            '${_fmt(scenario.weanedPigsPerServedSowPerYearComputed, 1)} '
            'destetados/hembra servida/año'
            '${scenario.farrowingsPerWeekComputed == null ? '' : '; servicios/semana × fertilidad = ${_fmt(scenario.farrowingsPerWeekComputed!, 1)} partos/semana'}. '
            'Factor vientres ÷ partos/semana = '
            '${_fmt(scenario.factorSowsPerFarrowing, 1)}.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          Text('Igual en los tres escenarios', style: textTheme.titleSmall),
          const SizedBox(height: 6),
          _Results([
            ('Vientres del modelo', _int(porcinoModel2400Sows.toDouble())),
            ('Jaulas de maternidad', '$porcinoModel2400Crates (8 salas × 48)'),
            ('Tasa de reemplazo', '$porcinoModel2400ReplacementPct %'),
            ('Factor del sistema simple', '$porcinoModel2400Factor'),
            (
              'Semanas de proceso (nacimiento a 110 kg)',
              '$porcinoModel2400ProcessWeeks (175 días)',
            ),
            ('Sistema de bandas', porcinoModel2400BandSystem),
          ]),
          const SizedBox(height: 14),
          PorcinoReferenceCard(
            title: 'KPIs históricos (años 60 y antes)',
            rows: porcinoHistoricalKpiRows,
          ),
          const SizedBox(height: 10),
          Text(
            'Fuente: $porcinoProductiveModelsSource',
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Tabla comparativa del Modelo 2400: una fila por indicador, una columna por
/// escenario.
class _Model2400Table extends StatelessWidget {
  const _Model2400Table();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final rows = <(String, String Function(PorcinoModel2400Scenario))>[
      ('Partos/semana', (s) => _fmt(s.farrowingsPerWeek, 0)),
      ('Partos/hembra/año', (s) => _fmt(s.farrowingsPerSowPerYear, 2)),
      ('Fertilidad', (s) => '${_fmt(s.fertility * 100, 0)} %'),
      ('Vientres productivos', (s) => _int(s.productiveSows)),
      ('Destetados/parto', (s) => _fmt(s.weanedPerLitter, 1)),
      (
        'Destetados/hembra servida/año',
        (s) => _fmt(s.weanedPigsPerServedSowPerYear, 1),
      ),
      ('Sobreproducción', (s) => '${_fmt(s.overproductionTargetPct, 0)} %'),
    ];
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VetColors.recessed,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VetColors.softShadow),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(flex: 3, child: SizedBox()),
              for (final s in porcinoModel2400Scenarios)
                Expanded(
                  flex: 2,
                  child: Text(
                    s.name,
                    textAlign: TextAlign.right,
                    style: textTheme.titleSmall,
                  ),
                ),
            ],
          ),
          for (final (label, valueOf) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(label, style: textTheme.bodyMedium),
                  ),
                  for (final s in porcinoModel2400Scenarios)
                    Expanded(
                      flex: 2,
                      child: Text(
                        valueOf(s),
                        textAlign: TextAlign.right,
                        style: textTheme.bodyMedium,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Sistemas de alimentación por etapas (Pork School): transporte de alimento,
/// silos-tolva, tolva-báscula, manejo de comederos y tamaño de partícula.
/// Solo lectura: los datos ya están fijados en el dominio. Incluye una
/// calculadora de transporte (modelo de tubo) y de boca de salida del silo.
class PorcinoFeedingSystemsPanel extends StatefulWidget {
  const PorcinoFeedingSystemsPanel({super.key});

  @override
  State<PorcinoFeedingSystemsPanel> createState() =>
      _PorcinoFeedingSystemsPanelState();
}

class _PorcinoFeedingSystemsPanelState
    extends State<PorcinoFeedingSystemsPanel> {
  int transport = 0;
  final systems = TextEditingController();
  String? outletError;

  @override
  void dispose() {
    systems.dispose();
    super.dispose();
  }

  void checkOutlet() {
    setState(() {
      outletError = null;
      final raw = systems.text.trim();
      if (raw.isEmpty) return;
      final value = int.tryParse(raw);
      if (value == null) {
        outletError = 'Escribe un número entero de sistemas.';
        return;
      }
      final inches = porcinoSiloOutletInches(value);
      outletError = inches == null
          ? 'El material solo cubre de 1 a 4 sistemas.'
          : 'Boca de salida sugerida: $inches.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final categories = <String, List<PorcinoFeedingRef>>{};
    for (final ref in porcinoFeedingRefs) {
      categories.putIfAbsent(ref.category, () => []).add(ref);
    }
    final t = porcinoFeedTransports[transport];
    return VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelHeader(
            icon: VetIcons.truck,
            title: 'Sistemas de alimentación por etapas',
            subtitle:
                'Transporte de alimento, silos-tolva, tolva-báscula, manejo de '
                'comederos y tamaño de partícula.',
          ),
          const VetNotice(
            text:
                'Referencias de material de clase (Pork School, ago-2026). Son '
                'pautas de diseño, no metas de rendimiento ni límites '
                'operativos. Confírmalas con tu proveedor.',
            icon: VetIcons.clipboardChecks,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 4),
            child: Text('Sistema de transporte', style: textTheme.titleSmall),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (i, model) in porcinoFeedTransports.indexed)
                ChoiceChip(
                  label: Text('Mod. ${model.model}'),
                  selected: transport == i,
                  onSelected: (_) => setState(() => transport = i),
                ),
            ],
          ),
          _Results([
            ('Diámetro', '${_fmt(t.diameterInches, 1)}"'),
            ('Longitud máxima', '${_fmt(t.maxLengthM, 0)} m'),
            ('Capacidad máxima', '${t.capacity} ${t.unit}'),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 4),
            child: Text('Silo: boca de salida', style: textTheme.titleSmall),
          ),
          _Field(
            controller: systems,
            label: 'Número de sistemas (líneas)',
            helper: '16" para 1-2 sistemas; 22" para 3-4 sistemas.',
            onChanged: checkOutlet,
          ),
          if (outletError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(outletError!, style: textTheme.bodySmall),
            ),
          for (final entry in categories.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 4),
              child: Text(entry.key, style: textTheme.titleSmall),
            ),
            for (final ref in entry.value)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ref.dato, style: textTheme.bodyMedium),
                          if (ref.nota.isNotEmpty)
                            Text(ref.nota, style: textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (ref.valor.isNotEmpty)
                      Text(
                        ref.unidad.isEmpty
                            ? ref.valor
                            : '${ref.valor} ${ref.unidad}',
                        textAlign: TextAlign.right,
                        style: textTheme.titleSmall,
                      ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 10),
          Text(
            'Fuente: $porcinoFeedingSource',
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Planes de flujo por bandas guardados en la clínica.
///
/// Lee los planes por RLS y guarda por el RPC idempotente
/// `produccion_banda_guardar`; elimina con `produccion_banda_eliminar`. Las
/// entradas se capturan como JSON: el panel no rehace el cálculo, conserva el
/// contrato del servidor.
class PorcinoBandPlanPanel extends StatefulWidget {
  const PorcinoBandPlanPanel({
    super.key,
    required this.repository,
    required this.clinicId,
  });
  final PorcinoRepository repository;
  final String clinicId;

  @override
  State<PorcinoBandPlanPanel> createState() => _PorcinoBandPlanPanelState();
}

class _PorcinoBandPlanPanelState extends State<PorcinoBandPlanPanel> {
  final name = TextEditingController();
  final sows = TextEditingController(text: '550');
  List<PorcinoBandPlan> plans = [];
  bool busy = false;
  String? error, status;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    name.dispose();
    sows.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final rows = await widget.repository.listBandPlans(widget.clinicId);
      if (!mounted) return;
      setState(() => plans = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = 'No se pudieron leer los planes: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    final planName = name.text.trim();
    if (planName.isEmpty) {
      setState(() => error = 'Ponle un nombre al plan.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
      status = null;
    });
    try {
      final id = await widget.repository.saveBandPlan(
        widget.clinicId,
        {
          'nombre': planName,
          'especie': 'cerdo',
          'entradas': {'vientres': int.tryParse(sows.text.trim()) ?? 0},
          'resultados': <String, dynamic>{},
        },
        operation: newOperationId(),
      );
      if (!mounted) return;
      setState(() => status = 'Plan guardado ($id).');
      name.clear();
      await load();
    } catch (e) {
      if (!mounted) return;
      setState(() => error = 'No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> remove(PorcinoBandPlan plan) async {
    setState(() {
      busy = true;
      error = null;
      status = null;
    });
    try {
      final ok = await widget.repository.deleteBandPlan(
        widget.clinicId,
        plan.id,
        operation: newOperationId(),
      );
      if (!mounted) return;
      setState(() => status = ok ? 'Plan eliminado.' : 'No se eliminó.');
      await load();
    } catch (e) {
      if (!mounted) return;
      setState(() => error = 'No se pudo eliminar: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelHeader(
            icon: VetIcons.cloudUpload,
            title: 'Planes guardados del flujo por bandas',
            subtitle:
                'Guarda en la clínica los planes de flujo. Se guardan por el '
                'RPC idempotente; la tabla solo permite leer.',
          ),
          const VetNotice(
            text:
                'Estos planes son registros operativos de tu clínica, no datos '
                'clínicos de pacientes. Se leen y escriben con tu sesión.',
            icon: VetIcons.shieldCheck,
          ),
          const SizedBox(height: 8),
          _Field(
            controller: name,
            label: 'Nombre del plan',
            onChanged: () => setState(() => status = null),
          ),
          _Field(
            controller: sows,
            label: 'Vientres',
            onChanged: () => setState(() => status = null),
          ),
          const SizedBox(height: 8),
          VetActionButton(
            icon: VetIcons.save,
            label: 'Guardar plan',
            onPressed: busy ? null : save,
          ),
          if (status != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: VetNotice(text: status!, icon: VetIcons.documentCheck),
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
          const SizedBox(height: 12),
          if (busy && plans.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (plans.isEmpty)
            Text('Aún no hay planes guardados.', style: textTheme.bodySmall)
          else
            for (final plan in plans)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(plan.name),
                subtitle: Text(
                  '${plan.species} · v${plan.version} · '
                  '${plan.inputs['vientres'] ?? '—'} vientres',
                  style: textTheme.bodySmall,
                ),
                trailing: IconButton(
                  icon: const Icon(VetIcons.trash),
                  tooltip: 'Eliminar plan',
                  onPressed: busy ? null : () => remove(plan),
                ),
              ),
        ],
      ),
    );
  }
}

/// Catálogo remoto de referencias de bioseguridad (solo lectura).
///
/// Muestra las 33 filas aplicadas en `produccion_bioseguridad_refs`, agrupadas
/// por categoría. No es un cálculo: es la fuente publicada, para consultarla.
class PorcinoBiosecurityRefsPanel extends StatefulWidget {
  const PorcinoBiosecurityRefsPanel({super.key, required this.repository});
  final PorcinoRepository repository;

  @override
  State<PorcinoBiosecurityRefsPanel> createState() =>
      _PorcinoBiosecurityRefsPanelState();
}

class _PorcinoBiosecurityRefsPanelState
    extends State<PorcinoBiosecurityRefsPanel> {
  List<Map<String, dynamic>> refs = [];
  bool busy = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final rows = await widget.repository.biosecurityRefs();
      if (!mounted) return;
      setState(() => refs = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = 'No se pudo leer el catálogo: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final row in refs) {
      grouped.putIfAbsent('${row['categoria']}', () => []).add(row);
    }
    return VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelHeader(
            icon: VetIcons.clipboardChecks,
            title: 'Catálogo de bioseguridad (en línea)',
            subtitle:
                'Referencias publicadas de bioseguridad porcina, agrupadas por '
                'categoría. Solo lectura.',
          ),
          if (busy && refs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (error != null)
            VetNotice(
              text: error!,
              icon: VetIcons.alertOctagon,
              kind: VetBadgeKind.danger,
            ),
          if (!busy && error == null && refs.isEmpty)
            Text('El catálogo está vacío.', style: textTheme.bodySmall),
          for (final entry in grouped.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 4),
              child: Text(entry.key, style: textTheme.titleSmall),
            ),
            for (final row in entry.value)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '${row['dato']}',
                        style: textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if ('${row['valor']}'.isNotEmpty)
                      Text(
                        '${row['valor']} ${row['unidad']}'.trim(),
                        textAlign: TextAlign.right,
                        style: textTheme.titleSmall,
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

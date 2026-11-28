import '../../../core/widgets/horizontal_choice_strip.dart';
import 'package:flutter/material.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_icons.dart';
import '../../../vet_ui/vet_theme.dart';
import '../domain/aquaculture_reference.dart';
import '../domain/aquaculture_management_reference.dart';
import '../domain/aquaculture_species.dart';

/// Paneles del módulo de acuicultura, agrupados por calculadora.
///
/// La especie se elige con un botón dentro de cada calculadora, no antes: así
/// se comparan especies sin salir del apartado. Cada calculadora solo se abre
/// donde la fuente publica el dato de esa especie; donde no, dice por qué en
/// vez de reutilizar la tabla de otra.
///
/// Cálculos de sesión; no guardan registros ni confirman que sea adecuado
/// sembrar o alimentar.
List<Widget> aquaculturePanelsFor(FishSpecies species) => [
  AquacultureSpeciesPanel(species: species),
  const _Gap(),
  AquacultureSeedPanel(species: species),
  const _Gap(),
  AquacultureRationPanel(species: species),
  const _Gap(),
  AquacultureIndicatorsPanel(),
  const _Gap(),
  AquacultureFcrPanel(),
  const _Gap(),
  AquacultureOxygenDemandPanel(),
  const _Gap(),
  AquacultureAeratorPanel(),
  const _Gap(),
  AquacultureOxygenReservePanel(),
  const _Gap(),
  AquacultureWaterExchangePanel(),
  const _Gap(),
  AquacultureNitriteSaltPanel(species: species),
  const _Gap(),
  AquacultureMedicatedFeedPanel(),
];

/// Cabecera del apartado: recuerda de qué especie son los datos y qué falta.
class AquacultureSpeciesPanel extends StatelessWidget {
  const AquacultureSpeciesPanel({super.key, required this.species});
  final FishSpecies species;

  @override
  Widget build(BuildContext context) => VetCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PanelHeader(
          icon: VetIcons.fish,
          title: 'Calculadoras de peces',
          subtitle:
              'Cada calculadora elige su especie y solo usa los datos que la '
              'fuente publica para ella.',
        ),
        VetNotice(
          text:
              'Datos de ${species.label}. Si cambias de especie en una '
              'calculadora, sus números se recalculan con la tabla de esa '
              'especie, nunca con la anterior.',
          icon: VetIcons.clipboardChecks,
        ),
      ],
    ),
  );
}

// ----------------------------------------------------------- Utilidades

class _Gap extends SizedBox {
  const _Gap() : super(height: 16);
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

/// Como [_decimal] pero admite el campo vacío. Se usa donde la fuente no
/// publica el dato para esa especie y el usuario puede dejarlo en blanco.
double _optionalDecimal(TextEditingController c, String label, double fallback) {
  if (c.text.trim().isEmpty) return fallback;
  return _decimal(c, label);
}

String _fmt(double v, [int decimals = 2]) {
  if (!v.isFinite) return '—';
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
    final tenue = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: VetColors.cyan),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: textTheme.bodySmall?.copyWith(color: tenue)),
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

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    super.key,
    required this.value,
    required this.label,
    required this.items,
    required this.onChanged,
    this.helper,
  });
  final T value;
  final String label;
  final String? helper;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, helperText: helper),
      items: [
        for (final (v, text) in items)
          DropdownMenuItem<T>(value: v, child: Text(text)),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    ),
  );
}

/// Botón de especie de una calculadora. Cada botón lleva su propia clave para
/// que dos calculadoras no compartan estado al cambiar de especie.
class _SpeciesButtons extends StatelessWidget {
  const _SpeciesButtons({
    required this.species,
    required this.onChanged,
    required this.keyPrefix,
  });
  final FishSpecies species;
  final ValueChanged<FishSpecies> onChanged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Especie', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        HorizontalChoiceStrip(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in FishSpecies.values)
              VetChip(
                key: ValueKey('$keyPrefix-species-${option.name}'),
                label: option.label,
                icon: VetIcons.fish,
                selected: option == species,
                onSelected: () => onChanged(option),
              ),
          ],
        ),
      ],
    ),
  );
}

class _Results extends StatelessWidget {
  const _Results(this.rows, {this.headline});
  final List<(String, String)> rows;
  final (String, String)? headline;
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (headline != null) ...[
            Text(
              headline!.$1,
              style: textTheme.headlineSmall?.copyWith(color: VetColors.cyan),
            ),
            Text(headline!.$2, style: textTheme.bodySmall),
            const SizedBox(height: 8),
          ],
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

// ------------------------------------------------ Siembra y biomasa

class AquacultureSeedPanel extends StatefulWidget {
  const AquacultureSeedPanel({super.key, required this.species});
  final FishSpecies species;
  @override
  State<AquacultureSeedPanel> createState() => _AquacultureSeedPanelState();
}

class _AquacultureSeedPanelState extends State<AquacultureSeedPanel> {
  final area = TextEditingController(text: '1000');
  final depth = TextEditingController(text: '1.2');
  final harvest = TextEditingController(text: '500');
  final survival = TextEditingController(text: '85');
  late FishSpecies species = widget.species;
  int systemIndex = 0;
  int level = 1;
  SeedStockPlan? result;
  String? error;

  @override
  void didUpdateWidget(AquacultureSeedPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.species != widget.species) {
      species = widget.species;
      systemIndex = 0;
      result = null;
      error = null;
    }
  }

  /// Tabla de densidades de la especie elegida, o vacía si la fuente no la da.
  List<AquacultureSystem> get systems => switch (species) {
    FishSpecies.tilapia => aquacultureSystems,
    FishSpecies.trucha => troutDensityRanges,
    FishSpecies.cachama || FishSpecies.bagre => const [],
  };

  String get source => switch (species) {
    FishSpecies.tilapia => aquacultureSeedSource,
    FishSpecies.trucha => troutDensitySource,
    _ => '',
  };

  @override
  void dispose() {
    for (final c in [area, depth, harvest, survival]) {
      c.dispose();
    }
    super.dispose();
  }

  void reset() => setState(() {
    result = null;
    error = null;
  });

  void changeSpecies(FishSpecies next) => setState(() {
    species = next;
    // El índice de sistema apunta a otra tabla; se vuelve al primero para no
    // leer una densidad que pertenece a la especie anterior.
    systemIndex = 0;
    result = null;
    error = null;
  });

  void calculate() {
    setState(() {
      result = null;
      error = null;
      try {
        result = SeedStockPlan(
          systemIndex: systemIndex,
          areaM2: _decimal(area, 'Área del espejo'),
          averageDepthM: _decimal(depth, 'Profundidad media'),
          harvestWeightG: _decimal(harvest, 'Peso de cosecha'),
          survivalPercent: _decimal(survival, 'Supervivencia'),
          level: level,
          systems: systems,
        );
      } on FormatException catch (e) {
        error = e.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = result;
    final table = systems;
    final unit = table.isEmpty
        ? 'm²'
        : (table[systemIndex].perVolume ? 'm³' : 'm²');
    return VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelHeader(
            icon: VetIcons.fish,
            title: 'Siembra y biomasa máxima',
            subtitle:
                'Cuántos alevinos sembrar según el sistema, con la densidad '
                'máxima que la fuente publica para la especie elegida.',
          ),
          _SpeciesButtons(
            keyPrefix: 'aqua-seed',
            species: species,
            onChanged: changeSpecies,
          ),
          if (table.isEmpty)
            VetNotice(
              text: seedUnavailableReason(species),
              icon: VetIcons.alertOctagon,
              kind: VetBadgeKind.warning,
            )
          else ...[
            _Dropdown<int>(
              key: const ValueKey('aqua-seed-system'),
              value: systemIndex,
              label: 'Sistema de cultivo',
              items: [
                for (var i = 0; i < table.length; i++)
                  (i, '${table[i].name} (${table[i].range})'),
              ],
              onChanged: (v) => setState(() {
                systemIndex = v;
                result = null;
                error = null;
              }),
            ),
          _Field(
            controller: area,
            label: 'Área del espejo (m²)',
            decimal: true,
            onChanged: reset,
          ),
          _Field(
            controller: depth,
            label: 'Profundidad media (m)',
            decimal: true,
            onChanged: reset,
          ),
          _Field(
            controller: harvest,
            label: 'Peso de cosecha (g)',
            decimal: true,
            onChanged: reset,
          ),
          _Field(
            controller: survival,
            label: 'Supervivencia (%)',
            decimal: true,
            onChanged: reset,
          ),
          _Dropdown<int>(
            key: const ValueKey('aqua-seed-level'),
            value: level,
            label: 'Nivel de intensidad',
            items: const [
              (0, 'Conservador (mínimo)'),
              (1, 'Medio'),
              (2, 'Máximo de referencia'),
            ],
            onChanged: (v) => setState(() {
              level = v;
              result = null;
              error = null;
            }),
          ),
          VetActionButton(
            icon: VetIcons.calculator,
            label: 'Calcular siembra',
            onPressed: calculate,
          ),
          if (error != null)
            VetNotice(
              text: error!,
              icon: VetIcons.alertOctagon,
              kind: VetBadgeKind.danger,
            ),
          if (r != null)
            _Results([
              ('Biomasa final', '${_fmt(r.biomassKg, 0)} kg'),
              ('Peces a cosechar', _fmt(r.harvestFish, 0)),
              (
                'Densidad de siembra',
                '${_fmt(r.densityPerUnit, 1)} peces/$unit',
              ),
              ('Volumen de agua', '${_fmt(r.volumeM3, 0)} m³'),
            ], headline: (_fmt(r.seedFish, 0), 'alevinos a sembrar')),
          const SizedBox(height: 12),
          Text(source),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------ Ración diaria

class AquacultureRationPanel extends StatefulWidget {
  const AquacultureRationPanel({super.key, required this.species});
  final FishSpecies species;
  @override
  State<AquacultureRationPanel> createState() => _AquacultureRationPanelState();
}

class _AquacultureRationPanelState extends State<AquacultureRationPanel> {
  final weight = TextEditingController(text: '60');
  final count = TextEditingController(text: '1000');
  late FishSpecies species = widget.species;
  String temperature = '24_32';
  int troutRow = 0;
  int troutSize = 0;
  int cachamaWeek = 0;
  DailyRationPlan? result;
  TroutRationPlan? troutResult;
  CachamaRationPlan? cachamaResult;
  String? error;

  @override
  void dispose() {
    weight.dispose();
    count.dispose();
    super.dispose();
  }

  void reset() => setState(() {
    result = null;
    troutResult = null;
    cachamaResult = null;
    error = null;
  });

  @override
  void didUpdateWidget(AquacultureRationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.species != widget.species) {
      species = widget.species;
      troutRow = 0;
      troutSize = 0;
      cachamaWeek = 0;
      result = null;
      troutResult = null;
      cachamaResult = null;
      error = null;
    }
  }

  void changeSpecies(FishSpecies next) => setState(() {
    species = next;
    result = null;
    troutResult = null;
    cachamaResult = null;
    error = null;
  });

  void calculate() {
    setState(() {
      result = null;
      troutResult = null;
      cachamaResult = null;
      error = null;
      try {
        switch (species) {
          case FishSpecies.tilapia:
            result = DailyRationPlan(
              averageGrams: _decimal(weight, 'Peso promedio'),
              fishCount: _whole(count, 'Número de peces'),
              temperatureFactor: senaTemperatureFactor(temperature),
            );
          case FishSpecies.trucha:
            troutResult = TroutRationPlan(
              rowIndex: troutRow,
              sizeIndex: troutSize,
              averageGrams: _decimal(weight, 'Peso promedio'),
              fishCount: _whole(count, 'Número de peces'),
            );
          case FishSpecies.cachama:
            cachamaResult = CachamaRationPlan(
              weekIndex: cachamaWeek,
              fishCount: _whole(count, 'Número de peces'),
            );
          case FishSpecies.bagre:
            error = rationUnavailableReason(species);
        }
      } on FormatException catch (e) {
        error = e.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = result;
    final trout = troutResult;
    final cachama = cachamaResult;
    return VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelHeader(
            icon: VetIcons.trough,
            title: 'Ración diaria',
            subtitle:
                'Cada especie usa su propia tabla: SENA para tilapia, Shelton '
                'para trucha y el plan semanal de Cipa para cachama.',
          ),
          _SpeciesButtons(
            keyPrefix: 'aqua-ration',
            species: species,
            onChanged: changeSpecies,
          ),
          if (species == FishSpecies.bagre)
            VetNotice(
              text: rationUnavailableReason(species),
              icon: VetIcons.alertOctagon,
              kind: VetBadgeKind.warning,
            )
          else ...[
            _Field(
              controller: weight,
              label: 'Peso promedio (g)',
              decimal: true,
              helper: species == FishSpecies.cachama
                  ? 'Solo informativo: el plan de cachama fija el peso por semana.'
                  : null,
              onChanged: reset,
            ),
            _Field(
              controller: count,
              label: 'Número de peces',
              onChanged: reset,
            ),
            if (species == FishSpecies.tilapia)
              _Dropdown<String>(
                key: const ValueKey('aqua-ration-temp'),
                value: temperature,
                label: 'Temperatura del agua',
                items: const [
                  ('24_32', '24 a 32 °C'),
                  ('22_24', '22 a 24 °C'),
                  ('20_22', '20 a 22 °C'),
                  ('18_20', '18 a 20 °C'),
                ],
                onChanged: (v) => setState(() {
                  temperature = v;
                  result = null;
                  error = null;
                }),
              ),
            if (species == FishSpecies.trucha) ...[
              _Dropdown<int>(
                key: const ValueKey('aqua-ration-trout-temp'),
                value: troutRow,
                label: 'Temperatura del agua',
                items: [
                  for (var i = 0; i < troutRationRows.length; i++)
                    (i, troutRationRows[i].label),
                ],
                onChanged: (v) => setState(() {
                  troutRow = v;
                  troutResult = null;
                  error = null;
                }),
              ),
              _Dropdown<int>(
                key: const ValueKey('aqua-ration-trout-size'),
                value: troutSize,
                label: 'Talla (peces por libra)',
                items: [
                  for (var i = 0; i < troutSizeClasses.length; i++)
                    (i, troutSizeClasses[i]),
                ],
                helper: troutRationRows[troutRow].review,
                onChanged: (v) => setState(() {
                  troutSize = v;
                  troutResult = null;
                  error = null;
                }),
              ),
            ],
            if (species == FishSpecies.cachama)
              _Dropdown<int>(
                key: const ValueKey('aqua-ration-cachama-week'),
                value: cachamaWeek,
                label: 'Semana del plan',
                items: [
                  for (var i = 0; i < cachamaWeeks.length; i++)
                    (
                      i,
                      'Semana ${cachamaWeeks[i].week} · '
                          '${_fmt(cachamaWeeks[i].finalG, 0)} g',
                    ),
                ],
                helper: 'Cipa Acuavit, 20 semanas.',
                onChanged: (v) => setState(() {
                  cachamaWeek = v;
                  cachamaResult = null;
                  error = null;
                }),
              ),
            VetActionButton(
              icon: VetIcons.calculator,
              label: 'Calcular ración',
              onPressed: calculate,
            ),
            if (error != null)
              VetNotice(
                text: error!,
                icon: VetIcons.alertOctagon,
                kind: VetBadgeKind.danger,
              ),
            if (r != null)
              _Results([
                ('Biomasa', '${_fmt(r.biomassKg, 1)} kg'),
                (
                  '% de la biomasa',
                  '${_fmt(r.dailyPercent!, 1)} %'
                      '${r.temperatureFactor < 1 ? ' × factor de temperatura' : ''}',
                ),
              ], headline: (
                '${_fmt(r.rationKg, 2)} kg',
                'de alimento al día (repartidos en 3 o 4 raciones)',
              )),
            if (trout != null)
              _Results([
                ('Biomasa', '${_fmt(trout.biomassKg, 1)} kg'),
                ('Tasa de la tabla', '${_fmt(trout.dailyPercent!, 1)} % del peso'),
                ('Temperatura', trout.row.label),
                ('Talla', troutSizeClasses[trout.sizeIndex]),
              ], headline: (
                '${_fmt(trout.rationKg, 2)} kg',
                'de alimento al día',
              )),
            if (cachama != null)
              _Results([
                ('Peso al cierre de la semana', '${_fmt(cachama.week.finalG, 0)} g'),
                ('Ganancia diaria', '${_fmt(cachama.week.gainPerDayG, 1)} g'),
                ('Consumo por pez y día', '${_fmt(cachama.week.consumptionGPerFishDay, 2)} g'),
                ('Producto de la fuente', cachama.week.feedProduct),
                ('FCA de la fuente', _fmt(cachama.week.fcr, 2)),
                ('Biomasa estimada', '${_fmt(cachama.biomassKg, 1)} kg'),
              ], headline: (
                '${_fmt(cachama.feedKgPerDay, 2)} kg',
                'de alimento al día (${_fmt(cachama.feedKgPerWeek, 1)} kg por semana)',
              )),
            const SizedBox(height: 12),
            Text(
              switch (species) {
                FishSpecies.tilapia =>
                  'Tabla SENA (mojarra roja). Es una guía: ajusta con muestreos '
                      'cada 15 días y con el oxígeno disuelto. Solo cubre hasta '
                      '500 g de peso promedio; por encima no se interpola.',
                FishSpecies.trucha =>
                  '$troutRationSource\n\n$troutMaintenanceNote',
                FishSpecies.cachama => cachamaRationSource,
                FishSpecies.bagre => '',
              },
            ),
          ],
        ],
      ),
    );
  }
}

// --------------------------------------------- Indicadores y costos

class AquacultureIndicatorsPanel extends StatefulWidget {
  const AquacultureIndicatorsPanel({super.key});
  @override
  State<AquacultureIndicatorsPanel> createState() =>
      _AquacultureIndicatorsPanelState();
}

class _AquacultureIndicatorsPanelState
    extends State<AquacultureIndicatorsPanel> {
  final initialFish = TextEditingController(text: '18000');
  final finalFish = TextEditingController(text: '15000');
  final initialWeight = TextEditingController(text: '5');
  final finalWeight = TextEditingController(text: '772');
  final feed = TextEditingController(text: '14000');
  final feedPrice = TextEditingController(text: '0.9');
  final labor = TextEditingController(text: '3000');
  final operating = TextEditingController(text: '2000');
  final salePrice = TextEditingController(text: '2.5');
  final volume = TextEditingController(text: '5000');
  CycleIndicators? result;
  String? error;

  @override
  void dispose() {
    for (final c in [
      initialFish,
      finalFish,
      initialWeight,
      finalWeight,
      feed,
      feedPrice,
      labor,
      operating,
      salePrice,
      volume,
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
        result = CycleIndicators(
          initialFish: _whole(initialFish, 'Peces iniciales'),
          finalFish: _whole(finalFish, 'Peces finales'),
          initialWeightG: _decimal(initialWeight, 'Peso inicial'),
          finalWeightG: _decimal(finalWeight, 'Peso final'),
          feedKg: _decimal(feed, 'Alimento total'),
          feedPricePerKg: _decimal(feedPrice, 'Precio del alimento'),
          laborCost: _decimal(labor, 'Mano de obra'),
          operatingCost: _decimal(operating, 'Costos operativos'),
          salePricePerKg: _decimal(salePrice, 'Precio de venta'),
          pondVolumeM3: _decimal(volume, 'Volumen del estanque'),
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
            icon: VetIcons.banknote,
            title: 'Indicadores y costos del ciclo',
            subtitle:
                'Biomasas, supervivencia, FCA, costos, ingresos y densidad a '
                'partir de los datos del ciclo.',
          ),
          _Field(
            controller: initialFish,
            label: 'Peces iniciales',
            onChanged: reset,
          ),
          _Field(
            controller: finalFish,
            label: 'Peces finales',
            onChanged: reset,
          ),
          _Field(
            controller: initialWeight,
            label: 'Peso inicial (g)',
            decimal: true,
            onChanged: reset,
          ),
          _Field(
            controller: finalWeight,
            label: 'Peso final (g)',
            decimal: true,
            helper: '1 lb = 454 g (1.7 lb = 772 g)',
            onChanged: reset,
          ),
          _Field(
            controller: feed,
            label: 'Alimento total (kg)',
            decimal: true,
            onChanged: reset,
          ),
          _Field(
            controller: feedPrice,
            label: 'Precio alimento (\$/kg)',
            decimal: true,
            onChanged: reset,
          ),
          _Field(
            controller: labor,
            label: 'Mano de obra (\$)',
            decimal: true,
            onChanged: reset,
          ),
          _Field(
            controller: operating,
            label: 'Costos operativos (\$)',
            decimal: true,
            onChanged: reset,
          ),
          _Field(
            controller: salePrice,
            label: 'Precio de venta (\$/kg)',
            decimal: true,
            onChanged: reset,
          ),
          _Field(
            controller: volume,
            label: 'Volumen del estanque (m³)',
            decimal: true,
            onChanged: reset,
          ),
          VetActionButton(
            icon: VetIcons.calculator,
            label: 'Calcular indicadores',
            onPressed: calculate,
          ),
          if (error != null)
            VetNotice(
              text: error!,
              icon: VetIcons.alertOctagon,
              kind: VetBadgeKind.danger,
            ),
          if (r != null)
            _Results([
              (
                'Biomasa inicial / final',
                '${_fmt(r.initialBiomassKg, 0)} / ${_fmt(r.finalBiomassKg, 0)} kg',
              ),
              ('Ganancia de biomasa', '${_fmt(r.biomassGainKg, 0)} kg'),
              (
                'Supervivencia / mortalidad',
                '${_fmt(r.survivalPercent, 1)} % / ${_fmt(r.mortalityPercent, 1)} %',
              ),
              ('FCA', _fmt(r.feedConversionRatio, 2)),
              ('Costo de alimento', '\$${_fmt(r.feedCost, 0)}'),
              ('Costo total', '\$${_fmt(r.totalCost, 0)}'),
              ('Costo por kg producido', '\$${_fmt(r.costPerKg, 2)}'),
              ('Ingresos', '\$${_fmt(r.income, 0)}'),
              ('Ganancia final', '\$${_fmt(r.profit, 0)}'),
              ('Densidad poblacional', '${_fmt(r.densityPerM3, 1)} peces/m³'),
            ]),
        ],
      ),
    );
  }
}

// ------------------------------------------------ Oxígeno y aireación

class AquacultureOxygenDemandPanel extends StatefulWidget {
  const AquacultureOxygenDemandPanel({super.key});
  @override
  State<AquacultureOxygenDemandPanel> createState() =>
      _AquacultureOxygenDemandPanelState();
}

class _AquacultureOxygenDemandPanelState
    extends State<AquacultureOxygenDemandPanel> {
  final feed = TextEditingController(text: '100');
  final oxygen = TextEditingController(text: '0.35');
  final peak = TextEditingController(text: '1.5');
  String transfer = 'piedras_difusoras';
  OxygenDemand? result;
  String? error;

  @override
  void dispose() {
    for (final c in [feed, oxygen, peak]) {
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
        result = OxygenDemand(
          feedKgPerDay: _decimal(feed, 'Alimento por día'),
          oxygenPerKg: _decimal(oxygen, 'kg O₂ por kg de alimento'),
          peakFactor: _decimal(peak, 'Factor de pico'),
          transferEfficiency: oxygenTransferEfficiency(transfer),
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
            title: 'A. Demanda de oxígeno por alimento',
            subtitle:
                '350 g de O₂ por kg de alimento (Novair; Techma da 250–500 g). '
                'En RAS sube a ~1 kg.',
          ),
          _Field(
            controller: feed,
            label: 'Alimento (kg/día)',
            decimal: true,
            onChanged: reset,
          ),
          _Field(
            controller: oxygen,
            label: 'kg O₂ por kg de alimento',
            decimal: true,
            onChanged: reset,
          ),
          _Field(
            controller: peak,
            label: 'Factor de pico',
            decimal: true,
            helper: 'Pico de 1.5 a 2 veces el promedio',
            onChanged: reset,
          ),
          _Dropdown<String>(
            key: const ValueKey('aqua-o2-transfer'),
            value: transfer,
            label: 'Eficiencia de transferencia',
            items: const [
              ('piedras_difusoras', 'Piedras difusoras (10–20 %)'),
              ('venturi', 'Venturi (30–50 %)'),
              ('nanoburbujas', 'Nanoburbujas (70–85 %)'),
              ('cono_speece', 'Cono Speece (85–95 %)'),
            ],
            onChanged: (v) => setState(() {
              transfer = v;
              result = null;
              error = null;
            }),
          ),
          VetActionButton(
            icon: VetIcons.calculator,
            label: 'Calcular oxígeno',
            onPressed: calculate,
          ),
          if (error != null)
            VetNotice(
              text: error!,
              icon: VetIcons.alertOctagon,
              kind: VetBadgeKind.danger,
            ),
          if (r != null)
            _Results([
              ('O₂ por día', '${_fmt(r.oxygenKgPerDay, 1)} kg'),
              (
                'O₂ promedio / pico',
                '${_fmt(r.averageKgPerHour, 2)} / ${_fmt(r.peakKgPerHour, 2)} kg/h',
              ),
              (
                'Generador necesario',
                '${_fmt(r.generatorKgPerHour, 2)} kg/h '
                    '(${_fmt(r.generatorNm3PerHour, 1)} Nm³/h)',
              ),
            ]),
        ],
      ),
    );
  }
}

class AquacultureAeratorPanel extends StatefulWidget {
  const AquacultureAeratorPanel({super.key});
  @override
  State<AquacultureAeratorPanel> createState() =>
      _AquacultureAeratorPanelState();
}

class _AquacultureAeratorPanelState extends State<AquacultureAeratorPanel> {
  final tod = TextEditingController(text: '3');
  final co = TextEditingController();
  final rc = TextEditingController();
  final rf = TextEditingController();
  final volume = TextEditingController();
  final sotr = TextEditingController(text: '3.25');
  final cs = TextEditingController(text: '7.8');
  final c1 = TextEditingController(text: '3.4');
  final t1 = TextEditingController(text: '25');
  final tf = TextEditingController(text: '28');
  final kw = TextEditingController(text: '3');
  final hours = TextEditingController(text: '24');
  final price = TextEditingController(text: '0.035');
  AeratorPlan? result;
  double? monthlyKwh;
  double? monthlyCost;
  String? error;

  @override
  void dispose() {
    for (final c in [
      tod,
      co,
      rc,
      rf,
      volume,
      sotr,
      cs,
      c1,
      t1,
      tf,
      kw,
      hours,
      price,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _optional(TextEditingController c) {
    final raw = c.text.trim();
    if (raw.isEmpty) return null;
    return _decimal(c, 'Valor');
  }

  void reset() => setState(() {
    result = null;
    monthlyKwh = null;
    monthlyCost = null;
    error = null;
  });

  void calculate() {
    setState(() {
      result = null;
      monthlyKwh = null;
      monthlyCost = null;
      error = null;
      try {
        final coV = _optional(co), rcV = _optional(rc), rfV = _optional(rf);
        final volumeV = _optional(volume);
        final sum = (coV ?? 0) + (rcV ?? 0) + (rfV ?? 0);
        final plan = (volumeV != null && volumeV > 0 && sum > 0)
            ? AeratorPlan.fromConsumption(
                coMgLh: coV ?? 0,
                rcMgLh: rcV ?? 0,
                rfMgLh: rfV ?? 0,
                volumeM3: volumeV,
                sotrKgPerHour: _decimal(sotr, 'SOTR'),
                saturationMgL: _decimal(cs, 'Cs'),
                minimumMgL: _decimal(c1, 'C1'),
                t1C: _decimal(t1, 'T1'),
                tfC: _decimal(tf, 'TF'),
              )
            : AeratorPlan(
                todKgPerHour: _decimal(tod, 'TOD'),
                sotrKgPerHour: _decimal(sotr, 'SOTR'),
                saturationMgL: _decimal(cs, 'Cs'),
                minimumMgL: _decimal(c1, 'C1'),
                t1C: _decimal(t1, 'T1'),
                tfC: _decimal(tf, 'TF'),
              );
        result = plan;
        final kwh =
            plan.aeratorsToInstall *
            _decimal(kw, 'Consumo por aireador') *
            _decimal(hours, 'Horas por día') *
            30;
        monthlyKwh = kwh;
        monthlyCost = kwh * _decimal(price, 'Precio por kWh');
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
            icon: VetIcons.wind,
            title: 'B. Número de aireadores',
            subtitle:
                'TOD directo o derivado de (CO + RC + RF) × V, con el OTR '
                'corregido por temperatura (1.024^(T1 − TF)).',
          ),
          _Field(
            controller: tod,
            label: 'TOD directo (kg O₂/h)',
            decimal: true,
            helper: 'Se ignora si llenas CO, RC, RF y V abajo',
            onChanged: reset,
          ),
          _Field(
            controller: co,
            label: 'CO peces (mg/L/h)',
            decimal: true,
            onChanged: reset,
          ),
          _Field(
            controller: rc,
            label: 'RC columna (mg/L/h)',
            decimal: true,
            onChanged: reset,
          ),
          _Field(
            controller: rf,
            label: 'RF fondo (mg/L/h)',
            decimal: true,
            onChanged: reset,
          ),
          _Field(
            controller: volume,
            label: 'V (m³)',
            decimal: true,
            onChanged: reset,
          ),
          _Field(
            controller: sotr,
            label: 'SOTR (kg O₂/h por aireador)',
            decimal: true,
            onChanged: reset,
          ),
          _Field(
            controller: cs,
            label: 'Cs, saturación (mg/L)',
            decimal: true,
            onChanged: reset,
          ),
          _Field(
            controller: c1,
            label: 'C1, mínimo permitido (mg/L)',
            decimal: true,
            onChanged: reset,
          ),
          _Field(
            controller: t1,
            label: 'T1 (°C)',
            decimal: true,
            onChanged: reset,
          ),
          _Field(
            controller: tf,
            label: 'TF (°C)',
            decimal: true,
            helper: 'T1 y TF por confirmar: el SOTR se publica a 20 °C',
            onChanged: reset,
          ),
          _Field(
            controller: kw,
            label: 'Consumo por aireador (kW)',
            decimal: true,
            onChanged: reset,
          ),
          _Field(
            controller: hours,
            label: 'Horas por día',
            decimal: true,
            onChanged: reset,
          ),
          _Field(
            controller: price,
            label: 'Precio (USD/kWh)',
            decimal: true,
            onChanged: reset,
          ),
          VetActionButton(
            icon: VetIcons.calculator,
            label: 'Calcular aireadores',
            onPressed: calculate,
          ),
          if (error != null)
            VetNotice(
              text: error!,
              icon: VetIcons.alertOctagon,
              kind: VetBadgeKind.danger,
            ),
          if (r != null)
            _Results([
              ('TOD usado', '${_fmt(r.todKgPerHour, 2)} kg O₂/h'),
              (
                'OTR / OTR corregido',
                '${_fmt(r.otrKgPerHour, 2)} / ${_fmt(r.otrTemperatureKgPerHour, 2)}',
              ),
              if (monthlyKwh != null)
                (
                  'Consumo y costo mensual',
                  '${_fmt(monthlyKwh!, 0)} kWh · \$${_fmt(monthlyCost!, 1)}',
                ),
            ], headline: (
              _fmt(r.aeratorsToInstall.toDouble(), 0),
              'aireadores a instalar (calculado ${_fmt(r.aerators, 2)})',
            )),
          const SizedBox(height: 12),
          const Text(
            'El presentador dice que el SOTR está a 20 °C, pero su ejemplo usa '
            'T1 = 25 y TF = 28. Confirma esas temperaturas antes de usarlo.',
          ),
        ],
      ),
    );
  }
}

class AquacultureOxygenReservePanel extends StatefulWidget {
  const AquacultureOxygenReservePanel({super.key});
  @override
  State<AquacultureOxygenReservePanel> createState() =>
      _AquacultureOxygenReservePanelState();
}

class _AquacultureOxygenReservePanelState
    extends State<AquacultureOxygenReservePanel> {
  final oxygen = TextEditingController(text: '8.5');
  final minimum = TextEditingController(text: '3.5');
  final losses = TextEditingController(text: '0.6');
  final reading = TextEditingController(text: '18');
  final dawn = TextEditingController(text: '6');
  OxygenReserve? result;
  String? error;

  @override
  void dispose() {
    for (final c in [oxygen, minimum, losses, reading, dawn]) {
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
        result = OxygenReserve(
          currentMgL: _decimal(oxygen, 'O₂ a la hora de lectura'),
          minimumMgL: _decimal(minimum, 'Mínimo'),
          lossesMgLh: _decimal(losses, 'Pérdidas totales'),
          readingHour: _whole(reading, 'Hora de lectura'),
          dawnHour: _whole(dawn, 'Hora del amanecer'),
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
            icon: VetIcons.clock,
            title: 'C. Horas de reserva de oxígeno',
            subtitle:
                'Cuánto aguanta el oxígeno sin aireación y si alcanza hasta el '
                'amanecer.',
          ),
          _Field(
            controller: oxygen,
            label: 'O₂ a la hora de lectura (mg/L)',
            decimal: true,
            onChanged: reset,
          ),
          _Field(
            controller: minimum,
            label: 'Mínimo (mg/L)',
            decimal: true,
            onChanged: reset,
          ),
          _Field(
            controller: losses,
            label: 'Pérdidas totales (mg/L/h)',
            decimal: true,
            onChanged: reset,
          ),
          _Field(
            controller: reading,
            label: 'Hora de lectura (0–23)',
            onChanged: reset,
          ),
          _Field(
            controller: dawn,
            label: 'Hora del amanecer (0–23)',
            onChanged: reset,
          ),
          VetActionButton(
            icon: VetIcons.calculator,
            label: 'Calcular reserva',
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
                'Superávit y horas de reserva',
                '${_fmt(r.surplusMgL, 1)} mg/L · ${_fmt(r.reserveHours, 1)} h',
              ),
              (
                'Hay oxígeno hasta',
                r.depletionHour == null
                    ? 'Ya por debajo del mínimo'
                    : '${r.depletionHour!.toString().padLeft(2, '0')}:00',
              ),
            ]),
            VetNotice(
              text: r.reachesDawn
                  ? 'Alcanza hasta el amanecer: no haría falta aireación nocturna.'
                  : 'No alcanza hasta el amanecer: hay que prender aireadores antes de esa hora.',
              icon: VetIcons.wind,
              kind: r.reachesDawn ? VetBadgeKind.success : VetBadgeKind.warning,
            ),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------- FCA, recambio, sal, medicado

class AquacultureFcrPanel extends StatefulWidget {
  const AquacultureFcrPanel({super.key});
  @override
  State<AquacultureFcrPanel> createState() => _AquacultureFcrPanelState();
}

class _AquacultureFcrPanelState extends State<AquacultureFcrPanel> {
  final feed = TextEditingController(text: '1000');
  final initial = TextEditingController(text: '10');
  final finalBiomass = TextEditingController(text: '765');
  final withdrawn = TextEditingController(text: '0');
  final dead = TextEditingController(text: '0');
  final initialWeight = TextEditingController(text: '1');
  final finalWeight = TextEditingController(text: '500');
  final feedPrice = TextEditingController(text: '2.8');
  final salePrice = TextEditingController(text: '0');
  final days = TextEditingController(text: '100');
  final target = TextEditingController(text: '1.2');
  FeedConversionPlan? result;
  String? error;

  @override
  void dispose() {
    for (final c in [
      feed,
      initial,
      finalBiomass,
      withdrawn,
      dead,
      initialWeight,
      finalWeight,
      feedPrice,
      salePrice,
      days,
      target,
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
        result = FeedConversionPlan(
          feedKg: _decimal(feed, 'Alimento'),
          initialBiomassKg: _decimal(initial, 'Biomasa inicial'),
          finalBiomassKg: _decimal(finalBiomass, 'Biomasa final'),
          withdrawnBiomassKg: _decimal(withdrawn, 'Biomasa retirada'),
          deadFish: _whole(dead, 'Peces muertos'),
          initialWeightG: _decimal(initialWeight, 'Peso inicial'),
          finalWeightG: _decimal(finalWeight, 'Peso final'),
          feedPricePerKg: _decimal(feedPrice, 'Precio del alimento'),
          salePricePerKg: _decimal(salePrice, 'Precio de venta'),
          days: _decimal(days, 'Días del ciclo'),
        );
      } on FormatException catch (e) {
        error = e.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = result;
    final targetValue = double.tryParse(target.text.replaceAll(',', '.'));
    return VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelHeader(
            icon: VetIcons.trendingUp,
            title: 'Conversión alimenticia (FCA) y costo',
            subtitle:
                'FCA aparente y con mortalidad, costo por kg producido y '
                'cuánto se ahorra al bajar el FCA.',
          ),
          _Field(controller: feed, label: 'Alimento consumido (kg)', decimal: true, onChanged: reset),
          _Field(controller: initial, label: 'Biomasa inicial (kg)', decimal: true, onChanged: reset),
          _Field(controller: finalBiomass, label: 'Biomasa final (kg)', decimal: true, onChanged: reset),
          _Field(controller: withdrawn, label: 'Biomasa retirada (kg)', decimal: true, onChanged: reset),
          _Field(controller: dead, label: 'Peces muertos (nº)', onChanged: reset),
          _Field(controller: initialWeight, label: 'Peso inicial (g)', decimal: true, onChanged: reset),
          _Field(controller: finalWeight, label: 'Peso final (g)', decimal: true, onChanged: reset),
          _Field(controller: feedPrice, label: 'Precio alimento (\$/kg)', decimal: true, onChanged: reset),
          _Field(controller: salePrice, label: 'Precio de venta (\$/kg)', decimal: true, onChanged: reset),
          _Field(controller: days, label: 'Días del ciclo', decimal: true, onChanged: reset),
          _Field(controller: target, label: 'FCA objetivo', decimal: true, helper: 'Para la tabla de ahorro', onChanged: reset),
          VetActionButton(
            icon: VetIcons.calculator,
            label: 'Calcular FCA y costo',
            onPressed: calculate,
          ),
          if (error != null)
            VetNotice(text: error!, icon: VetIcons.alertOctagon, kind: VetBadgeKind.danger),
          if (r != null) ...[
            _Results([
              ('Biomasa producida', '${_fmt(r.producedBiomassKg, 0)} kg'),
              ('FCA aparente', _fmt(r.apparentFcr, 2)),
              ('FCA con mortalidad', _fmt(r.fcrWithMortality, 2)),
              ('Alimento por día', '${_fmt(r.feedPerDayKg, 2)} kg'),
              ('Ganancia diaria', '${_fmt(r.dailyWeightGainG, 2)} g/día'),
              ('Costo de alimento por kg', '\$${_fmt(r.feedCostPerKg, 2)}'),
              if (r.feedShareOfSalePrice != null)
                ('Alimento sobre precio de venta', '${_fmt(r.feedShareOfSalePrice! * 100, 1)} %'),
            ]),
            if (targetValue != null && targetValue > 0)
              _Results([
                ('Alimento con FCA ${_fmt(targetValue, 2)}', '${_fmt(r.feedForTargetFcr(targetValue), 0)} kg'),
                ('Ahorro de alimento', '\$${_fmt(r.savingsForTargetFcr(targetValue), 0)}'),
              ]),
            const VetNotice(
              text:
                  'La biomasa de los peces muertos se estima con el peso medio '
                  'si no se registró: es un supuesto, no un dato medido.',
              icon: VetIcons.clipboardChecks,
            ),
          ],
        ],
      ),
    );
  }
}

class AquacultureWaterExchangePanel extends StatefulWidget {
  const AquacultureWaterExchangePanel({super.key});
  @override
  State<AquacultureWaterExchangePanel> createState() =>
      _AquacultureWaterExchangePanelState();
}

class _AquacultureWaterExchangePanelState
    extends State<AquacultureWaterExchangePanel> {
  final volume = TextEditingController(text: '10');
  final ammonia = TextEditingController(text: '0');
  final ammoniaTarget = TextEditingController(text: '0');
  final nitrite = TextEditingController(text: '4');
  final nitriteTarget = TextEditingController(text: '2.5');
  final nitrate = TextEditingController(text: '0');
  final nitrateTarget = TextEditingController(text: '0');
  WaterExchangePlan? result;
  String? error;

  @override
  void dispose() {
    for (final c in [
      volume,
      ammonia,
      ammoniaTarget,
      nitrite,
      nitriteTarget,
      nitrate,
      nitrateTarget,
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
        result = WaterExchangePlan(
          volumeM3: _decimal(volume, 'Volumen'),
          currentAmmoniaMgL: _decimal(ammonia, 'Amonio actual'),
          desiredAmmoniaMgL: _decimal(ammoniaTarget, 'Amonio deseado'),
          currentNitriteMgL: _decimal(nitrite, 'Nitrito actual'),
          desiredNitriteMgL: _decimal(nitriteTarget, 'Nitrito deseado'),
          currentNitrateMgL: _decimal(nitrate, 'Nitrato actual'),
          desiredNitrateMgL: _decimal(nitrateTarget, 'Nitrato deseado'),
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
            title: 'Recambio de agua',
            subtitle:
                'Fracción a recambiar por dilución, tomando el máximo entre '
                'amonio, nitrito y nitrato.',
          ),
          _Field(controller: volume, label: 'Volumen (m³)', decimal: true, onChanged: reset),
          _Field(controller: ammonia, label: 'Amonio (TAN) actual (mg/L)', decimal: true, onChanged: reset),
          _Field(controller: ammoniaTarget, label: 'Amonio deseado (mg/L)', decimal: true, onChanged: reset),
          _Field(controller: nitrite, label: 'Nitrito (NO₂-N) actual (mg/L)', decimal: true, onChanged: reset),
          _Field(controller: nitriteTarget, label: 'Nitrito deseado (mg/L)', decimal: true, onChanged: reset),
          _Field(controller: nitrate, label: 'Nitrato (NO₃-N) actual (mg/L)', decimal: true, onChanged: reset),
          _Field(controller: nitrateTarget, label: 'Nitrato deseado (mg/L)', decimal: true, onChanged: reset),
          VetActionButton(
            icon: VetIcons.calculator,
            label: 'Calcular recambio',
            onPressed: calculate,
          ),
          if (error != null)
            VetNotice(text: error!, icon: VetIcons.alertOctagon, kind: VetBadgeKind.danger),
          if (r != null)
            _Results([
              ('Fracción a recambiar', '${_fmt(r.requiredFraction * 100, 1)} %'),
              ('Agua a recambiar', '${_fmt(r.liters, 0)} L'),
              ('Recambios sucesivos', '${r.exchanges}'),
              ('Amonio / nitrito / nitrato', '${_fmt(r.ammoniaFraction * 100, 0)} % · ${_fmt(r.nitriteFraction * 100, 0)} % · ${_fmt(r.nitrateFraction * 100, 0)} %'),
            ]),
        ],
      ),
    );
  }
}

class AquacultureNitriteSaltPanel extends StatefulWidget {
  const AquacultureNitriteSaltPanel({super.key, required this.species});
  final FishSpecies species;
  @override
  State<AquacultureNitriteSaltPanel> createState() =>
      _AquacultureNitriteSaltPanelState();
}

class _AquacultureNitriteSaltPanelState
    extends State<AquacultureNitriteSaltPanel> {
  final volume = TextEditingController(text: '100');
  final nitrite = TextEditingController(text: '2');
  final chloride = TextEditingController(text: '10');
  final ratio = TextEditingController(text: '20');
  final maintenance = TextEditingController();
  final purity = TextEditingController(text: '99');
  late FishSpecies species = widget.species;
  NitriteSaltPlan? result;
  String? error;

  @override
  void initState() {
    super.initState();
    _applySpeciesDefaults(species);
  }

  /// Siembra la relación y el cloruro con el dato publicado de la especie. En
  /// las que no lo publican el campo queda vacío a propósito: rellenarlo con el
  /// número de otra especie es justo el error que hay que evitar.
  void _applySpeciesDefaults(FishSpecies next) {
    ratio.text = next == FishSpecies.bagre ? _fmt(bagreNitriteRatio, 0) : '20';
    final published = maintenanceChlorideFor(next);
    maintenance.text = published == null ? '' : _fmt(published, 0);
  }

  @override
  void didUpdateWidget(AquacultureNitriteSaltPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.species != widget.species) {
      species = widget.species;
      _applySpeciesDefaults(species);
      result = null;
      error = null;
    }
  }

  @override
  void dispose() {
    for (final c in [volume, nitrite, chloride, ratio, maintenance, purity]) {
      c.dispose();
    }
    super.dispose();
  }

  void reset() => setState(() {
    result = null;
    error = null;
  });

  void changeSpecies(FishSpecies next) => setState(() {
    species = next;
    _applySpeciesDefaults(next);
    result = null;
    error = null;
  });

  void calculate() {
    setState(() {
      result = null;
      error = null;
      try {
        result = NitriteSaltPlan(
          volumeM3: _decimal(volume, 'Volumen'),
          nitriteNitrogenMgL: _decimal(nitrite, 'Nitrito'),
          currentChlorideMgL: _decimal(chloride, 'Cloruro actual'),
          ratio: _decimal(ratio, 'Relación'),
          maintenanceChlorideMgL: _optionalDecimal(
            maintenance,
            'Cloruro de mantenimiento',
            0,
          ),
          purityPercent: _decimal(purity, 'Pureza'),
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
            icon: VetIcons.flask,
            title: 'Sal contra el nitrito',
            subtitle:
                'Cloruro objetivo por la relación Cl:NO₂-N, sal común sin yodo '
                'necesaria para alcanzarlo.',
          ),
          _SpeciesButtons(
            keyPrefix: 'aqua-nitrite',
            species: species,
            onChanged: changeSpecies,
          ),
          _Field(controller: volume, label: 'Volumen (m³)', decimal: true, onChanged: reset),
          _Field(controller: nitrite, label: 'Nitrito (NO₂-N) (mg/L)', decimal: true, onChanged: reset),
          _Field(controller: chloride, label: 'Cloruro actual (mg/L)', decimal: true, onChanged: reset),
          _Field(controller: ratio, label: 'Relación Cl:NO₂-N', decimal: true, helper: '20 recomendada, 10 mínima', onChanged: reset),
          _Field(
            controller: maintenance,
            label: 'Cloruro de mantenimiento (mg/L)',
            decimal: true,
            helper: switch (species) {
              FishSpecies.tilapia => 'Tilapia 150–200',
              FishSpecies.bagre => 'Bagre: cloruro de seguro 100 ppm',
              _ => 'Sin valor publicado para esta especie: decide tú',
            },
            onChanged: reset,
          ),
          _Field(controller: purity, label: 'Pureza de la sal (%)', decimal: true, onChanged: reset),
          VetActionButton(
            icon: VetIcons.calculator,
            label: 'Calcular sal',
            onPressed: calculate,
          ),
          if (error != null)
            VetNotice(text: error!, icon: VetIcons.alertOctagon, kind: VetBadgeKind.danger),
          if (r != null) ...[
            _Results([
              ('Cloruro objetivo', '${_fmt(r.targetChlorideMgL, 0)} mg/L'),
              ('Cloruro a añadir', '${_fmt(r.chlorideToAddMgL, 0)} mg/L'),
              ('Sal por m³', '${_fmt(r.saltGramPerM3, 1)} g/m³'),
              ('Sal total', '${_fmt(r.saltKg, 2)} kg'),
            ]),
            if (r.belowMinimumRatio)
              const VetNotice(
                text:
                    'La relación cloruro:nitrito es menor que 10. Hay que subir '
                    'el cloruro antes de que el nitrito dañe a los peces.',
                icon: VetIcons.alertOctagon,
                kind: VetBadgeKind.warning,
              ),
            const VetNotice(
              text: 'Sal común sin yodo. Nunca sal de cura ni nitrada.',
              icon: VetIcons.flask,
            ),
          ],
        ],
      ),
    );
  }
}

class AquacultureMedicatedFeedPanel extends StatefulWidget {
  const AquacultureMedicatedFeedPanel({super.key});
  @override
  State<AquacultureMedicatedFeedPanel> createState() =>
      _AquacultureMedicatedFeedPanelState();
}

class _AquacultureMedicatedFeedPanelState
    extends State<AquacultureMedicatedFeedPanel> {
  final biomass = TextEditingController(text: '200');
  final dailyFeed = TextEditingController(text: '4');
  final dose = TextEditingController(text: '10');
  final concentration = TextEditingController(text: '50');
  final days = TextEditingController(text: '10');
  final consumption = TextEditingController(text: '100');
  MedicatedDoseBasis basis = MedicatedDoseBasis.perFishPerDay;
  MedicatedFeedPlan? result;
  String? error;

  @override
  void dispose() {
    for (final c in [biomass, dailyFeed, dose, concentration, days, consumption]) {
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
        result = MedicatedFeedPlan(
          biomassKg: _decimal(biomass, 'Biomasa'),
          dailyFeedKg: _decimal(dailyFeed, 'Alimento por día'),
          doseBasis: basis,
          doseValue: _decimal(dose, 'Dosis'),
          productConcentration: MedicatedFeedPlan.concentrationFromPercent(
            _decimal(concentration, 'Concentración'),
          ),
          treatmentDays: _decimal(days, 'Días de tratamiento'),
        );
      } on FormatException catch (e) {
        error = e.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = result;
    final consumptionValue = double.tryParse(consumption.text.replaceAll(',', '.'));
    return VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelHeader(
            icon: VetIcons.pills,
            title: 'Alimento medicado o suplementado',
            subtitle:
                'Solo aritmética: convierte la dosis que ya decidió el MVZ. No '
                'recomienda productos ni dosis.',
          ),
          _Field(controller: biomass, label: 'Biomasa (kg)', decimal: true, onChanged: reset),
          _Field(controller: dailyFeed, label: 'Alimento por día (kg)', decimal: true, onChanged: reset),
          _Dropdown<MedicatedDoseBasis>(
            value: basis,
            label: 'Base de la dosis',
            items: const [
              (MedicatedDoseBasis.perFishPerDay, 'Por kg de pez y día (mg/kg/día)'),
              (MedicatedDoseBasis.perKgFeed, 'Por kg de alimento (mg/kg)'),
            ],
            onChanged: (v) {
              basis = v;
              reset();
            },
          ),
          _Field(controller: dose, label: 'Dosis', decimal: true, onChanged: reset),
          _Field(controller: concentration, label: 'Concentración del producto (%)', decimal: true, onChanged: reset),
          _Field(controller: days, label: 'Días de tratamiento', decimal: true, onChanged: reset),
          _Field(controller: consumption, label: 'Consumo real (% del ofrecido)', decimal: true, onChanged: reset),
          VetActionButton(
            icon: VetIcons.calculator,
            label: 'Calcular alimento medicado',
            onPressed: calculate,
          ),
          if (error != null)
            VetNotice(text: error!, icon: VetIcons.alertOctagon, kind: VetBadgeKind.danger),
          if (r != null) ...[
            _Results([
              ('Activo por día', '${_fmt(r.activeGramsPerDay, 2)} g'),
              ('Producto por día', '${_fmt(r.productGramsPerDay, 2)} g'),
              ('Producto por kg de alimento', '${_fmt(r.productPerKgFeed, 3)} g'),
              ('Inclusión en el alimento', '${_fmt(r.inclusionPercent, 3)} %'),
              ('Producto para el lote', '${_fmt(r.batchGrams, 0)} g'),
              if (consumptionValue != null && consumptionValue > 0 && consumptionValue <= 100)
                (
                  'Dosis real si comen ${_fmt(consumptionValue, 0)} %',
                  '${_fmt(r.realDoseAtConsumption(consumptionValue / 100), 2)} mg/kg/día',
                ),
            ]),
            const VetNotice(
              text:
                  'Antibiótico solo con diagnóstico y receta de MVZ, y solo '
                  'productos autorizados para peces. Respetar el tiempo de '
                  'retiro y completar el tratamiento.',
              icon: VetIcons.alertOctagon,
              kind: VetBadgeKind.warning,
            ),
          ],
        ],
      ),
    );
  }
}


import 'package:flutter/material.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_icons.dart';
import '../../../vet_ui/vet_theme.dart';
import '../domain/aquaculture_reference.dart';

/// Paneles del módulo de acuicultura (tilapia): siembra y biomasa, ración
/// diaria, indicadores y costos, y oxígeno / aireación. Cálculos de sesión;
/// no guardan registros ni confirman que sea adecuado sembrar o alimentar.
List<Widget> aquaculturePanelsFor(String activity) {
  const notice = VetNotice(
    text:
        'Cálculos de sesión con referencias de clase para tilapia. No guardan '
        'registros de granja y no confirman que sea adecuado sembrar o '
        'alimentar.',
    icon: VetIcons.clipboardChecks,
  );
  return switch (activity) {
    'Tilapia' => const [
      notice,
      AquacultureSeedPanel(),
      _Gap(),
      AquacultureRationPanel(),
      _Gap(),
      AquacultureIndicatorsPanel(),
      _Gap(),
      AquacultureOxygenDemandPanel(),
      _Gap(),
      AquacultureAeratorPanel(),
      _Gap(),
      AquacultureOxygenReservePanel(),
    ],
    _ => const [],
  };
}

// ----------------------------------------------------------- Utilidades

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
  const AquacultureSeedPanel({super.key});
  @override
  State<AquacultureSeedPanel> createState() => _AquacultureSeedPanelState();
}

class _AquacultureSeedPanelState extends State<AquacultureSeedPanel> {
  final area = TextEditingController(text: '1000');
  final depth = TextEditingController(text: '1.2');
  final harvest = TextEditingController(text: '500');
  final survival = TextEditingController(text: '85');
  int systemIndex = 0;
  int level = 1;
  SeedStockPlan? result;
  String? error;

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
        );
      } on FormatException catch (e) {
        error = e.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = result;
    final unit = aquacultureSystems[systemIndex].perVolume ? 'm³' : 'm²';
    return VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelHeader(
            icon: VetIcons.fish,
            title: 'Siembra y biomasa máxima',
            subtitle:
                'Cuántos alevinos sembrar según el sistema, con la densidad '
                'máxima publicada para tilapia.',
          ),
          _Dropdown<int>(
            key: const ValueKey('aqua-seed-system'),
            value: systemIndex,
            label: 'Sistema de cultivo',
            items: [
              for (var i = 0; i < aquacultureSystems.length; i++)
                (i, '${aquacultureSystems[i].name} (${aquacultureSystems[i].range})'),
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
          const Text(aquacultureSeedSource),
        ],
      ),
    );
  }
}

// ------------------------------------------------------ Ración diaria

class AquacultureRationPanel extends StatefulWidget {
  const AquacultureRationPanel({super.key});
  @override
  State<AquacultureRationPanel> createState() => _AquacultureRationPanelState();
}

class _AquacultureRationPanelState extends State<AquacultureRationPanel> {
  final weight = TextEditingController(text: '60');
  final count = TextEditingController(text: '1000');
  String temperature = '24_32';
  DailyRationPlan? result;
  String? error;

  @override
  void dispose() {
    weight.dispose();
    count.dispose();
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
        result = DailyRationPlan(
          averageGrams: _decimal(weight, 'Peso promedio'),
          fishCount: _whole(count, 'Número de peces'),
          temperatureFactor: senaTemperatureFactor(temperature),
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
            icon: VetIcons.trough,
            title: 'Ración diaria',
            subtitle:
                'Tasa diaria de la tabla SENA (mojarra roja) por talla y '
                'temperatura. Es una guía.',
          ),
          _Field(
            controller: weight,
            label: 'Peso promedio (g)',
            decimal: true,
            onChanged: reset,
          ),
          _Field(
            controller: count,
            label: 'Número de peces',
            onChanged: reset,
          ),
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
          const SizedBox(height: 12),
          const Text(
            'Tabla SENA (mojarra roja). Es una guía: ajusta con muestreos cada '
            '15 días y con el oxígeno disuelto. Solo cubre hasta 500 g de peso '
            'promedio; por encima no se interpola.',
          ),
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

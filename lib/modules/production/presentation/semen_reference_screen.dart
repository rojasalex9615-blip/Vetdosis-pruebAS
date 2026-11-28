import '../../../core/widgets/horizontal_choice_strip.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/calculator_surface.dart';
import '../../../vet_ui/vet_components.dart';
import '../../production/domain/porcino_semen.dart';
import '../../production/domain/semen_reference.dart';

/// Evaluación seminal por especie: cerdo, perro y caballo.
///
/// Pantalla unificada. Reutiliza las piezas genéricas del módulo porcino
/// ([SemenChamber], [SemenConcentration]) y la dimensión de especie del
/// prototipo «Evaluación seminal por especie»: el perro solo evalúa el
/// eyaculado; el cerdo y el caballo reparten en dosis.
///
/// Cálculo de sesión: no guarda registros de granja ni consulta Supabase.
class SemenReferenceScreen extends StatefulWidget {
  const SemenReferenceScreen({super.key});
  @override
  State<SemenReferenceScreen> createState() => _SemenReferenceScreenState();
}

class _SemenReferenceScreenState extends State<SemenReferenceScreen> {
  final inputs = <String, TextEditingController>{};

  SemenSpeciesProfile profile = semenSpeciesProfiles.first;
  bool fromCount = false;
  SemenChamber chamber = SemenChamber.smallSquares;
  int doseTypeIndex = 0;
  SemenDiluent diluent = SemenDiluent.short;
  late DateTime collectedOn = DateTime.now();

  SemenEvaluation? result;
  double? usedConcentration;

  @override
  void initState() {
    super.initState();
    _applyProfile(profile);
  }

  @override
  void dispose() {
    for (final c in inputs.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController controller(String key) =>
      inputs.putIfAbsent(key, TextEditingController.new);

  /// Texto de un campo, o el valor por defecto si aún no se ha escrito.
  double _decimal(String key, {double? fallback}) {
    final raw = controller(key).text.trim().replaceAll(',', '.');
    if (raw.isEmpty && fallback != null) return fallback;
    final value = double.tryParse(raw);
    if (value == null) {
      throw const FormatException('Usa números sin separadores de miles.');
    }
    return value;
  }

  String _fmt(double value) {
    final fixed = value.toStringAsFixed(2);
    final trimmed = fixed.replaceFirst(RegExp(r'\.?0+$'), '');
    return trimmed.isEmpty ? '0' : trimmed;
  }

  void _applyProfile(SemenSpeciesProfile next) {
    profile = next;
    fromCount = false;
    doseTypeIndex = next.exampleDoseTypeIndex ?? 0;
    inputs.clear();
    controller('vol').text = _fmt(next.exampleVolumeMl);
    controller('conc').text = _fmt(next.exampleConcentration);
    controller('mot').text = _fmt(next.exampleMotility);
    if (next.exampleMorphology != null) {
      controller('mor').text = _fmt(next.exampleMorphology!);
    }
    if (next.exampleProgressive != null) {
      controller('prog').text = _fmt(next.exampleProgressive!);
    }
    if (next.exampleVsl != null) controller('vsl').text = _fmt(next.exampleVsl!);
    if (next.exampleStr != null) controller('str').text = _fmt(next.exampleStr!);
    if (next.exampleDoseVolumeMl != null) {
      controller('vd').text = _fmt(next.exampleDoseVolumeMl!);
    }
    controller('perd').text = '0';
    final t = next.thresholds;
    controller('t_mot').text = _fmt(t.motilityMin);
    controller('t_mor').text = t.morphologyMin == null ? '' : _fmt(t.morphologyMin!);
    controller('t_prog').text =
        t.progressiveMin == null ? '' : _fmt(t.progressiveMin!);
    controller('t_vsl').text = t.vslMin == null ? '' : _fmt(t.vslMin!);
    controller('t_str').text = t.strMin == null ? '' : _fmt(t.strMin!);
    controller('t_vol').text = _fmt(t.volumeMinMl);
    controller('t_tot').text = _fmt(t.totalSpermMinBillion);
    _compute();
  }

  SemenThresholds _readThresholds() => SemenThresholds(
    motilityMin: _decimal('t_mot', fallback: profile.thresholds.motilityMin),
    morphologyMin: profile.showMorphology
        ? _decimal('t_mor', fallback: profile.thresholds.morphologyMin ?? 0)
        : null,
    progressiveMin: profile.showProgressive
        ? _decimal('t_prog', fallback: profile.thresholds.progressiveMin ?? 0)
        : null,
    vslMin: profile.showKinetics
        ? _decimal('t_vsl', fallback: profile.thresholds.vslMin ?? 0)
        : null,
    strMin: profile.showKinetics
        ? _decimal('t_str', fallback: profile.thresholds.strMin ?? 0)
        : null,
    volumeMinMl: _decimal('t_vol', fallback: profile.thresholds.volumeMinMl),
    totalSpermMinBillion: _decimal(
      't_tot',
      fallback: profile.thresholds.totalSpermMinBillion,
    ),
  );

  void recalc() => setState(_compute);

  void _compute() {
    result = null;
    usedConcentration = null;
    try {
      final concentration = fromCount
          ? SemenConcentration.fromCount(
              cells: _decimal('cont', fallback: 38).round(),
              dilution: _decimal('dil', fallback: 200),
              chamber: chamber,
            ).millionsPerMl
          : SemenConcentration.direct(
              _decimal('conc', fallback: profile.exampleConcentration),
            ).millionsPerMl;
      usedConcentration = concentration;
      final doses = profile.doseTypes;
      result = SemenEvaluation(
        profile: profile,
        volumeMl: _decimal('vol', fallback: profile.exampleVolumeMl),
        concentrationMillionsPerMl: concentration,
        motilityPercent: _decimal('mot', fallback: profile.exampleMotility),
        morphologyPercent: profile.showMorphology
            ? _decimal('mor', fallback: profile.exampleMorphology ?? 0)
            : null,
        progressivePercent: profile.showProgressive
            ? _decimal('prog', fallback: profile.exampleProgressive ?? 0)
            : null,
        spermPerDoseBillion: profile.assessesDoses
            ? doses[doseTypeIndex].spermPerDoseBillion
            : null,
        doseVolumeMl: profile.showDoseVolume
            ? _decimal('vd', fallback: profile.exampleDoseVolumeMl ?? 80)
            : null,
        doseVolumeRange: profile.assessesDoses
            ? doses[doseTypeIndex].volumeRange
            : null,
        lossPercent: _decimal('perd', fallback: 0),
        shelfLifeDays: profile.showDiluent ? diluent.days : null,
        collectedOn: profile.showDiluent ? collectedOn : null,
        thresholds: _readThresholds(),
      );
    } on FormatException {
      // Mientras se escribe un dato incompleto no hay resultado; no se
      // inventa uno ni se grita un error en cada tecla.
    } on RangeError {
      // Un tipo de dosis fuera de lista no debe tumbar la pantalla.
    }
  }

  Future<void> pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: collectedOn,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    setState(() => collectedOn = date);
    recalc();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Evaluación seminal')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: CalculatorSurface(
        id: 'semen',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _speciesCard(),
            const SizedBox(height: 12),
            _macroCard(),
            const SizedBox(height: 12),
            _concentrationCard(),
            const SizedBox(height: 12),
            _qualityCard(),
            if (profile.assessesDoses) ...[
              const SizedBox(height: 12),
              _doseCard(),
            ],
            const SizedBox(height: 12),
            _thresholdsCard(),
            const SizedBox(height: 12),
            _resultCard(),
            if (profile.id == 'cerdo') ...[
              const SizedBox(height: 12),
              _protocolCard(),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _card(String title, List<Widget> children) => VetCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title.isNotEmpty) ...[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
        ],
        ...children,
      ],
    ),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 10),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );

  Widget _field(
    String key,
    String label, {
    bool text = false,
    double? fallback,
    String? hint,
    ValueChanged<String>? onChanged,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: TextField(
      key: ValueKey('semen-$key'),
      controller: controller(key),
      keyboardType: text
          ? TextInputType.text
          : const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      onChanged: onChanged ?? (_) => recalc(),
    ),
  );

  Widget _speciesCard() => _card('', [
    DropdownButtonFormField<String>(
      key: const ValueKey('semen-especie'),
      initialValue: profile.id,
      decoration: const InputDecoration(labelText: 'Especie'),
      items: [
        for (final p in semenSpeciesProfiles)
          DropdownMenuItem(value: p.id, child: Text(p.label)),
      ],
      onChanged: (id) {
        if (id == null) return;
        setState(() => _applyProfile(semenSpeciesProfile(id)));
      },
    ),
    const SizedBox(height: 8),
    Text(profile.source, style: Theme.of(context).textTheme.bodySmall),
  ]);

  Widget _macroCard() => _card('1. Macroscópico', [
    _field('vol', profile.volumeLabel),
    _field(
      'aspecto',
      'Color / olor / aspecto',
      text: true,
      hint: 'blanquecino',
    ),
  ]);

  Widget _concentrationCard() => _card('2. Concentración', [
    HorizontalChoiceStrip(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Lectura del analizador'),
          selected: !fromCount,
          onSelected: (_) {
            setState(() => fromCount = false);
            recalc();
          },
        ),
        ChoiceChip(
          label: const Text('Conteo en cámara de Neubauer'),
          selected: fromCount,
          onSelected: (_) {
            setState(() => fromCount = true);
            recalc();
          },
        ),
      ],
    ),
    if (fromCount) ...[
      const SizedBox(height: 8),
      _field('cont', 'Células contadas', fallback: 38),
      _field('dil', 'Factor de dilución (1:X)', fallback: 200),
      const SizedBox(height: 6),
      DropdownButtonFormField<SemenChamber>(
        key: const ValueKey('semen-area'),
        initialValue: chamber,
        decoration: const InputDecoration(labelText: 'Área contada'),
        items: [
          for (final c in SemenChamber.values)
            DropdownMenuItem(value: c, child: Text(c.label)),
        ],
        onChanged: (value) {
          if (value == null) return;
          setState(() => chamber = value);
          recalc();
        },
      ),
      const VetNotice(
        text:
            'Atajo con 1:200 y 5 cuadros medianos: células contadas × 10 = '
            'millones/ml. Confirma la dilución con tu material del curso.',
        icon: Icons.rule_outlined,
        kind: VetBadgeKind.warning,
      ),
    ] else
      _field('conc', 'Concentración (×10⁶/ml)'),
    if (usedConcentration != null)
      _row('Concentración usada', '${_fmt(usedConcentration!)} ×10⁶/ml'),
  ]);

  Widget _qualityCard() => _card('3. Calidad', [
    _field('mot', profile.motilityLabel),
    if (profile.showMorphology) _field('mor', 'Morfología normal (%)'),
    if (profile.showProgressive) _field('prog', 'Motilidad progresiva (%)'),
    if (profile.showKinetics) ...[
      _field('vsl', 'VSL (µm/s)'),
      _field('str', 'STR, rectitud (%)'),
    ],
    if (result != null)
      VetNotice(
        text: result!.verdict,
        icon: result!.isApt ? Icons.check_circle_outline : Icons.warning_amber,
        kind: result!.isApt ? VetBadgeKind.success : VetBadgeKind.danger,
      ),
  ]);

  Widget _doseCard() => _card('4. Dosis', [
    DropdownButtonFormField<int>(
      key: ValueKey('semen-tipo-${profile.id}'),
      initialValue: doseTypeIndex,
      decoration: const InputDecoration(labelText: 'Tipo de dosis'),
      items: [
        for (final (i, t) in profile.doseTypes.indexed)
          DropdownMenuItem(value: i, child: Text(t.label)),
      ],
      onChanged: (value) {
        if (value == null) return;
        setState(() => doseTypeIndex = value);
        recalc();
      },
    ),
    if (profile.showDoseVolume) ...[
      Builder(
        builder: (context) {
          final range = profile.doseTypes[doseTypeIndex].volumeRange;
          return _field(
            'vd',
            'Volumen por dosis (ml)',
            hint: range == null
                ? null
                : 'rango ${_fmt(range.min)}–${_fmt(range.max)}',
          );
        },
      ),
    ],
    _field('perd', 'Margen de pérdida (%)', fallback: 0),
    if (profile.showDiluent) ...[
      const SizedBox(height: 6),
      DropdownButtonFormField<SemenDiluent>(
        key: const ValueKey('semen-dilu'),
        initialValue: diluent,
        decoration: const InputDecoration(labelText: 'Diluyente'),
        items: [
          for (final d in SemenDiluent.values)
            DropdownMenuItem(value: d, child: Text(d.label)),
        ],
        onChanged: (value) {
          if (value == null) return;
          setState(() => diluent = value);
          recalc();
        },
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: OutlinedButton.icon(
          icon: const Icon(Icons.event_outlined),
          label: Text(
            'Fecha de colecta: '
            '${collectedOn.day}/${collectedOn.month}/${collectedOn.year}',
          ),
          onPressed: pickDate,
        ),
      ),
    ],
  ]);

  Widget _thresholdsCard() => _card('Umbrales editables', [
    _field('t_mot', 'Motilidad mín. (%)'),
    if (profile.showMorphology)
      _field('t_mor', 'Morfología normal mín. (%)'),
    if (profile.showProgressive) _field('t_prog', 'Progresiva mín. (%)'),
    if (profile.showKinetics) ...[
      _field('t_vsl', 'VSL mín. (µm/s)'),
      _field('t_str', 'STR mín. (%)'),
    ],
    _field('t_vol', 'Volumen mín. (ml)'),
    _field('t_tot', 'Total de espermatozoides mín. (×10⁹)'),
    const VetNotice(
      text:
          'Los valores por defecto cambian con la especie y la fuente. '
          'Ajústalos según tu equipo.',
      icon: Icons.rule_outlined,
      kind: VetBadgeKind.warning,
    ),
  ]);

  Widget _resultCard() {
    final r = result;
    final textTheme = Theme.of(context).textTheme;
    return _card('Resultado', [
      Text(
        r == null
            ? '—'
            : r.profile.assessesDoses
            ? '${r.doses}'
            : _fmt(r.totalSpermBillion * 1e9),
        style: textTheme.displaySmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      Text(
        r == null
            ? 'dosis'
            : r.profile.assessesDoses
            ? 'dosis'
            : 'millones de espermatozoides por eyaculado',
        style: textTheme.bodySmall,
      ),
      if (r != null) ...[
        const SizedBox(height: 8),
        _row(
          r.profile.assessesDoses
              ? 'Espermatozoides útiles totales'
              : 'Espermatozoides totales',
          '${_fmt((r.profile.assessesDoses ? r.usableSperm : r.totalSpermBillion * 1e9) / 1e9)} ×10⁹',
        ),
        if (r.finalVolumeMl != null)
          _row('Volumen final', '${_fmt(r.finalVolumeMl!)} ml'),
        if (r.diluentToAddMl != null)
          _row('Diluyente a preparar', '${_fmt(r.diluentToAddMl!)} ml'),
        if (r.useBefore != null)
          _row(
            'Usar antes de',
            '${r.useBefore!.day}/${r.useBefore!.month}/${r.useBefore!.year} '
                '(mínimo del rango)',
          ),
        if (r.leftoverSpermBillion != null)
          _row('Sobrante sin completar dosis', '${_fmt(r.leftoverSpermBillion!)} ×10⁹'),
        for (final a in r.alerts)
          VetNotice(
            text: a,
            icon: Icons.warning_amber,
            kind: VetBadgeKind.danger,
          ),
      ],
    ]);
  }

  Widget _protocolCard() => _card('Protocolo (cerdo)', [
    for (final (i, step) in semenProtocol.indexed) Text('${i + 1}. $step'),
  ]);
}

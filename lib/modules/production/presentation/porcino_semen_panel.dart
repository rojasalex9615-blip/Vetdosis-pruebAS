import 'package:flutter/material.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_theme.dart';
import '../domain/porcino_semen.dart';

/// Dosis seminales porcinas: del eyaculado a las dosis de inseminación.
///
/// Cálculo de sesión: no guarda registros de granja ni consulta Supabase.
/// Réplica del prototipo de la hoja de clase, con sus referencias y avisos.
class PorcinoSemenPanel extends StatefulWidget {
  const PorcinoSemenPanel({super.key});
  @override
  State<PorcinoSemenPanel> createState() => _PorcinoSemenPanelState();
}

class _PorcinoSemenPanelState extends State<PorcinoSemenPanel> {
  final volume = TextEditingController(text: '200');
  final aspect = TextEditingController(text: 'blanquecino, sin olor');
  final cells = TextEditingController(text: '38');
  final dilution = TextEditingController(text: '200');
  final directConc = TextEditingController(text: '380');
  final motility = TextEditingController(text: '90');
  final morphology = TextEditingController(text: '88');
  final progressive = TextEditingController(text: '75');
  final str = TextEditingController(text: '75');
  final vsl = TextEditingController(text: '35');
  final spermPerDose = TextEditingController(text: '2');
  final doseVolume = TextEditingController(text: '80');
  final loss = TextEditingController(text: '0');
  final thresholdMotility = TextEditingController(text: '85');
  final thresholdProgressive = TextEditingController(text: '70');
  final thresholdVsl = TextEditingController(text: '30');
  final thresholdStr = TextEditingController(text: '70');
  final thresholdVolume = TextEditingController(text: '50');

  bool fromCount = false;
  SemenChamber chamber = SemenChamber.smallSquares;
  SemenInsemination? insemination = SemenInsemination.postCervical;
  SemenDiluent diluent = SemenDiluent.short;
  late DateTime collectedOn = DateTime.now();

  SemenDosePlan? result;
  SemenQualityAssessment? quality;
  double? usedConcentration;

  @override
  void initState() {
    super.initState();
    _compute();
  }

  @override
  void dispose() {
    for (final c in [
      volume,
      aspect,
      cells,
      dilution,
      directConc,
      motility,
      morphology,
      progressive,
      str,
      vsl,
      spermPerDose,
      doseVolume,
      loss,
      thresholdMotility,
      thresholdProgressive,
      thresholdVsl,
      thresholdStr,
      thresholdVolume,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double _decimal(TextEditingController c) {
    final raw = c.text.trim().replaceAll(',', '.');
    final value = double.tryParse(raw);
    if (value == null) {
      throw const FormatException('Usa números sin separadores de miles.');
    }
    return value;
  }

  void recalc() => setState(_compute);

  void _compute() {
    result = null;
    quality = null;
    usedConcentration = null;
    try {
      final concentration = fromCount
          ? SemenConcentration.fromCount(
              cells: _decimal(cells).round(),
              dilution: _decimal(dilution),
              chamber: chamber,
            ).millionsPerMl
          : SemenConcentration.direct(_decimal(directConc)).millionsPerMl;
      usedConcentration = concentration;
      final thresholds = SemenQualityThresholds(
        motilityTotalMin: _decimal(thresholdMotility),
        progressiveMin: _decimal(thresholdProgressive),
        vslMin: _decimal(thresholdVsl),
        strMin: _decimal(thresholdStr),
        volumeMinMl: _decimal(thresholdVolume),
      );
      quality = SemenQualityAssessment(
        motilityPercent: _decimal(motility),
        progressivePercent: _decimal(progressive),
        strPercent: _decimal(str),
        vslMicronsPerSecond: _decimal(vsl),
        thresholds: thresholds,
      );
      result = SemenDosePlan(
        volumeMl: _decimal(volume),
        concentrationMillionsPerMl: concentration,
        motilityPercent: _decimal(motility),
        morphologyPercent: _decimal(morphology),
        spermPerDoseBillion: _decimal(spermPerDose),
        doseVolumeMl: _decimal(doseVolume),
        lossPercent: _decimal(loss),
        shelfLifeDays: diluent.days,
        collectedOn: collectedOn,
        doseVolumeRange: insemination?.doseVolumeRange,
        thresholds: thresholds,
      );
    } on FormatException {
      // Mientras se escribe un dato incompleto no hay resultado; no se
      // inventa uno ni se grita un error en cada tecla.
    }
  }

  void pickInsemination(SemenInsemination value) {
    setState(() {
      insemination = value;
      spermPerDose.text = _fmt(value.spermPerDoseBillion);
    });
    recalc();
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
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final r = result;
    return VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelHeader(
            icon: Icons.science_outlined,
            title: 'Dosis seminales porcinas',
            subtitle:
                'Del eyaculado a las dosis de inseminación. Cálculo de sesión.',
          ),
          const VetNotice(
            text:
                'Dilución y área de conteo por confirmar con el material del curso.',
            icon: Icons.rule_outlined,
            kind: VetBadgeKind.warning,
          ),

          _Step(title: '1. Macroscópico', children: [
            _Field(
              controller: volume,
              label: 'Volumen eyaculado (ml)',
              onChanged: recalc,
            ),
            _Field(
              controller: aspect,
              label: 'Color / olor / aspecto',
              text: true,
              onChanged: recalc,
            ),
          ]),

          _Step(title: '2. Concentración', children: [
            Wrap(
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
                  label: const Text('Conteo en cámara'),
                  selected: fromCount,
                  onSelected: (_) {
                    setState(() => fromCount = true);
                    recalc();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (fromCount) ...[
              _Field(
                controller: cells,
                label: 'Células contadas',
                onChanged: recalc,
              ),
              _Field(
                controller: dilution,
                label: 'Factor de dilución (1:X)',
                onChanged: recalc,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in SemenChamber.values)
                      ChoiceChip(
                        label: Text(c.label),
                        selected: chamber == c,
                        onSelected: (_) {
                          setState(() => chamber = c);
                          recalc();
                        },
                      ),
                  ],
                ),
              ),
              const VetNotice(
                text: semenCountShortcut,
                icon: Icons.calculate_outlined,
                kind: VetBadgeKind.warning,
              ),
            ] else
              _Field(
                controller: directConc,
                label: 'Concentración (×10⁶/ml)',
                onChanged: recalc,
              ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Concentración usada', style: textTheme.bodyMedium),
                  ),
                  Text(
                    usedConcentration == null
                        ? '—'
                        : '${_fmt(usedConcentration!)} ×10⁶/ml',
                    style: textTheme.titleSmall,
                  ),
                ],
              ),
            ),
          ]),

          _Step(title: '3. Calidad', children: [
            _Field(
              controller: motility,
              label: 'Motilidad (%)',
              onChanged: recalc,
            ),
            _Field(
              controller: morphology,
              label: 'Morfología normal (%)',
              onChanged: recalc,
            ),
            _Field(
              controller: progressive,
              label: 'Motilidad progresiva (%)',
              onChanged: recalc,
            ),
            _Field(
              controller: str,
              label: 'STR, rectitud (%)',
              onChanged: recalc,
            ),
            _Field(
              controller: vsl,
              label: 'VSL (µm/s)',
              onChanged: recalc,
            ),
            if (quality != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: VetNotice(
                  text: quality!.verdict,
                  icon: quality!.isApt
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  kind: quality!.isApt
                      ? VetBadgeKind.success
                      : VetBadgeKind.warning,
                ),
              ),
          ]),

          _Step(title: '4. Dosis y diluyente', children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final i in SemenInsemination.values)
                    ChoiceChip(
                      label: Text('${i.label} (${_fmt(i.spermPerDoseBillion)} ×10⁹)'),
                      selected: insemination == i,
                      onSelected: (_) => pickInsemination(i),
                    ),
                ],
              ),
            ),
            _Field(
              controller: spermPerDose,
              label: 'Espermas por dosis (×10⁹)',
              decimal: true,
              helper: 'Referencia de clase. Edítalo si usas otra pauta.',
              onChanged: recalc,
            ),
            _Field(
              controller: doseVolume,
              label: 'Volumen por dosis (ml)',
              helper: insemination == null
                  ? null
                  : 'Rango recomendado: ${_fmt(insemination!.doseVolumeMinMl)}–${_fmt(insemination!.doseVolumeMaxMl)} ml',
              onChanged: recalc,
            ),
            _Field(
              controller: loss,
              label: 'Margen de pérdida (%)',
              helper: 'Manejo y equipo. 0 si no lo estimas.',
              onChanged: recalc,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in SemenDiluent.values)
                    ChoiceChip(
                      label: Text(d.label),
                      selected: diluent == d,
                      onSelected: (_) {
                        setState(() => diluent = d);
                        recalc();
                      },
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Fecha de colecta: ${_dateLabel(collectedOn)}',
                      style: textTheme.bodyMedium,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: pickDate,
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: const Text('Cambiar'),
                  ),
                ],
              ),
            ),
          ]),

          _Step(title: 'Umbrales editables', children: [
            _Field(
              controller: thresholdMotility,
              label: 'Motilidad total mín. (%)',
              onChanged: recalc,
            ),
            _Field(
              controller: thresholdProgressive,
              label: 'Progresiva mín. (%)',
              onChanged: recalc,
            ),
            _Field(
              controller: thresholdVsl,
              label: 'VSL mín. (µm/s)',
              onChanged: recalc,
            ),
            _Field(
              controller: thresholdStr,
              label: 'STR mín. (%)',
              onChanged: recalc,
            ),
            _Field(
              controller: thresholdVolume,
              label: 'Volumen mín. del eyaculado (ml)',
              onChanged: recalc,
            ),
            const VetNotice(
              text:
                  'Por defecto: criterios de tu práctica con iSPERM. Con '
                  'microscopio y evaluación subjetiva, otras fuentes aceptan '
                  'motilidad total de 70 % o más. Ajusta según tu equipo y '
                  'especie.',
              icon: Icons.tune_outlined,
              kind: VetBadgeKind.warning,
            ),
          ]),

          if (r != null) ...[
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: VetColors.recessed,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: VetColors.softShadow),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Resultado', style: textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    '${r.doses}',
                    key: const ValueKey('semen-doses'),
                    style: textTheme.displaySmall?.copyWith(
                      color: VetColors.pink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text('dosis completas', style: textTheme.bodySmall),
                  const SizedBox(height: 10),
                  _ResultRow(
                    'Espermatozoides útiles totales',
                    '${_fmt(r.usableSpermBillion)} ×10⁹',
                  ),
                  _ResultRow('Volumen final', '${_fmt(r.finalVolumeMl)} ml'),
                  _ResultRow(
                    'Diluyente a preparar',
                    '${_fmt(r.diluentToAddMl)} ml',
                  ),
                  _ResultRow(
                    'Usar antes de',
                    '${_dateLabel(r.useBefore)} (mínimo del rango)',
                  ),
                  _ResultRow(
                    'Sobrante sin completar dosis',
                    '${_fmt(r.leftoverSpermBillion)} ×10⁹',
                  ),
                  if (r.alerts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: VetNotice(
                        text: r.alerts.join(' '),
                        icon: Icons.warning_amber_outlined,
                        kind: VetBadgeKind.warning,
                      ),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),
          Text('Protocolo', style: textTheme.titleSmall),
          const SizedBox(height: 6),
          for (final (i, step) in semenProtocol.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 22,
                    child: Text('${i + 1}.', style: textTheme.bodyMedium),
                  ),
                  Expanded(child: Text(step, style: textTheme.bodyMedium)),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Text(semenSource, style: textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        ...children,
      ],
    ),
  );
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
                Text(subtitle, style: textTheme.bodySmall),
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
    this.text = false,
  });
  final TextEditingController controller;
  final String label;
  final String? helper;
  final bool decimal, text;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: TextField(
      controller: controller,
      keyboardType: text
          ? TextInputType.text
          : TextInputType.numberWithOptions(decimal: decimal || !text),
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      onChanged: (_) => onChanged(),
    ),
  );
}

class _ResultRow extends StatelessWidget {
  const _ResultRow(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: textTheme.bodyMedium)),
          const SizedBox(width: 12),
          Text(value, textAlign: TextAlign.right, style: textTheme.titleSmall),
        ],
      ),
    );
  }
}

const _months = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

String _dateLabel(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

String _fmt(double value, [int decimals = 1]) {
  final fixed = value.toStringAsFixed(decimals);
  if (!fixed.contains('.')) return fixed;
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

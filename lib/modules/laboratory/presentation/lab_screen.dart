import 'package:flutter/material.dart';

import '../../../vet_ui/vet_components.dart';
import '../domain/lab_repository.dart';
import '../domain/lab_result.dart';
import 'lab_view_model.dart';

/// Analiticas de un paciente.
///
/// La pantalla NO resume las fuentes. Cuando un analito tiene mas de un
/// rango legitimo se pintan todos, cada uno con su procedencia y con lo que
/// cada uno dice del valor, y si no coinciden se dice en voz alta. Elegir es
/// del profesional, no de la app.
class LabScreen extends StatefulWidget {
  const LabScreen({
    super.key,
    required this.repository,
    required this.clinicId,
    required this.patientId,
    required this.patientName,
  });

  final LabRepository repository;
  final String clinicId, patientId, patientName;

  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen> {
  late final LabViewModel model = LabViewModel(
    widget.repository,
    widget.clinicId,
    widget.patientId,
  );

  @override
  void initState() {
    super.initState();
    model.load();
  }

  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  Future<void> capture() async {
    final guardado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CaptureSheet(model: model),
    );
    if (guardado == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Toma guardada.')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Analíticas')),
    body: ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final ws = model.workspace;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            VetSectionHeader(
              large: true,
              title: widget.patientName,
              subtitle:
                  'Resultados y sus referencias. Cuando las fuentes no '
                  'coinciden se muestran las dos: la lectura es tuya.',
            ),
            if (model.busy) const LinearProgressIndicator(),
            if (model.error != null)
              VetNotice(
                text: model.error!,
                icon: Icons.error_outline,
                kind: VetBadgeKind.danger,
              ),
            if (ws != null && ws.canRecord) ...[
              VetActionButton(
                icon: Icons.add,
                label: 'Registrar una toma',
                onPressed: model.busy ? null : capture,
              ),
              const SizedBox(height: 12),
            ],
            if (ws != null && !ws.canRecord)
              const VetNotice(
                text:
                    'Tu cuenta puede consultar las analíticas pero no '
                    'registrarlas. Requiere habilitación profesional vigente '
                    'y el permiso de escritura de pacientes.',
                icon: Icons.lock_outline,
              ),
            if (ws != null && ws.panels.isEmpty && !model.busy)
              const VetNotice(
                text: 'Este paciente todavía no tiene analíticas registradas.',
                icon: Icons.inbox_outlined,
              ),
            for (final panel in ws?.panels ?? const <LabStoredPanel>[])
              _PanelCard(
                panel: panel,
                model: model,
                canRecord: ws?.canRecord ?? false,
              ),
          ],
        );
      },
    ),
  );
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({
    required this.panel,
    required this.model,
    required this.canRecord,
  });
  final LabStoredPanel panel;
  final LabViewModel model;
  final bool canRecord;

  String get _fecha {
    final d = panel.collectedAt;
    String dos(int v) => v.toString().padLeft(2, '0');
    return '${dos(d.day)}/${dos(d.month)}/${d.year} ${dos(d.hour)}:${dos(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: VetCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_fecha, style: textTheme.titleMedium),
            Text(
              panel.labName.isEmpty
                  ? panel.originLabel
                  : '${panel.originLabel} · ${panel.labName}',
              style: textTheme.bodySmall,
            ),
            if (panel.notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(panel.notes, style: textTheme.bodyMedium),
              ),
            const Divider(height: 20),
            for (final stored in panel.current)
              _ResultTile(
                view: model.view(panel, stored),
                model: canRecord ? model : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.view, this.model});
  final LabResultView view;

  /// Nulo cuando la cuenta no puede escribir: entonces no se ofrece corregir.
  final LabViewModel? model;

  /// 37.0 se lee peor que 37, y 4.50 peor que 4.5.
  static String cifra(double v) {
    final s = v.toStringAsFixed(3);
    return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
  }

  static String label(LabFlag f) => switch (f) {
    LabFlag.withinRange => 'Dentro',
    LabFlag.below => 'Bajo',
    LabFlag.above => 'Alto',
    LabFlag.noReference => 'Sin referencia',
    LabFlag.unitMismatch => 'Otra unidad',
  };

  static VetBadgeKind kind(LabFlag f) => switch (f) {
    LabFlag.withinRange => VetBadgeKind.success,
    LabFlag.below || LabFlag.above => VetBadgeKind.warning,
    _ => VetBadgeKind.unverified,
  };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final r = view.stored;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(r.analyteKey, style: textTheme.titleSmall),
              ),
              Text('${r.value} ${r.unit}', style: textTheme.titleMedium),
              if (model != null)
                IconButton(
                  icon: const Icon(Icons.edit_note, size: 20),
                  tooltip: 'Corregir este resultado',
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) =>
                        _CorrectionDialog(model: model!, result: r),
                  ),
                ),
            ],
          ),
          if (r.isCorrection && r.correctionReason != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Corregido: ${r.correctionReason}',
                style: textTheme.bodySmall,
              ),
            ),
          // Una linea por fuente. Ninguna se esconde ni se promedia.
          for (final lectura in view.readings)
            if (lectura.range != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '${cifra(lectura.range!.low)} – '
                        '${cifra(lectura.range!.high)} '
                        '${lectura.range!.unit} · ${lectura.range!.source}',
                        style: textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(width: 8),
                    VetStatusBadge(
                      label: label(lectura.flag),
                      kind: kind(lectura.flag),
                    ),
                  ],
                ),
              ),
          if (view.unjudged)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                view.readings.first.flag == LabFlag.unitMismatch
                    ? 'Hay referencias para este analito pero en otra unidad. '
                          'No se convierte ni se juzga.'
                    : 'Sin rango de referencia para esta especie. El valor se '
                          'guarda y se muestra, sin lectura.',
                style: textTheme.bodySmall,
              ),
            ),
          if (view.disputed)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: VetNotice(
                text:
                    'Las fuentes no coinciden en este valor. Ambas quedan a la '
                    'vista con su procedencia; la lectura es tuya.',
                icon: Icons.compare_arrows,
                kind: VetBadgeKind.warning,
              ),
            ),
        ],
      ),
    );
  }
}

/// Pide el valor nuevo y el motivo.
///
/// Es un widget con estado y no una funcion con controladores locales
/// porque los controladores tienen que vivir y morir con el dialogo. Al
/// cerrarlo, la ruta sigue animandose y vuelve a construir los campos: si
/// los controladores ya se liberaron, revienta con «A TextEditingController
/// was used after being disposed», y la excepcion se arrastra a lo que
/// venga despues.
class _CorrectionDialog extends StatefulWidget {
  const _CorrectionDialog({required this.model, required this.result});
  final LabViewModel model;
  final LabStoredResult result;

  @override
  State<_CorrectionDialog> createState() => _CorrectionDialogState();
}

class _CorrectionDialogState extends State<_CorrectionDialog> {
  late final valor = TextEditingController(text: widget.result.value);
  late final unidad = TextEditingController(text: widget.result.unit);
  final motivo = TextEditingController();
  String? error;

  @override
  void dispose() {
    valor.dispose();
    unidad.dispose();
    motivo.dispose();
    super.dispose();
  }

  Future<void> guardar() async {
    final fallo = await widget.model.correct(
      widget.result.id,
      value: valor.text,
      unit: unidad.text,
      reason: motivo.text,
    );
    if (!mounted) return;
    if (fallo != null) {
      setState(() => error = fallo);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Corregir ${widget.result.analyteKey}'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'El valor original no se borra: queda guardado y esta corrección '
          'apunta a él.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: valor,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Valor corregido'),
        ),
        TextField(
          controller: unidad,
          decoration: const InputDecoration(labelText: 'Unidad'),
        ),
        TextField(
          controller: motivo,
          decoration: const InputDecoration(
            labelText: 'Motivo de la corrección',
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: guardar,
        child: const Text('Guardar la corrección'),
      ),
    ],
  );
}

class _CaptureSheet extends StatefulWidget {
  const _CaptureSheet({required this.model});
  final LabViewModel model;

  @override
  State<_CaptureSheet> createState() => _CaptureSheetState();
}

class _CaptureSheetState extends State<_CaptureSheet> {
  final labName = TextEditingController();
  final notes = TextEditingController();
  final filas = <({
    TextEditingController analyte,
    TextEditingController value,
    TextEditingController unit,
    FocusNode focus,
  })>[];
  DateTime collectedAt = DateTime.now();
  String origin = 'laboratorio_externo';
  String? error;

  @override
  void initState() {
    super.initState();
    agregarFila();
  }

  void agregarFila() => setState(
    () => filas.add((
      analyte: TextEditingController(),
      value: TextEditingController(),
      unit: TextEditingController(),
      focus: FocusNode(),
    )),
  );

  @override
  void dispose() {
    labName.dispose();
    notes.dispose();
    for (final f in filas) {
      f.analyte.dispose();
      f.value.dispose();
      f.unit.dispose();
      f.focus.dispose();
    }
    super.dispose();
  }

  Future<void> elegirFecha() async {
    final hoy = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: collectedAt,
      firstDate: hoy.subtract(const Duration(days: 3650)),
      lastDate: hoy,
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(collectedAt),
    );
    if (!mounted) return;
    setState(
      () => collectedAt = DateTime(
        d.year,
        d.month,
        d.day,
        t?.hour ?? collectedAt.hour,
        t?.minute ?? collectedAt.minute,
      ),
    );
  }

  Future<void> guardar() async {
    final fallo = await widget.model.record(
      collectedAt: collectedAt,
      origin: origin,
      labName: labName.text,
      notes: notes.text,
      rows: [
        for (final f in filas)
          (analyte: f.analyte.text, value: f.value.text, unit: f.unit.text),
      ],
    );
    if (!mounted) return;
    if (fallo != null) {
      setState(() => error = fallo);
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    String dos(int v) => v.toString().padLeft(2, '0');
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            VetSectionHeader(
              title: 'Registrar una toma',
              subtitle:
                  'Captura los valores tal como vienen del reporte. Usa punto '
                  'decimal: la coma es separador de miles.'
                  '${widget.model.catalog.isEmpty ? '' : ' La biblioteca '
                      'conoce ${widget.model.catalog.length} analitos de esta '
                      'especie: escribe y elige uno para que la referencia '
                      'aparezca.'}',
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (valor, etiqueta) in const [
                  ('laboratorio_externo', 'Laboratorio externo'),
                  ('equipo_propio', 'Equipo propio'),
                ])
                  ChoiceChip(
                    label: Text(etiqueta),
                    selected: origin == valor,
                    onSelected: (_) => setState(() => origin = valor),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: elegirFecha,
              icon: const Icon(Icons.event),
              label: Text(
                'Toma: ${dos(collectedAt.day)}/${dos(collectedAt.month)}/'
                '${collectedAt.year} ${dos(collectedAt.hour)}:'
                '${dos(collectedAt.minute)}',
              ),
            ),
            if (origin == 'laboratorio_externo')
              TextField(
                controller: labName,
                decoration: const InputDecoration(
                  labelText: 'Laboratorio',
                  helperText: 'Opcional',
                ),
              ),
            const SizedBox(height: 8),
            for (final (i, f) in filas.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      // El nombre se puede teclear libre, pero si la
                      // biblioteca conoce la especie del paciente se
                      // ofrecen SUS nombres: son los que resuelven un
                      // rango. Al elegir uno se llena tambien la unidad en
                      // que la fuente publica el intervalo, que es la otra
                      // mitad de que la referencia aparezca.
                      child: RawAutocomplete<LabAnalyte>(
                        textEditingController: f.analyte,
                        focusNode: f.focus,
                        displayStringForOption: (o) => o.analyteKey,
                        optionsBuilder: (valor) {
                          final q = valor.text.trim().toLowerCase();
                          final todos = widget.model.catalog;
                          if (q.isEmpty) return todos.take(12);
                          return todos
                              .where(
                                (o) =>
                                    o.analyteKey.toLowerCase().contains(q),
                              )
                              .take(12);
                        },
                        onSelected: (o) => setState(() {
                          f.analyte.text = o.analyteKey;
                          f.unit.text = o.unit;
                        }),
                        fieldViewBuilder:
                            (context, controller, focus, onSubmit) =>
                                TextField(
                                  controller: controller,
                                  focusNode: focus,
                                  onSubmitted: (_) => onSubmit(),
                                  decoration: InputDecoration(
                                    labelText: 'Analito ${i + 1}',
                                  ),
                                ),
                        optionsViewBuilder: (context, onSelected, opciones) =>
                            Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 240,
                                    maxWidth: 360,
                                  ),
                                  child: ListView(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    children: [
                                      for (final o in opciones)
                                        ListTile(
                                          dense: true,
                                          title: Text(o.label),
                                          onTap: () => onSelected(o),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: f.value,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: 'Valor'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: f.unit,
                        decoration: const InputDecoration(labelText: 'Unidad'),
                      ),
                    ),
                  ],
                ),
              ),
            TextButton.icon(
              onPressed: agregarFila,
              icon: const Icon(Icons.add),
              label: const Text('Otro analito'),
            ),
            TextField(
              controller: notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notas'),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: VetNotice(
                  text: error!,
                  icon: Icons.error_outline,
                  kind: VetBadgeKind.danger,
                ),
              ),
            const SizedBox(height: 12),
            VetActionButton(
              icon: Icons.save_outlined,
              label: 'Guardar la toma',
              loading: widget.model.busy,
              onPressed: widget.model.busy ? null : guardar,
            ),
          ],
        ),
      ),
    );
  }
}

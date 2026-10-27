import '../../../core/widgets/calculator_surface.dart';
import 'dart:convert';
import '../../patients/domain/recorded_weight.dart';
import 'package:file_picker/file_picker.dart';
import '../data/personal_dose_repository.dart';
import 'personal_dose_screen.dart';
import 'package:flutter/material.dart';
import '../data/catalog_repository.dart';
import '../domain/catalog.dart';
import 'dose_view_model.dart';
import 'commercial_package_dose_screen.dart';

class DoseScreen extends StatefulWidget {
  const DoseScreen({
    super.key,
    this.repository,
    this.personalRepository,
    this.clinicId,
    this.userId,
    this.admin = false,
    this.offline = false,
    this.recordedWeight,
    this.validateRecordedWeight,
    this.initialDrug,
    this.onChoosePatient,
    this.onReviewPatientInstructions,
  });
  final CatalogRepository? repository;
  final PersonalDoseRepository? personalRepository;
  final String? clinicId, userId;
  final bool admin, offline;
  final RecordedPatientWeight? recordedWeight;
  final Future<bool> Function(RecordedPatientWeight)? validateRecordedWeight;
  final DrugDose? initialDrug;
  final Future<void> Function()? onChoosePatient;
  final Future<void> Function(String patientId)? onReviewPatientInstructions;
  @override
  State<DoseScreen> createState() => _DoseScreenState();
}

class _DoseScreenState extends State<DoseScreen> {
  late final DoseViewModel model;
  final weight = TextEditingController(),
      step = TextEditingController(),
      breed = TextEditingController(),
      conditions = TextEditingController();
  bool checkingWeight = false, weightApplied = false;
  String? weightError;

  String get weightContext {
    final w = widget.recordedWeight!;
    return '${w.patientName} · Paciente ${w.patientId}\nPeso medido: ${w.kg} kg · ${w.observedAt.toLocal()}\nMidió: ${w.performedBy}\nRegistró: ${w.recordedBy} · ${w.recordedAt.toLocal()}\nCaso: ${w.caseId} · Medición: ${w.id}';
  }

  /// Revalidates the saved measurement, returning true when none is attached.
  ///
  /// Missing or failed validation, a changed measurement, or offline mode clears
  /// the applied weight and calculation. Validator errors become false.
  Future<bool> checkWeight() async {
    final source = widget.recordedWeight;
    if (source == null) return true;
    if (checkingWeight) return false;
    setState(() {
      checkingWeight = true;
      weightError = null;
    });
    var valid = false;
    try {
      valid = await widget.validateRecordedWeight?.call(source) ?? false;
      valid =
          valid &&
          widget.recordedWeight?.sameMeasurement(source) == true &&
          !widget.offline;
    } catch (_) {
      valid = false;
    }
    if (!mounted) return false;
    setState(() {
      checkingWeight = false;
      if (!valid) {
        weightApplied = false;
        weight.clear();
        model.invalidate();
        weightError =
            'La medición ya no se pudo comprobar. Revisa acceso, estancia y correcciones antes de continuar.';
      }
    });
    return valid;
  }

  /// Applies the revalidated saved kilograms and invalidates any prior result.
  Future<void> applyWeight() async {
    if (!await checkWeight() || !mounted) return;
    setState(() {
      model.invalidate();
      weight.text = widget.recordedWeight!.kg;
      weightApplied = true;
    });
  }

  /// Calculates from current inputs after any saved weight is explicitly applied.
  ///
  /// Rechecks that measurement and abandons calculation if inputs or catalog
  /// selections change while validation is pending.
  Future<void> calculate() async {
    if (checkingWeight) return;
    // Snapshot every input before the asynchronous permission/source check.
    final inputs = [
      weight.text,
      model.drug?.prescribedDose?.display() ?? '',
      step.text,
      breed.text,
      conditions.text,
    ];
    final selectedDrug = model.drug, selectedPresentation = model.presentation;
    model.invalidate();
    if (widget.recordedWeight != null) {
      if (!weightApplied) {
        setState(
          () => weightError =
              'Revisa y confirma el peso registrado antes de calcular.',
        );
        return;
      }
      if (!await checkWeight() || !mounted) return;
      final current = [
        weight.text,
        model.drug?.prescribedDose?.display() ?? '',
        step.text,
        breed.text,
        conditions.text,
      ];
      if (!identical(selectedDrug, model.drug) ||
          !identical(selectedPresentation, model.presentation) ||
          List.generate(
            inputs.length,
            (i) => inputs[i] == current[i],
          ).contains(false)) {
        return;
      }
    }
    model.calculate(inputs[0], inputs[1], inputs[2], inputs[3], inputs[4]);
  }

  String query = '';
  String? species;
  List<DrugDose> personal = [];
  Future<void> refreshPersonal() async {
    if (widget.personalRepository == null ||
        widget.clinicId == null ||
        widget.offline) {
      return;
    }
    try {
      final rows = await widget.personalRepository!.list(widget.clinicId!);
      if (mounted) {
        setState(
          () => personal = rows
              .where((e) => e.state == 'approved' || e.userId == widget.userId)
              .map((e) => e.drug)
              .toList(),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => model.error =
              'Las dosis personales aún no están disponibles. Revisa la conexión y su configuración.',
        );
      }
    }
  }

  Future<void> importCatalog() async {
    try {
      final selection = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (!mounted || selection.isEmpty) return;
      final length = await selection.single.xFile.length();
      if (length > 2 * 1024 * 1024) {
        throw const FormatException('Selecciona un catálogo de hasta 2 MB.');
      }
      final bytes = await selection.single.xFile.readAsBytes();
      if (bytes.length > 2 * 1024 * 1024) {
        throw const FormatException('Selecciona un catálogo de hasta 2 MB.');
      }
      if (!mounted) return;
      final text = utf8.decode(bytes);
      final incoming = DoseCatalog.parse(text);
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Importar catálogo'),
          content: Text(
            'Versión ${incoming.version} · ${incoming.drugs.length} entradas. Reemplazará el catálogo general guardado en este dispositivo. Las fuentes y estados provienen del archivo; la app no los verifica automáticamente.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Importar'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
      final repository = model.repository;
      if (repository is! AssetCatalogRepository) {
        throw const FormatException('Importación no disponible.');
      }
      await repository.import(text);
      if (!mounted) return;
      model.drug = null;
      model.presentation = null;
      model.invalidate();
      setState(() {
        species = null;
        query = '';
      });
      await model.load();
      refreshPersonal();
    } on FormatException catch (e) {
      if (mounted) setState(() => model.error = e.message.toString());
    } catch (_) {
      if (mounted) {
        setState(() => model.error = 'No se pudo importar el catálogo.');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    model = DoseViewModel(widget.repository ?? AssetCatalogRepository());
    model.load().then((_) {
      if (mounted && widget.initialDrug != null) {
        model.select(widget.initialDrug!);
      }
    });
    refreshPersonal();
  }

  @override
  void didUpdateWidget(covariant DoseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recordedWeight != widget.recordedWeight ||
        oldWidget.clinicId != widget.clinicId ||
        oldWidget.userId != widget.userId ||
        oldWidget.offline != widget.offline) {
      weightApplied = false;
      weight.clear();
      model.invalidate();
    }
  }

  @override
  void dispose() {
    for (final c in [weight, step, breed, conditions]) {
      c.dispose();
    }
    model.dispose();
    super.dispose();
  }

  Widget field(
    String label,
    TextEditingController controller, {
    bool numeric = false,
    bool readOnly = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      controller: controller,
      readOnly: readOnly,
      enabled: !checkingWeight,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => model.invalidate(),
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      if (model.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      final general = model.catalog;
      final catalog = general == null
          ? null
          : DoseCatalog(general.version, [...general.drugs, ...personal]);
      final selected = model.drug;
      final content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CalculatorHeading(
            id: 'dose',
            title: 'Calcular dosis de un producto',
          ),
          const SizedBox(height: 16),
          if (widget.recordedWeight == null && widget.onChoosePatient != null)
            CalculatorSelectorCard(
              id: 'dose',
              title: 'Paciente y dosis indicada',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Usa un peso registrado y después elige el principio activo, nombre comercial o dosis personal.',
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: widget.offline ? null : widget.onChoosePatient,
                    icon: const Icon(Icons.person_search_outlined),
                    label: const Text('Elegir paciente y peso registrado'),
                  ),
                ],
              ),
            ),
          if (widget.recordedWeight != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      weightContext,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Text(
                      'Comprueba que esta medición corresponde al paciente y es adecuada para este cálculo. No actualiza tratamientos vigentes.',
                    ),
                    OutlinedButton(
                      onPressed: checkingWeight ? null : applyWeight,
                      child: const Text('Usar peso registrado'),
                    ),
                    if (weightApplied)
                      const Text('Peso registrado seleccionado.'),
                    if (checkingWeight) const LinearProgressIndicator(),
                    if (weightError != null) Text(weightError!),
                  ],
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CommercialPackageDoseScreen(
                  recordedWeight: widget.recordedWeight,
                  validateRecordedWeight: widget.validateRecordedWeight,
                ),
              ),
            ),
            icon: const Icon(Icons.medication_liquid_outlined),
            label: const Text('Vademécum comercial · dosis del empaque'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Vademécum farmacológico: dosis por principio activo, '
            'presentación y validación clínica independiente.',
          ),
          const SizedBox(height: 8),
          const Text(
            'Selecciona un fármaco con dosis documentada, elige su presentación e ingresa el peso. La app no propone dosis faltantes ni interpreta rangos.',
          ),
          const SizedBox(height: 12),
          if (widget.admin)
            OutlinedButton.icon(
              onPressed: importCatalog,
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('Importar catálogo'),
            ),
          if (widget.personalRepository != null &&
              widget.clinicId != null &&
              !widget.offline)
            OutlinedButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => PersonalDoseScreen(
                      repository: widget.personalRepository!,
                      clinicId: widget.clinicId!,
                      admin: widget.admin,
                      general: general?.drugs ?? [],
                    ),
                  ),
                );
                if (mounted) {
                  model.drug = null;
                  model.presentation = null;
                  model.invalidate();
                  await refreshPersonal();
                }
              },
              child: const Text('Mis dosis personales y solicitudes'),
            ),
          if (catalog == null)
            Text(model.error ?? 'Catálogo no disponible.')
          else if (catalog.drugs.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'El Vademécum no tiene fármacos disponibles para calcular. Importa un catálogo con fuente, dosis por peso y concentración por presentación. No se calculará una dosis ingresada libremente en este modo.',
                ),
              ),
            )
          else ...[
            DropdownButtonFormField<String>(
              initialValue: species,
              decoration: const InputDecoration(labelText: 'Especie'),
              items:
                  (catalog.drugs.map((d) => d.species).toSet().toList()..sort())
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
              onChanged: (s) {
                setState(() {
                  species = s;
                  model.drug = null;
                  model.presentation = null;
                });
                model.invalidate();
              },
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar principio activo o nombre comercial',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (s) => setState(() => query = s),
            ),
            for (final item in catalog.search(query, species: species))
              ListTile(
                title: Text(item.name),
                subtitle: Text(
                  '${item.species} · ${item.personal ? 'Dosis personal' : 'Base general'} · ${item.evidence.verified ? 'Verificada' : 'Sin verificar'}\nPresentaciones: ${item.presentations.map((p) => p.brand).join(', ')}',
                ),
                selected: selected == item,
                onTap: () => model.select(item),
              ),
            if (selected != null) ...[
              const Divider(),
              Text(
                '${selected.name} · ${selected.species}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text('Fuente: ${selected.evidence.source ?? 'Pendiente'}'),
              Text(
                'Vía: ${selected.route ?? 'Pendiente'} · Intervalo: ${selected.interval ?? 'Pendiente'}',
              ),
              Text(
                selected.prescribedDose == null
                    ? 'Dosis: sin valor único; este modo no calcula rangos automáticamente.'
                    : 'Dosis registrada: ${selected.prescribedDose!.display()} mg/kg',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<Presentation>(
                key: ObjectKey(selected),
                initialValue: model.presentation,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Presentación comercial',
                  border: OutlineInputBorder(),
                ),
                items: selected.presentations
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text(
                          '${p.brand} · ${p.concentration?.display() ?? 'Pendiente'} mg/ml',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (p) {
                  if (p != null) model.selectPresentation(p);
                },
              ),
              if (model.presentation != null)
                Text(
                  'Fuente de presentación: ${model.presentation!.evidence.source ?? 'Pendiente'}',
                ),
              const SizedBox(height: 16),
              field(
                'Peso (kg)',
                weight,
                numeric: true,
                readOnly: widget.recordedWeight != null,
              ),
              if (selected.prescribedDose != null)
                _bookletDoseValue(selected.prescribedDose!.display()),
              field(
                'Graduación de jeringa (mL, opcional)',
                step,
                numeric: true,
              ),
              field('Raza', breed),
              field(
                'Condiciones del paciente (separadas por coma)',
                conditions,
              ),
              if (selected.contraindications.isNotEmpty) ...[
                const Text('Revisa las contraindicaciones publicadas:'),
                for (final c in selected.contraindications)
                  Text(
                    '${c.kind}: ${c.value} · ${c.note} · Fuente: ${c.evidence.source ?? 'Pendiente'}',
                  ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: checkingWeight ? null : calculate,
                child: const Text('Calcular'),
              ),
            ],
          ],
          if (model.error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                model.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (model.result case final r?) ...[
            const SizedBox(height: 20),
            Text(
              step.text.trim().isEmpty
                  ? 'Masa calculada: ${r.mass.display()} mg\nVolumen calculado: ${r.volume.display()} mL'
                  : 'Masa calculada: ${r.mass.display()} mg\nVolumen teórico: ${r.volume.display()} mL\nVolumen redondeado a la graduación: ${r.roundedVolume.display(places: 9)} mL',
            ),
            const Text(
              'La visualización se aproxima; los límites se evalúan con valores exactos.',
            ),
            for (final alert in r.alerts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  alert,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            CheckboxListTile(
              title: const Text(
                'Revisé paciente, peso, dosis, presentación, vía y contraindicaciones.',
              ),
              value: model.stage != ConfirmationStage.none,
              onChanged: r.canConfirm && model.stage == ConfirmationStage.none
                  ? (_) => model.review()
                  : null,
            ),
            FilledButton(
              onPressed:
                  model.stage == ConfirmationStage.reviewed &&
                      r.canConfirm &&
                      !checkingWeight
                  ? () async {
                      if (!await checkWeight() ||
                          !context.mounted ||
                          !identical(model.result, r)) {
                        return;
                      }
                      final accepted = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Segunda confirmación'),
                          content: Text(
                            '${widget.recordedWeight == null ? '' : '$weightContext\n'}${selected!.name} · ${selected.species}\n${model.presentation!.brand}\nPeso: ${weight.text} kg · Dosis: ${selected.prescribedDose?.display() ?? 'no disponible'} mg/kg\nVolumen: ≈ ${r.roundedVolume.display(places: 9)} ml\nVía: ${selected.route} · Intervalo: ${selected.interval}',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Volver a revisar'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Confirmar cálculo'),
                            ),
                          ],
                        ),
                      );
                      if (accepted == true &&
                          mounted &&
                          identical(model.result, r)) {
                        if (await checkWeight() &&
                            mounted &&
                            identical(model.result, r)) {
                          model.confirm();
                        }
                      }
                    }
                  : null,
              child: const Text('Confirmar por segunda vez'),
            ),
            if (model.stage == ConfirmationStage.confirmed)
              const Text(
                'Cálculo confirmado. No registra una administración ni genera una receta.',
              ),
            if (model.stage == ConfirmationStage.confirmed &&
                widget.recordedWeight != null &&
                widget.onReviewPatientInstructions != null)
              OutlinedButton.icon(
                onPressed: checkingWeight
                    ? null
                    : () async {
                        if (!await checkWeight() ||
                            !mounted ||
                            !identical(model.result, r) ||
                            model.stage != ConfirmationStage.confirmed) {
                          return;
                        }
                        await widget.onReviewPatientInstructions!(
                          widget.recordedWeight!.patientId,
                        );
                      },
                icon: const Icon(Icons.assignment_outlined),
                label: const Text('Revisar indicaciones del paciente'),
              ),
          ],
        ],
      );
      return CalculatorSurface(id: 'dose', child: content);
    },
  );
}

Widget _bookletDoseValue(String dose) => Padding(
  padding: const EdgeInsets.only(bottom: 16),
  child: InputDecorator(
    decoration: const InputDecoration(
      labelText: 'Dosis del Vademécum',
      border: OutlineInputBorder(),
    ),
    child: Text('$dose mg/kg · no editable'),
  ),
);

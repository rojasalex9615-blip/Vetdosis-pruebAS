import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/presentation/unsaved_form_scope.dart';
import '../../patients/presentation/patient_view_model.dart';
import '../domain/hospital_care.dart';
import '../domain/hospital_models.dart';
import '../../../vet_ui/vet_icons.dart';

class HospitalCareForm extends StatefulWidget {
  const HospitalCareForm({
    super.key,
    required this.stay,
    required this.kind,
    required this.reviewTypes,
    required this.save,
    this.now,
  });

  final HospitalStay stay;
  final HospitalCareKind kind;
  final List<HospitalReviewType> reviewTypes;
  final DateTime Function()? now;
  final Future<bool> Function(
    String procedure,
    HospitalCareDraft draft,
    List<DateTime> times,
    int delay,
    String operation,
  )
  save;

  @override
  State<HospitalCareForm> createState() => _HospitalCareFormState();
}

class _HospitalCareFormState extends State<HospitalCareForm> {
  final exit = FormExitController();
  final food = TextEditingController();
  final portion = TextEditingController();
  final device = TextEditingController();
  final instructions = TextEditingController();
  final delay = TextEditingController();
  final minutes = <int>[];
  DateTimeRange? dates;
  String? procedure, unit, error, attempted;
  String operation = newOperationId();
  bool busy = false, reviewed = false;
  DateTime get now => widget.now?.call() ?? DateTime.now();
  bool get feeding => widget.kind == HospitalCareKind.feeding;
  bool get dirty =>
      dates != null ||
      minutes.isNotEmpty ||
      procedure != null ||
      unit != null ||
      reviewed ||
      [
        food,
        portion,
        device,
        instructions,
        delay,
      ].any((c) => c.text.isNotEmpty);

  @override
  void dispose() {
    exit.dispose();
    for (final c in [food, portion, device, instructions, delay]) {
      c.dispose();
    }
    super.dispose();
  }

  void changed() => setState(() {
    reviewed = false;
    error = null;
  });

  List<DateTime> schedule() {
    if (dates == null) {
      throw const FormatException('Selecciona la primera y última fecha.');
    }
    return dailyCareSchedule(
      firstDay: dates!.start,
      lastDay: dates!.end,
      minutesOfDay: minutes,
      now: now,
    );
  }

  Future<void> chooseDates() async {
    final today = DateTime(now.year, now.month, now.day);
    final selected = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: DateTime(today.year + 1, today.month, today.day),
      initialDateRange: dates,
      helpText: 'Fechas de la orden (máximo 31 días)',
    );
    if (!mounted || selected == null) return;
    setState(() => dates = selected);
    changed();
  }

  Future<void> addTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (!mounted || selected == null) return;
    final minute = selected.hour * 60 + selected.minute;
    if (minutes.contains(minute)) {
      setState(() => error = 'Ese horario ya está en la orden.');
      return;
    }
    setState(() {
      minutes.add(minute);
      minutes.sort();
    });
    changed();
  }

  /// Saves reviewed care, retaining the operation ID for identical retries.
  ///
  /// Changed payloads get a new operation ID. Closes on success; validation,
  /// callback errors, and a false result are shown in the form.
  Future<void> save() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (!reviewed) {
        throw const FormatException(
          'Revisa paciente, indicaciones y horarios antes de guardar.',
        );
      }
      if (!widget.reviewTypes.any((t) => t.id == procedure)) {
        throw const FormatException(
          'Selecciona el tipo de procedimiento configurado por la clínica.',
        );
      }
      final draft = HospitalCareDraft(
        kind: widget.kind,
        food: food.text,
        portion: portion.text,
        unit: unit ?? '',
        device: device.text,
        instructions: instructions.text,
      );
      final times = schedule();
      final escalation = int.tryParse(delay.text.trim());
      if (escalation == null || escalation < 1 || escalation > 120) {
        throw const FormatException(
          'Indica entre 1 y 120 minutos para el aviso de retraso.',
        );
      }
      final fingerprint = jsonEncode([
        procedure,
        draft.label,
        draft.details,
        times.map((t) => t.toIso8601String()).toList(),
        escalation,
      ]);
      if (attempted != null && attempted != fingerprint) {
        operation = newOperationId();
      }
      attempted = fingerprint;
      final ok = await widget.save(
        procedure!,
        draft,
        times,
        escalation,
        operation,
      );
      if (!mounted) return;
      if (ok) {
        exit.close(context);
      } else {
        setState(
          () => error =
              'No se pudo guardar. Actualiza la hoja y revisa si la orden ya aparece antes de repetirla.',
        );
      }
    } on FormatException catch (e) {
      if (mounted) setState(() => error = e.message.toString());
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'No se pudo confirmar el guardado. Actualiza la hoja antes de repetirlo.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String dateLabel(DateTime d) => d.toIso8601String().substring(0, 10);
  String timeLabel(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

  Widget field(
    TextEditingController controller,
    String label, {
    int lines = 1,
    int? maxLength,
    bool number = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: TextField(
      controller: controller,
      enabled: !busy,
      maxLines: lines,
      maxLength: maxLength,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => changed(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    List<DateTime> times = [];
    String? scheduleNotice;
    if (dates != null && minutes.isNotEmpty) {
      try {
        times = schedule();
      } on FormatException catch (e) {
        scheduleNotice = e.message.toString();
      }
    }
    return UnsavedFormScope(
      controller: exit,
      dirty: dirty,
      busy: busy,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.kind.title)),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('${widget.stay.patientName} · Jaula ${widget.stay.cageLabel}'),
            const SizedBox(height: 12),
            const Text(
              'Captura la indicación del profesional. Todos los días elegidos tendrán los mismos horarios; revisa la zona horaria del dispositivo.',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: procedure,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Tipo de procedimiento',
              ),
              items: [
                for (final type in widget.reviewTypes)
                  DropdownMenuItem(value: type.id, child: Text(type.name)),
              ],
              onChanged: busy
                  ? null
                  : (value) {
                      procedure = value;
                      changed();
                    },
            ),
            if (widget.reviewTypes.isEmpty)
              const Text(
                'No hay tipos activos. Solicita su configuración antes de programar cuidados.',
              ),
            if (feeding) ...[
              field(food, 'Alimento indicado', maxLength: 200),
              field(portion, 'Porción por horario', number: true),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: unit,
                decoration: const InputDecoration(
                  labelText: 'Unidad de la porción',
                ),
                items: [
                  for (final value in ['g', 'ml', 'porción'])
                    DropdownMenuItem(value: value, child: Text(value)),
                ],
                onChanged: busy
                    ? null
                    : (value) {
                        unit = value;
                        changed();
                      },
              ),
            ] else
              field(
                device,
                'Dispositivo / sitio a revisar o cambiar',
                maxLength: 200,
              ),
            field(
              instructions,
              feeding
                  ? 'Indicaciones de alimentación'
                  : 'Indicaciones del cuidado',
              lines: 4,
              maxLength: 3000,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: busy ? null : chooseDates,
              icon: const Icon(VetIcons.calendar),
              label: Text(
                dates == null
                    ? 'Elegir fechas'
                    : '${dateLabel(dates!.start)} a ${dateLabel(dates!.end)}',
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final minute in minutes)
                  InputChip(
                    label: Text(timeLabel(minute)),
                    onDeleted: busy
                        ? null
                        : () {
                            minutes.remove(minute);
                            changed();
                          },
                  ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : addTime,
              icon: const Icon(VetIcons.clock),
              label: const Text('Añadir horario diario'),
            ),
            if (scheduleNotice != null)
              Text(
                scheduleNotice,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (times.isNotEmpty) ...[
              Text(
                '${times.length} cuidados programados. La orden termina el ${dateLabel(dates!.end)}; no se renueva automáticamente.',
              ),
              ExpansionTile(
                title: const Text('Revisar todos los horarios'),
                children: [
                  for (final time in times)
                    ListTile(
                      title: Text(
                        '${dateLabel(time.toLocal())} · ${timeLabel(time.toLocal().hour * 60 + time.toLocal().minute)}',
                      ),
                    ),
                ],
              ),
            ],
            field(delay, 'Aviso de retraso tras (minutos)', number: true),
            const Text(
              'El aviso no cambia la indicación ni avisa por sí solo a otro integrante del equipo.',
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Revisé paciente, indicaciones y todos los horarios.',
              ),
              value: reviewed,
              onChanged: busy
                  ? null
                  : (value) => setState(() => reviewed = value ?? false),
            ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (busy) const LinearProgressIndicator(),
            FilledButton(
              onPressed: busy || widget.reviewTypes.isEmpty ? null : save,
              child: const Text('Guardar orden de cuidados'),
            ),
          ],
        ),
      ),
    );
  }
}

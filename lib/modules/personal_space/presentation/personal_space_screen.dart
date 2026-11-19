import 'package:flutter/material.dart';

import '../../../vet_ui/vet_icons.dart';
import '../../auth/domain/clinic_membership.dart';
import '../../operations/domain/operations_repository.dart';
import '../../operations/presentation/staff_medical_screen.dart';
import '../domain/personal_space.dart';

/// Mi espacio personal: lo que es de la persona y no de una clinica.
///
/// No cambia la clinica activa ni el area de trabajo: antes el boton
/// «Abrir mi espacio personal» cambiaba de area de trabajo y dejaba a la
/// persona en Inicio o Produccion, sin notas ni ficha.
class PersonalSpaceScreen extends StatefulWidget {
  const PersonalSpaceScreen({
    super.key,
    required this.memberships,
    this.repository,
    this.medical,
    this.now,
  });
  final List<ClinicMembership> memberships;
  final PersonalSpaceRepository? repository;
  final StaffMedicalRepository? medical;
  final DateTime Function()? now;
  @override
  State<PersonalSpaceScreen> createState() => _PersonalSpaceScreenState();
}

class _PersonalSpaceScreenState extends State<PersonalSpaceScreen> {
  List<PersonalNote> notes = [];
  List<WorkSchedule> schedules = [];
  bool busy = false;
  String? error;

  List<ClinicMembership> get clinics =>
      widget.memberships.where((m) => !m.isPersonal).toList();

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final repository = widget.repository;
    if (repository == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final n = await repository.notes();
      final s = await repository.schedules();
      if (!mounted) return;
      setState(() {
        notes = n;
        schedules = s;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => error =
              e.toString().contains('PGRST205') ||
                  e.toString().contains('personal_notes')
              ? 'Tus notas y horarios requieren la actualización del servidor.'
              : 'No se pudieron cargar tus notas y horarios. Revisa tu conexión.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      if (!mounted) return;
      busy = false;
      await load();
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error =
              'No se guardó el cambio. Revisa tu conexión e inténtalo de nuevo.';
        });
      }
    }
  }

  Future<void> editNote({PersonalNote? note, required bool reminder}) async {
    final result = await showDialog<PersonalNote>(
      context: context,
      builder: (_) => _NoteDialog(
        note: note,
        reminder: reminder,
        now: widget.now ?? DateTime.now,
      ),
    );
    if (result == null || widget.repository == null) return;
    await run(() => widget.repository!.saveNote(result));
  }

  Future<void> editSchedule([WorkSchedule? schedule]) async {
    final result = await showDialog<WorkSchedule>(
      context: context,
      builder: (_) => _ScheduleDialog(schedule: schedule, clinics: clinics),
    );
    if (result == null || widget.repository == null) return;
    await run(() => widget.repository!.saveSchedule(result));
  }

  Future<bool> confirmDelete(String what) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Eliminar $what'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      ) ==
      true;

  Widget status() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (busy) const LinearProgressIndicator(),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
    ],
  );

  Widget unavailable() => const Padding(
    padding: EdgeInsets.all(16),
    child: Text(
      'Las notas, recordatorios y horarios se guardan en tu cuenta y requieren conexión al servidor.',
    ),
  );

  Widget notesTab() {
    final items = notes.where((n) => !n.reminder).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        status(),
        const Text('Solo tú ves tus notas.'),
        const SizedBox(height: 8),
        if (widget.repository == null) unavailable(),
        if (widget.repository != null && items.isEmpty && !busy)
          const Text('Aún no tienes notas.'),
        for (final note in items)
          Card(
            child: ListTile(
              title: Text(note.title),
              subtitle: note.body.isEmpty ? null : Text(note.body),
              onTap: busy ? null : () => editNote(note: note, reminder: false),
              trailing: IconButton(
                tooltip: 'Eliminar nota',
                icon: const Icon(VetIcons.trash),
                onPressed: busy
                    ? null
                    : () async {
                        if (await confirmDelete('nota')) {
                          await run(
                            () => widget.repository!.deleteNote(note.id!),
                          );
                        }
                      },
              ),
            ),
          ),
        if (widget.repository != null)
          FilledButton.icon(
            onPressed: busy ? null : () => editNote(reminder: false),
            icon: const Icon(VetIcons.noteEdit),
            label: const Text('Nueva nota'),
          ),
      ],
    );
  }

  Widget remindersTab() {
    final items = sortedReminders(notes);
    final now = (widget.now ?? DateTime.now)();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        status(),
        const Text('Recordatorios personales. Solo tú los ves.'),
        const SizedBox(height: 8),
        if (widget.repository == null) unavailable(),
        if (widget.repository != null && items.isEmpty && !busy)
          const Text('Sin recordatorios.'),
        for (final note in items)
          Card(
            child: CheckboxListTile(
              value: note.done,
              onChanged: busy
                  ? null
                  : (v) => run(
                      () => widget.repository!.saveNote(
                        note.copyWith(done: v ?? false),
                      ),
                    ),
              title: Text(
                note.title,
                style: note.done
                    ? const TextStyle(decoration: TextDecoration.lineThrough)
                    : null,
              ),
              subtitle: Text(
                [
                  if (note.remindAt != null)
                    '${formatDateTime(note.remindAt!)}'
                        '${!note.done && note.remindAt!.isBefore(now) ? ' · vencido' : ''}',
                  if (note.body.isNotEmpty) note.body,
                ].join('\n'),
              ),
              secondary: IconButton(
                tooltip: 'Editar recordatorio',
                icon: const Icon(VetIcons.pencil),
                onPressed: busy
                    ? null
                    : () => editNote(note: note, reminder: true),
              ),
            ),
          ),
        if (widget.repository != null)
          FilledButton.icon(
            onPressed: busy ? null : () => editNote(reminder: true),
            icon: const Icon(VetIcons.bell),
            label: const Text('Nuevo recordatorio'),
          ),
      ],
    );
  }

  Widget schedulesTab() {
    final week = sortedWeek(schedules);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        status(),
        const Text(
          'Tu horario en una o más clínicas. Solo tú lo ves; no cambia el control de asistencia ni los turnos de la clínica.',
        ),
        const SizedBox(height: 8),
        if (widget.repository == null) unavailable(),
        if (widget.repository != null && week.isEmpty && !busy)
          const Text('Aún no registras horarios.'),
        for (final day in weekdayLabels.entries)
          if (week.any((s) => s.weekday == day.key)) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                day.value,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            for (final s in week.where((s) => s.weekday == day.key))
              Card(
                child: ListTile(
                  title: Text('${s.range} · ${s.place}'),
                  subtitle: s.note.isEmpty ? null : Text(s.note),
                  onTap: busy ? null : () => editSchedule(s),
                  trailing: IconButton(
                    tooltip: 'Eliminar horario',
                    icon: const Icon(VetIcons.trash),
                    onPressed: busy
                        ? null
                        : () async {
                            if (await confirmDelete('horario')) {
                              await run(
                                () => widget.repository!.deleteSchedule(s.id!),
                              );
                            }
                          },
                  ),
                ),
              ),
          ],
        if (widget.repository != null)
          FilledButton.icon(
            onPressed: busy ? null : () => editSchedule(),
            icon: const Icon(VetIcons.calendarPlus),
            label: const Text('Agregar horario'),
          ),
      ],
    );
  }

  Widget emergencyTab() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text(
        'Tu ficha de emergencia: contacto, tipo de sangre, alergias, fármacos a los que eres alérgico/a y, si quieres, enfermedades o padecimientos.',
      ),
      const SizedBox(height: 8),
      const Text(
        'Se guarda por clínica y solo con tu consentimiento. La consultan la administración de la clínica con permiso y los compañeros que tú elijas; cada consulta queda registrada y la ves tú y la administración.',
      ),
      const SizedBox(height: 16),
      if (widget.medical == null)
        const Text('La ficha de emergencia requiere conexión al servidor.')
      else if (clinics.isEmpty)
        const Text(
          'Únete a una clínica para tener ficha de emergencia: se comparte con su equipo, no existe en el área de trabajo personal.',
        )
      else
        for (final clinic in clinics)
          Card(
            child: ListTile(
              leading: const Icon(VetIcons.firstAidKit),
              title: Text(clinic.clinicName),
              subtitle: const Text(
                'Mi ficha, compañeros con acceso y registro',
              ),
              trailing: const Icon(VetIcons.chevronRight),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => StaffMedicalScreen(
                    repository: widget.medical!,
                    member: clinic,
                  ),
                ),
              ),
            ),
          ),
    ],
  );

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Mi espacio personal'),
        bottom: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'Notas'),
            Tab(text: 'Recordatorios'),
            Tab(text: 'Horarios'),
            Tab(text: 'Emergencia'),
          ],
        ),
      ),
      body: TabBarView(
        children: [notesTab(), remindersTab(), schedulesTab(), emergencyTab()],
      ),
    ),
  );
}

String formatDateTime(DateTime at) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(at.day)}/${two(at.month)}/${at.year} ${two(at.hour)}:${two(at.minute)}';
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({this.note, required this.reminder, required this.now});
  final PersonalNote? note;
  final bool reminder;
  final DateTime Function() now;
  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final title = TextEditingController(text: widget.note?.title ?? '');
  late final body = TextEditingController(text: widget.note?.body ?? '');
  late DateTime? at = widget.note?.remindAt;
  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> pick() async {
    final base = at ?? widget.now().add(const Duration(hours: 1));
    final day = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null || !mounted) return;
    setState(
      () => at = DateTime(day.year, day.month, day.day, time.hour, time.minute),
    );
  }

  bool get valid =>
      title.text.trim().isNotEmpty && (!widget.reminder || at != null);

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.note == null
          ? (widget.reminder ? 'Nuevo recordatorio' : 'Nueva nota')
          : (widget.reminder ? 'Editar recordatorio' : 'Editar nota'),
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: title,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'Título'),
            onChanged: (_) => setState(() {}),
          ),
          TextField(
            controller: body,
            maxLength: 4000,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'Detalle'),
          ),
          if (widget.reminder)
            OutlinedButton.icon(
              onPressed: pick,
              icon: const Icon(VetIcons.calendar),
              label: Text(
                at == null ? 'Elegir fecha y hora' : formatDateTime(at!),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: valid
            ? () => Navigator.pop(
                context,
                PersonalNote(
                  id: widget.note?.id,
                  title: title.text.trim(),
                  body: body.text.trim(),
                  reminder: widget.reminder,
                  remindAt: widget.reminder ? at : null,
                  done: widget.note?.done ?? false,
                ),
              )
            : null,
        child: const Text('Guardar'),
      ),
    ],
  );
}

class _ScheduleDialog extends StatefulWidget {
  const _ScheduleDialog({this.schedule, required this.clinics});
  final WorkSchedule? schedule;
  final List<ClinicMembership> clinics;
  @override
  State<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<_ScheduleDialog> {
  late final place = TextEditingController(text: widget.schedule?.place ?? '');
  late final note = TextEditingController(text: widget.schedule?.note ?? '');
  late String? clinicId =
      widget.clinics.any((c) => c.clinicId == widget.schedule?.clinicId)
      ? widget.schedule?.clinicId
      : null;
  late int weekday = widget.schedule?.weekday ?? 1;
  late int start = widget.schedule?.startMinutes ?? 9 * 60;
  late int end = widget.schedule?.endMinutes ?? 17 * 60;
  @override
  void dispose() {
    place.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> pick(bool isStart) async {
    final value = isStart ? start : end;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: value ~/ 60, minute: value % 60),
    );
    if (time == null || !mounted) return;
    setState(() {
      final minutes = time.hour * 60 + time.minute;
      isStart ? start = minutes : end = minutes;
    });
  }

  bool get valid => place.text.trim().isNotEmpty && start != end;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.schedule == null ? 'Agregar horario' : 'Editar horario'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          if (widget.clinics.isNotEmpty)
            DropdownButtonFormField<String?>(
              initialValue: clinicId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Clínica en VetDosis',
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Otro lugar')),
                for (final c in widget.clinics)
                  DropdownMenuItem(
                    value: c.clinicId,
                    child: Text(c.clinicName),
                  ),
              ],
              onChanged: (v) => setState(() {
                clinicId = v;
                final name = widget.clinics
                    .where((c) => c.clinicId == v)
                    .firstOrNull
                    ?.clinicName;
                if (name != null) place.text = name;
              }),
            ),
          TextField(
            controller: place,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Lugar'),
            onChanged: (_) => setState(() {}),
          ),
          DropdownButtonFormField<int>(
            initialValue: weekday,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Día'),
            items: [
              for (final d in weekdayLabels.entries)
                DropdownMenuItem(value: d.key, child: Text(d.value)),
            ],
            onChanged: (v) => setState(() => weekday = v ?? weekday),
          ),
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => pick(true),
                  child: Text('Entrada ${WorkSchedule.clock(start)}'),
                ),
              ),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => pick(false),
                  child: Text('Salida ${WorkSchedule.clock(end)}'),
                ),
              ),
            ],
          ),
          if (end < start)
            const Text('La salida es al día siguiente (guardia nocturna).'),
          TextField(
            controller: note,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'Nota (opcional)'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: valid
            ? () => Navigator.pop(
                context,
                WorkSchedule(
                  id: widget.schedule?.id,
                  place: place.text.trim(),
                  clinicId: clinicId,
                  weekday: weekday,
                  startMinutes: start,
                  endMinutes: end,
                  note: note.text.trim(),
                ),
              )
            : null,
        child: const Text('Guardar'),
      ),
    ],
  );
}

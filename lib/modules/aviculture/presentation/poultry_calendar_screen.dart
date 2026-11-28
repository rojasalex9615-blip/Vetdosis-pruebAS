import 'package:flutter/material.dart';
import '../../../core/widgets/capture_sheet.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_icons.dart';
import '../../../vet_ui/vet_format.dart';
import '../domain/poultry_farm.dart';
import '../domain/poultry_schedule.dart';
import '../domain/aviculture_records.dart';
import 'poultry_farm_screen.dart' show poultryFarmError;

class PoultryCalendarScreen extends StatefulWidget {
  const PoultryCalendarScreen({
    super.key,
    required this.clinicId,
    required this.repository,
    this.houseId,
  });
  final String clinicId;
  final PoultryFarmRepository repository;
  final String? houseId;
  @override
  State<PoultryCalendarScreen> createState() => _PoultryCalendarScreenState();
}

class _PoultryCalendarScreenState extends State<PoultryCalendarScreen> {
  PoultryFarmWorkspace? data;
  List<PoultrySchedule> items = [];
  bool busy = true, all = false;
  String error = '';
  String? house;
  int generation = 0;
  DateTime? checked;
  @override
  void initState() {
    super.initState();
    house = widget.houseId;
    load();
  }

  @override
  void didUpdateWidget(covariant PoultryCalendarScreen old) {
    super.didUpdateWidget(old);
    if (old.clinicId != widget.clinicId ||
        old.repository != widget.repository) {
      house = widget.houseId;
      load();
    }
  }

  Future<void> load() async {
    final gen = ++generation;
    setState(() {
      busy = true;
      error = '';
      data = null;
      items = [];
      checked = null;
    });
    try {
      final repo = widget.repository;
      if (repo is! PoultryScheduleRepository) {
        throw const FormatException(
          'El calendario aún no está habilitado en esta versión de tu cuenta.',
        );
      }
      final values = await Future.wait<Object>([
        repo.load(widget.clinicId),
        (repo as PoultryScheduleRepository).calendar(widget.clinicId),
      ]);
      final workspace = values[0] as PoultryFarmWorkspace;
      final list = PoultrySchedule.read(
        values[1] as Map<String, dynamic>,
        widget.clinicId,
        workspace,
      );
      if (!mounted || gen != generation) return;
      setState(() {
        data = workspace;
        items = list;
        checked = DateTime.now();
        if (!workspace.records.houses.any(
          (h) => h.id == house && workspace.houseFarmIds[h.id] != null,
        )) {
          house = null;
        }
      });
    } on Object catch (e) {
      if (mounted && gen == generation) {
        setState(
          () => error = e.toString().contains('PGRST202')
              ? 'El calendario compartido requiere habilitar el servicio de tu cuenta.'
              : e is FormatException
              ? e.message
              : poultryFarmError(e),
        );
      }
    } finally {
      if (mounted && gen == generation) setState(() => busy = false);
    }
  }

  String name(PoultryFarmWorkspace d, String id) {
    final h = d.records.houses.firstWhere((e) => e.id == id);
    final f = d.farms.firstWhere((e) => e.id == d.houseFarmIds[id]);
    return '${f.name} · ${h.name}';
  }

  Future<void> edit(PoultryFarmWorkspace d, {PoultrySchedule? item}) async {
    final h = item?.houseId ?? house;
    if (h == null) return;
    final saved = await openCaptureSheet(
      context,
      _CalendarForm(
        repo: widget.repository as PoultryScheduleRepository,
        clinic: widget.clinicId,
        house: h,
        day: d.records.day,
        flocks: d.records.flocks.where((f) => f.houseId == h).toList(),
        item: item,
      ),
    );
    if (saved && mounted) await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Calendario sanitario por caseta'),
      actions: [
        IconButton(
          onPressed: busy ? null : load,
          tooltip: 'Actualizar calendario',
          icon: const Icon(VetIcons.refresh),
        ),
      ],
    ),
    body: busy
        ? const Center(child: CircularProgressIndicator())
        : data == null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  VetNotice(text: error, kind: VetBadgeKind.warning),
                  TextButton(onPressed: load, child: const Text('Reintentar')),
                ],
              ),
            ),
          )
        : body(data!),
  );
  Widget body(PoultryFarmWorkspace d) {
    final filtered = items
        .where(
          (e) =>
              (house == null || e.houseId == house) &&
              (all || e.status == 'pendiente'),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const VetNotice(
          text:
              'Programaciones compartidas del equipo. Los avisos se muestran aquí al consultar el calendario; no son notificaciones del teléfono. Completar una tarea no registra una vacuna o medicación aplicada: captura lo realizado en Sanidad.',
        ),
        if (checked != null)
          Text(
            'Consulta confirmada: ${VetFormat.date(checked!)} · ${TimeOfDay.fromDateTime(checked!).format(context)}',
          ),
        DropdownButtonFormField<String>(
          key: ValueKey('calendar-house-$house'),
          isExpanded: true,
          initialValue: house ?? '',
          decoration: const InputDecoration(labelText: 'Granja y caseta'),
          items: [
            const DropdownMenuItem(value: '', child: Text('Todas las casetas')),
            for (final h in d.records.houses.where(
              (h) => d.houseFarmIds[h.id] != null,
            ))
              DropdownMenuItem(
                value: h.id,
                child: Text(name(d, h.id), maxLines: 2),
              ),
          ],
          onChanged: (v) => setState(() => house = v == '' ? null : v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Incluir completadas y canceladas'),
          value: all,
          onChanged: (v) => setState(() => all = v),
        ),
        if (d.records.canWrite &&
            house != null &&
            d.records.houses.any((h) => h.id == house && !h.archived))
          FilledButton.icon(
            onPressed: () => edit(d),
            icon: const Icon(VetIcons.calendar),
            label: const Text('Programar tarea sanitaria'),
          ),
        if (house == null && d.records.canWrite)
          const Text('Elige una caseta para programar una tarea.'),
        if (filtered.isEmpty)
          const VetEmptyState(
            text: 'Sin tareas para este filtro.',
            icon: VetIcons.calendar,
          ),
        for (final item in filtered)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: VetCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(name(d, item.houseId)),
                  Text(
                    'Fecha programada: ${VetFormat.date(item.date)} · ${item.status}',
                  ),
                  Text(
                    item.flockId == null
                        ? 'Alcance: caseta completa'
                        : 'Parvada: ${d.records.flocks.firstWhere((f) => f.id == item.flockId).code}',
                  ),
                  if (item.warnsOn(d.records.day))
                    VetNotice(
                      text: item.overdueOn(d.records.day)
                          ? 'Tarea vencida pendiente de revisión.'
                          : 'Tarea dentro del plazo de aviso.',
                      kind: VetBadgeKind.warning,
                    ),
                  Text(
                    'Aviso dentro de la app: desde ${item.daysBefore} días antes.',
                  ),
                  if ('${item.data['notes'] ?? ''}'.isNotEmpty)
                    Text('${item.data['notes']}'),
                  if (d.records.canWrite)
                    TextButton(
                      onPressed: () => edit(d, item: item),
                      child: const Text('Editar fecha, aviso o estado'),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CalendarForm extends StatefulWidget {
  const _CalendarForm({
    required this.repo,
    required this.clinic,
    required this.house,
    required this.day,
    required this.flocks,
    this.item,
  });
  final PoultryScheduleRepository repo;
  final String clinic, house;
  final DateTime day;
  final List<AviFlock> flocks;
  final PoultrySchedule? item;
  @override
  State<_CalendarForm> createState() => _CalendarFormState();
}

class _CalendarFormState extends State<_CalendarForm> {
  late final title = TextEditingController(text: widget.item?.title ?? ''),
      notes = TextEditingController(
        text: widget.item?.data['notes'] as String? ?? '',
      ),
      days = TextEditingController(text: '${widget.item?.daysBefore ?? 0}');
  late DateTime date = widget.item?.date ?? widget.day;
  late String kind = widget.item?.data['kind'] as String? ?? 'seguimiento',
      status = widget.item?.status ?? 'pendiente',
      flock = widget.item?.flockId ?? '';
  @override
  void dispose() {
    title.dispose();
    notes.dispose();
    days.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CaptureSheet(
    title: widget.item == null
        ? 'Programar tarea sanitaria'
        : 'Editar programación sanitaria',
    icon: VetIcons.calendar,
    translateError: poultryFarmError,
    notice:
        'Solo programación y seguimiento. No propone productos, dosis ni protocolos.',
    fields: (busy) => [
      CaptureTextField(
        controller: title,
        label: 'Tarea programada',
        busy: busy,
        required: true,
        maxLength: 160,
      ),
      CaptureChoiceField<String>(
        value: kind,
        label: 'Tipo de tarea',
        options: const ['seguimiento', 'vacunacion', 'medicacion'],
        nameOf: (v) => {
          'seguimiento': 'Seguimiento',
          'vacunacion': 'Vacunación programada',
          'medicacion': 'Medicación programada',
        }[v]!,
        busy: busy,
        onChanged: (v) => setState(() => kind = v ?? kind),
      ),
      CaptureDateField(
        value: date,
        label: 'Fecha programada',
        busy: busy,
        required: true,
        pastOnly: false,
        onChanged: (v) => setState(() => date = v ?? date),
      ),
      CaptureChoiceField<String>(
        value: flock,
        label: 'Alcance',
        options: ['', ...widget.flocks.map((f) => f.id)],
        nameOf: (v) => v.isEmpty
            ? 'Caseta completa'
            : widget.flocks.firstWhere((f) => f.id == v).code,
        busy: busy || widget.item != null,
        onChanged: (v) => setState(() => flock = v ?? ''),
      ),
      CaptureIntField(
        controller: days,
        label: 'Avisar dentro de la app desde (días antes)',
        busy: busy,
        required: true,
        min: 0,
        max: 90,
      ),
      if (widget.item != null)
        CaptureChoiceField<String>(
          value: status,
          label: 'Estado de la tarea',
          options: const ['pendiente', 'completada', 'cancelada'],
          nameOf: (v) => {
            'pendiente': 'Pendiente',
            'completada': 'Completada por confirmación manual',
            'cancelada': 'Cancelada',
          }[v]!,
          busy: busy,
          onChanged: (v) => setState(() => status = v ?? status),
        ),
      CaptureTextField(
        controller: notes,
        label: 'Notas y responsable',
        busy: busy,
        lines: 3,
        maxLength: 2000,
      ),
    ],
    onSave: (op) => widget.repo.saveScheduled(
      widget.clinic,
      {
        'house_id': widget.house,
        'flock_id': flock.isEmpty ? null : flock,
        'date': aviDate(date),
        'kind': kind,
        'title': title.text.trim(),
        'notes': notes.text.trim(),
        'days_before': int.parse(days.text),
        'status': status,
      },
      id: widget.item?.id,
      version: widget.item?.version,
      operation: op,
    ),
  );
}

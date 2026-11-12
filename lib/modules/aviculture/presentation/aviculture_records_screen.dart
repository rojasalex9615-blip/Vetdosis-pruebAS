import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../vet_ui/vet_components.dart';
import '../data/supabase_aviculture_records_repository.dart';
import '../domain/aviculture_records.dart';
import '../domain/aviculture_records_repository.dart';
import 'aviculture_records_view_model.dart';

/// Registros productivos de aves de postura.
///
/// La pantalla es autocontenida, como el resto de herramientas avícolas: recibe
/// el espacio activo y crea su repositorio. Cada operación se autoriza en el
/// servidor; los botones solo reflejan la capacidad declarada por el RPC.
class AvicultureRecordsScreen extends StatefulWidget {
  const AvicultureRecordsScreen({super.key, this.clinicId, this.repository});

  final String? clinicId;
  final AvicultureRecordsRepository? repository;

  @override
  State<AvicultureRecordsScreen> createState() =>
      _AvicultureRecordsScreenState();
}

class _AvicultureRecordsScreenState extends State<AvicultureRecordsScreen> {
  AvicultureRecordsViewModel? _model;
  String _setupError = '';

  @override
  void initState() {
    super.initState();
    final clinic = widget.clinicId;
    if (clinic == null || clinic.isEmpty) {
      _setupError =
          'Elige un espacio de trabajo para consultar o registrar parvadas.';
      return;
    }
    try {
      final repository =
          widget.repository ??
          SupabaseAvicultureRecordsRepository(Supabase.instance.client);
      final model = AvicultureRecordsViewModel(
        clinicId: clinic,
        repository: repository,
      );
      _model = model;
      model.load();
    } catch (_) {
      _setupError =
          'La conexión con el servidor no está configurada en este dispositivo.';
    }
  }

  @override
  void dispose() {
    _model?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = _model;
    return Scaffold(
      appBar: AppBar(title: const Text('Aves de postura')),
      floatingActionButton: model == null
          ? null
          : AnimatedBuilder(
              animation: model,
              builder: (context, _) {
                final data = model.workspace;
                if (data == null || !data.canWrite) {
                  return const SizedBox.shrink();
                }
                return FloatingActionButton.extended(
                  onPressed: () => _openFlockDialog(model, data),
                  icon: const Icon(Icons.add),
                  label: const Text('Nueva parvada'),
                );
              },
            ),
      body: model == null
          ? _centered(_setupError)
          : AnimatedBuilder(
              animation: model,
              builder: (context, _) => _body(model),
            ),
    );
  }

  Widget _centered(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: VetNotice(text: text, icon: Icons.info_outline),
    ),
  );

  Widget _body(AvicultureRecordsViewModel model) {
    final data = model.workspace;
    if (data == null) {
      return Center(
        child: model.loading
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VetNotice(
                      text: model.error.isEmpty
                          ? 'No se pudieron cargar los registros avícolas.'
                          : model.error,
                      icon: Icons.cloud_off_outlined,
                      kind: VetBadgeKind.warning,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: model.load,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
      );
    }
    return RefreshIndicator(
      onRefresh: model.load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          if (model.error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: VetNotice(
                text: model.error,
                icon: Icons.error_outline,
                kind: VetBadgeKind.warning,
              ),
            ),
          if (model.busy) const LinearProgressIndicator(),
          const VetSectionHeader(
            title: 'Parvadas y producción',
            subtitle:
                'Indicadores calculados con los registros del servidor. '
                'Semana, aves vivas y postura usan el último día capturado.',
            large: true,
          ),
          if (data.flocks.isEmpty)
            const VetNotice(
              text:
                  'Aún no hay parvadas en este espacio. Crea la primera para '
                  'empezar a registrar producción.',
              icon: Icons.egg_outlined,
            )
          else
            for (final flock in data.flocks)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _flockCard(model, data, flock),
              ),
          const SizedBox(height: 8),
          VetSectionHeader(
            title: 'Registros recientes',
            subtitle: data.canWrite
                ? 'Toca un registro para corregirlo. Cada edición conserva '
                      'su versión y queda auditada.'
                : 'Consulta de los últimos registros del espacio.',
          ),
          if (data.records.isEmpty)
            const VetNotice(
              text: 'Todavía no hay registros productivos.',
              icon: Icons.receipt_long_outlined,
            )
          else
            for (final record in data.records.take(8))
              _recordTile(model, data, record),
          const SizedBox(height: 8),
          const VetSectionHeader(
            title: 'Eventos sanitarios',
            subtitle:
                'Vacunación, tratamiento, desparasitación y manejo. '
                'El retiro de huevo se conserva con su fecha.',
          ),
          if (data.events.isEmpty)
            const VetNotice(
              text: 'Sin eventos registrados.',
              icon: Icons.medical_services_outlined,
            )
          else
            for (final event in data.events.take(6))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.medical_services_outlined),
                title: Text('${event.title} · ${event.flock}'),
                subtitle: Text(
                  '${aviShortDate(event.date)} · ${event.kindLabel}'
                  '${event.withdrawalUntil == null ? '' : ' · retiro de huevo hasta ${aviShortDate(event.withdrawalUntil)}'}',
                ),
                trailing: data.canWrite
                    ? IconButton(
                        tooltip: 'Agregar evento a esta parvada',
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => _openEventDialog(
                          model,
                          data,
                          flock: _findFlock(data.flocks, event.flockId),
                        ),
                      )
                    : null,
              ),
          const SizedBox(height: 8),
          const VetSectionHeader(
            title: 'Casetas',
            subtitle:
                'Capacidad declarada por el espacio; no sustituye una '
                'verificación de bienestar.',
          ),
          if (data.houses.isEmpty)
            const VetNotice(
              text: 'Sin casetas registradas.',
              icon: Icons.home_work_outlined,
            )
          else
            for (final house in data.houses)
              VetCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.home_work_outlined),
                  title: Text(house.name),
                  subtitle: Text(
                    '${house.systemLabel} · ${house.capacity} aves'
                    '${house.archived ? ' · archivada' : ''}',
                  ),
                  trailing: data.canWrite
                      ? const Icon(Icons.edit_outlined)
                      : null,
                  onTap: data.canWrite
                      ? () => _openHouseDialog(model, house: house)
                      : null,
                ),
              ),
          if (data.canWrite)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton.icon(
                onPressed: () => _openHouseDialog(model),
                icon: const Icon(Icons.add_home_outlined),
                label: const Text('Agregar caseta'),
              ),
            ),
          const SizedBox(height: 16),
          _references(data),
          const SizedBox(height: 16),
          const VetNotice(
            text:
                'Los rangos avícolas provienen de la fuente indicada y varios '
                'siguen sin verificar. Fuera de rango se avisa, pero no se '
                'bloquea el registro ni equivale a aprobación técnica.',
            icon: Icons.fact_check_outlined,
          ),
        ],
      ),
    );
  }

  Widget _flockCard(
    AvicultureRecordsViewModel model,
    AviWorkspace data,
    AviFlock flock,
  ) => VetCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    flock.code,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${flock.house.isEmpty ? 'Sin caseta' : flock.house}'
                    '${flock.geneticLine.isEmpty ? '' : ' · ${flock.geneticLine}'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            VetStatusBadge(
              label: flock.active ? 'Activa' : 'Cerrada',
              kind: flock.active
                  ? VetBadgeKind.success
                  : VetBadgeKind.information,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 20,
          runSpacing: 10,
          children: [
            _metric('Semana', '${flock.week}'),
            _metric('Aves vivas', '${flock.birds}'),
            _metric(
              'Postura',
              flock.layingPct == null ? '—' : '${aviNumber(flock.layingPct)} %',
            ),
            _metric('Mortalidad', '${aviNumber(flock.mortalityPct)} %'),
            _metric('Huevos', '${flock.eggsTotal}'),
            _metric('Alimento', '${aviNumber(flock.feedKgTotal)} kg'),
            _metric('Último día', aviShortDate(flock.lastRecord)),
          ],
        ),
        if (flock.active && data.canWrite) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _openRecordDialog(model, data, flock: flock),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Registrar día'),
              ),
              OutlinedButton.icon(
                onPressed: () => _openEventDialog(model, data, flock: flock),
                icon: const Icon(Icons.medical_services_outlined),
                label: const Text('Evento'),
              ),
              TextButton.icon(
                onPressed: () => _confirmClose(model, flock),
                icon: const Icon(Icons.lock_outline),
                label: const Text('Cerrar ciclo'),
              ),
            ],
          ),
        ],
      ],
    ),
  );

  Widget _metric(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      Text(value, style: Theme.of(context).textTheme.titleSmall),
    ],
  );

  Widget _recordTile(
    AvicultureRecordsViewModel model,
    AviWorkspace data,
    AviRecord record,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.receipt_long_outlined),
    title: Text('${aviShortDate(record.date)} · ${record.flock}'),
    subtitle: Text(
      '${record.eggs} huevos · ${record.eggsDiscarded} descartados · '
      '${record.mortality} bajas · ${aviNumber(record.feedKg)} kg'
      '${record.avgWeightG == null ? '' : ' · ${aviNumber(record.avgWeightG)} g'}',
    ),
    trailing: data.canWrite ? const Icon(Icons.edit_outlined) : null,
    onTap: data.canWrite
        ? () => _openRecordDialog(model, data, record: record)
        : null,
  );

  Widget _references(AviWorkspace data) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    title: const Text('Referencias de capacidad y equipos'),
    subtitle: Text(
      '${data.references.length} parámetros · '
      '${data.equipment.length} equipos',
    ),
    children: [
      for (final reference in data.references)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(
            '${reference.stage} · ${reference.parameter.replaceAll('_', ' ')}',
          ),
          subtitle: Text(
            '${reference.system.replaceAll('_', ' ')} · ${reference.weeks} · '
            '${reference.range}'
            '${reference.source.isEmpty ? '' : ' · ${reference.source}'}',
          ),
          trailing: _statusBadge(reference.status),
        ),
      for (final equipment in data.equipment)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(equipment.equipment.replaceAll('_', ' ')),
          subtitle: Text(
            '${equipment.stage.replaceAll('_', ' ')} · ${equipment.range}'
            '${equipment.note.isEmpty ? '' : ' · ${equipment.note}'}',
          ),
          trailing: _statusBadge(equipment.status),
        ),
    ],
  );

  Widget _statusBadge(String status) => switch (status) {
    'verificada' => const VetStatusBadge(
      label: 'Verificada',
      kind: VetBadgeKind.success,
    ),
    'sin_verificar' => const VetStatusBadge(
      label: 'Sin verificar',
      kind: VetBadgeKind.warning,
    ),
    _ => const VetStatusBadge(
      label: 'Pendiente',
      kind: VetBadgeKind.unverified,
    ),
  };

  Future<void> _openHouseDialog(
    AvicultureRecordsViewModel model, {
    AviHouse? house,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _HouseDialog(model: model, house: house),
    );
  }

  Future<void> _openFlockDialog(
    AvicultureRecordsViewModel model,
    AviWorkspace data,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _FlockDialog(model: model, houses: data.houses),
    );
  }

  Future<void> _openRecordDialog(
    AvicultureRecordsViewModel model,
    AviWorkspace data, {
    AviFlock? flock,
    AviRecord? record,
  }) async {
    final flocks = data.flocks.where((f) => f.active).toList();
    if (flocks.isEmpty && record == null) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _RecordDialog(
        model: model,
        flocks: flocks,
        flock: flock,
        record: record,
        today: data.day,
      ),
    );
  }

  Future<void> _openEventDialog(
    AvicultureRecordsViewModel model,
    AviWorkspace data, {
    AviFlock? flock,
  }) async {
    if (data.flocks.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _EventDialog(
        model: model,
        flocks: data.flocks,
        flock: flock,
        today: data.day,
      ),
    );
  }

  Future<void> _confirmClose(
    AvicultureRecordsViewModel model,
    AviFlock flock,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar ciclo'),
        content: Text(
          'La parvada ${flock.code} dejará de admitir registros. '
          'Los datos existentes se conservan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cerrar ciclo'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await model.closeFlock(flock);
  }
}

AviFlock? _findFlock(List<AviFlock> flocks, String id) {
  for (final flock in flocks) {
    if (flock.id == id) return flock;
  }
  return null;
}

String _flockCode(List<AviFlock> flocks, String id) =>
    _findFlock(flocks, id)?.code ?? 'Parvada';

String? _required(String? value) =>
    (value == null || value.trim().isEmpty) ? 'Campo obligatorio' : null;

int? _parseInt(String text) => int.tryParse(text.trim());
double? _parseNumber(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));

class _HouseDialog extends StatefulWidget {
  const _HouseDialog({required this.model, this.house});

  final AvicultureRecordsViewModel model;
  final AviHouse? house;

  @override
  State<_HouseDialog> createState() => _HouseDialogState();
}

class _HouseDialogState extends State<_HouseDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _capacity;
  late final TextEditingController _notes;
  late String _system;
  late bool _archived;
  bool _saving = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    final house = widget.house;
    _name = TextEditingController(text: house?.name ?? '');
    _capacity = TextEditingController(
      text: house == null ? '' : '${house.capacity}',
    );
    _notes = TextEditingController(text: house?.notes ?? '');
    _system = house?.system ?? 'piso';
    _archived = house?.archived ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _capacity.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.house == null ? 'Nueva caseta' : 'Editar caseta'),
    content: SizedBox(
      width: 380,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: _required,
              ),
              DropdownButtonFormField<String>(
                value: _system,
                decoration: const InputDecoration(labelText: 'Sistema'),
                items: const [
                  DropdownMenuItem(value: 'piso', child: Text('Piso')),
                  DropdownMenuItem(
                    value: 'jaula_bateria',
                    child: Text('Jaula / batería'),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _system = value ?? 'piso'),
              ),
              TextFormField(
                controller: _capacity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Capacidad de aves',
                ),
                validator: (value) {
                  final parsed = _parseInt(value ?? '');
                  if (parsed == null || parsed < 0) return 'Número inválido';
                  return null;
                },
              ),
              TextFormField(
                controller: _notes,
                maxLength: 1000,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notas'),
              ),
              if (widget.house != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Archivada'),
                  value: _archived,
                  onChanged: (value) => setState(() => _archived = value),
                ),
              if (_error.isNotEmpty)
                VetNotice(
                  text: _error,
                  icon: Icons.error_outline,
                  kind: VetBadgeKind.warning,
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _saving ? null : _submit,
        child: Text(_saving ? 'Guardando…' : 'Guardar'),
      ),
    ],
  );

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = '';
    });
    final ok = await widget.model.saveHouse(
      id: widget.house?.id,
      version: widget.house?.version,
      name: _name.text.trim(),
      system: _system,
      capacity: _parseInt(_capacity.text) ?? 0,
      notes: _notes.text.trim(),
      archived: _archived,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = ok ? '' : widget.model.error;
    });
    if (ok) Navigator.of(context).pop();
  }
}

class _FlockDialog extends StatefulWidget {
  const _FlockDialog({required this.model, required this.houses});

  final AvicultureRecordsViewModel model;
  final List<AviHouse> houses;

  @override
  State<_FlockDialog> createState() => _FlockDialogState();
}

class _FlockDialogState extends State<_FlockDialog> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _line = TextEditingController();
  final _birds = TextEditingController();
  final _notes = TextEditingController();
  String? _houseId;
  DateTime _start = DateTime.now();
  bool _saving = false;
  String _error = '';

  @override
  void dispose() {
    _code.dispose();
    _line.dispose();
    _birds.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nueva parvada'),
    content: SizedBox(
      width: 380,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _code,
                maxLength: 30,
                decoration: const InputDecoration(
                  labelText: 'Código de parvada',
                ),
                validator: _required,
              ),
              TextFormField(
                controller: _line,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Línea genética (opcional)',
                ),
              ),
              TextFormField(
                controller: _birds,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Aves iniciales',
                ),
                validator: (value) {
                  final parsed = _parseInt(value ?? '');
                  if (parsed == null || parsed < 1) return 'Número inválido';
                  if (parsed > 1000000) return 'Máximo 1 000 000';
                  return null;
                },
              ),
              DropdownButtonFormField<String?>(
                value: _houseId,
                decoration: const InputDecoration(
                  labelText: 'Caseta (opcional)',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Sin caseta'),
                  ),
                  for (final house in widget.houses)
                    if (!house.archived)
                      DropdownMenuItem<String?>(
                        value: house.id,
                        child: Text(house.name),
                      ),
                ],
                onChanged: (value) => setState(() => _houseId = value),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Inicio del ciclo'),
                subtitle: Text(aviShortDate(_start)),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: _pickDate,
              ),
              TextFormField(
                controller: _notes,
                maxLength: 1000,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notas'),
              ),
              if (_error.isNotEmpty)
                VetNotice(
                  text: _error,
                  icon: Icons.error_outline,
                  kind: VetBadgeKind.warning,
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _saving ? null : _submit,
        child: Text(_saving ? 'Guardando…' : 'Guardar'),
      ),
    ],
  );

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(today.year - 5),
      lastDate: today,
    );
    if (picked == null || !mounted) return;
    setState(() => _start = picked);
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = '';
    });
    final ok = await widget.model.createFlock(
      code: _code.text.trim(),
      houseId: _houseId,
      geneticLine: _line.text.trim(),
      startDate: _start,
      initialBirds: _parseInt(_birds.text) ?? 0,
      notes: _notes.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = ok ? '' : widget.model.error;
    });
    if (ok) Navigator.of(context).pop();
  }
}

class _RecordDialog extends StatefulWidget {
  const _RecordDialog({
    required this.model,
    required this.flocks,
    this.flock,
    this.record,
    required this.today,
  });

  final AvicultureRecordsViewModel model;
  final List<AviFlock> flocks;
  final AviFlock? flock;
  final AviRecord? record;
  final DateTime today;

  @override
  State<_RecordDialog> createState() => _RecordDialogState();
}

class _RecordDialogState extends State<_RecordDialog> {
  final _form = GlobalKey<FormState>();
  final _eggs = TextEditingController();
  final _discarded = TextEditingController();
  final _mortality = TextEditingController();
  final _feed = TextEditingController();
  final _weight = TextEditingController();
  final _water = TextEditingController();
  final _notes = TextEditingController();
  String? _flockId;
  DateTime _date = DateTime.now();
  bool _saving = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    _flockId = record?.flockId ?? widget.flock?.id;
    if (_flockId == null && widget.flocks.length == 1) {
      _flockId = widget.flocks.first.id;
    }
    _date = record?.date ?? widget.today;
    if (record != null) {
      _eggs.text = '${record.eggs}';
      _discarded.text = '${record.eggsDiscarded}';
      _mortality.text = '${record.mortality}';
      _feed.text = aviNumber(record.feedKg);
      _weight.text = record.avgWeightG == null
          ? ''
          : aviNumber(record.avgWeightG);
      _water.text = record.waterL == null ? '' : aviNumber(record.waterL);
      _notes.text = record.notes;
    }
  }

  @override
  void dispose() {
    _eggs.dispose();
    _discarded.dispose();
    _mortality.dispose();
    _feed.dispose();
    _weight.dispose();
    _water.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.record != null;
    return AlertDialog(
      title: Text(editing ? 'Editar registro' : 'Registrar día'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!editing)
                  DropdownButtonFormField<String>(
                    value: _flockId,
                    decoration: const InputDecoration(labelText: 'Parvada'),
                    items: [
                      for (final flock in widget.flocks)
                        DropdownMenuItem(
                          value: flock.id,
                          child: Text('${flock.code} · ${flock.birds} aves'),
                        ),
                    ],
                    validator: (value) =>
                        value == null ? 'Elige una parvada' : null,
                    onChanged: (value) => setState(() => _flockId = value),
                  )
                else
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _flockCode(widget.flocks, widget.record!.flockId),
                    ),
                    subtitle: const Text('La parvada no cambia en la edición.'),
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fecha del registro'),
                  subtitle: Text(aviShortDate(_date)),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: editing ? null : _pickDate,
                ),
                TextFormField(
                  controller: _eggs,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Huevos totales',
                  ),
                  validator: (value) => _nonNegative(value),
                ),
                TextFormField(
                  controller: _discarded,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Huevos descartados',
                  ),
                  validator: (value) => _nonNegative(value),
                ),
                TextFormField(
                  controller: _mortality,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Bajas del día'),
                  validator: (value) => _nonNegative(value),
                ),
                TextFormField(
                  controller: _feed,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Alimento consumido (kg)',
                  ),
                  validator: (value) => _nonNegative(value),
                ),
                TextFormField(
                  controller: _weight,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Peso promedio (g, opcional)',
                  ),
                  validator: (value) => _nonNegative(value),
                ),
                TextFormField(
                  controller: _water,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Agua (L, opcional)',
                  ),
                  validator: (value) => _nonNegative(value),
                ),
                TextFormField(
                  controller: _notes,
                  maxLength: 1000,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notas'),
                ),
                if (_error.isNotEmpty)
                  VetNotice(
                    text: _error,
                    icon: Icons.error_outline,
                    kind: VetBadgeKind.warning,
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(_saving ? 'Guardando…' : 'Guardar'),
        ),
      ],
    );
  }

  String? _nonNegative(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final parsed = _parseNumber(text);
    if (parsed == null || parsed < 0) return 'Número inválido';
    return null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(widget.today.year - 5),
      lastDate: widget.today,
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final flockId = _flockId;
    if (flockId == null) return;
    setState(() {
      _saving = true;
      _error = '';
    });
    final ok = await widget.model.saveRecord(
      id: widget.record?.id,
      version: widget.record?.version,
      flockId: flockId,
      date: _date,
      eggs: _parseInt(_eggs.text) ?? 0,
      discarded: _parseInt(_discarded.text) ?? 0,
      mortality: _parseInt(_mortality.text) ?? 0,
      feedKg: _parseNumber(_feed.text) ?? 0,
      avgWeightG: _parseNumber(_weight.text),
      waterL: _parseNumber(_water.text),
      notes: _notes.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = ok ? '' : widget.model.error;
    });
    if (ok) Navigator.of(context).pop();
  }
}

class _EventDialog extends StatefulWidget {
  const _EventDialog({
    required this.model,
    required this.flocks,
    this.flock,
    required this.today,
  });

  final AvicultureRecordsViewModel model;
  final List<AviFlock> flocks;
  final AviFlock? flock;
  final DateTime today;

  @override
  State<_EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends State<_EventDialog> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _details = TextEditingController();
  String? _flockId;
  String _kind = 'tratamiento';
  DateTime _date = DateTime.now();
  DateTime? _withdrawal;
  bool _saving = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _flockId = widget.flock?.id;
    if (_flockId == null && widget.flocks.length == 1) {
      _flockId = widget.flocks.first.id;
    }
    _date = widget.today;
  }

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Evento sanitario'),
    content: SizedBox(
      width: 380,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _flockId,
                decoration: const InputDecoration(labelText: 'Parvada'),
                items: [
                  for (final flock in widget.flocks)
                    DropdownMenuItem(
                      value: flock.id,
                      child: Text('${flock.code} · ${flock.birds} aves'),
                    ),
                ],
                validator: (value) =>
                    value == null ? 'Elige una parvada' : null,
                onChanged: (value) => setState(() => _flockId = value),
              ),
              DropdownButtonFormField<String>(
                value: _kind,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: [
                  for (final entry in AviEvent.kinds.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _kind = value ?? 'otro'),
              ),
              TextFormField(
                controller: _title,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: _required,
              ),
              TextFormField(
                controller: _details,
                maxLength: 2000,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Detalles (producto, dosis, indicación)',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Fecha del evento'),
                subtitle: Text(aviShortDate(_date)),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: _pickDate,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Retiro de huevo hasta (opcional)'),
                subtitle: Text(
                  _withdrawal == null
                      ? 'Sin retiro declarado'
                      : aviShortDate(_withdrawal),
                ),
                trailing: _withdrawal == null
                    ? const Icon(Icons.add_circle_outline)
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Quitar retiro',
                        onPressed: () => setState(() => _withdrawal = null),
                      ),
                onTap: _pickWithdrawal,
              ),
              if (_error.isNotEmpty)
                VetNotice(
                  text: _error,
                  icon: Icons.error_outline,
                  kind: VetBadgeKind.warning,
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _saving ? null : _submit,
        child: Text(_saving ? 'Guardando…' : 'Guardar'),
      ),
    ],
  );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(widget.today.year - 5),
      lastDate: widget.today,
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
  }

  Future<void> _pickWithdrawal() async {
    final initial = _withdrawal == null || _withdrawal!.isBefore(_date)
        ? _date
        : _withdrawal!;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _date,
      lastDate: DateTime(widget.today.year + 2),
    );
    if (picked == null || !mounted) return;
    setState(() => _withdrawal = picked);
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final flockId = _flockId;
    if (flockId == null) return;
    setState(() {
      _saving = true;
      _error = '';
    });
    final ok = await widget.model.saveEvent(
      flockId: flockId,
      date: _date,
      kind: _kind,
      title: _title.text.trim(),
      details: _details.text.trim(),
      withdrawalUntil: _withdrawal,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = ok ? '' : widget.model.error;
    });
    if (ok) Navigator.of(context).pop();
  }
}

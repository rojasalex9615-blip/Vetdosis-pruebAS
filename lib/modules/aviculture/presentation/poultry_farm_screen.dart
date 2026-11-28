import 'package:flutter/material.dart';
import '../../../core/widgets/capture_sheet.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_format.dart';
import '../../../vet_ui/vet_icons.dart';
import '../domain/poultry_farm.dart';
import '../domain/aviculture_records.dart';
import 'aviculture_records_screen.dart';
import 'aviculture_records_view_model.dart' show avicultureError;

String poultryFarmError(Object error) {
  final text = error.toString();
  for (final e in {
    'PGRST202':
        'El registro de granjas aún no está habilitado en esta versión de tu cuenta.',
    'farm_not_available': 'La granja no existe o está archivada.',
    'farm_has_active_houses':
        'Primero archiva las casetas activas de esta granja.',
    'house_has_history':
        'Esta caseta ya tiene historial y no puede trasladarse a otra granja.',
    'flock_not_in_house': 'La parvada elegida no pertenece a esta caseta.',
    'duplicate key':
        'Ese nombre ya está registrado en esta granja o área de trabajo.',
  }.entries) {
    if (text.contains(e.key)) return e.value;
  }
  return avicultureError(error);
}

class PoultryFarmScreen extends StatefulWidget {
  const PoultryFarmScreen({super.key, this.clinicId, this.repository});
  final String? clinicId;
  final PoultryFarmRepository? repository;
  @override
  State<PoultryFarmScreen> createState() => _PoultryFarmScreenState();
}

class _PoultryFarmScreenState extends State<PoultryFarmScreen> {
  PoultryFarmWorkspace? _data;
  String _error = '';
  bool _loading = true;
  int _request = 0;
  String? _farm, _house, _flock;
  String _kind = '';
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PoultryFarmScreen old) {
    super.didUpdateWidget(old);
    if (old.clinicId != widget.clinicId ||
        old.repository != widget.repository) {
      _farm = _house = _flock = null;
      _load();
    }
  }

  Future<void> _load() async {
    final request = ++_request,
        repo = widget.repository,
        clinic = widget.clinicId;
    setState(() {
      _loading = true;
      _error = '';
      _data = null;
    });
    try {
      if (repo == null || clinic == null || clinic.isEmpty) {
        throw const FormatException(
          'Conecta tu cuenta y elige un área de trabajo para consultar las granjas.',
        );
      }
      final data = await repo.load(clinic);
      if (!mounted || request != _request) return;
      setState(() {
        if (!data.farms.any((f) => f.id == _farm)) _farm = null;
        if (!data.records.houses.any(
          (h) =>
              h.id == _house &&
              (_farm == null || data.houseFarmIds[h.id] == _farm),
        )) {
          _house = null;
        }
        if (!data.records.flocks.any(
          (f) =>
              f.id == _flock &&
              (_house == null || f.houseId == _house) &&
              (_farm == null || data.houseFarmIds[f.houseId] == _farm),
        )) {
          _flock = null;
        }
        _data = data;
      });
    } on Object catch (e) {
      if (mounted && request == _request) {
        setState(
          () => _error = e is FormatException ? e.message : poultryFarmError(e),
        );
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _after(Future<bool> action) async {
    final saved = await action;
    if (saved && mounted) await _load();
  }

  List<AviHouse> _houses(PoultryFarmWorkspace d) => d.records.houses
      .where((h) => _farm == null || d.houseFarmIds[h.id] == _farm)
      .toList();
  List<AviFlock> _flocks(PoultryFarmWorkspace d) => d.records.flocks
      .where(
        (f) =>
            (_farm == null || d.houseFarmIds[f.houseId] == _farm) &&
            (_house == null || f.houseId == _house),
      )
      .toList();
  String _farmName(PoultryFarmWorkspace d, String? house) =>
      d.farms.where((f) => f.id == d.houseFarmIds[house]).firstOrNull?.name ??
      'Sin granja asignada';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Granjas, casetas y sanidad'),
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          tooltip: 'Actualizar registros',
          icon: const Icon(VetIcons.refresh),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _data == null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  VetNotice(text: _error, kind: VetBadgeKind.warning),
                  TextButton(onPressed: _load, child: const Text('Reintentar')),
                ],
              ),
            ),
          )
        : _body(_data!),
  );
  Widget _body(PoultryFarmWorkspace d) {
    final houses = _houses(d), flocks = _flocks(d);
    final health = d.health
        .where(
          (e) =>
              (_farm == null || d.houseFarmIds[e.houseId] == _farm) &&
              (_house == null || e.houseId == _house) &&
              (_flock == null || e.flockId == _flock) &&
              (_kind.isEmpty || e.kind == _kind),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const VetNotice(
          text:
              'Organización compartida del área de trabajo: granja → caseta → parvada. Los registros sanitarios se guardan en la caseta, con parvada opcional. Cada guardado queda auditado.',
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('farm-$_farm'),
          isExpanded: true,
          initialValue: _farm ?? '',
          decoration: const InputDecoration(labelText: 'Granja'),
          items: [
            const DropdownMenuItem(value: '', child: Text('Todas las granjas')),
            for (final f in d.farms)
              DropdownMenuItem(
                value: f.id,
                child: Text('${f.name}${f.archived ? ' · archivada' : ''}'),
              ),
          ],
          onChanged: (v) => setState(() {
            _farm = v == '' ? null : v;
            _house = _flock = null;
          }),
        ),
        if (d.canManage)
          Wrap(
            spacing: 10,
            children: [
              TextButton.icon(
                onPressed: () => _after(
                  capturePoultryFarm(
                    context,
                    widget.repository!,
                    widget.clinicId!,
                  ),
                ),
                icon: const Icon(VetIcons.add),
                label: const Text('Nueva granja'),
              ),
              if (_farm != null)
                TextButton(
                  onPressed: () => _after(
                    capturePoultryFarm(
                      context,
                      widget.repository!,
                      widget.clinicId!,
                      farm: d.farms.firstWhere((f) => f.id == _farm),
                    ),
                  ),
                  child: const Text('Editar granja'),
                ),
            ],
          ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('house-$_farm-$_house'),
          isExpanded: true,
          initialValue: _house ?? '',
          decoration: const InputDecoration(labelText: 'Caseta'),
          items: [
            const DropdownMenuItem(value: '', child: Text('Todas las casetas')),
            for (final h in houses)
              DropdownMenuItem(
                value: h.id,
                child: Text('${h.name} · ${_farmName(d, h.id)}', maxLines: 2),
              ),
          ],
          onChanged: (v) => setState(() {
            _house = v == '' ? null : v;
            _flock = null;
          }),
        ),
        if (d.canManage) ...[
          if (_farm != null)
            TextButton.icon(
              onPressed: () => _after(
                capturePoultryHouse(
                  context,
                  widget.repository!,
                  widget.clinicId!,
                  _farm!,
                ),
              ),
              icon: const Icon(VetIcons.add),
              label: const Text('Nueva caseta en esta granja'),
            ),
          if (_house != null && _farm != null)
            TextButton(
              onPressed: () => _after(
                capturePoultryHouse(
                  context,
                  widget.repository!,
                  widget.clinicId!,
                  _farm!,
                  house: houses.firstWhere((h) => h.id == _house),
                ),
              ),
              child: const Text('Editar caseta'),
            ),
          if (d.records.houses.any((h) => d.houseFarmIds[h.id] == null) &&
              _farm != null)
            ExpansionTile(
              title: const Text('Asignar una caseta existente a esta granja'),
              children: [
                for (final h in d.records.houses.where(
                  (h) => d.houseFarmIds[h.id] == null,
                ))
                  ListTile(
                    title: Text(h.name),
                    trailing: const Icon(VetIcons.chevronRight),
                    onTap: () => _after(
                      capturePoultryHouse(
                        context,
                        widget.repository!,
                        widget.clinicId!,
                        _farm!,
                        house: h,
                      ),
                    ),
                  ),
              ],
            ),
        ],
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('flock-$_house-$_flock'),
          isExpanded: true,
          initialValue: _flock ?? '',
          decoration: const InputDecoration(labelText: 'Parvada'),
          items: [
            const DropdownMenuItem(
              value: '',
              child: Text('Todas las parvadas / caseta completa'),
            ),
            for (final f in flocks)
              DropdownMenuItem(
                value: f.id,
                child: Text('${f.code} · ${f.house}', maxLines: 2),
              ),
          ],
          onChanged: (v) => setState(() => _flock = v == '' ? null : v),
        ),
        if (d.canManage && _house != null)
          TextButton.icon(
            onPressed: () => _after(
              capturePoultryFlock(
                context,
                widget.repository!,
                widget.clinicId!,
                houses.firstWhere((h) => h.id == _house),
                d.records.day,
              ),
            ),
            icon: const Icon(VetIcons.add),
            label: const Text('Nueva parvada en esta caseta'),
          ),
        for (final f in flocks)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: VetCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(f.code, style: Theme.of(context).textTheme.titleMedium),
                  Text('${_farmName(d, f.houseId)} · ${f.house}'),
                  Text(
                    '${f.birds} aves registradas · ${f.geneticLine.isEmpty ? 'Sin línea genética capturada' : f.geneticLine}',
                  ),
                  Text(
                    'Inicio ${VetFormat.date(f.startDate)} · ${f.active ? 'Activa' : 'Cerrada'}',
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  AvicultureRecordsScreen(clinicId: widget.clinicId),
            ),
          ),
          child: const Text('Abrir parvadas y registros de producción'),
        ),
        const VetSectionHeader(
          title: 'Historial sanitario',
          subtitle:
              'Vacunas, medicaciones y enfermedades registradas; no propone productos ni dosis.',
        ),
        DropdownButtonFormField<String>(
          initialValue: _kind,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Tipo de registro'),
          items: const [
            DropdownMenuItem(value: '', child: Text('Todos')),
            DropdownMenuItem(value: 'vacunacion', child: Text('Vacunaciones')),
            DropdownMenuItem(value: 'medicacion', child: Text('Medicación')),
            DropdownMenuItem(value: 'enfermedad', child: Text('Enfermedades')),
          ],
          onChanged: (v) => setState(() => _kind = v ?? ''),
        ),
        if (d.records.canWrite &&
            _house != null &&
            d.houseFarmIds[_house] != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: FilledButton.icon(
              onPressed: () => _after(
                capturePoultryHealth(
                  context,
                  widget.repository!,
                  widget.clinicId!,
                  _house!,
                  d.records.day,
                  flocks: d.records.flocks
                      .where((f) => f.houseId == _house)
                      .toList(),
                  initialFlock: _flock,
                ),
              ),
              icon: const Icon(VetIcons.add),
              label: const Text('Registrar vacuna, medicación o enfermedad'),
            ),
          ),
        if (health.isEmpty)
          const VetEmptyState(
            text: 'Sin registros sanitarios nuevos para este filtro.',
            icon: VetIcons.clipboardChecks,
          ),
        for (final e in health)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: VetCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${e.label} · ${VetFormat.date(e.date)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(e.title),
                  Text(
                    '${_farmName(d, e.houseId)} · ${d.records.houses.firstWhere((h) => h.id == e.houseId).name}',
                  ),
                  Text(
                    e.flockId == null
                        ? 'Alcance: caseta completa'
                        : 'Parvada: ${d.records.flocks.firstWhere((f) => f.id == e.flockId).code}',
                  ),
                  for (final field in {
                    'dose': 'Dosis registrada',
                    'route': 'Vía',
                    'diagnosis': 'Diagnóstico registrado',
                    'details': 'Notas',
                    'status': 'Estado',
                  }.entries)
                    if ('${e.data[field.key] ?? ''}'.isNotEmpty)
                      Text('${field.value}: ${e.data[field.key]}'),
                  if (e.data['withdrawal_until'] != null)
                    Text(
                      'Fin de retiro capturado: ${VetFormat.dateFromIso(e.data['withdrawal_until'])}',
                    ),
                ],
              ),
            ),
          ),
        ExpansionTile(
          title: const Text('Eventos anteriores registrados en parvadas'),
          children: [
            for (final e in d.records.events.where(
              (e) =>
                  flocks.any((f) => f.id == e.flockId) &&
                  (_flock == null || e.flockId == _flock),
            ))
              ListTile(
                title: Text('${e.kindLabel} · ${e.title}'),
                subtitle: Text(
                  '${e.flock} · ${VetFormat.date(e.date)}\n${e.details}',
                ),
              ),
          ],
        ),
      ],
    );
  }
}

Future<bool> capturePoultryFarm(
  BuildContext context,
  PoultryFarmRepository repo,
  String clinic, {
  PoultryFarm? farm,
}) => openCaptureSheet(
  context,
  _FarmForm(repo: repo, clinic: clinic, farm: farm),
);

class _FarmForm extends StatefulWidget {
  const _FarmForm({required this.repo, required this.clinic, this.farm});
  final PoultryFarmRepository repo;
  final String clinic;
  final PoultryFarm? farm;
  @override
  State<_FarmForm> createState() => _FarmFormState();
}

class _FarmFormState extends State<_FarmForm> {
  late final name = TextEditingController(text: widget.farm?.name ?? ''),
      identifier = TextEditingController(text: widget.farm?.identifier ?? ''),
      location = TextEditingController(text: widget.farm?.location ?? ''),
      notes = TextEditingController(text: widget.farm?.notes ?? '');
  @override
  void dispose() {
    name.dispose();
    identifier.dispose();
    location.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CaptureSheet(
    title: widget.farm == null ? 'Nueva granja' : 'Editar granja',
    icon: VetIcons.barn,
    translateError: poultryFarmError,
    fields: (busy) => [
      CaptureTextField(
        controller: name,
        label: 'Nombre de la granja',
        busy: busy,
        required: true,
        maxLength: 80,
      ),
      CaptureTextField(
        controller: identifier,
        label: 'UPP o identificador',
        busy: busy,
        maxLength: 80,
      ),
      CaptureTextField(
        controller: location,
        label: 'Ubicación',
        busy: busy,
        maxLength: 200,
      ),
      CaptureTextField(
        controller: notes,
        label: 'Notas',
        busy: busy,
        maxLength: 1000,
        lines: 3,
      ),
    ],
    onSave: (op) => widget.repo.saveFarm(
      widget.clinic,
      {
        'name': name.text.trim(),
        'identifier': identifier.text.trim(),
        'location': location.text.trim(),
        'notes': notes.text.trim(),
      },
      id: widget.farm?.id,
      version: widget.farm?.version,
      operation: op,
    ),
  );
}

Future<bool> capturePoultryHouse(
  BuildContext context,
  PoultryFarmRepository repo,
  String clinic,
  String farm, {
  AviHouse? house,
}) => openCaptureSheet(
  context,
  _HouseForm(repo: repo, clinic: clinic, farm: farm, house: house),
);

class _HouseForm extends StatefulWidget {
  const _HouseForm({
    required this.repo,
    required this.clinic,
    required this.farm,
    this.house,
  });
  final PoultryFarmRepository repo;
  final String clinic, farm;
  final AviHouse? house;
  @override
  State<_HouseForm> createState() => _HouseFormState();
}

class _HouseFormState extends State<_HouseForm> {
  late final name = TextEditingController(text: widget.house?.name ?? ''),
      capacity = TextEditingController(
        text: widget.house == null ? '' : '${widget.house!.capacity}',
      ),
      notes = TextEditingController(text: widget.house?.notes ?? '');
  late String system = widget.house?.system ?? 'piso';
  @override
  void dispose() {
    name.dispose();
    capacity.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CaptureSheet(
    title: widget.house == null ? 'Nueva caseta' : 'Editar / asignar caseta',
    icon: VetIcons.barn,
    translateError: poultryFarmError,
    fields: (busy) => [
      CaptureTextField(
        controller: name,
        label: 'Nombre de la caseta',
        busy: busy,
        required: true,
        maxLength: 80,
      ),
      CaptureChoiceField<String>(
        value: system,
        label: 'Alojamiento',
        options: const ['piso', 'jaula_bateria'],
        nameOf: (s) => s == 'piso' ? 'Piso' : 'Jaula / batería',
        busy: busy,
        onChanged: (s) => setState(() => system = s ?? system),
      ),
      CaptureIntField(
        controller: capacity,
        label: 'Capacidad registrada (aves)',
        busy: busy,
        required: true,
        min: 1,
        max: 1000000,
      ),
      CaptureTextField(
        controller: notes,
        label: 'Notas',
        busy: busy,
        maxLength: 1000,
      ),
    ],
    onSave: (op) => widget.repo.saveHouse(
      widget.clinic,
      widget.farm,
      {
        'name': name.text.trim(),
        'system': system,
        'capacity': int.parse(capacity.text),
        'notes': notes.text.trim(),
      },
      id: widget.house?.id,
      version: widget.house?.version,
      operation: op,
    ),
  );
}

Future<bool> capturePoultryFlock(
  BuildContext context,
  PoultryFarmRepository repo,
  String clinic,
  AviHouse house,
  DateTime day,
) => openCaptureSheet(
  context,
  _FlockForm(repo: repo, clinic: clinic, house: house, day: day),
);

class _FlockForm extends StatefulWidget {
  const _FlockForm({
    required this.repo,
    required this.clinic,
    required this.house,
    required this.day,
  });
  final PoultryFarmRepository repo;
  final String clinic;
  final AviHouse house;
  final DateTime day;
  @override
  State<_FlockForm> createState() => _FlockFormState();
}

class _FlockFormState extends State<_FlockForm> {
  final code = TextEditingController(),
      line = TextEditingController(),
      birds = TextEditingController();
  late DateTime start = widget.day;
  @override
  void dispose() {
    code.dispose();
    line.dispose();
    birds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CaptureSheet(
    title: 'Nueva parvada · ${widget.house.name}',
    icon: VetIcons.bird,
    translateError: poultryFarmError,
    fields: (busy) => [
      CaptureTextField(
        controller: code,
        label: 'Código único en el área de trabajo',
        busy: busy,
        required: true,
        maxLength: 30,
      ),
      CaptureTextField(
        controller: line,
        label: 'Línea genética registrada',
        busy: busy,
        maxLength: 80,
      ),
      CaptureIntField(
        controller: birds,
        label: 'Aves alojadas inicialmente',
        busy: busy,
        required: true,
        min: 1,
        max: 1000000,
      ),
      CaptureDateField(
        value: start,
        label: 'Inicio de la parvada',
        busy: busy,
        required: true,
        onChanged: (d) => setState(() => start = d ?? start),
      ),
    ],
    onSave: (op) => widget.repo.saveFlock(widget.clinic, {
      'code': code.text.trim(),
      'house_id': widget.house.id,
      'genetic_line': line.text.trim(),
      'initial_birds': int.parse(birds.text),
      'start_date': aviDate(start),
    }, operation: op),
  );
}

Future<bool> capturePoultryHealth(
  BuildContext context,
  PoultryFarmRepository repo,
  String clinic,
  String house,
  DateTime day, {
  required List<AviFlock> flocks,
  String? initialFlock,
}) => openCaptureSheet(
  context,
  _HealthForm(
    repo: repo,
    clinic: clinic,
    house: house,
    day: day,
    flocks: flocks,
    initialFlock: initialFlock,
  ),
);

class _HealthForm extends StatefulWidget {
  const _HealthForm({
    required this.repo,
    required this.clinic,
    required this.house,
    required this.day,
    required this.flocks,
    this.initialFlock,
  });
  final PoultryFarmRepository repo;
  final String clinic, house;
  final DateTime day;
  final List<AviFlock> flocks;
  final String? initialFlock;
  @override
  State<_HealthForm> createState() => _HealthFormState();
}

class _HealthFormState extends State<_HealthForm> {
  final product = TextEditingController(),
      dose = TextEditingController(),
      route = TextEditingController(),
      diagnosis = TextEditingController(),
      details = TextEditingController();
  String kind = 'vacunacion', status = 'observada';
  late String flock = widget.initialFlock ?? '';
  late DateTime date = widget.day;
  DateTime? ended, withdrawal;
  @override
  void dispose() {
    product.dispose();
    dose.dispose();
    route.dispose();
    diagnosis.dispose();
    details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CaptureSheet(
    title: 'Registro sanitario de caseta',
    icon: VetIcons.clipboardChecks,
    translateError: poultryFarmError,
    notice:
        'Captura lo observado o aplicado y su dosis real. Este registro no emite una receta ni propone una pauta.',
    fields: (busy) => [
      CaptureChoiceField<String>(
        value: kind,
        label: 'Tipo',
        options: const ['vacunacion', 'medicacion', 'enfermedad'],
        nameOf: (s) => {
          'vacunacion': 'Vacunación',
          'medicacion': 'Medicación',
          'enfermedad': 'Enfermedad',
        }[s]!,
        busy: busy,
        onChanged: (s) => setState(() => kind = s ?? kind),
      ),
      CaptureChoiceField<String>(
        value: flock,
        label: 'Alcance',
        options: ['', ...widget.flocks.map((f) => f.id)],
        nameOf: (s) => s.isEmpty
            ? 'Caseta completa'
            : widget.flocks.firstWhere((f) => f.id == s).code,
        busy: busy,
        onChanged: (s) => setState(() => flock = s ?? ''),
      ),
      CaptureDateField(
        value: date,
        label: 'Fecha del registro',
        busy: busy,
        required: true,
        onChanged: (d) => setState(() => date = d ?? date),
      ),
      if (kind != 'enfermedad')
        CaptureTextField(
          controller: product,
          label: kind == 'vacunacion'
              ? 'Vacuna / producto registrado'
              : 'Medicamento / producto registrado',
          busy: busy,
          required: true,
          maxLength: 160,
        ),
      if (kind != 'enfermedad')
        CaptureTextField(
          controller: dose,
          label: 'Dosis y unidad registradas',
          busy: busy,
          maxLength: 200,
        ),
      if (kind != 'enfermedad')
        CaptureTextField(
          controller: route,
          label: 'Vía registrada',
          busy: busy,
          maxLength: 80,
        ),
      CaptureTextField(
        controller: diagnosis,
        label: kind == 'enfermedad'
            ? 'Enfermedad / diagnóstico registrado'
            : 'Motivo o diagnóstico registrado',
        busy: busy,
        required: kind == 'enfermedad',
        maxLength: 300,
      ),
      CaptureChoiceField<String>(
        value: status,
        label: 'Estado registrado',
        options: const ['observada', 'confirmada', 'resuelta'],
        nameOf: (s) => {
          'observada': 'Observada / sospecha',
          'confirmada': 'Confirmada',
          'resuelta': 'Resuelta',
        }[s]!,
        busy: busy,
        onChanged: (s) => setState(() => status = s ?? status),
      ),
      CaptureDateField(
        value: ended,
        label: 'Fecha de resolución / fin registrada',
        busy: busy,
        onChanged: (d) => setState(() => ended = d),
      ),
      if (kind != 'enfermedad')
        CaptureDateField(
          value: withdrawal,
          label: 'Fin de retiro capturado',
          busy: busy,
          pastOnly: false,
          onChanged: (d) => setState(() => withdrawal = d),
        ),
      CaptureTextField(
        controller: details,
        label: 'Notas, responsable y seguimiento',
        busy: busy,
        lines: 3,
        maxLength: 2000,
      ),
    ],
    onSave: (op) => widget.repo.saveHealth(widget.clinic, {
      'house_id': widget.house,
      'flock_id': flock.isEmpty ? null : flock,
      'date': aviDate(date),
      'kind': kind,
      'product': kind == 'enfermedad' ? '' : product.text.trim(),
      'dose': kind == 'enfermedad' ? '' : dose.text.trim(),
      'route': kind == 'enfermedad' ? '' : route.text.trim(),
      'diagnosis': diagnosis.text.trim(),
      'status': status,
      'details': details.text.trim(),
      'ended_on': ended == null ? null : aviDate(ended!),
      'withdrawal_until': kind == 'enfermedad' || withdrawal == null
          ? null
          : aviDate(withdrawal!),
    }, operation: op),
  );
}

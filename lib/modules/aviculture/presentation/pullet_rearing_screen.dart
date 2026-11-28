import '../domain/poultry_farm.dart';
import 'poultry_farm_screen.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/calculator_surface.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_format.dart';
import '../../../vet_ui/vet_icons.dart';
import '../../../vet_ui/vet_theme.dart';
import '../../auth/domain/clinic_membership.dart';
import '../../exports/domain/branded_export.dart';
import '../../exports/presentation/branded_export_action.dart' show brandedPdf;
import '../data/pullet_guide_repository.dart';
import '../domain/pullet_guide.dart';
import '../domain/pullet_rearing.dart';
import '../domain/pullet_rearing_export.dart';
import '../domain/rearing_project_repository.dart';
import 'rearing_projects_screen.dart';

class PulletRearingHub extends StatefulWidget {
  const PulletRearingHub({
    super.key,
    this.member,
    this.projects,
    this.catalog,
    this.farms,
  });
  final ClinicMembership? member;
  final RearingProjectRepository? projects;
  final PulletGuideCatalog? catalog;
  final PoultryFarmRepository? farms;
  @override
  State<PulletRearingHub> createState() => _PulletRearingHubState();
}

class _PulletRearingHubState extends State<PulletRearingHub> {
  late final future = widget.catalog == null
      ? PulletGuideRepository().load()
      : Future.value(widget.catalog!);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Crianza de aves de postura')),
    body: FutureBuilder<PulletGuideCatalog>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('No se pudieron cargar las guías de crianza.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final catalog = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const VetNotice(
              text:
                  'Planea alimento, espacio, equipo y costo por pollona. Elige la línea genética y la guía de su sistema; los precios los capturas tú.',
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              icon: const Icon(VetIcons.barn),
              label: const Text('Granjas, casetas y sanidad'),
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => PoultryFarmScreen(
                    clinicId: widget.member?.clinicId,
                    repository: widget.farms,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (final brand in ['Bovans', 'Hy-Line', 'Lohmann'])
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: VetCard(
                  child: ListTile(
                    leading: const Icon(VetIcons.bird),
                    title: Text(brand),
                    subtitle: Text(
                      catalog
                          .forBrand(brand)
                          .map((g) => g.strain)
                          .toSet()
                          .join(', '),
                    ),
                    trailing: const Icon(VetIcons.chevronRight),
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PulletBrandScreen(
                          brand: brand,
                          catalog: catalog,
                          member: widget.member,
                          projects: widget.projects,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            OutlinedButton.icon(
              icon: const Icon(VetIcons.pencil),
              label: const Text('Otra línea · captura propia'),
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => PulletRearingScreen(
                    brand: 'Otra',
                    catalog: catalog,
                    member: widget.member,
                    projects: widget.projects,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              icon: const Icon(VetIcons.folder),
              label: const Text('Proyectos guardados y comparación'),
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => RearingProjectsScreen(
                    catalog: catalog,
                    member: widget.member,
                    repository: widget.projects,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class PulletBrandScreen extends StatelessWidget {
  const PulletBrandScreen({
    super.key,
    required this.brand,
    required this.catalog,
    this.member,
    this.projects,
  });
  final String brand;
  final PulletGuideCatalog catalog;
  final ClinicMembership? member;
  final RearingProjectRepository? projects;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('$brand · crianza')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Cada edición conserva sus propias cifras. Puedes comparar las referencias en la tabla semanal; no se promedian guías ni sistemas.',
        ),
        const SizedBox(height: 12),
        for (final guide in catalog.forBrand(brand))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: VetCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    guide.strain,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '${guide.system == 'piso' ? 'Piso / sistemas alternativos' : 'Jaula'} · ${guide.edition}',
                  ),
                  Text(
                    'Semanas publicadas: ${guide.rows.first['week']}–${guide.rows.last['week']} · ${guide.title}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  for (final note in guide.notes)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        note,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PulletRearingScreen(
                          brand: brand,
                          catalog: catalog,
                          initialGuide: guide,
                          member: member,
                          projects: projects,
                        ),
                      ),
                    ),
                    child: const Text('Ver tabla y calcular'),
                  ),
                  TextButton.icon(
                    onPressed: () => _openGuide(context, guide.url),
                    icon: const Icon(VetIcons.book),
                    label: const Text('Abrir guía oficial'),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

Future<void> _openGuide(BuildContext context, String url) async {
  try {
    if (await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
      return;
    }
  } on Object {
    /* show a useful error below */
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No se pudo abrir la guía. Revisa la conexión.'),
      ),
    );
  }
}

class PulletRearingScreen extends StatefulWidget {
  const PulletRearingScreen({
    super.key,
    required this.brand,
    required this.catalog,
    this.initialGuide,
    this.project,
    this.member,
    this.projects,
  });
  final String brand;
  final PulletGuideCatalog catalog;
  final PulletGuide? initialGuide;
  final RearingProject? project;
  final ClinicMembership? member;
  final RearingProjectRepository? projects;
  @override
  State<PulletRearingScreen> createState() => _PulletRearingScreenState();
}

class _ItemEditor {
  _ItemEditor(RearingItem item)
    : name = TextEditingController(text: item.name),
      coverage = TextEditingController(text: item.coverage),
      price = TextEditingController(text: item.price),
      applications = TextEditingController(text: '${item.applications}'),
      basis = item.basis,
      source = item.source,
      enabled = item.enabled,
      originalCoverage = item.coverage;
  final TextEditingController name, coverage, price, applications;
  final String source, originalCoverage;
  String basis;
  bool enabled;
  void dispose() {
    name.dispose();
    coverage.dispose();
    price.dispose();
    applications.dispose();
  }

  RearingItem value() => RearingItem(
    name: name.text,
    basis: basis,
    coverage: coverage.text,
    price: price.text,
    applications: int.tryParse(applications.text) ?? 0,
    enabled: enabled,
    source: coverage.text != originalCoverage
        ? 'Editado por el usuario · $source'
        : source,
  );
}

class _PulletRearingScreenState extends State<PulletRearingScreen> {
  final _fields = <String, TextEditingController>{};
  final _equipment = <_ItemEditor>[],
      _vaccines = <_ItemEditor>[],
      _removed = <_ItemEditor>[];
  PulletGuide? _guide;
  late String _system;
  String? _projectId;
  bool _mortality = false,
      _electricityPerBird = false,
      _busy = false,
      _upperPie = false;
  int _comparisonWeek = 17;
  String _error = '';
  PulletRearingResult? _result;
  TextEditingController _ctrl(String key, [String initial = '']) =>
      _fields.putIfAbsent(key, () => TextEditingController(text: initial));
  String _text(String key) => _ctrl(key).text;
  @override
  void initState() {
    super.initState();
    final p = widget.project?.plan;
    _projectId = widget.project?.id;
    _guide = p?.guide ?? widget.initialGuide;
    _system = p?.system ?? _guide?.system ?? 'piso';
    _mortality = p?.adjustMortality ?? false;
    _electricityPerBird = p?.electricityPerBird ?? false;
    for (final e in <String, String>{
      'name': p?.name ?? '',
      'birds': p?.birds ?? '',
      'weeks': '${p?.weeks ?? 17}',
      'waste': p?.waste ?? '0',
      'end1': '${p?.stages.firstOrNull?.lastWeek ?? 6}',
      'end2': '${p != null && p.stages.length > 1 ? p.stages[1].lastWeek : 12}',
      'chickPrice': p?.chickPrice ?? '',
      'gas': p?.gasPerBird ?? '',
      'bedKg': p?.beddingKgPerBird ?? '',
      'bedPrice': p?.beddingPriceKg ?? '',
      'electricity': p?.electricityPrice ?? '',
      'periods': p?.electricityPeriods ?? '',
      'linear': p?.linearMetres ?? '',
      'margin': p?.margin ?? '',
    }.entries) {
      _ctrl(e.key, e.value);
    }
    for (var i = 0; i < 3; i++) {
      final s = p != null && i < p.stages.length ? p.stages[i] : null;
      _ctrl(
        'stageName$i',
        s?.name ?? ['Inicio', 'Crecimiento', 'Desarrollo'][i],
      );
      _ctrl('price$i', s?.price ?? '');
      _ctrl('density$i', s?.density ?? '');
    }
    for (final e in p?.feedOverrides.entries ?? <MapEntry<int, String>>[]) {
      _ctrl('feed${e.key}', e.value);
    }
    for (final e
        in p?.mortalityOverrides.entries ?? <MapEntry<int, String>>[]) {
      _ctrl('mort${e.key}', e.value);
    }
    for (final e in p?.weightOverrides.entries ?? <MapEntry<int, String>>[]) {
      _ctrl('weight${e.key}', e.value);
    }
    for (final e in p?.lightOverrides.entries ?? <MapEntry<int, String>>[]) {
      _ctrl('light${e.key}', e.value);
    }
    if (p != null) {
      _equipment.addAll(p.equipment.map(_ItemEditor.new));
      _vaccines.addAll(p.vaccines.map(_ItemEditor.new));
    } else {
      for (final row in widget.catalog.equipmentDefaults) {
        _equipment.add(
          _ItemEditor(
            RearingItem(
              name: row['name'] as String,
              basis: row['basis'] as String,
              coverage: row['coverage'] as String,
              source: row['source'] as String,
            ),
          ),
        );
      }
      _equipment.add(
        _ItemEditor(
          const RearingItem(
            name: 'Focos LED',
            basis: 'area',
            coverage: '',
            enabled: false,
            source: 'Proyecto aportado: 12–15 m² por foco; elige tu razón.',
          ),
        ),
      );
      _equipment.add(
        _ItemEditor(
          const RearingItem(
            name: 'Divisiones temporales',
            basis: 'linear',
            coverage: '1',
            enabled: false,
            source: 'Proyecto aportado: una división por metro lineal.',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    for (final e in [..._equipment, ..._vaccines, ..._removed]) {
      e.dispose();
    }
    super.dispose();
  }

  void _invalidate([String? _]) => setState(() {
    _result = null;
    _error = '';
  });
  int get _weeks => (int.tryParse(_text('weeks')) ?? 17).clamp(1, 104);
  Widget _field(
    String key,
    String label, {
    String? unit,
    String? help,
    bool number = true,
    ValueChanged<String>? changed,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: TextField(
      key: ValueKey(key),
      controller: _ctrl(key),
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        suffixText: unit,
        helperText: help,
        helperMaxLines: 5,
      ),
      onChanged: changed ?? _invalidate,
    ),
  );
  PulletRearingPlan _plan() {
    final weeks = int.tryParse(_text('weeks'));
    if (weeks == null || weeks < 1 || weeks > 104) {
      throw const FormatException('Captura una duración de 1 a 104 semanas.');
    }
    final end1 = int.tryParse(_text('end1')),
        end2 = int.tryParse(_text('end2'));
    if (end1 == null || end2 == null) {
      throw const FormatException('Revisa los finales de etapa.');
    }
    final stages = <RearingStage>[];
    var start = 1;
    for (var i = 0; i < 3 && start <= weeks; i++) {
      final end = i == 0
          ? end1
          : i == 1
          ? end2
          : weeks;
      stages.add(
        RearingStage(
          name: _text('stageName$i'),
          firstWeek: start,
          lastWeek: end,
          price: _text('price$i'),
          density: _text('density$i'),
        ),
      );
      start = end + 1;
    }
    return PulletRearingPlan(
      name: _text('name'),
      brand: widget.brand,
      system: _system,
      birds: _text('birds'),
      weeks: weeks,
      stages: stages,
      guide: _guide,
      waste: _text('waste'),
      adjustMortality: _mortality,
      feedOverrides: {
        for (var i = 1; i <= weeks; i++)
          if (_text('feed$i').trim().isNotEmpty) i: _text('feed$i'),
      },
      mortalityOverrides: {
        for (var i = 1; i <= weeks; i++)
          if (_text('mort$i').trim().isNotEmpty) i: _text('mort$i'),
      },
      weightOverrides: {
        for (var w = 1; w <= weeks; w++)
          if (_text('weight$w').trim().isNotEmpty) w: _text('weight$w'),
      },
      lightOverrides: {
        for (var w = 1; w <= weeks; w++)
          if (_text('light$w').trim().isNotEmpty) w: _text('light$w'),
      },
      equipment: _equipment.map((e) => e.value()).toList(),
      vaccines: _vaccines.map((e) => e.value()).toList(),
      chickPrice: _text('chickPrice'),
      gasPerBird: _text('gas'),
      beddingKgPerBird: _text('bedKg'),
      beddingPriceKg: _text('bedPrice'),
      electricityPrice: _text('electricity'),
      electricityPeriods: _text('periods'),
      electricityPerBird: _electricityPerBird,
      linearMetres: _text('linear'),
      margin: _text('margin'),
    );
  }

  void _calculate() {
    try {
      final result = calculatePulletRearing(_plan());
      setState(() {
        _result = result;
        _error = '';
      });
    } on FormatException catch (e) {
      setState(() {
        _result = null;
        _error = e.message;
      });
    }
  }

  bool get _canSave =>
      widget.projects != null &&
      widget.member != null &&
      widget.member!.userId.isNotEmpty &&
      widget.member!.clinicId.isNotEmpty;
  Future<void> _save() async {
    if (!_canSave || _busy) return;
    try {
      final plan = _plan();
      if (plan.name.trim().isEmpty) {
        throw const FormatException(
          'Ponle nombre al proyecto antes de guardar.',
        );
      }
      setState(() => _busy = true);
      final id =
          _projectId ??
          '${DateTime.now().microsecondsSinceEpoch}-${math.Random.secure().nextInt(1 << 30)}';
      await widget.projects!.save(
        widget.member!.userId,
        widget.member!.clinicId,
        RearingProject(id: id, updatedAt: DateTime.now(), plan: plan),
      );
      if (!mounted) return;
      setState(() => _projectId = id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proyecto guardado en este dispositivo.')),
      );
    } on Object catch (e) {
      if (mounted) {
        setState(
          () => _error = e is FormatException
              ? e.message
              : 'No se pudo guardar el proyecto.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export(String format) async {
    final result = _result;
    if (result == null || _busy) return;
    setState(() => _busy = true);
    try {
      final rows = pulletRearingExportRows(result),
          brand = ExportBranding(
            name: widget.member?.clinicName ?? 'VetDosis Pro',
            header: 'Crianza de aves de postura · presupuesto MXN',
          );
      final bytes = format == 'xlsx'
          ? brandedXlsx(
              brand,
              result.plan.name.isEmpty
                  ? 'Presupuesto de crianza'
                  : result.plan.name,
              rows,
            )
          : await brandedPdf(
              brand,
              result.plan.name.isEmpty
                  ? 'Presupuesto de crianza'
                  : result.plan.name,
              rows,
            );
      if (!mounted) return;
      await FilePicker.saveFile(
        fileName: 'crianza-postura.$format',
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: [format],
      );
    } on Object {
      if (mounted) {
        setState(() => _error = 'No se pudo exportar el presupuesto.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 5,
    child: Scaffold(
      appBar: AppBar(
        title: Text('${widget.brand} · crianza'),
        bottom: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'Entradas'),
            Tab(text: 'Alimento'),
            Tab(text: 'Equipo y vacunas'),
            Tab(text: 'Resumen'),
            Tab(text: 'Desglose'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Guardar proyecto',
            onPressed: _canSave && !_busy ? _save : null,
            icon: const Icon(VetIcons.save),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: CalculatorActionButton(
            id: 'layer_reference',
            onPressed: _busy ? null : _calculate,
            child: const Text('Calcular presupuesto'),
          ),
        ),
      ),
      body: Column(
        children: [
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: VetNotice(text: _error, kind: VetBadgeKind.danger),
            ),
          Expanded(
            child: TabBarView(
              children: [
                _entries(),
                _feed(),
                _items(),
                _summary(),
                _breakdown(),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Widget _scroll(List<Widget> children) =>
      ListView(padding: const EdgeInsets.all(16), children: children);
  Widget _entries() {
    final options = widget.catalog.forBrand(widget.brand, system: _system);
    if (_guide != null) {
      // Reopened projects keep their frozen table and edition label.
      options.removeWhere((g) => g.id == _guide!.id);
      options.insert(0, _guide!);
    }
    return _scroll([
      const VetNotice(
        text:
            'Presupuesto editable. Las etapas de costos no indican cuándo cambiar de dieta; la guía y el peso corporal determinan el manejo.',
      ),
      _field('name', 'Nombre del proyecto', number: false),
      _field('birds', 'Número de pollitas', unit: 'aves'),
      _field(
        'weeks',
        'Semanas de crianza',
        unit: 'semanas',
        changed: (v) {
          final n = int.tryParse(v);
          if (n != null && n > 0 && n <= 104) {
            _ctrl('end1').text = '${math.min(6, n)}';
            _ctrl('end2').text = '${math.min(12, n)}';
          }
          _invalidate();
        },
      ),
      DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: _system,
        decoration: const InputDecoration(labelText: 'Sistema de alojamiento'),
        items: const [
          DropdownMenuItem(value: 'piso', child: Text('Piso / alternativo')),
          DropdownMenuItem(value: 'jaula', child: Text('Jaula')),
        ],
        onChanged: (s) {
          if (s != null) {
            setState(() {
              _system = s;
              _guide = null;
              _result = null;
              _error = '';
            });
          }
        },
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        key: ValueKey('guide-$_system-${_guide?.id}'),
        initialValue: _guide?.id ?? '',
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Guía y edición'),
        items: [
          const DropdownMenuItem(
            value: '',
            child: Text('Otra · captura propia'),
          ),
          for (final g in options)
            DropdownMenuItem(value: g.id, child: Text(g.edition, maxLines: 2)),
        ],
        onChanged: (id) => setState(() {
          _guide = options.where((g) => g.id == id).firstOrNull;
          _result = null;
        }),
      ),
      if (_guide != null) ...[
        const SizedBox(height: 8),
        Text(_guide!.citation, style: Theme.of(context).textTheme.bodySmall),
        TextButton.icon(
          onPressed: () => _openGuide(context, _guide!.url),
          icon: const Icon(VetIcons.book),
          label: const Text('Consultar fuente oficial'),
        ),
        for (final note in _guide!.notes)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(note, style: Theme.of(context).textTheme.bodySmall),
          ),
      ],
      _field(
        'waste',
        'Merma de alimento',
        unit: '%',
        help: 'Parámetro del proyecto. No procede de la guía.',
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Ajustar consumo por mortalidad'),
        value: _mortality,
        subtitle: const Text(
          'Usa aves vivas a cada semana; requiere mortalidad acumulada de guía o capturada.',
        ),
        onChanged: (v) => setState(() {
          _mortality = v;
          _result = null;
        }),
      ),
      const VetSectionHeader(
        title: 'Etapas y espacio',
        subtitle:
            'Los precios son MXN/kg; deja vacío si todavía no lo conoces. Usa 0 solo cuando el costo sea cero.',
      ),
      _field('end1', 'Última semana de Inicio'),
      if (_weeks > 6) _field('end2', 'Última semana de Crecimiento'),
      for (var i = 0; i < 3; i++)
        ExpansionTile(
          title: Text(_text('stageName$i')),
          initiallyExpanded: i == 0,
          children: [
            _field('stageName$i', 'Nombre de etapa ${i + 1}', number: false),
            _field(
              'price$i',
              'Precio alimento · etapa ${i + 1}',
              unit: 'MXN/kg',
            ),
            _field(
              'density$i',
              'Densidad · etapa ${i + 1}',
              unit: 'aves/m²',
              help: 'Valor de diseño capturado por el usuario.',
            ),
          ],
        ),
      if (_guide?.data['densityReferences'] case final List refs)
        for (final r in refs)
          Text(
            'Referencia al transferir en semana ${r['week']}: ${r['birdsPerM2']} aves/m². ${r['note']} ${_guide!.citation}, p. ${r['page']}.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ExpansionTile(
        title: const Text('Insumos, precios y margen'),
        children: [
          _field('chickPrice', 'Costo por pollita', unit: 'MXN/ave'),
          _field('gas', 'Gas por ave', unit: 'MXN/ave'),
          _field('bedKg', 'Cama por ave', unit: 'kg/ave'),
          _field('bedPrice', 'Precio de cama', unit: 'MXN/kg'),
          SwitchListTile(
            title: const Text('Capturar luz por ave'),
            value: _electricityPerBird,
            onChanged: (v) => setState(() {
              _electricityPerBird = v;
              _result = null;
              _error = '';
            }),
          ),
          _field(
            'electricity',
            _electricityPerBird ? 'Luz por ave' : 'Gasto bimestral de luz',
            unit: _electricityPerBird ? 'MXN/ave' : 'MXN/bimestre',
          ),
          if (!_electricityPerBird)
            _field('periods', 'Duración de luz', unit: 'bimestres'),
          _field('linear', 'Longitud de divisiones', unit: 'm'),
          _field('margin', 'Margen sobre costo · opcional', unit: '%'),
        ],
      ),
      const SizedBox(height: 12),
      if (!_canSave)
        const Text(
          'Conecta tu cuenta y área de trabajo para guardar proyectos. Puedes usar la calculadora sin guardar.',
        )
      else
        OutlinedButton.icon(
          onPressed: _busy ? null : _save,
          icon: const Icon(VetIcons.save),
          label: const Text('Guardar proyecto en este dispositivo'),
        ),
    ]);
  }

  String _range(Map<String, dynamic>? r, String key, String unit) {
    if (r?['${key}Min'] == null) return 'Sin datos de guía';
    final lo = '${r!['${key}Min']}', hi = '${r['${key}Max']}';
    return '${lo == hi ? lo : '$lo–$hi'} $unit';
  }

  Widget _feed() => _scroll([
    const VetNotice(
      text:
          'Los rangos publicados se presupuestan completos. Si necesitas un consumo concreto, captúralo en su semana; quedará marcado como editado.',
    ),
    ExpansionTile(
      title: const Text('Comparar referencias por semana'),
      children: [
        DropdownButtonFormField<int>(
          initialValue: _comparisonWeek,
          decoration: const InputDecoration(labelText: 'Semana a comparar'),
          items: [
            for (var w = 1; w <= 18; w++)
              DropdownMenuItem(value: w, child: Text('$w')),
          ],
          onChanged: (v) => setState(() => _comparisonWeek = v ?? 17),
        ),
        for (final g in widget.catalog.forBrand(widget.brand))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${g.edition} · ${g.system}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  'Consumo: ${_range(g.week(_comparisonWeek), 'feed', 'g/ave/día')}',
                ),
                Text('Peso: ${_range(g.week(_comparisonWeek), 'weight', 'g')}'),
                Text(
                  g.source(_comparisonWeek),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    ),
    for (var w = 1; w <= _weeks; w++)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: VetCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Semana $w', style: Theme.of(context).textTheme.titleMedium),
              Text(
                'Referencia de consumo: ${_range(_guide?.week(w), 'feed', 'g/ave/día')}',
              ),
              Text(
                'Peso: ${_range(_guide?.week(w), 'weight', 'g')} · Acumulado: ${_range(_guide?.week(w), 'cumulative', 'g/ave')}',
              ),
              Text(
                'Luz: ${_range(_guide?.week(w), 'light', 'h/día')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_guide?.week(w)?['uniformityMin'] != null)
                Text(
                  'Uniformidad publicada: ${_guide!.week(w)!['uniformityQualifier'] ?? ''}${_guide!.week(w)!['uniformityMin']} %',
                ),
              _field(
                'feed$w',
                'Consumo propio · semana $w',
                unit: 'g/ave/día',
                help: _text('feed$w').trim().isEmpty
                    ? (_guide?.source(w) ??
                          'Sin datos de guía para esta línea/semana.')
                    : 'Editado por el usuario · referencia: ${_guide?.source(w) ?? 'captura propia'}',
              ),
              ExpansionTile(
                title: const Text('Ajustes de peso y luz'),
                children: [
                  _field(
                    'weight$w',
                    'Peso propio · semana $w',
                    unit: 'g',
                    help: _text('weight$w').isEmpty
                        ? (_guide?.source(w, field: 'weight') ??
                              'Captura propia')
                        : 'Editado por el usuario',
                  ),
                  _field(
                    'light$w',
                    'Luz propia · semana $w',
                    unit: 'h/día',
                    help: _text('light$w').isEmpty
                        ? (_guide?.source(w, field: 'light') ??
                              'Captura propia')
                        : 'Editado por el usuario',
                  ),
                ],
              ),
              if (_mortality)
                _field(
                  'mort$w',
                  'Mortalidad acumulada · semana $w',
                  unit: '%',
                  help: _text('mort$w').isNotEmpty
                      ? 'Editado por el usuario'
                      : _guide?.week(w)?['mortality'] == null
                      ? 'Sin dato de guía; captura la mortalidad acumulada.'
                      : 'Guía: ${_guide!.week(w)!['mortality']} %',
                ),
              if (_result != null) ...[
                Text(
                  'Consumo: ${rearingQuantity(_result!.weekly[w - 1].consumption)}',
                ),
                Text(
                  'Compra: ${rearingCount(_result!.weekly[w - 1].purchase)}',
                ),
                Text(
                  'Costo semanal: ${rearingMoney(_result!.weekly[w - 1].cost)}',
                ),
              ],
            ],
          ),
        ),
      ),
  ]);
  Widget _editor(_ItemEditor item, bool vaccine, int index) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              item.name.text.isEmpty
                  ? (vaccine ? 'Vacuna' : 'Equipo')
                  : item.name.text,
            ),
            value: item.enabled,
            onChanged: (v) => setState(() {
              item.enabled = v;
              _result = null;
              _error = '';
            }),
          ),
          if (item.enabled) ...[
            TextField(
              controller: item.name,
              decoration: InputDecoration(
                labelText: vaccine ? 'Nombre de vacuna' : 'Nombre del equipo',
              ),
              onChanged: _invalidate,
            ),
            if (!vaccine)
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: item.basis,
                decoration: const InputDecoration(labelText: 'Base del conteo'),
                items: const [
                  DropdownMenuItem(
                    value: 'birds',
                    child: Text('Número de aves'),
                  ),
                  DropdownMenuItem(
                    value: 'area',
                    child: Text('Superficie máxima'),
                  ),
                  DropdownMenuItem(
                    value: 'linear',
                    child: Text('Metros lineales'),
                  ),
                ],
                onChanged: (v) => setState(() {
                  item.basis = v ?? 'birds';
                  _result = null;
                  _error = '';
                }),
              ),
            TextField(
              controller: item.coverage,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: vaccine
                    ? 'Dosis por frasco'
                    : item.basis == 'area'
                    ? 'm² por pieza'
                    : item.basis == 'linear'
                    ? 'Metros por pieza'
                    : 'Aves por pieza',
              ),
              onChanged: _invalidate,
            ),
            TextField(
              controller: item.price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: vaccine
                    ? 'Precio por frasco (MXN)'
                    : 'Precio por pieza (MXN)',
              ),
              onChanged: _invalidate,
            ),
            if (vaccine)
              TextField(
                controller: item.applications,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Número de aplicaciones a presupuestar',
                ),
                onChanged: _invalidate,
              ),
            Text(
              item.coverage.text != item.originalCoverage
                  ? 'Editado por el usuario · ${item.source}'
                  : item.source,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          TextButton(
            onPressed: () => setState(() {
              (vaccine ? _vaccines : _equipment).remove(item);
              _removed.add(item);
              _result = null;
              _error = '';
            }),
            child: const Text('Quitar del presupuesto'),
          ),
        ],
      ),
    ),
  );
  Widget _items() => _scroll([
    const VetNotice(
      text:
          'Las razones iniciales de equipo proceden del proyecto aportado, no de los fabricantes. Todas son editables. Las vacunas se presupuestan con tus datos; aquí no se indica un calendario sanitario.',
    ),
    const VetSectionHeader(title: 'Equipo'),
    for (var i = 0; i < _equipment.length; i++)
      _editor(_equipment[i], false, i),
    OutlinedButton(
      onPressed: () => setState(() {
        _equipment.add(
          _ItemEditor(
            const RearingItem(
              name: 'Equipo adicional',
              basis: 'birds',
              coverage: '',
              source: 'Capturado por el usuario',
            ),
          ),
        );
        _result = null;
      }),
      child: const Text('Agregar equipo'),
    ),
    const SizedBox(height: 16),
    const VetSectionHeader(title: 'Vacunas'),
    for (var i = 0; i < _vaccines.length; i++) _editor(_vaccines[i], true, i),
    OutlinedButton(
      onPressed: () => setState(() {
        _vaccines.add(
          _ItemEditor(
            const RearingItem(
              name: 'Vacuna a presupuestar',
              basis: 'birds',
              coverage: '',
              source: 'Capturado por el usuario; sin pauta prescrita',
            ),
          ),
        );
        _result = null;
      }),
      child: const Text('Agregar vacuna'),
    ),
    if (_result != null)
      for (final item in [..._result!.equipment, ..._result!.vaccines])
        ListTile(
          title: Text(item.item.name),
          subtitle: Text(
            '${item.count ?? 'Pendiente'} piezas / frascos · ${item.item.applications} aplicaciones\n${item.cost == null ? 'Costo pendiente' : VetFormat.moneyFromCents(item.cost)}',
          ),
        ),
  ]);
  Widget _summary() {
    final r = _result;
    if (r == null) {
      return _scroll([
        const VetEmptyState(
          text: 'Captura las entradas y pulsa Calcular presupuesto.',
          icon: VetIcons.calculator,
        ),
      ]);
    }
    return _scroll([
      VetSectionHeader(
        title: r.plan.name.isEmpty ? 'Resumen de crianza' : r.plan.name,
        subtitle:
            '${r.plan.brand} · ${r.plan.system} · ${r.plan.weeks} semanas',
      ),
      _stat('Costo total', rearingMoney(r.total)),
      _stat('Subtotal capturado', rearingMoney(r.knownSubtotal)),
      _stat('Costo por pollona alojada', rearingMoney(r.costPerBird)),
      _stat(
        'Precio de venta',
        r.plan.margin.isEmpty
            ? 'Sin margen capturado'
            : rearingMoney(r.salePrice),
      ),
      _stat('Consumo de alimento', rearingQuantity(r.consumption)),
      _stat('Compra de alimento', rearingCount(r.purchase)),
      _stat(
        'Compra por pollita',
        r.purchase == null
            ? 'Sin datos completos'
            : rearingQuantity(
                QuantityBand(
                  intQ(r.purchase!.low) / q(r.plan.birds),
                  intQ(r.purchase!.high) / q(r.plan.birds),
                ),
                unit: 'kg/ave',
              ),
      ),
      _stat(
        'Superficie máxima',
        r.area == null ? 'Falta densidad' : '${r.area} m²',
      ),
      _stat(
        'Cama requerida',
        r.beddingKg == null
            ? 'Falta kg/ave'
            : '${r.beddingKg!.display(places: 1)} kg',
      ),
      for (final s in r.stages)
        _stat(
          '${s.stage.name} · semanas ${s.stage.firstWeek}–${s.stage.lastWeek}',
          '${rearingCount(s.purchase)}\n${rearingMoney(s.cost)}\n${s.area ?? 'Pendiente'} m²',
        ),
      for (final warning in r.warnings)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: VetNotice(text: warning, kind: VetBadgeKind.warning),
        ),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          for (final format in ['pdf', 'xlsx'])
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _export(format),
              icon: const Icon(VetIcons.cloudDownload),
              label: Text('Exportar ${format.toUpperCase()}'),
            ),
        ],
      ),
      const Text(
        'Consumo en kg sin merma; compra redondeada semanalmente al kg más cercano. Equipo, frascos y espacio se redondean hacia arriba. El costo por pollona se divide entre las pollitas alojadas.',
      ),
    ]);
  }

  Widget _stat(String title, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          SelectableText(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    ),
  );
  Widget _breakdown() {
    final r = _result;
    if (r == null) {
      return _scroll([
        const VetEmptyState(
          text: 'Calcula el presupuesto para ver el desglose.',
          icon: VetIcons.chartGrowth,
        ),
      ]);
    }
    final entries = r.categories.entries.where((e) => e.value != null).toList();
    double number(CountBand v) => (_upperPie ? v.high : v.low).toDouble();
    final total = entries.fold<double>(0, (a, b) => a + number(b.value!));
    const colors = [
      VetColors.turquoise,
      VetColors.violet,
      VetColors.cyan,
      VetColors.warning,
      VetColors.pink,
      VetColors.success,
      VetColors.lilac,
    ];
    return _scroll([
      Text(
        r.complete
            ? 'Desglose del costo total'
            : 'Desglose de rubros con costo capturado',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      SwitchListTile(
        title: const Text('Mostrar límite superior del rango'),
        value: _upperPie,
        onChanged: (v) => setState(() => _upperPie = v),
      ),
      if (total > 0)
        Center(
          child: Semantics(
            label: 'Desglose porcentual; valores en la lista siguiente',
            child: SizedBox(
              width: 180,
              height: 180,
              child: CustomPaint(
                painter: _CostPie([
                  for (final e in entries) number(e.value!),
                ], colors),
              ),
            ),
          ),
        )
      else
        const VetEmptyState(
          text: 'No hay importes positivos para graficar.',
          icon: VetIcons.chartGrowth,
        ),
      for (var i = 0; i < entries.length; i++)
        ListTile(
          leading: Icon(VetIcons.dot, color: colors[i % colors.length]),
          title: Text(entries[i].key),
          subtitle: Text(rearingMoney(entries[i].value)),
          trailing: Text(
            total == 0
                ? '0 %'
                : '${(number(entries[i].value!) / total * 100).toStringAsFixed(1)} %',
          ),
        ),
      for (final e in r.categories.entries.where((e) => e.value == null))
        ListTile(
          title: Text(e.key),
          subtitle: const Text('Pendiente; no se incluye en el subtotal.'),
        ),
    ]);
  }
}

class _CostPie extends CustomPainter {
  _CostPie(this.values, this.colors);
  final List<double> values;
  final List<Color> colors;
  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;
    var angle = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      canvas.drawArc(
        Offset.zero & size,
        angle,
        sweep,
        true,
        Paint()..color = colors[i % colors.length],
      );
      angle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _CostPie old) =>
      old.values.toString() != values.toString();
}

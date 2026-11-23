import '../../../core/widgets/accent_glow.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_icons.dart';
import '../../doses/domain/manufacturer_pauta.dart';
import '../../doses/presentation/vademecum_views.dart';
import '../data/reference_library_repository.dart';

/// Pantalla completa de la biblioteca: la envoltura del panel.
class ReferenceLibraryScreen extends StatelessWidget {
  const ReferenceLibraryScreen({
    super.key,
    required this.repository,
    required this.clinicId,
    this.initialSection = 'fisiologia',
    this.canCalculate = false,
    this.onOpenDrugCalculator,
    this.pautas,
  });
  final ReferenceLibraryRepository repository;
  final String clinicId;
  final String initialSection;
  final bool canCalculate;
  final VoidCallback? onOpenDrugCalculator;
  final ManufacturerPautaCatalog? pautas;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Biblioteca de referencias')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VetSectionHeader(
            title: 'Biblioteca de referencias',
            subtitle:
                'Constantes, laboratorio y los dos vademécums, cada uno con '
                'su calculadora. Todo es consulta: no clasifica pacientes.',
            icon: VetIcons.book,
            large: true,
          ),
          const SizedBox(height: 16),
          ReferenceLibraryPanel(
            repository: repository,
            clinicId: clinicId,
            initialSection: initialSection,
            canCalculate: canCalculate,
            onOpenDrugCalculator: onOpenDrugCalculator,
            pautas: pautas,
          ),
        ],
      ),
    ),
  );
}

/// Las referencias guardadas en la base y los vademécums integrados.
///
/// Es una columna, no una lista con desplazamiento propio: asi cabe tanto en
/// la pantalla completa como dentro de «Cálculos clínicos», que ya se
/// desplaza por su cuenta. Solo consulta: no evalua ni clasifica pacientes.
class ReferenceLibraryPanel extends StatefulWidget {
  const ReferenceLibraryPanel({
    super.key,
    required this.repository,
    required this.clinicId,
    this.initialSection = 'fisiologia',
    this.showSections = true,
    this.canCalculate = false,
    this.onOpenDrugCalculator,
    this.pautas,
  });
  final ReferenceLibraryRepository repository;
  final String clinicId;
  final String initialSection;

  /// Si se ofrecen las pestañas de seccion. Incrustado en una herramienta
  /// concreta (constantes) la seccion ya esta decidida y sobran.
  final bool showSections;

  /// Habilita la calculadora de empaque y el acceso a la de mg/kg.
  final bool canCalculate;
  final VoidCallback? onOpenDrugCalculator;

  /// Pautas ya cargadas; en la app se leen del activo.
  final ManufacturerPautaCatalog? pautas;

  @override
  State<ReferenceLibraryPanel> createState() => _ReferenceLibraryPanelState();
}

class _ReferenceLibraryPanelState extends State<ReferenceLibraryPanel> {
  final searchController = TextEditingController();
  late String section = widget.initialSection;
  List<Map<String, dynamic>> items = [];
  ManufacturerPautaCatalog? pautas;
  bool pautasLoading = false;
  bool pautasFailed = false;
  int total = 0;
  int generation = 0;
  bool busy = false;
  String? error;

  bool get isLocal => section == 'farmacologia' || section == 'comercial';

  @override
  void initState() {
    super.initState();
    pautas = widget.pautas;
    if (pautas == null) loadPautas();
    load(reset: true);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  /// Las pautas integradas son las mismas para las dos vistas locales.
  Future<void> loadPautas() async {
    if (pautas != null || pautasLoading) return;
    pautasLoading = true;
    try {
      final catalog = await ManufacturerPautaCatalog.load();
      if (mounted) setState(() => pautas = catalog);
    } catch (_) {
      if (mounted) setState(() => pautasFailed = true);
    } finally {
      if (mounted) setState(() => pautasLoading = false);
    }
  }

  Future<void> load({bool reset = false}) async {
    // Las secciones locales filtran en memoria: no consultan la base.
    if (isLocal) {
      setState(() {});
      return;
    }
    if (busy && !reset) return;
    final request = ++generation;
    final offset = reset ? 0 : items.length;
    final search = searchController.text.trim();
    setState(() {
      busy = true;
      error = null;
      if (reset) {
        items = [];
        total = 0;
      }
    });
    try {
      final page = await widget.repository.list(
        widget.clinicId,
        section,
        search,
        offset,
      );
      if (!mounted || request != generation) return;
      setState(() {
        items = [...items, ...page.items];
        total = page.total;
      });
    } catch (_) {
      if (mounted && request == generation) {
        setState(
          () => error =
              'No se pudieron consultar las referencias. Revisa conexión y '
              'permisos de lectura clínica.',
        );
      }
    } finally {
      if (mounted && request == generation) setState(() => busy = false);
    }
  }

  Future<void> openSource(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir la fuente.')),
        );
      }
    }
  }

  void selectSection(String value) {
    if (section == value) return;
    setState(() {
      section = value;
      items = [];
      total = 0;
      error = null;
    });
    if (isLocal) {
      loadPautas();
      setState(() {});
    } else {
      load(reset: true);
    }
  }

  Widget referenceCard(Map<String, dynamic> row) {
    final highlighted =
        row['review_state'] == 'fuente_contrastada_pendiente_mvz';
    final alternatives = row['alternatives'] as int? ?? 1;
    final distinctIntervals = row['distinct_intervals'] as int? ?? 1;
    String value(String key) => (row[key] ?? '').toString().trim();
    final range = value('min_value').isEmpty && value('max_value').isEmpty
        ? (value('transcripcion').isEmpty ? 'Sin intervalo transcrito' : '')
        : '${value('min_value')} – ${value('max_value')} ${value('unit')}';
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: VetCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${value('species')} · ${value('parameter')}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            if (range.isNotEmpty)
              Text(range, style: Theme.of(context).textTheme.titleLarge),
            if (value('transcripcion').isNotEmpty)
              Text(
                '«${value('transcripcion')}»',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 6),
            Text(
              highlighted
                  ? 'Fuente externa contrastada · pendiente de revisión MVZ'
                  : 'Transcripción pendiente de revisión MVZ',
            ),
            const Text(
              'Consulta la fuente antes de decidir: esta ficha no calcula ni '
              'prescribe.',
            ),
            if (distinctIntervals > 1)
              Text(
                '$distinctIntervals intervalos distintos para esta especie, '
                'parámetro y unidad. Revisa condiciones y fuentes.',
              ),
            if (distinctIntervals == 1 && alternatives > 1)
              Text('$alternatives fuentes registradas para este intervalo.'),
            if (value('notes').isNotEmpty) Text(value('notes')),
            const SizedBox(height: 6),
            Text(
              'Fuente: ${value('source_title').isEmpty ? 'No identificada' : value('source_title')}',
            ),
            if (value('source_row').isNotEmpty)
              Text(
                'Origen: ${value('source_filename')} · '
                '${value('source_sheet')} · fila ${value('source_row')}',
              ),
            if (value('source_url').isNotEmpty)
              TextButton.icon(
                onPressed: () => openSource(value('source_url')),
                icon: const Icon(VetIcons.externalLink),
                label: const Text('Abrir fuente'),
              ),
          ],
        ),
      ),
    );
  }

  static const _sections = [
    ('fisiologia', 'Constantes y fisiología', VetIcons.heartPulse),
    ('laboratorio', 'Laboratorio', VetIcons.flask),
    ('farmacologia', 'Vademécum por fármaco', VetIcons.pills),
    ('comercial', 'Vademécum por nombre comercial', VetIcons.medicineBottle),
  ];

  String get _sectionHint => switch (section) {
    'fisiologia' => 'Intervalos de constantes y fisiología con su fuente.',
    'laboratorio' => 'Analitos, unidades e intervalos del laboratorio clínico.',
    'farmacologia' =>
      'Índice por principio activo para la calculadora de dosis en mg/kg.',
    _ => 'Productos y pautas por nombre comercial para la dosis de empaque.',
  };

  String get _searchLabel => switch (section) {
    'fisiologia' => 'Buscar especie, parámetro o fuente',
    'laboratorio' => 'Buscar especie, analito o fuente',
    'farmacologia' => 'Buscar principio activo',
    _ => 'Buscar nombre comercial, laboratorio o principio',
  };

  Widget _localView() {
    if (pautasLoading) return const LinearProgressIndicator();
    if (pautasFailed || pautas == null) {
      return const Text('No se pudieron cargar los vademécums integrados.');
    }
    final list = pautas!.pautas;
    return section == 'farmacologia'
        ? VademecumDrugView(
            pautas: list,
            query: searchController.text,
            canCalculate: widget.canCalculate,
            onOpenDrugCalculator: widget.onOpenDrugCalculator,
          )
        : VademecumCommercialView(
            pautas: list,
            query: searchController.text,
            canCalculate: widget.canCalculate,
          );
  }

  @override
  void didUpdateWidget(ReferenceLibraryPanel old) {
    super.didUpdateWidget(old);
    // Otra clinica u otro repositorio: lo mostrado ya no corresponde.
    if (old.clinicId != widget.clinicId ||
        old.repository != widget.repository) {
      load(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                VetIcons.info,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Referencias para consulta y evaluación. Los intervalos pendientes '
                  'no clasifican pacientes ni alimentan recetas o calculadoras. En '
                  'laboratorio, usa el intervalo del método y analizador que emitió '
                  'el resultado.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (widget.showSections) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (i, option) in _sections.indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  glowChip(
                    ChoiceChip(
                      avatar: Icon(option.$3, size: 18),
                      label: Text(option.$2),
                      selected: section == option.$1,
                      onSelected: (_) => selectSection(option.$1),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (widget.showSections)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: VetCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    _sections
                        .firstWhere(
                          (s) => s.$1 == section,
                          orElse: () => _sections.first,
                        )
                        .$3,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_sectionHint)),
                ],
              ),
            ),
          ),
        TextField(
          controller: searchController,
          maxLength: 80,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: _searchLabel,
            border: const OutlineInputBorder(),
            counterText: '',
            suffixIcon: IconButton(
              tooltip: 'Buscar',
              onPressed: () {
                if (isLocal) {
                  setState(() {});
                } else {
                  load(reset: true);
                }
              },
              icon: const Icon(VetIcons.search),
            ),
          ),
          onChanged: (_) {
            if (isLocal) setState(() {});
          },
          onSubmitted: (_) {
            if (!isLocal) load(reset: true);
          },
        ),
        if (isLocal)
          _localView()
        else ...[
          if (busy) const LinearProgressIndicator(),
          if (error != null) ...[
            Text(error!, style: TextStyle(color: theme.colorScheme.error)),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => load(reset: true),
                icon: const Icon(VetIcons.refresh),
                label: const Text('Reintentar'),
              ),
            ),
          ],
          if (!busy && error == null) Text('$total referencias encontradas'),
          for (final row in items) referenceCard(row),
          if (items.length < total)
            OutlinedButton(
              onPressed: busy ? null : () => load(),
              child: const Text('Ver más referencias'),
            ),
        ],
      ],
    );
  }
}

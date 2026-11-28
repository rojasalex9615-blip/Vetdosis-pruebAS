import '../../../core/widgets/app_heading_scope.dart';
import 'manufacturer_catalog_screen.dart';
import '../../../core/widgets/contrast.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_theme.dart';
import 'package:flutter/material.dart';
import '../data/catalog_repository.dart';
import '../data/personal_dose_repository.dart';
import '../domain/catalog.dart';
import '../domain/manufacturer_pauta.dart';
import '../domain/pauta_farmacologica.dart';
import 'dose_screen.dart';
import 'farmacologico_dose_screen.dart';
import 'farmacologico_views.dart';
import 'personal_dose_screen.dart';
import 'vademecum_views.dart';
import '../../../vet_ui/vet_icons.dart';

class VademecumScreen extends StatefulWidget {
  const VademecumScreen({
    super.key,
    required this.catalog,
    this.personal,
    this.clinicId,
    this.userId,
    this.admin = false,
    this.canCalculate = false,
    this.canCalculateManufacturer = false,
    this.offline = false,
    this.pautas,
    this.farmacologico,
  });
  final CatalogRepository catalog;
  final PersonalDoseRepository? personal;
  final String? clinicId, userId;
  final bool admin, canCalculate, offline;

  /// Pautas ya cargadas. En la app se leen del activo; las pruebas inyectan
  /// un catálogo pequeño para no depender del archivo completo.
  final ManufacturerPautaCatalog? pautas;

  /// Vademécum farmacológico ya cargado. Las pruebas inyectan uno pequeño para
  /// no depender del archivo completo.
  final FarmacologicoCatalog? farmacologico;

  /// Calculadora aritmética de la dosis del empaque. La abre también el revisor
  /// para comprobar la pauta; la dosis clínica por paciente sigue en
  /// [canCalculate].
  final bool canCalculateManufacturer;
  @override
  State<VademecumScreen> createState() => _VademecumScreenState();
}

class _VademecumScreenState extends State<VademecumScreen> {
  DoseCatalog? catalog;
  ManufacturerPautaCatalog? pautas;
  FarmacologicoCatalog? farmacologico;
  List<PersonalDoseEntry> personal = [];
  String query = '', scope = 'todos', mode = 'farmaco';
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final general = await widget.catalog.load();
      final entries =
          widget.personal == null || widget.clinicId == null || widget.offline
          ? <PersonalDoseEntry>[]
          : await widget.personal!.list(widget.clinicId!);
      // Las pautas integradas del fabricante no deben tumbar el vademecum si
      // el activo falta o viene corrupto: se muestran como sección aparte.
      ManufacturerPautaCatalog? pautaCatalog = widget.pautas;
      if (pautaCatalog == null) {
        try {
          pautaCatalog = await ManufacturerPautaCatalog.load();
        } catch (_) {
          pautaCatalog = null;
        }
      }
      // El vademécum farmacológico es la fuente principal del índice por
      // principio activo; si el activo falta, se avisa en su pestaña y el
      // vademécum comercial sigue funcionando.
      FarmacologicoCatalog? farmacoCatalog = widget.farmacologico;
      if (farmacoCatalog == null) {
        try {
          farmacoCatalog = await FarmacologicoCatalog.load();
        } catch (_) {
          farmacoCatalog = null;
        }
      }
      if (mounted) {
        setState(() {
          catalog = general;
          personal = entries;
          pautas = pautaCatalog;
          farmacologico = farmacoCatalog;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'No se pudo cargar el vademécum. Revisa la conexión y los permisos.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void openDoseCalculator(BuildContext context) {
    final dosis = farmacologico;
    if (dosis == null) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Dosis por principio activo')),
          body: FarmacologicoDoseScreen(
            catalog: dosis,
            marcas: pautas?.pautas ?? const [],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = <(DrugDose, String)>[
      for (final d in catalog?.drugs ?? <DrugDose>[]) (d, 'Base de la app'),
      for (final e in personal)
        if (e.state == 'approved' || e.userId == widget.userId)
          (e.drug, e.state == 'approved' ? 'Clínica' : 'Personal'),
    ];
    final visible = entries
        .where(
          (e) =>
              (scope == 'todos' || e.$2 == scope) &&
              ('${e.$1.name} ${e.$1.species} ${e.$1.presentations.map((p) => p.brand).join(' ')}')
                  .toLowerCase()
                  .contains(query.toLowerCase()),
        )
        .toList();
    final canCalculateDrug = widget.canCalculate;
    final pautaList = pautas?.pautas ?? const <ManufacturerPauta>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppPageHeading(title: 'Vademécum', screens: {'Vademécum'}),
        const Text(
          'Dos vademécums distintos. Por principio activo: qué pautas '
          'mencionan el agente y en qué especie. Por nombre comercial: qué '
          'contiene la marca y qué indica el fabricante.',
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'farmaco',
              label: Text('Por principio activo'),
              icon: Icon(VetIcons.pills),
            ),
            ButtonSegment(
              value: 'comercial',
              label: Text('Por nombre comercial'),
              icon: Icon(VetIcons.medicineBottle),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (value) => setState(() => mode = value.first),
        ),
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 12),
        if (mode == 'farmaco') ...[
          if (widget.personal != null &&
              widget.clinicId != null &&
              !widget.offline)
            OutlinedButton.icon(
              onPressed: () async {
                await Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PersonalDoseScreen(
                      repository: widget.personal!,
                      clinicId: widget.clinicId!,
                      admin: widget.admin,
                      general: catalog?.drugs ?? [],
                    ),
                  ),
                );
                if (mounted) await load();
              },
              icon: const Icon(VetIcons.add),
              label: const Text(
                'Agregar ficha personal o solicitar compartirla',
              ),
            ),
          // Las fichas verificadas son otra fuente: solo se enseñan cuando
          // existen, con su buscador y su filtro de origen. El índice de
          // pautas del fabricante va aparte y no se mezcla con ellas.
          if (entries.isNotEmpty) ...[
            TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar en las fichas verificadas',
                prefixIcon: Icon(VetIcons.search),
              ),
              onChanged: (value) => setState(() => query = value),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  for (final option in const [
                    ('todos', 'Todas'),
                    ('Base de la app', 'Base de la app'),
                    ('Clínica', 'Compartidas con la clínica'),
                    ('Personal', 'Solo mías'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(option.$2),
                        selected: scope == option.$1,
                        onSelected: (_) => setState(() => scope = option.$1),
                      ),
                    ),
                ],
              ),
            ),
            for (final entry in visible) _fichaCard(context, entry),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
          ] else if (!busy)
            const Text(
              'Las fichas verificadas y personales se muestran aquí cuando están disponibles. El catálogo bibliográfico por principio activo se consulta abajo.',
            ),
          if (farmacologico == null)
            const Text(
              'No se pudo cargar el vademécum de dosis. Revisa el activo '
              'farmacologico.v1.json.',
            )
          else
            VademecumFarmacologicoView(
              catalog: farmacologico!,
              marcas: pautaList,
              onOpenDrugCalculator: canCalculateDrug
                  ? () => openDoseCalculator(context)
                  : null,
            ),
        ] else ...[
          OutlinedButton.icon(
            icon: const Icon(VetIcons.book),
            label: const Text('Catálogo comercial y dosis del fabricante'),
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => ManufacturerCatalogScreen(
                  canCalculate:
                      widget.canCalculateManufacturer || widget.canCalculate,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (pautas == null)
            const Text('No se pudieron cargar las pautas del fabricante.')
          else
            VademecumCommercialView(
              pautas: pautaList,
              canCalculate:
                  widget.canCalculateManufacturer || widget.canCalculate,
            ),
        ],
      ],
    );
  }

  Widget _fichaCard(BuildContext context, (DrugDose, String) entry) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: VetCard(
        padding: const EdgeInsets.all(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: readableOn(switch (entry.$2) {
                    'Clínica' => VetColors.lilac,
                    'Personal' => VetColors.mint,
                    _ => VetColors.brandSky,
                  }, Theme.of(context).colorScheme.surface),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      entry.$1.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${entry.$1.species} · ${entry.$2} · '
                      '${entry.$1.evidence.verified ? 'Verificada' : 'Sin verificar'}',
                    ),
                    Text(
                      'Dosis registrada: '
                      '${entry.$1.prescribedDose?.display() ?? 'sin valor único'} '
                      'mg/kg · ${entry.$1.route ?? 'vía pendiente'}',
                    ),
                    Text('Fuente: ${entry.$1.evidence.source ?? 'Pendiente'}'),
                    for (final p in entry.$1.presentations)
                      Text(
                        '${p.brand} · '
                        '${p.concentration?.display() ?? 'concentración pendiente'} '
                        'mg/ml',
                      ),
                    if (widget.canCalculate)
                      TextButton.icon(
                        onPressed: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              appBar: AppBar(title: Text(entry.$1.name)),
                              body: SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: DoseScreen(
                                  repository: widget.catalog,
                                  personalRepository: widget.personal,
                                  clinicId: widget.clinicId,
                                  userId: widget.userId,
                                  admin: widget.admin,
                                  offline: widget.offline,
                                  initialDrug: entry.$1,
                                ),
                              ),
                            ),
                          ),
                        ),
                        icon: const Icon(VetIcons.calculator),
                        label: const Text('Calcular dosis'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

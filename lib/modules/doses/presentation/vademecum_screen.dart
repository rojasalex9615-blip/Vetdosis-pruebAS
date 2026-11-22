import 'manufacturer_catalog_screen.dart';
import '../../../core/widgets/contrast.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_theme.dart';
import 'package:flutter/material.dart';
import '../data/catalog_repository.dart';
import '../data/personal_dose_repository.dart';
import '../domain/catalog.dart';
import '../domain/manufacturer_pauta.dart';
import 'commercial_package_dose_screen.dart';
import 'dose_screen.dart';
import 'personal_dose_screen.dart';
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
  });
  final CatalogRepository catalog;
  final PersonalDoseRepository? personal;
  final String? clinicId, userId;
  final bool admin, canCalculate, offline;

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
  List<PersonalDoseEntry> personal = [];
  String query = '', scope = 'todos';
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
      ManufacturerPautaCatalog? pautaCatalog;
      try {
        pautaCatalog = await ManufacturerPautaCatalog.load();
      } catch (_) {
        pautaCatalog = null;
      }
      if (mounted)
        setState(() {
          catalog = general;
          personal = entries;
          pautas = pautaCatalog;
        });
    } catch (_) {
      if (mounted)
        setState(
          () => error =
              'No se pudo cargar el vademécum. Revisa la conexión y los permisos.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Vademécum', style: Theme.of(context).textTheme.headlineMedium),
        const Text('Consulta fuentes y presentaciones antes de calcular.'),
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
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Buscar fármaco o nombre comercial',
            prefixIcon: Icon(VetIcons.search),
          ),
          onChanged: (value) => setState(() => query = value),
        ),
        // El filtro pasa de lista desplegable a fila de pastillas, como en el
        // «Vademecum rapido» de las referencias: las cuatro vistas a la vista
        // y un toque para cambiar, en vez de abrir un menu.
        const SizedBox(height: 12),
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
                ('fabricante', 'Fabricante'),
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
        const SizedBox(height: 8),
        if (scope != 'fabricante' &&
            widget.personal != null &&
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
            label: const Text('Agregar ficha personal o solicitar compartirla'),
          ),
        if (!busy && visible.isEmpty && scope != 'fabricante')
          const Text(
            'Aún no hay fichas en esta vista. Añade una ficha con fuente verificable o importa el catálogo general.',
          ),
        if (scope == 'fabricante') _manufacturerSection(context),
        for (final entry in visible)
          // Ficha con barra de color a la izquierda segun de donde viene
          // (app, clinica o personal), como las de la referencia.
          Padding(
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
                            '${entry.$1.species} · ${entry.$2} · ${entry.$1.evidence.verified ? 'Verificada' : 'Sin verificar'}',
                          ),
                          Text(
                            'Dosis registrada: ${entry.$1.prescribedDose?.display() ?? 'sin valor único'} mg/kg · ${entry.$1.route ?? 'vía pendiente'}',
                          ),
                          Text(
                            'Fuente: ${entry.$1.evidence.source ?? 'Pendiente'}',
                          ),
                          for (final p in entry.$1.presentations)
                            Text(
                              '${p.brand} · ${p.concentration?.display() ?? 'concentración pendiente'} mg/ml',
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
          ),
      ],
    );
  }

  Widget _manufacturerSection(BuildContext context) {
    final all = pautas?.pautas ?? const <ManufacturerPauta>[];
    final needle = query.trim().toLowerCase();
    final matches = needle.isEmpty
        ? const <ManufacturerPauta>[]
        : all
              .where(
                (p) =>
                    '${p.productName} ${p.manufacturer} '
                            '${p.ingredients} ${p.species}'
                        .toLowerCase()
                        .contains(needle),
              )
              .toList();
    final canCalculate = widget.canCalculateManufacturer || widget.canCalculate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${all.length} pautas del fabricante integradas · '
          'investigación sin verificar',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Text(
          'El texto literal es la fuente. La calculadora solo precarga '
          'reglas proporcionales al peso en unidad de empaque.',
        ),
        if (needle.isEmpty)
          const Text(
            'Escribe un producto, laboratorio o principio activo para buscar.',
          )
        else if (matches.isEmpty)
          const Text('No hay pautas que coincidan con la búsqueda.')
        else ...[
          Text('${matches.length} coincidencias'),
          for (final p in matches.take(20))
            _PautaTile(pauta: p, canCalculate: canCalculate),
        ],
      ],
    );
  }
}

class _PautaTile extends StatelessWidget {
  const _PautaTile({required this.pauta, required this.canCalculate});
  final ManufacturerPauta pauta;
  final bool canCalculate;

  bool get _calculable =>
      canCalculate &&
      pauta.rule == PautaRule.proportionalToWeight &&
      pauta.calculator == PautaCalculator.package;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(pauta.productName, style: theme.textTheme.titleMedium),
            Text(pauta.manufacturer),
            Text(
              'Especie: ${pauta.species}'
              '${pauta.route.isEmpty ? '' : ' · Vía: ${pauta.route}'}',
            ),
            const SizedBox(height: 6),
            Text('Posología literal', style: theme.textTheme.labelLarge),
            Text(pauta.literal, maxLines: 4, overflow: TextOverflow.ellipsis),
            if (pauta.doseReference.isNotEmpty)
              Text('Referencia: ${pauta.doseReference}'),
            if (pauta.withdrawal.isNotEmpty)
              Text('Retiro: ${pauta.withdrawal}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (_calculable)
                  FilledButton.icon(
                    onPressed: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CommercialPackageDoseScreen(initialPauta: pauta),
                      ),
                    ),
                    icon: const Icon(VetIcons.calculator),
                    label: const Text('Calcular según el empaque'),
                  )
                else
                  const Text(
                    'Solo consulta: la regla no es proporcional al peso.',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

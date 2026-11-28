import 'production_workspace.dart';
import 'apiary_harvest_screen.dart';
import 'production_pending_screen.dart';
import 'growth_panel.dart';
import '../../../core/widgets/horizontal_choice_strip.dart';
import 'production_calculator_entries.dart';
import '../../aviculture/presentation/poultry_farm_screen.dart';
import '../../aviculture/domain/poultry_farm.dart';
import '../../aviculture/domain/rearing_project_repository.dart';
import '../../aviculture/presentation/pullet_rearing_screen.dart';
import 'package:flutter/material.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_theme.dart';
import 'porcino_panels.dart';
import 'aquaculture_panels.dart';
import 'semen_reference_screen.dart';
import '../../aviculture/presentation/aviculture_records_screen.dart';
import '../../aviculture/presentation/aviculture_screen.dart';
import '../../aviculture/presentation/broiler_screen.dart';
import '../../aviculture/presentation/layer_reference_screen.dart';
import '../../aviculture/presentation/poultry_index_screen.dart';
import '../../incubation/presentation/incubation_screen.dart';
import '../../auth/domain/clinic_membership.dart';
import '../../calculations/presentation/calculation_screen.dart';
import '../../core/domain/module_access.dart';
import '../../core/domain/navigation_access.dart';
import '../../../vet_ui/vet_icons.dart';
import '../domain/porcino_repository.dart';
import '../domain/production_farm.dart';
import '../domain/production_write_repository.dart';
import '../../reproduction/domain/gestation.dart';
import '../../reproduction/domain/gestation_write_repository.dart';
import '../../reproduction/presentation/gestation_panel.dart';
import '../domain/feed_inventory.dart';
import '../domain/feed_write_repository.dart';
import 'feed_inventory_panel.dart';
import '../domain/aquaculture_species.dart';
import '../domain/production_catalog.dart';
import '../domain/production_unit_repository.dart';
import 'production_units_screen.dart';
import 'production_units_summary.dart';
import 'production_dashboard.dart';

export '../domain/production_catalog.dart';

/// Catalog and existing local tools only. No farm records or operating limits
/// are created by selecting a species/activity.
class ProductionMenu extends StatefulWidget {
  const ProductionMenu({
    super.key,
    required this.onNavigate,
    this.member,
    this.access,
    this.porcino,
    this.farm,
    this.farmWrite,
    this.gestation,
    this.gestationWrite,
    this.feed,
    this.feedWrite,
    this.units,
    this.rearingProjects,
    this.poultryFarms,
    this.initialSpecies,
    this.initialViewDashboard = false,
  });
  final ValueChanged<String> onNavigate;
  final ClinicMembership? member;
  final ModuleAccess? access;
  final PorcinoRepository? porcino;

  /// Datos reales de la granja para el Dashboard Pecuario.
  final ProductionFarmRepository? farm;

  /// Por donde se guardan lotes, registros y eventos de manejo.
  final ProductionWriteRepository? farmWrite;

  /// Gestaciones. La tabla es compartida con exoticos: una gestacion cuelga
  /// del paciente, no del modulo.
  final GestationRepository? gestation;
  final GestationWriteRepository? gestationWrite;
  final FeedInventoryRepository? feed;
  final FeedWriteRepository? feedWrite;

  /// Donde se guardan las unidades de produccion.
  ///
  /// Opcional: sin almacen la seccion de unidades no aparece, igual que el
  /// resto de la pantalla sigue funcionando sin sesion.
  final ProductionUnitRepository? units;
  final RearingProjectRepository? rearingProjects;
  final PoultryFarmRepository? poultryFarms;

  /// Especie con la que abrir directamente el detalle, si aplica.
  final String? initialSpecies;

  /// Si abre directo en la pestaña del Dashboard Pecuario Independiente.
  final bool initialViewDashboard;

  @override
  State<ProductionMenu> createState() => _ProductionMenuState();
}

class _ProductionMenuState extends State<ProductionMenu> {
  String? species, activity;
  String? _dashboardSpecies;
  late int _viewMode; // 0: Catálogo, 1: Dashboard, 2: Reproducción, 3: Alimento

  @override
  void initState() {
    super.initState();
    _viewMode = widget.initialViewDashboard ? 1 : 0;
    species = widget.initialSpecies;
  }

  bool allowed(String page) =>
      navigationAllowed(page, widget.member, widget.access);

  Future<void> open(Widget screen) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _openCalculator(String type, String currentSpecies) {
    open(
      ProductionCalculatorModal(
        calcType: type,
        species: currentSpecies,
        fullScreen: true,
      ),
    );
  }

  void _openVademecum(String currentSpecies) {
    if (allowed('Vademécum')) widget.onNavigate('Vademécum');
  }

  void _openPrescription({
    required bool quantified,
    required String currentSpecies,
  }) {
    if (allowed('Receta')) widget.onNavigate('Receta');
  }

  void _showVitalsDialog(String currentSpecies) {
    if (allowed('Cálculos clínicos')) widget.onNavigate('Cálculos clínicos');
  }

  void _openDashboard() {
    setState(() {
      _dashboardSpecies = species ?? _dashboardSpecies;
      species = null;
      activity = null;
      _viewMode = 1;
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (species == null) ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          // Con tres pestañas los segmentos ya no caben en un teléfono de
          // 360 dp, así que se dejan desplazar en vez de recortarles el texto.
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('Catálogo y Especies'),
                  icon: Icon(VetIcons.paw),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('Dashboard Pecuario'),
                  icon: Icon(VetIcons.dashboard),
                ),
                ButtonSegment(
                  value: 2,
                  label: Text('Reproducción'),
                  icon: Icon(VetIcons.heart),
                ),
                ButtonSegment(
                  value: 3,
                  label: Text('Alimento'),
                  icon: Icon(VetIcons.feedBag),
                ),
              ],
              selected: {_viewMode},
              onSelectionChanged: (val) =>
                  setState(() => _viewMode = val.first),
            ),
          ),
        ),
        if (_viewMode == 1)
          ProductionDashboard(
            onOpenTools: (chosen) => setState(() {
              species = chosen;
              activity = null;
              _viewMode = 0;
            }),
            onNavigate: widget.onNavigate,
            member: widget.member,
            access: widget.access,
            units: widget.units,
            farm: widget.farm,
            farmWrite: widget.farmWrite,
            initialSpecies:
                _dashboardSpecies ?? widget.initialSpecies ?? 'Bovinos',
          )
        else if (_viewMode == 2)
          // La misma pantalla que abre exoticos: la gestacion no es de un
          // modulo, cuelga del paciente.
          GestationPanel(
            member: widget.member,
            repository: widget.gestation,
            writeRepository: widget.gestationWrite,
          )
        else if (_viewMode == 3)
          // El inventario de alimento solo vive aqui: en exoticos la racion
          // es individual y ya se anota en exotic_feedings.
          FeedInventoryPanel(
            member: widget.member,
            repository: widget.feed,
            writeRepository: widget.feedWrite,
          )
        else
          ..._speciesList(context),
      ] else
        ..._detail(context),
    ],
  );

  List<Widget> _speciesList(BuildContext context) => [
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        'Elige una especie o grupo. La clínica y tus permisos se conservan.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
    // Acceso directo destacado al Dashboard Independiente
    VetCard(
      padding: const EdgeInsets.all(16),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              VetIconBox(
                icon: VetIcons.dashboard,
                accent: VetColors.turquoise,
                size: 44,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dashboard Independiente: Producción Pecuaria',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Pulso financiero, curvas teóricas vs reales, mapa de naves y dosificación.',
                      style: TextStyle(fontSize: 12, color: VetColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          VetActionButton(
            label: 'Abrir Dashboard Pecuario Completo',
            icon: VetIcons.arrowForward,
            style: VetActionStyle.primary,
            onPressed: () => setState(() => _viewMode = 1),
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    if (allowed('Cálculos clínicos')) ...[
      const VetSectionHeader(
        title: 'Calculadoras rápidas',
        subtitle: 'Sin elegir especie: por cabeza y lote, agua y alimento.',
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (id, label, toolIcon) in [
            ('herd', 'Por cabeza y lote', VetIcons.cow),
            ('water', 'Medicación en agua', VetIcons.waves),
            ('feed', 'Medicación en alimento', VetIcons.feedBag),
          ])
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: VetModuleTile(
                  title: label,
                  icon: toolIcon,
                  accent: VetColors.turquoise,
                  onTap: () => open(
                    CalculationScreen(
                      initialTool: id,
                      tools: productionCalculationTools,
                      title: 'Producción: $label',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ],
    if (widget.units case final ProductionUnitRepository almacen)
      if (widget.member case final ClinicMembership miembro) ...[
        const SizedBox(height: 20),
        ProductionUnitsSummary(
          key: ValueKey('units:${miembro.userId}:${miembro.clinicId}'),
          repository: almacen,
          userId: miembro.userId,
          clinicId: miembro.clinicId,
          visualFor: speciesVisual,
          onOpen: (unit) => open(
            ProductionUnitsScreen(
              repository: almacen,
              userId: miembro.userId,
              clinicId: miembro.clinicId,
              species: unit.species,
              activity: unit.activity,
            ),
          ),
        ),
      ],
    const SizedBox(height: 20),
    const VetSectionHeader(
      title: 'Especies',
      subtitle: 'Elige una especie o grupo para ver sus herramientas.',
    ),
    for (final entry in productionSpecies.entries)
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _SpeciesCard(
          name: entry.key,
          summary: entry.value.join(' · '),
          badges: _speciesBadges(entry.key),
          onTap: () => setState(() {
            species = entry.key;
            activity = null;
          }),
        ),
      ),
  ];

  /// Las insignias de cada especie.
  ///
  /// La segunda sale de [codigosDeEspecie], no de una lista escrita a mano:
  /// si la especie esta en el catalogo productivo, ya se le pueden dar de
  /// alta lotes y capturar registros y eventos, y decir «en preparacion»
  /// seria mentir. Equinos, que no esta en el catalogo, es el unico caso en
  /// que la insignia gris sigue siendo cierta.
  List<Widget> _speciesBadges(String name) {
    final enCatalogo = (codigosDeEspecie[name] ?? const []).isNotEmpty;
    final registros = enCatalogo
        ? const VetStatusBadge(
            label: 'Lotes y registros productivos',
            kind: VetBadgeKind.success,
          )
        : const VetStatusBadge(
            label: 'Registros en preparación',
            kind: VetBadgeKind.unverified,
          );
    return switch (name) {
      'Peces' => [
        const VetStatusBadge(
          label: 'Calculadora de biomasa y ración',
          kind: VetBadgeKind.success,
        ),
        registros,
      ],
      'Porcinos' => [
        const VetStatusBadge(
          label: 'Calculadora de crecimiento y engorda',
          kind: VetBadgeKind.success,
        ),
        registros,
      ],
      'Aves' => const [
        VetStatusBadge(
          label: 'Capacidad e incubación según acceso',
          kind: VetBadgeKind.success,
        ),
        VetStatusBadge(
          label: 'Parvadas y producción',
          kind: VetBadgeKind.success,
        ),
      ],
      _ => [
        const VetStatusBadge(label: 'Organización de actividades'),
        registros,
      ],
    };
  }

  List<Widget> _detail(BuildContext context) {
    final chosen = species!, current = activity;
    final entries = <ProductionEntry>[];
    void action(
      String id,
      String title,
      ProductionArea area,
      VoidCallback callback, {
      String subtitle = '',
    }) => entries.add(
      ProductionEntry(
        id: '$chosen/${current ?? ''}/$id',
        title: title,
        area: area,
        open: callback,
        subtitle: subtitle,
      ),
    );
    void screen(
      String id,
      String title,
      Widget page, {
      ProductionArea area = ProductionArea.calculators,
      String subtitle = '',
    }) => action(id, title, area, () => open(page), subtitle: subtitle);
    void panel(String id, Widget child) {
      final reference =
          child is PorcinoReferenceCard ||
          child is PorcinoBiosecurityRefsPanel ||
          child is AquacultureSpeciesPanel;
      if (child is SizedBox || child is VetNotice) return;
      final title = child is AquacultureSpeciesPanel
          ? 'Referencias y alcance de acuicultura'
          : productionPanelTitle(child);
      screen(
        id,
        title,
        Scaffold(
          appBar: AppBar(title: Text('$chosen · $title')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (chosen == 'Porcinos')
                const VetNotice(
                  text:
                      'Referencia de clase sin validación externa independiente. Los valores de referencia no representan registros de tu granja ni metas de rendimiento.',
                ),
              child,
            ],
          ),
        ),
        area: child is PorcinoBandPlanPanel
            ? ProductionArea.records
            : reference
            ? ProductionArea.references
            : ProductionArea.calculators,
      );
    }

    if (current != null && allowed('Cálculos clínicos')) {
      if (chosen == 'Bovinos') {
        for (final pair in [
          ('ration', 'Calculadora de Ración'),
          ('fca', 'FCA / Conversión'),
          ('density', 'Densidad Animal'),
          ('capacity', 'Capacidad de Caseta/Nave'),
          ('semen', 'Dosis Seminales'),
        ]) {
          action(
            pair.$1,
            pair.$2,
            ProductionArea.calculators,
            () => _openCalculator(pair.$1, chosen),
          );
        }
        for (final pair in [
          ('herd', 'Por cabeza y lote'),
          ('water', 'Medicación en agua'),
          ('feed', 'Medicación en alimento'),
        ]) {
          screen(
            pair.$1,
            pair.$2,
            CalculationScreen(
              initialTool: pair.$1,
              tools: [pair.$1],
              title: 'Bovinos: ${pair.$2}',
            ),
          );
        }
        if (current != 'Atención individual') {
          panel(
            'growth',
            GrowthPanel(showCosts: allowed('Planeación financiera')),
          );
        }
      }
      if (chosen == 'Ovinos / caprinos') {
        panel(
          'growth',
          GrowthPanel(showCosts: allowed('Planeación financiera')),
        );
        action(
          'density',
          'Densidad del rebaño',
          ProductionArea.calculators,
          () => _openCalculator('density', current),
        );
        action(
          'capacity',
          'Capacidad según superficie y densidad capturada',
          ProductionArea.calculators,
          () => _openCalculator('capacity', current),
        );
        screen(
          'semen',
          'Evaluación seminal por especie',
          const SemenReferenceScreen(),
        );
      }
      if (chosen == 'Abejas') {
        screen(
          'harvest',
          'Rendimiento de cosecha del apiario',
          ApiaryHarvestScreen(showCosts: allowed('Planeación financiera')),
        );
      }
      if (chosen == 'Aves') {
        if (current == 'Postura') {
          screen(
            'rearing',
            'Crianza de pollitas · Bovans, Hy-Line y Lohmann',
            PulletRearingHub(
              member: widget.member,
              projects: widget.rearingProjects,
              farms: widget.poultryFarms,
            ),
          );
          screen(
            'facilities',
            'Capacidad e instalaciones avícolas',
            const AvicultureScreen(),
          );
          screen(
            'laying',
            'Postura: luz, huevos y calidad del huevo',
            const LayerReferenceScreen(),
          );
        }
        if (current == 'Engorda') {
          screen(
            'broiler',
            'Capacidad de pollo de engorda',
            const BroilerScreen(),
          );
        }
        if (current == 'Engorda' || current == 'Postura') {
          screen(
            'indices',
            'Índices productivos (engorda y postura)',
            const PoultryIndexScreen(),
          );
        }
        if (current == 'Reproducción e incubación') {
          screen(
            'incubation',
            'Abrir herramientas de incubación',
            const IncubationScreen(),
          );
        }
      }
      if (chosen == 'Peces') {
        final fish = FishSpecies.fromActivity(current);
        if (fish != null) {
          var i = 0;
          for (final p in aquaculturePanelsFor(fish)) {
            panel('aquaculture-${i++}', p);
          }
        }
      }
      if (chosen == 'Porcinos') {
        var i = 0;
        for (final p in porcinoPanelsFor(
          current,
          showCosts: allowed('Planeación financiera'),
          repository: widget.member == null ? null : widget.porcino,
          clinicId: widget.member?.clinicId,
        )) {
          panel('porcino-${i++}', p);
        }
      }
      if (chosen == 'Equinos' && current == 'Reproducción y crianza') {
        screen(
          'semen',
          'Evaluación seminal por especie',
          const SemenReferenceScreen(),
        );
      }
    }
    if (chosen == 'Aves' && current == 'Postura') {
      screen(
        'farms',
        'Granjas, casetas y sanidad',
        PoultryFarmScreen(
          clinicId: widget.member?.clinicId,
          repository: widget.poultryFarms,
        ),
        area: ProductionArea.records,
        subtitle:
            'Compartido con el equipo autorizado; requiere servicio habilitado.',
      );
      screen(
        'flocks',
        'Parvadas, casetas y producción',
        AvicultureRecordsScreen(clinicId: widget.member?.clinicId),
        area: ProductionArea.records,
      );
      if (allowed('Cálculos clínicos')) {
        screen(
          'guides',
          'Guías oficiales Bovans, Hy-Line y Lohmann',
          PulletRearingHub(
            member: widget.member,
            projects: widget.rearingProjects,
            farms: widget.poultryFarms,
          ),
          area: ProductionArea.references,
        );
      }
    }
    action(
      'dashboard',
      'Registros Productivos',
      ProductionArea.records,
      _openDashboard,
      subtitle: 'Lotes, capturas y eventos reales de $chosen.',
    );
    if (widget.member case final member?) {
      if (widget.units case final repo? when current != null) {
        screen(
          'units',
          'Abrir unidades',
          ProductionUnitsScreen(
            repository: repo,
            userId: member.userId,
            clinicId: member.clinicId,
            species: chosen,
            activity: current,
          ),
          area: ProductionArea.records,
          subtitle: 'Guardado local en este dispositivo.',
        );
      }
      if (chosen != 'Abejas' && chosen != 'Peces' && chosen != 'Aves') {
        screen(
          'gestations',
          'Gestaciones y seguimiento reproductivo',
          Scaffold(
            appBar: AppBar(title: const Text('Gestaciones del espacio')),
            body: SingleChildScrollView(
              child: GestationPanel(
                member: member,
                repository: widget.gestation,
                writeRepository: widget.gestationWrite,
              ),
            ),
          ),
          area: ProductionArea.records,
          subtitle:
              'Registros por paciente del área de trabajo; sin filtro automático por especie.',
        );
      }
    }
    if (allowed('Receta')) {
      action(
        'prescription',
        'Receta del espacio',
        ProductionArea.records,
        () => _openPrescription(quantified: false, currentSpecies: chosen),
      );
    }
    for (final pair in [
      ('Pacientes individuales', 'Pacientes'),
      ('Agenda del espacio', 'Agenda'),
      ('Inventario del espacio', 'Inventario'),
    ]) {
      if (allowed(pair.$2)) {
        action(
          pair.$2,
          pair.$1,
          ProductionArea.records,
          () => widget.onNavigate(pair.$2),
          subtitle: 'Abre el área de trabajo completa; sin filtro por especie.',
        );
      }
    }
    if (allowed('Cálculos clínicos')) {
      action(
        'vitals',
        'Constantes Fisiológicas',
        ProductionArea.references,
        () => _showVitalsDialog(chosen),
      );
    }
    if (allowed('Vademécum')) {
      action(
        'drugs',
        'Vademécum Pecuario',
        ProductionArea.references,
        () => _openVademecum(chosen),
      );
    }
    screen(
      'pending',
      'Estado y pendientes de Producción',
      const ProductionPendingScreen(),
      area: ProductionArea.references,
    );
    return [
      Row(
        children: [
          Expanded(
            child: TextButton.icon(
              onPressed: () => setState(() {
                species = null;
                activity = null;
              }),
              icon: const Icon(VetIcons.arrowBack),
              label: const Text('Volver a especies'),
            ),
          ),
          TextButton(
            onPressed: _openDashboard,
            child: const Text('Ver en Dashboard'),
          ),
        ],
      ),
      Text(chosen, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      Text('Actividad', style: Theme.of(context).textTheme.titleMedium),
      HorizontalChoiceStrip(
        children: [
          for (final a in productionSpecies[chosen]!)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(a),
                selected: a == current,
                onSelected: (_) => setState(() => activity = a),
              ),
            ),
        ],
      ),
      if (current == null)
        const VetNotice(text: 'Elige una actividad para ver sus herramientas.'),
      if (!allowed('Cálculos clínicos'))
        const VetNotice(
          text: 'Las calculadoras no están habilitadas para tu acceso actual.',
        ),
      ProductionWorkspace(
        scope: '$chosen/${current ?? ''}',
        userId: widget.member?.userId,
        clinicId: widget.member?.clinicId,
        entries: entries,
        notices: [
          'Los resultados de calculadoras son cálculos de sesión. Para guardar datos reales utiliza Registros.',
          if (chosen == 'Porcinos')
            'Las referencias porcinas de clase conservan su estado sin verificar; no son metas de rendimiento.',
          if (chosen == 'Ovinos / caprinos')
            'Densidad y capacidad usan los valores que capturas; no proponen cargas animales. La genealogía de progenitores sigue pendiente.',
          if (chosen == 'Abejas')
            'Rendimiento = cosecha ÷ colmenas productivas y cosecha ÷ días. No se incluyen metas biológicas ni dosis de tratamientos.',
        ],
      ),
    ];
  }
}

/// Ícono y color de acento de cada especie, solo presentación.
(IconData, Color) speciesVisual(String name) => switch (name) {
  'Bovinos' => (VetIcons.cow, VetColors.turquoise),
  'Ovinos / caprinos' => (VetIcons.sheep, VetColors.violet),
  'Aves' => (VetIcons.chicken, VetColors.warning),
  'Peces' => (VetIcons.fish, VetColors.cyan),
  'Abejas' => (VetIcons.hive, VetColors.warning),
  'Porcinos' => (VetIcons.pig, VetColors.pink),
  'Equinos' => (VetIcons.horse, VetColors.purpleDeep),
  _ => (VetIcons.paw, VetColors.turquoise),
};

class _SpeciesCard extends StatelessWidget {
  const _SpeciesCard({
    required this.name,
    required this.summary,
    required this.badges,
    required this.onTap,
  });
  final String name, summary;
  final List<Widget> badges;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final (icon, accent) = speciesVisual(name);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: VetCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VetIconBox(icon: icon, accent: accent, size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const Icon(VetIcons.chevronRight, size: 20),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    summary,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: VetColors.muted),
                  ),
                  if (badges.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(spacing: 6, runSpacing: 6, children: badges),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

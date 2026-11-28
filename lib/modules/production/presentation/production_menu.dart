import '../../../core/widgets/accent_glow.dart';
import '../../../core/widgets/neu_identity.dart';
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
    showDialog<void>(
      context: context,
      builder: (_) =>
          ProductionCalculatorModal(calcType: type, species: currentSpecies),
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

  /// Paneles de peces: un apartado por especie, con las calculadoras dentro.
  List<Widget> _fishPanels(Widget denied) {
    final chosen = activity;
    if (chosen == null) return const [];
    final fish = FishSpecies.fromActivity(chosen);
    if (fish == null) return const [];
    return [
      const SizedBox(height: 16),
      if (allowed('Cálculos clínicos'))
        ...aquaculturePanelsFor(fish)
      else
        denied,
    ];
  }

  List<Widget> _detail(BuildContext context) {
    final currentSpecies = species!;
    final (icon, accent) = speciesVisual(currentSpecies);
    final textTheme = Theme.of(context).textTheme;
    final activities = productionSpecies[currentSpecies]!;

    const denied = VetNotice(
      text: 'Las calculadoras no están habilitadas para tu acceso actual.',
      icon: VetIcons.lock,
      kind: VetBadgeKind.warning,
    );

    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: () => setState(() {
              species = null;
              activity = null;
            }),
            icon: const Icon(VetIcons.arrowBack),
            label: const Text('Volver a especies'),
          ),
          TextButton.icon(
            onPressed: _openDashboard,
            icon: const Icon(VetIcons.dashboard, size: 16),
            label: const Text('Ver en Dashboard'),
          ),
        ],
      ),
      const SizedBox(height: 4),
      VetCard(
        child: Row(
          children: [
            VetIconBox(icon: icon, accent: accent, size: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(currentSpecies, style: textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    activities.length == 1
                        ? '1 actividad'
                        : '${activities.length} actividades',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      VetCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Actividad', style: textTheme.titleSmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final name in activities)
                  glowChip(
                    ChoiceChip(
                      label: Text(name),
                      selected: activity == name,
                      onSelected: (_) => setState(() => activity = name),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      if (activity == null)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: VetNotice(
            text: 'Elige una actividad para ver sus herramientas.',
            icon: VetIcons.tap,
          ),
        ),
      if (activity != null) ...[
        const SizedBox(height: 16),
        const VetSectionHeader(
          title: 'Calculadoras de producción',
          subtitle:
              'Cálculo por cabeza y lote, medicación en agua y medicación en alimento.',
        ),
        if (allowed('Cálculos clínicos'))
          for (final (id, label, toolIcon, description) in [
            (
              'herd',
              'Por cabeza y lote',
              VetIcons.cow,
              'Cálculo por cabeza y lote.',
            ),
            (
              'water',
              'Medicación en agua',
              VetIcons.waves,
              'Medicación en el agua de bebida.',
            ),
            (
              'feed',
              'Medicación en alimento',
              VetIcons.feedBag,
              'Medicación en el alimento.',
            ),
          ]) ...[
            VetSectionHeader(title: label, subtitle: description),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: NeuPrimaryButton(
                dense: true,
                onPressed: () => open(
                  CalculationScreen(
                    initialTool: id,
                    tools: productionCalculationTools,
                    title: 'Producción: $label',
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(toolIcon, size: 18),
                    const SizedBox(width: 8),
                    Flexible(child: Text(label)),
                  ],
                ),
              ),
            ),
          ]
        else
          const VetNotice(
            text: 'Tu acceso actual no incluye las calculadoras de producción.',
            icon: VetIcons.lock,
            kind: VetBadgeKind.warning,
          ),
      ],
      if (currentSpecies == 'Aves' && activity != null) ...[
        const SizedBox(height: 16),
        if (allowed('Cálculos clínicos') && activity == 'Postura')
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: VetActionButton(
              icon: VetIcons.barn,
              label: 'Capacidad e instalaciones avícolas',
              onPressed: () => open(const AvicultureScreen()),
            ),
          ),
        if (allowed('Cálculos clínicos') && activity == 'Postura')
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: VetActionButton(
              icon: VetIcons.egg,
              label: 'Postura: luz, huevos y calidad del huevo',
              onPressed: () => open(const LayerReferenceScreen()),
            ),
          ),
        if (allowed('Cálculos clínicos') && activity == 'Postura')
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: VetActionButton(
              icon: VetIcons.egg,
              label: 'Parvadas, casetas y producción',
              onPressed: () => open(
                AvicultureRecordsScreen(clinicId: widget.member?.clinicId),
              ),
            ),
          ),
        if (allowed('Cálculos clínicos') &&
            activity == 'Reproducción e incubación')
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: VetActionButton(
              icon: VetIcons.egg,
              label: 'Abrir herramientas de incubación',
              onPressed: () => open(const IncubationScreen()),
            ),
          ),
        if (allowed('Cálculos clínicos') && activity == 'Engorda')
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: VetActionButton(
              icon: VetIcons.bird,
              label: 'Capacidad de pollo de engorda',
              onPressed: () => open(const BroilerScreen()),
            ),
          ),
        if (allowed('Cálculos clínicos') &&
            (activity == 'Postura' || activity == 'Engorda'))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: VetActionButton(
              icon: VetIcons.chartGrowth,
              label: 'Índices productivos (engorda y postura)',
              onPressed: () => open(const PoultryIndexScreen()),
            ),
          ),
        if (!allowed('Cálculos clínicos')) denied,
        if (activity == 'Engorda')
          const VetNotice(
            text:
                'Las referencias de engorda son de clase (CUCBA; tabla Cobb) y están sin verificar. Las tablas de postura no se aplican a engorda.',
            icon: VetIcons.clipboardChecks,
          ),
        if (activity != 'Engorda')
          const VetNotice(
            text:
                'Las herramientas conservan sus referencias y avisos de datos sin verificar.',
            icon: VetIcons.clipboardChecks,
          ),
      ],
      if (currentSpecies == 'Peces') ..._fishPanels(denied),
      if (currentSpecies == 'Porcinos' && activity != null) ...[
        const SizedBox(height: 16),
        if (allowed('Cálculos clínicos') &&
            activity == 'Reproducción y gestación')
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: VetActionButton(
              icon: VetIcons.microscope,
              label: 'Evaluación seminal por especie',
              onPressed: () => open(const SemenReferenceScreen()),
            ),
          ),
        if (allowed('Cálculos clínicos'))
          ...porcinoPanelsFor(
            activity!,
            showCosts: allowed('Planeación financiera'),
            repository: widget.porcino,
            clinicId: widget.member?.clinicId,
          )
        else
          denied,
      ],
      if (currentSpecies == 'Equinos' &&
          activity == 'Reproducción y crianza') ...[
        const SizedBox(height: 16),
        if (allowed('Cálculos clínicos'))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: VetActionButton(
              icon: VetIcons.microscope,
              label: 'Evaluación seminal por especie',
              onPressed: () => open(const SemenReferenceScreen()),
            ),
          )
        else
          denied,
      ],
      const SizedBox(height: 24),

      // 2. HERRAMIENTAS DE LA ESPECIE ELEGIDA (Tarjetas)
      VetSectionHeader(
        title: 'Herramientas de $currentSpecies',
        subtitle:
            'Calculadoras zootécnicas, constantes fisiológicas, vademécum y registros de campo.',
      ),
      const SizedBox(height: 8),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        // 1.35 dejaba la celda en 118 dp y el rotulo a dos lineas no cabia.
        childAspectRatio: 1.2,
        children: [
          ProductionToolTile(
            title: 'Calculadora de Ración',
            subtitle: 'Requerimientos por etapa',
            icon: VetIcons.feedBag,
            accent: VetColors.turquoise,
            onTap: () => _openCalculator('ration', currentSpecies),
          ),
          ProductionToolTile(
            title: 'FCA / Conversión',
            subtitle: 'Factor conversión alimenticia',
            icon: VetIcons.balance,
            accent: VetColors.violet,
            onTap: () => _openCalculator('fca', currentSpecies),
          ),
          ProductionToolTile(
            title: 'Densidad Animal',
            subtitle: 'kg/m² o animales/corral',
            icon: VetIcons.grid,
            accent: VetColors.cyan,
            onTap: () => _openCalculator('density', currentSpecies),
          ),
          ProductionToolTile(
            title: 'Capacidad de Caseta/Nave',
            subtitle: 'Superficie y ventilación',
            icon: VetIcons.barn,
            accent: VetColors.warning,
            onTap: () => _openCalculator('capacity', currentSpecies),
          ),
          ProductionToolTile(
            title: 'Dosis Seminales',
            subtitle: 'Espermatozoides por dosis',
            icon: VetIcons.microscope,
            accent: VetColors.pink,
            onTap: () => _openCalculator('semen', currentSpecies),
          ),
          ProductionToolTile(
            title: 'Constantes Fisiológicas',
            subtitle: 'Rangos normales T°, FC, FR',
            icon: VetIcons.heartPulse,
            accent: VetColors.turquoise,
            onTap: () => _showVitalsDialog(currentSpecies),
          ),
          ProductionToolTile(
            title: 'Vademécum Pecuario',
            subtitle: 'Fármacos y tiempos de retiro',
            icon: VetIcons.pills,
            accent: VetColors.lilac,
            onTap: () => _openVademecum(currentSpecies),
          ),
          ProductionToolTile(
            title: 'Registros Productivos',
            subtitle: 'Pesajes, consumo y mortalidad',
            icon: VetIcons.clipboardChecks,
            accent: VetColors.turquoise,
            onTap: _openDashboard,
          ),
        ],
      ),
      const SizedBox(height: 24),

      // 3 y 4. LOTES Y ALERTAS
      //
      // Antes salian de `speciesDataCatalog`: lotes como «Vaquillas de
      // Reemplazo» y alertas de una «Vaca #402» que no eran de nadie. Los
      // datos de verdad estan en Supabase y los lee el Dashboard Pecuario,
      // que sabe esperar la consulta y distinguir «sin registros» de «sin
      // red». Aqui se enlaza alli en lugar de inventar cifras.
      const VetSectionHeader(
        title: 'Mis Lotes y Alertas',
        subtitle:
            'Animales por etapa, vacunas por vencer y resguardos de fármaco.',
      ),
      const SizedBox(height: 8),
      VetCard(
        child: VetEmptyState(
          text:
              'Tus lotes y alertas se consultan en el Dashboard Pecuario, '
              'que los lee de tus propios registros.',
          icon: VetIcons.barn,
          actionLabel: 'Abrir Dashboard Pecuario',
          onAction: _openDashboard,
        ),
      ),
      const SizedBox(height: 24),

      // 5. RECETAS Y CONTROL
      const VetSectionHeader(
        title: 'Recetas y Control',
        subtitle:
            'Acceso directo a receta médica pecuaria simple o cuantificada oficial.',
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: VetActionButton(
              icon: VetIcons.document,
              label: 'Receta Simple',
              style: VetActionStyle.neutral,
              onPressed: () => _openPrescription(
                quantified: false,
                currentSpecies: currentSpecies,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: VetActionButton(
              icon: VetIcons.documentCheck,
              label: 'Receta Cuantificada',
              style: VetActionStyle.primary,
              onPressed: () => _openPrescription(
                quantified: true,
                currentSpecies: currentSpecies,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),

      // UNIDADES DE PRODUCCIÓN PERSISTENTES
      if (widget.units case final ProductionUnitRepository almacen)
        if (widget.member case final ClinicMembership miembro)
          if (activity case final String elegida) ...[
            const VetSectionHeader(
              title: 'Unidades de producción',
              subtitle:
                  'El hato, lote, parvada o apiario del que cuelgan los demás registros. Se guarda en este dispositivo.',
            ),
            VetActionButton(
              icon: VetIcons.clipboardList,
              label: 'Abrir unidades',
              onPressed: () => open(
                ProductionUnitsScreen(
                  repository: almacen,
                  userId: miembro.userId,
                  clinicId: miembro.clinicId,
                  species: currentSpecies,
                  activity: elegida,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

      // 6. PRÓXIMAMENTE (en gris)
      const VetSectionHeader(
        title: 'Próximamente',
        subtitle:
            'Lo que aún está en desarrollo técnico y bioseguridad ambiental.',
      ),
      const SizedBox(height: 8),
      Opacity(
        opacity: 0.5,
        child: Column(
          children: const [
            VetCard(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              radius: 16,
              child: Row(
                children: [
                  Icon(VetIcons.firstAidKit, color: Colors.grey, size: 28),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Grandes Especies: Cirugía y Clínica Avanzada',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          'Protocolos quirúrgicos de campo, cesáreas y laparotomía',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  VetStatusBadge(
                    label: 'En desarrollo',
                    kind: VetBadgeKind.unverified,
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
            VetCard(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              radius: 16,
              child: Row(
                children: [
                  Icon(VetIcons.leaf, color: Colors.grey, size: 28),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manejo de Efluentes, Desechos y Bioseguridad',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          'Lagunas de oxidación, compostaje de mortalidad y biodigestores',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  VetStatusBadge(
                    label: 'En desarrollo',
                    kind: VetBadgeKind.unverified,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      if (plannedProductionAreas[species] case final planned?
          when planned.isNotEmpty) ...[
        const VetSectionHeader(
          title: 'Apartados previstos',
          subtitle:
              'Lo que todavía no tiene dónde guardarse. Los lotes, registros y eventos de arriba sí se guardan.',
        ),
        for (final name in planned)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: VetCard(
              padding: EdgeInsets.zero,
              radius: 18,
              child: ListTile(
                leading: VetIconBox(
                  icon: VetIcons.clock,
                  accent: accent,
                  size: 40,
                ),
                title: Text(name),
                trailing: const VetStatusBadge(
                  label: 'En preparación',
                  kind: VetBadgeKind.unverified,
                ),
              ),
            ),
          ),
      ],
      const SizedBox(height: 16),
      const VetSectionHeader(
        title: 'Herramientas del espacio',
        subtitle:
            'Abren los registros actuales de tu espacio; todavía no aplican un filtro por la especie seleccionada.',
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, page, toolIcon) in [
            ('Pacientes individuales', 'Pacientes', VetIcons.paw),
            ('Agenda del espacio', 'Agenda', VetIcons.calendar),
            ('Inventario del espacio', 'Inventario', VetIcons.box),
          ])
            if (allowed(page))
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: VetModuleTile(
                    title: label,
                    icon: toolIcon,
                    accent: VetColors.violet,
                    onTap: () => widget.onNavigate(page),
                  ),
                ),
              ),
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

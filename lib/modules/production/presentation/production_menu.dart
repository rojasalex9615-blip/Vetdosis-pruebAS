import '../../../core/widgets/accent_glow.dart';
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
    this.units,
    this.initialSpecies,
    this.initialViewDashboard = false,
  });
  final ValueChanged<String> onNavigate;
  final ClinicMembership? member;
  final ModuleAccess? access;
  final PorcinoRepository? porcino;

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
  late int _viewMode; // 0: Catálogo y Especies, 1: Dashboard Pecuario

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
      builder: (_) => ProductionCalculatorModal(
        calcType: type,
        species: currentSpecies,
      ),
    );
  }

  void _openVademecum(String currentSpecies) {
    showDialog<void>(
      context: context,
      builder: (_) => ProductionVademecumModal(species: currentSpecies),
    );
  }

  void _openPrescription({required bool quantified, required String currentSpecies}) {
    showDialog<void>(
      context: context,
      builder: (_) => PecuariaPrescriptionModal(
        quantified: quantified,
        species: currentSpecies,
        clinicName: widget.member?.clinicName ?? 'Granja / Clínica Pecuaria',
        mvzName: widget.member?.userId ?? 'MVZ Responsable',
      ),
    );
  }

  void _showVitalsDialog(String currentSpecies) {
    final metrics = speciesDataCatalog[currentSpecies] ?? speciesDataCatalog['Bovinos']!;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(VetIcons.heartPulse, color: VetColors.turquoise),
            const SizedBox(width: 8),
            Text('Constantes: $currentSpecies'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final v in metrics.vitals) ...[
              ListTile(
                dense: true,
                title: Text(v.parameter, style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: Text(
                  '${v.range} ${v.unit}',
                  style: const TextStyle(color: VetColors.turquoise, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  void _showQuickRecordDialog() {
    final pesoCtrl = TextEditingController();
    final mortCtrl = TextEditingController();
    final consCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo Registro Productivo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pesoCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Pesaje promedio del lote (kg o g)'),
            ),
            TextField(
              controller: mortCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Mortalidad del día (cabezas)'),
            ),
            TextField(
              controller: consCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Consumo de alimento diario (kg)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Registro productivo guardado con éxito.'),
                  backgroundColor: VetColors.success,
                ),
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (species == null) ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
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
            ],
            selected: {_viewMode},
            onSelectionChanged: (val) => setState(() => _viewMode = val.first),
          ),
        ),
        if (_viewMode == 1)
          ProductionDashboard(
            onNavigate: widget.onNavigate,
            member: widget.member,
            access: widget.access,
            units: widget.units,
            initialSpecies: 'Bovinos',
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
                      style: TextStyle(
                        fontSize: 12,
                        color: VetColors.muted,
                      ),
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

  List<Widget> _speciesBadges(String name) => switch (name) {
    'Peces' => const [
      VetStatusBadge(
        label: 'Calculadora de biomasa y ración',
        kind: VetBadgeKind.success,
      ),
      VetStatusBadge(
        label: 'Registros en preparación',
        kind: VetBadgeKind.unverified,
      ),
    ],
    'Porcinos' => const [
      VetStatusBadge(
        label: 'Calculadora de crecimiento y engorda',
        kind: VetBadgeKind.success,
      ),
      VetStatusBadge(
        label: 'Registros en preparación',
        kind: VetBadgeKind.unverified,
      ),
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
    _ => const [
      VetStatusBadge(label: 'Organización de actividades'),
      VetStatusBadge(
        label: 'Registros en preparación',
        kind: VetBadgeKind.unverified,
      ),
    ],
  };

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
    final metrics = speciesDataCatalog[currentSpecies] ?? speciesDataCatalog['Bovinos']!;

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
            onPressed: () => setState(() {
              _viewMode = 1;
              species = null;
            }),
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
          for (final (id, label, toolIcon) in [
            ('herd', 'Por cabeza y lote', VetIcons.cow),
            ('water', 'Medicación en agua', VetIcons.waves),
            ('feed', 'Medicación en alimento', VetIcons.feedBag),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: VetActionButton(
                icon: toolIcon,
                label: label,
                onPressed: () => open(
                  CalculationScreen(
                    initialTool: id,
                    tools: productionCalculationTools,
                    title: 'Producción: $label',
                  ),
                ),
              ),
            )
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
      if (currentSpecies == 'Equinos' && activity == 'Reproducción y crianza') ...[
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
        childAspectRatio: 1.35,
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
            onTap: () => _showQuickRecordDialog(),
          ),
        ],
      ),
      const SizedBox(height: 24),

      // 3. MIS LOTES / HATOS (Resumen)
      const VetSectionHeader(
        title: 'Mis Lotes / Hatos',
        subtitle:
            'Número de animales, etapa productiva, días en etapa y último registro.',
      ),
      const SizedBox(height: 8),
      for (final b in metrics.batches)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: VetCard(
            padding: const EdgeInsets.all(12),
            radius: 16,
            child: Row(
              children: [
                VetIconBox(
                  icon: icon,
                  accent: accent,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        '${b.headcount} animales · Etapa: ${b.stage} (${b.daysInStage} días)',
                        style: const TextStyle(fontSize: 12, color: VetColors.muted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Último: ${b.lastRecordDate} (${b.lastRecordDetail})',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 24),

      // 4. ALERTAS
      const VetSectionHeader(
        title: 'Alertas',
        subtitle:
            'Vacunas por vencer, resguardos de fármaco activos y partos o servicios próximos.',
      ),
      const SizedBox(height: 8),
      for (final a in metrics.alerts)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: VetCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            radius: 16,
            child: Row(
              children: [
                Icon(
                  a.type == 'withdrawal'
                      ? VetIcons.alertOctagon
                      : (a.type == 'birth' ? VetIcons.heart : VetIcons.bell),
                  color: a.type == 'withdrawal' ? VetColors.danger : VetColors.warning,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(a.subtitle, style: const TextStyle(fontSize: 12, color: VetColors.muted)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (a.daysLeft <= 2 ? VetColors.danger : VetColors.warning).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    a.daysLeft == 0 ? 'Hoy' : 'En ${a.daysLeft} d',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: a.daysLeft <= 2 ? VetColors.danger : VetColors.warning,
                    ),
                  ),
                ),
              ],
            ),
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
              onPressed: () => _openPrescription(quantified: false, currentSpecies: currentSpecies),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: VetActionButton(
              icon: VetIcons.documentCheck,
              label: 'Receta Cuantificada',
              style: VetActionStyle.primary,
              onPressed: () => _openPrescription(quantified: true, currentSpecies: currentSpecies),
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
        subtitle: 'Lo que aún está en desarrollo técnico y bioseguridad ambiental.',
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
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        Text(
                          'Protocolos quirúrgicos de campo, cesáreas y laparotomía',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  VetStatusBadge(label: 'En desarrollo', kind: VetBadgeKind.unverified),
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
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        Text(
                          'Lagunas de oxidación, compostaje de mortalidad y biodigestores',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  VetStatusBadge(label: 'En desarrollo', kind: VetBadgeKind.unverified),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),

      const VetSectionHeader(
        title: 'Apartados previstos',
        subtitle:
            'Estos registros específicos están en preparación; las unidades de arriba sí se guardan.',
      ),
      for (final name in plannedProductionAreas[currentSpecies]!)
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: VetColors.muted,
                    ),
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

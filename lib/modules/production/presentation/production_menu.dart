import '../../../core/widgets/accent_glow.dart';
import 'package:flutter/material.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_theme.dart';
import 'porcino_panels.dart';
import 'feeding_panel.dart';
import '../../aviculture/presentation/aviculture_screen.dart';
import '../../incubation/presentation/incubation_screen.dart';
import '../../auth/domain/clinic_membership.dart';
import '../../core/domain/module_access.dart';
import '../../core/domain/navigation_access.dart';
import '../../../vet_ui/vet_icons.dart';

const productionSpecies = <String, List<String>>{
  'Bovinos': [
    'Leche',
    'Carne y engorda',
    'Doble propósito',
    'Atención individual',
  ],
  'Ovinos / caprinos': ['Ovinos', 'Caprinos'],
  'Aves': ['Postura', 'Engorda', 'Reproducción e incubación'],
  'Peces': ['Tilapia'],
  'Abejas': ['Apiarios y colmenas'],
  'Porcinos': [
    'Reproducción y gestación',
    'Maternidad y destete',
    'Crecimiento y engorda',
    'Bioseguridad y ambiente',
    'Planeación financiera',
  ],
  'Equinos': ['Atención individual', 'Reproducción y crianza'],
};

const plannedProductionAreas = <String, List<String>>{
  'Bovinos': [
    'Animales y hatos/lotes',
    'Reproducción y alimentación',
    'Indicadores por unidad',
  ],
  'Ovinos / caprinos': [
    'Animales y rebaños',
    'Carne, leche y fibra según actividad',
    'Reproducción y alimentación',
  ],
  'Aves': [
    'Parvadas, casetas y ciclos',
    'Registros productivos',
    'Alimentación y seguimiento',
  ],
  'Peces': [
    'Lotes y unidades de cultivo',
    'Calidad del agua y alimentación',
    'Biomasa y ciclos',
  ],
  'Abejas': [
    'Apiarios y colmenas',
    'Revisiones y sanidad',
    'Cosechas y seguimiento',
  ],
  'Porcinos': [
    'Reproductores y servicios',
    'Camadas y alimentación',
    'Engorda e indicadores',
  ],
  'Equinos': ['Atención y seguimiento individual', 'Reproducción y crianza'],
};

/// Catalog and existing local tools only. No farm records or operating limits
/// are created by selecting a species/activity.
class ProductionMenu extends StatefulWidget {
  const ProductionMenu({
    super.key,
    required this.onNavigate,
    this.member,
    this.access,
  });
  final ValueChanged<String> onNavigate;
  final ClinicMembership? member;
  final ModuleAccess? access;
  @override
  State<ProductionMenu> createState() => _ProductionMenuState();
}

class _ProductionMenuState extends State<ProductionMenu> {
  String? species, activity;
  bool allowed(String page) =>
      navigationAllowed(page, widget.member, widget.access);
  Future<void> open(Widget screen) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (species == null) ..._speciesList(context) else ..._detail(context),
    ],
  );

  List<Widget> _speciesList(BuildContext context) => [
    const VetSectionHeader(
      title: 'Producción y grandes especies',
      subtitle:
          'Elige una especie o grupo. La clínica y tus permisos se conservan.',
      large: true,
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
    ],
    _ => const [
      VetStatusBadge(label: 'Organización de actividades'),
      VetStatusBadge(
        label: 'Registros en preparación',
        kind: VetBadgeKind.unverified,
      ),
    ],
  };

  List<Widget> _detail(BuildContext context) {
    final (icon, accent) = speciesVisual(species!);
    final textTheme = Theme.of(context).textTheme;
    final activities = productionSpecies[species]!;
    const denied = VetNotice(
      text: 'Las calculadoras no están habilitadas para tu acceso actual.',
      icon: VetIcons.lock,
      kind: VetBadgeKind.warning,
    );
    return [
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() {
            species = null;
            activity = null;
          }),
          icon: const Icon(VetIcons.arrowBack),
          label: const Text('Volver a especies'),
        ),
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
                  Text(species!, style: textTheme.titleLarge),
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
                  glowChip(ChoiceChip(
                    label: Text(name),
                    selected: activity == name,
                    onSelected: (_) => setState(() => activity = name),
                  )),
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
      if (species == 'Aves' && activity != null) ...[
        const SizedBox(height: 16),
        if (allowed('Cálculos clínicos') && activity == 'Postura')
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: VetActionButton(
              icon: VetIcons.stable,
              label: 'Capacidad e instalaciones avícolas',
              onPressed: () => open(const AvicultureScreen()),
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
        if (!allowed('Cálculos clínicos')) denied,
        if (activity == 'Engorda')
          const VetNotice(
            text:
                'Las herramientas específicas de engorda están en preparación. Las tablas actuales de postura no se aplican automáticamente a engorda.',
            icon: VetIcons.clock,
            kind: VetBadgeKind.warning,
          ),
        if (activity != 'Engorda')
          const VetNotice(
            text:
                'Las herramientas conservan sus referencias y avisos de datos sin verificar.',
            icon: VetIcons.clipboardChecks,
          ),
      ],
      if (species == 'Peces' && activity == 'Tilapia') ...[
        const SizedBox(height: 16),
        if (allowed('Cálculos clínicos')) const FeedingPanel() else denied,
      ],
      if (species == 'Porcinos' && activity != null) ...[
        const SizedBox(height: 16),
        if (allowed('Cálculos clínicos'))
          ...porcinoPanelsFor(
            activity!,
            showCosts: allowed('Planeación financiera'),
          )
        else
          denied,
      ],
      const SizedBox(height: 24),
      const VetSectionHeader(
        title: 'Apartados previstos',
        subtitle:
            'Estos registros específicos están en preparación; aún no permiten guardar datos de unidades o lotes.',
      ),
      for (final name in plannedProductionAreas[species]!)
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
    final textTheme = Theme.of(context).textTheme;
    return VetCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VetIconBox(icon: icon, accent: accent, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(summary, style: textTheme.bodySmall),
                    const SizedBox(height: 10),
                    Wrap(spacing: 6, runSpacing: 6, children: badges),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 14),
                child: Icon(VetIcons.chevronRight, color: VetColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

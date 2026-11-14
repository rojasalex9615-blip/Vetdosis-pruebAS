import 'package:flutter/material.dart';
import '../../../core/widgets/workspace_panel.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_theme.dart';
import '../../auth/domain/clinic_membership.dart';
import '../domain/module_access.dart';
import '../../clinic_experience/domain/clinic_experience.dart';
import '../domain/navigation_access.dart';
import '../domain/section_catalog.dart';
import '../../../vet_ui/vet_icons.dart';

class SectionMenu extends StatefulWidget {
  const SectionMenu({
    super.key,
    required this.onNavigate,
    this.member,
    this.access,
    this.experience,
    this.onAccount,
    this.initialGroup,
  });
  final ValueChanged<String> onNavigate;
  final ClinicMembership? member;
  final ModuleAccess? access;
  final ClinicExperience? experience;
  final VoidCallback? onAccount;
  final String? initialGroup;
  @override
  State<SectionMenu> createState() => _SectionMenuState();
}

class _SectionMenuState extends State<SectionMenu> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final filtered = <SectionGroup>[];
    for (final group in sectionGroups) {
      final authorized = group.pages
          .where(
            (page) =>
                (page != 'Mi cuenta y clínicas' || widget.onAccount != null) &&
                navigationAllowed(page, widget.member, widget.access) &&
                (widget.experience?.visible(page) ?? true),
          )
          .toList();
      if (authorized.isEmpty) continue;
      bool matches(String page) =>
          normalizeSection(page).contains(query) ||
          normalizeSection(group.title).contains(query);
      final pages = authorized.where(matches).toList();
      final planned = group.planned.where(matches).toList();
      if (pages.isNotEmpty || planned.isNotEmpty) {
        filtered.add(SectionGroup(group.title, pages, planned: planned));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const VetSectionHeader(
          title: 'Secciones',
          subtitle: 'Herramientas y gestión de tu espacio.',
          large: true,
        ),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Buscar secciones',
            prefixIcon: Icon(VetIcons.search),
          ),
          onChanged: (value) => setState(() => query = normalizeSection(value)),
        ),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          const VetNotice(
            text: 'No hay secciones disponibles para esa búsqueda.',
            icon: VetIcons.searchOff,
          ),
        for (final (index, group) in filtered.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: VetCard(
              padding: EdgeInsets.zero,
              child: Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: ValueKey((group.title, query, widget.initialGroup)),
                  leading: VetIconBox(
                    icon: group.pages.isNotEmpty
                        ? sectionIcon(group.pages.first)
                        : VetIcons.clock,
                    accent: _groupAccents[index % _groupAccents.length],
                  ),
                  title: Text(
                    group.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: Text(
                    '${group.pages.length + group.planned.length} secciones',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  initiallyExpanded:
                      query.isNotEmpty || widget.initialGroup == group.title,
                  childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  children: [
                    for (final page in group.planned)
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        leading: const Icon(VetIcons.clock),
                        title: Text(page),
                        trailing: const VetStatusBadge(
                          label: 'En preparación',
                          kind: VetBadgeKind.unverified,
                        ),
                        enabled: false,
                      ),
                    for (final page in group.pages)
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        leading: Icon(
                          sectionIcon(page),
                          color: _groupAccents[index % _groupAccents.length],
                        ),
                        title: Text(page),
                        trailing: const Icon(
                          VetIcons.chevronRight,
                          color: VetColors.muted,
                        ),
                        onTap: page == 'Mi cuenta y clínicas'
                            ? widget.onAccount
                            : () => widget.onNavigate(page),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

const _groupAccents = [
  VetColors.turquoise,
  VetColors.violet,
  VetColors.pink,
  VetColors.purple,
  VetColors.cyan,
  VetColors.lilac,
];

class CalculationMenu extends StatelessWidget {
  const CalculationMenu({
    super.key,
    required this.onNavigate,
    this.member,
    this.access,
    this.experience,
  });
  final ValueChanged<String> onNavigate;
  final ClinicMembership? member;
  final ModuleAccess? access;
  final ClinicExperience? experience;
  @override
  Widget build(BuildContext context) {
    final canDose = navigationAllowed('Cálculo rápido', member, access) &&
        (experience?.visible('Cálculo rápido') ?? true);
    final canClinical = navigationAllowed('Cálculos clínicos', member, access) &&
        (experience?.visible('Cálculos clínicos') ?? true);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const VetSectionHeader(
          title: 'Calculadoras',
          subtitle: 'Elige la operación que necesitas.',
          large: true,
        ),
        if (experience?.visible('Vademécum') ?? true)
          _CalculationChoice(
            icon: VetIcons.book,
            title: 'Vademécum',
            description:
                'Consulta fichas de la app, compartidas con la clínica y personales.',
            onTap: () => onNavigate('Vademécum'),
          ),
        if (canDose)
          _CalculationChoice(
            icon: VetIcons.capsule,
            title: 'Calcular dosis de un producto',
            description:
                'Usa un catálogo con fuente y concentración por presentación; requiere revisión y confirmación.',
            onTap: () => onNavigate('Cálculo rápido'),
          ),
        if (navigationAllowed('Operaciones de dosis', member, access) &&
            (experience?.visible('Operaciones de dosis') ?? true))
          _CalculationChoice(
            icon: VetIcons.calculator,
            title: 'Otras operaciones de dosis',
            description:
                'Regla de tres, concentración tras reconstitución, UI y conversión métrica con parámetros explícitos.',
            onTap: () => onNavigate('Operaciones de dosis'),
          ),
        if (canClinical)
          _CalculationChoice(
            icon: VetIcons.heartPulse,
            title: 'Cálculos clínicos',
            description:
                'Fluidos, constantes, protocolos, peso metabólico, retiros y otras herramientas disponibles.',
            onTap: () => onNavigate('Cálculos clínicos'),
          ),
      ],
    );
  }
}

class _CalculationChoice extends StatelessWidget {
  const _CalculationChoice({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });
  final IconData icon;
  final String title, description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: VetCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VetIconBox(icon: icon, accent: VetColors.violet, size: 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(description, style: textTheme.bodySmall),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Icon(VetIcons.chevronRight, color: VetColors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

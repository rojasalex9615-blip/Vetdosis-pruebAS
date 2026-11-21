import 'package:flutter/material.dart';
import '../../../core/widgets/workspace_panel.dart';
import '../../../vet_ui/vet_components.dart';
import '../../auth/domain/clinic_membership.dart';
import '../domain/module_access.dart';
import '../domain/navigation_access.dart';
import '../domain/section_catalog.dart';

class SectionMenu extends StatefulWidget {
  const SectionMenu({
    super.key,
    required this.onNavigate,
    this.member,
    this.access,
    this.onAccount,
    this.initialGroup,
  });
  final ValueChanged<String> onNavigate;
  final ClinicMembership? member;
  final ModuleAccess? access;
  final VoidCallback? onAccount;
  final String? initialGroup;
  @override
  State<SectionMenu> createState() => _SectionMenuState();
}

class _SectionMenuState extends State<SectionMenu> {
  final search = TextEditingController();
  String query = '';

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = <SectionGroup>[];
    for (final group in sectionGroups) {
      final authorized = group.pages
          .where(
            (page) =>
                (page != 'Mi cuenta y clínicas' || widget.onAccount != null) &&
                navigationAllowed(page, widget.member, widget.access),
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
        Text('Secciones', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 2),
        Text(
          'Herramientas y gestión de tu espacio.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: search,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: 'Buscar secciones',
            hintText: 'Agenda, pacientes, caja…',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpiar búsqueda',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      search.clear();
                      setState(() => query = '');
                    },
                  ),
          ),
          onChanged: (value) => setState(() => query = normalizeSection(value)),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          VetCard(
            radius: 16,
            child: Row(
              children: [
                Icon(Icons.search_off, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'No hay secciones disponibles para esa búsqueda.',
                  ),
                ),
              ],
            ),
          ),
        for (final group in filtered)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Material(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                key: ValueKey((group.title, query, widget.initialGroup)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                collapsedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                title: Text(
                  group.title,
                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 15),
                ),
                initiallyExpanded:
                    query.isNotEmpty || widget.initialGroup == group.title,
                children: [
                  for (final page in group.planned)
                    ListTile(
                      leading: const Icon(Icons.schedule),
                      title: Text(page),
                      subtitle: const Text('En preparación'),
                      trailing: const VetStatusBadge(
                        label: 'Próximamente',
                        kind: VetBadgeKind.unverified,
                      ),
                      enabled: false,
                    ),
                  for (final page in group.pages)
                    ListTile(
                      leading: Icon(
                        sectionIcon(page),
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(page),
                      trailing: Icon(
                        page == 'Mi cuenta y clínicas'
                            ? Icons.manage_accounts_outlined
                            : Icons.chevron_right,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      onTap: page == 'Mi cuenta y clínicas'
                          ? widget.onAccount
                          : () => widget.onNavigate(page),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class CalculationMenu extends StatelessWidget {
  const CalculationMenu({
    super.key,
    required this.onNavigate,
    this.member,
    this.access,
  });
  final ValueChanged<String> onNavigate;
  final ClinicMembership? member;
  final ModuleAccess? access;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canDose = navigationAllowed('Cálculo rápido', member, access);
    final canClinical = navigationAllowed('Cálculos clínicos', member, access);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Calculadoras', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 2),
        Text(
          'Elige la operación que necesitas.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (canDose)
          _CalculationChoice(
            icon: Icons.medication_outlined,
            title: 'Calcular dosis de un producto',
            description:
                'Usa un catálogo con fuente y concentración por presentación; requiere revisión y confirmación.',
            onTap: () => onNavigate('Cálculo rápido'),
          ),
        if (canDose)
          _CalculationChoice(
            icon: Icons.calculate_outlined,
            title: 'Otras operaciones de dosis',
            description:
                'Regla de tres, concentración tras reconstitución, UI y conversión métrica con parámetros explícitos.',
            onTap: () => onNavigate('Operaciones de dosis'),
          ),
        if (canClinical)
          _CalculationChoice(
            icon: Icons.monitor_heart_outlined,
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
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: VetCard(
        radius: 18,
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 15,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

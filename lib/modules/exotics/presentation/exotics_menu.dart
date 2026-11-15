import 'package:flutter/material.dart';

import '../../../core/widgets/accent_glow.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_icons.dart';
import '../../../vet_ui/vet_theme.dart';
import '../domain/exotic_reference.dart';

/// Áreas de exóticos que aún no tienen datos; solo se nombran.
const plannedExoticAreas = <String>[
  'Aves exóticas',
  'Reptiles',
  'Anfibios',
  'Peces ornamentales',
];

/// Consulta de valores de referencia de mamíferos pequeños no convencionales.
///
/// Solo lectura: no guarda registros, no calcula dosis y no se liga a un
/// paciente. Cada grupo de datos muestra su fuente y su estado de revisión, y
/// los valores que la fuente marca para corroborar llevan aviso propio.
class ExoticsMenu extends StatefulWidget {
  const ExoticsMenu({super.key, this.allowed = true});

  /// Resultado del permiso de la pantalla; quien monta el menú lo calcula.
  final bool allowed;

  @override
  State<ExoticsMenu> createState() => _ExoticsMenuState();
}

class _ExoticsMenuState extends State<ExoticsMenu> {
  String? species;
  ExoticGroup? group;

  @override
  Widget build(BuildContext context) {
    if (!widget.allowed) {
      return const VetNotice(
        text:
            'Las referencias de exóticos no están habilitadas para tu acceso actual.',
        icon: VetIcons.lock,
        kind: VetBadgeKind.warning,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: species == null ? _speciesList(context) : _detail(context),
    );
  }

  List<Widget> _speciesList(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return [
      const VetSectionHeader(
        title: 'Exóticos',
        subtitle:
            'Mamíferos pequeños de compañía. Son valores de referencia de una obra; ninguno está validado clínicamente todavía.',
        large: true,
      ),
      for (final name in exoticSpecies)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: VetCard(
            padding: EdgeInsets.zero,
            child: InkWell(
              onTap: () => setState(() {
                species = name;
                group = exoticGroupsFor(name).first;
              }),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const VetIconBox(
                      icon: VetIcons.paw,
                      accent: VetColors.turquoise,
                      size: 52,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(
                            exoticGroupsFor(
                              name,
                            ).map((g) => g.label).join(' · '),
                            style: textTheme.bodySmall,
                          ),
                          const SizedBox(height: 10),
                          const VetStatusBadge(
                            label: 'Referencia sin validar',
                            kind: VetBadgeKind.unverified,
                          ),
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
          ),
        ),
      const SizedBox(height: 12),
      const VetSectionHeader(
        title: 'Previstos',
        subtitle: 'Todavía sin datos ni herramientas.',
      ),
      for (final name in plannedExoticAreas)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: VetCard(
            padding: EdgeInsets.zero,
            radius: 18,
            child: ListTile(
              leading: const VetIconBox(
                icon: VetIcons.clock,
                accent: VetColors.violet,
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
    ];
  }

  List<Widget> _detail(BuildContext context) {
    final name = species!;
    final groups = exoticGroupsFor(name);
    final current = group ?? groups.first;
    final rows = exoticRowsFor(name, current);
    final source = exoticSources[current]!;
    final taxonNote = exoticTaxonNotes[name];
    final textTheme = Theme.of(context).textTheme;
    return [
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() {
            species = null;
            group = null;
          }),
          icon: const Icon(VetIcons.arrowBack),
          label: const Text('Volver a especies'),
        ),
      ),
      const SizedBox(height: 4),
      VetCard(
        child: Row(
          children: [
            const VetIconBox(
              icon: VetIcons.paw,
              accent: VetColors.turquoise,
              size: 56,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    exoticTaxon[name] ?? 'Especie no precisada en la fuente',
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
            Text('Sección', style: textTheme.titleSmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in groups)
                  glowChip(
                    ChoiceChip(
                      label: Text(g.label),
                      selected: g == current,
                      onSelected: (_) => setState(() => group = g),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      VetNotice(
        text:
            'Fuente: ${source.work}, p. ${source.page}, tabla ${source.table}. ${source.status}.',
        icon: VetIcons.clipboardChecks,
        kind: VetBadgeKind.unverified,
      ),
      if (taxonNote != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: VetNotice(
            text: taxonNote,
            icon: VetIcons.clock,
            kind: VetBadgeKind.warning,
          ),
        ),
      if (rows.any((r) => r.flagged))
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: VetNotice(
            text:
                'La transcripción marca algunos valores como altos: corrobóralos con laboratorio o fuente primaria antes de usarlos.',
            icon: VetIcons.clock,
            kind: VetBadgeKind.warning,
          ),
        ),
      const SizedBox(height: 16),
      VetCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: 24),
              _ReferenceRow(row: rows[i]),
            ],
          ],
        ),
      ),
      // Deja libre el botón flotante del escáner.
      const SizedBox(height: 96),
    ];
  }
}

class _ReferenceRow extends StatelessWidget {
  const _ReferenceRow({required this.row});
  final ExoticReferenceRow row;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          row.title,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(row.range, style: textTheme.bodyLarge),
        if (row.note != null) ...[
          const SizedBox(height: 2),
          Text(row.note!, style: textTheme.bodySmall),
        ],
        if (row.flagged)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: VetStatusBadge(
              label: 'Corroborar valor y unidad',
              kind: VetBadgeKind.warning,
            ),
          ),
      ],
    );
  }
}

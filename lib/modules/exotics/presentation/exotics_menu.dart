import 'package:flutter/material.dart';

import '../../../core/widgets/accent_glow.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_icons.dart';
import '../../../vet_ui/vet_theme.dart';
import '../../calculations/presentation/calculation_screen.dart';
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
/// paciente. Cada valor cita su obra, página y tabla. Cuando dos obras dan
/// rangos distintos se muestran ambos, uno bajo otro: son criterios de
/// profesionales distintos y no se elige entre ellos.
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
            'Mamíferos pequeños de compañía. Valores publicados en libros de texto: cada uno cita su obra y, si dos obras difieren, se muestran ambas.',
        large: true,
      ),
      const VetSectionHeader(
        title: 'Calculadora rápida',
        subtitle: 'Peso metabólico: convierte el peso a la escala para comparar especies. No es una dosis.',
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: VetModuleTile(
                title: 'Peso metabólico',
                icon: VetIcons.scale,
                accent: VetColors.violet,
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CalculationScreen(
                      initialTool: 'metabolic',
                      tools: exoticCalculationTools,
                      title: 'Peso metabólico en exóticos',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      const VetSectionHeader(
        title: 'Especies',
        subtitle: 'Elige una especie para ver sus valores de referencia.',
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
                          VetStatusBadge(
                            label: exoticWorksFor(name) == 1
                                ? '1 obra citada'
                                : '${exoticWorksFor(name)} obras citadas',
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const VetIconBox(
                    icon: VetIcons.clock,
                    accent: VetColors.violet,
                    size: 40,
                  ),
                  const SizedBox(width: 14),
                  // La etiqueta va debajo del nombre, no como `trailing`: a
                  // 200% de texto un `ListTile` deja al `trailing` todo el
                  // ancho de la fila y revienta el layout.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name),
                        const SizedBox(height: 6),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: VetStatusBadge(
                            label: 'En preparación',
                            kind: VetBadgeKind.unverified,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
    final taxonNote = exoticTaxonNotes[name];
    final textTheme = Theme.of(context).textTheme;

    // Un bloque por parámetro; dentro, una línea por obra que lo da.
    final blocks = <String, List<ExoticReferenceRow>>{};
    for (final r in rows) {
      blocks.putIfAbsent(r.title, () => []).add(r);
    }
    final blockList = blocks.entries.toList();

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
                    exoticWorksFor(name) == 1
                        ? '1 obra citada'
                        : '${exoticWorksFor(name)} obras citadas',
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
      const VetNotice(
        text:
            'Cada valor cita su obra, página y tabla. Cuando dos obras difieren se muestran ambas; no se elige una.',
        icon: VetIcons.clipboardChecks,
      ),
      if (taxonNote != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: VetNotice(text: taxonNote, icon: VetIcons.clipboardChecks),
        ),
      if (rows.any((r) => r.flagged))
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: VetNotice(
            text:
                'La transcripción marca algunos valores como altos: corrobora valor y unidad contra la página de la obra.',
            icon: VetIcons.clock,
            kind: VetBadgeKind.warning,
          ),
        ),
      const SizedBox(height: 16),
      VetCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < blockList.length; i++) ...[
              if (i > 0) const Divider(height: 24),
              _ReferenceBlock(
                title: blockList[i].key,
                entries: blockList[i].value,
              ),
            ],
          ],
        ),
      ),
      // Deja libre el botón flotante del escáner.
      const SizedBox(height: 96),
    ];
  }
}

class _ReferenceBlock extends StatelessWidget {
  const _ReferenceBlock({required this.title, required this.entries});
  final String title;
  final List<ExoticReferenceRow> entries;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.range, style: textTheme.bodyLarge),
                const SizedBox(height: 2),
                Text(e.caption, style: textTheme.bodySmall),
                if (e.note != null) ...[
                  const SizedBox(height: 2),
                  Text(e.note!, style: textTheme.bodySmall),
                ],
                if (e.flagged)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: VetStatusBadge(
                      label: 'Corroborar valor y unidad',
                      kind: VetBadgeKind.warning,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

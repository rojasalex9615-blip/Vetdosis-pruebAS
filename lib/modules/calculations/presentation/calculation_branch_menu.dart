import 'package:flutter/material.dart';
import '../../../core/widgets/calculator_surface.dart';
import '../../../vet_ui/vet_icons.dart';
import '../../core/presentation/core_view_model.dart';
import '../../dashboard/presentation/home_pilot.dart';
import '../domain/calculation_branch.dart';

/// Pantalla de entrada de Calculos clinicos: primero la rama de trabajo, en
/// el mismo selector del Inicio, y debajo las calculadoras de esa rama.
///
/// Cada tarjeta abre su calculadora. Las que son una pantalla propia se
/// empujan encima; las que son una formula vuelven a esta lista con la
/// herramienta ya elegida, para poder cambiar de una a otra sin buscar en un
/// desplegable plano.
class CalculationBranchMenu extends StatelessWidget {
  const CalculationBranchMenu({
    super.key,
    required this.branch,
    required this.onBranchChanged,
    required this.onOpen,
    this.showAviculture = false,
  });
  final ClinicalBranch branch;
  final ValueChanged<ClinicalBranch> onBranchChanged;
  final ValueChanged<CalculationEntry> onOpen;

  /// Las de aves solo se ofrecen con acceso a produccion.
  final bool showAviculture;

  List<CalculationEntry> get entries => [
    for (final entry in calculationBranches[branch] ?? const <CalculationEntry>[])
      if (showAviculture || !_needsAviculture(entry.id)) entry,
  ];

  static bool _needsAviculture(String id) =>
      const {'aviculture', 'incubation', 'broiler', 'poultryIndex'}.contains(id);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      HomePracticeSelector(selected: branch, onChanged: onBranchChanged),
      const SizedBox(height: 24),
      Text(
        'Calculadoras de ${calculationBranchLabel(branch).toLowerCase()}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 4),
      Text(
        'Elige la calculadora. Los resultados no se guardan en el expediente.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 16),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 560 ? 1 : 2;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final entry in entries)
                SizedBox(
                  width: (constraints.maxWidth - 12 * (columns - 1)) / columns,
                  child: _CalculationCard(
                    entry: entry,
                    onTap: () => onOpen(entry),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}

class _CalculationCard extends StatelessWidget {
  const _CalculationCard({required this.entry, required this.onTap});
  final CalculationEntry entry;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final identity = calculatorIdentity(entry.id);
    return HomeSurface(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CalculatorIcon(entry.id),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                VetIcons.chevronRight,
                color: identity.color,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

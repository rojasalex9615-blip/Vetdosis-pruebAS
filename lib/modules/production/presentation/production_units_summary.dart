import 'package:flutter/material.dart';

import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_format.dart';
import '../../../vet_ui/vet_icons.dart';
import '../domain/production_unit.dart';
import '../domain/production_unit_repository.dart';

/// Resumen de las unidades de producción del espacio, para el panel de
/// Producción.
///
/// Solo muestra lo que el profesional guardó: cuántas unidades hay, cuántos
/// animales declaró y las más recientes. No calcula metas, etapas ni alertas.
class ProductionUnitsSummary extends StatefulWidget {
  const ProductionUnitsSummary({
    super.key,
    required this.repository,
    required this.userId,
    required this.clinicId,
    required this.visualFor,
    required this.onOpen,
  });

  final ProductionUnitRepository repository;
  final String userId, clinicId;

  /// Ícono y acento de cada especie; lo aporta quien monta el panel.
  final (IconData, Color) Function(String species) visualFor;

  /// Abre la unidad. Al volver, el resumen se vuelve a leer.
  final Future<void> Function(ProductionUnit unit) onOpen;

  @override
  State<ProductionUnitsSummary> createState() => _ProductionUnitsSummaryState();
}

class _ProductionUnitsSummaryState extends State<ProductionUnitsSummary> {
  List<ProductionUnit>? units;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final found = await widget.repository.list(
        widget.userId,
        widget.clinicId,
      );
      if (!mounted) return;
      setState(() {
        units = found;
        failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        units = null;
        failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final list = units;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const VetSectionHeader(
          title: 'Mis unidades',
          subtitle:
              'Hatos, lotes, parvadas y apiarios que guardaste en este dispositivo.',
        ),
        if (failed)
          const VetNotice(
            text: 'No se pudieron leer tus unidades en este momento.',
            icon: VetIcons.clock,
          )
        else if (list == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          )
        else if (list.isEmpty)
          const VetNotice(
            text:
                'Aún no guardas unidades. Se crean dentro de cada especie, en «Unidades de producción».',
            icon: VetIcons.clipboardList,
          )
        else ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              _totals(list),
              style: textTheme.bodySmall,
            ),
          ),
          for (final unit in list.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _card(context, unit),
            ),
        ],
      ],
    );
  }

  String _totals(List<ProductionUnit> list) {
    final count = list.length == 1 ? '1 unidad' : '${list.length} unidades';
    final declared = list.where((u) => u.headcount != null).toList();
    if (declared.isEmpty) return count;
    final total = declared.fold<int>(0, (sum, u) => sum + u.headcount!);
    final animals = total == 1
        ? '1 animal declarado'
        : '$total animales declarados';
    final partial = declared.length < list.length
        ? ' (solo de las que tienen cantidad)'
        : '';
    return '$count · $animals$partial';
  }

  Widget _card(BuildContext context, ProductionUnit unit) {
    final textTheme = Theme.of(context).textTheme;
    final (icon, accent) = widget.visualFor(unit.species);
    final headcount = unit.headcount;
    return VetCard(
      padding: EdgeInsets.zero,
      radius: 18,
      child: InkWell(
        onTap: () async {
          await widget.onOpen(unit);
          if (mounted) await _load();
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VetIconBox(icon: icon, accent: accent, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(unit.name, style: textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      '${unit.species} · ${unit.activity}',
                      style: textTheme.bodySmall,
                    ),
                    if (headcount != null)
                      Text(
                        headcount == 1 ? '1 animal' : '$headcount animales',
                        style: textTheme.bodySmall,
                      ),
                    Text(
                      'Actualizada ${VetFormat.date(unit.updatedAt ?? unit.createdAt)}',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Icon(VetIcons.chevronRight),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

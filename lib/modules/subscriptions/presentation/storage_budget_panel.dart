import 'package:flutter/material.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_format.dart';
import '../../../vet_ui/vet_icons.dart';
import '../domain/storage_budget.dart';

class StorageBudgetPanel extends StatelessWidget {
  const StorageBudgetPanel({
    super.key,
    required this.used,
    required this.limit,
    required this.personal,
  });
  final dynamic used, limit;
  final bool personal;
  @override
  Widget build(BuildContext context) {
    final budget = StorageBudget.read(used, limit);
    if (budget == null) {
      return const Text(
        'Uso de almacenamiento no disponible. Actualiza para consultarlo.',
      );
    }
    final message = switch (budget.level) {
      StorageLevel.normal => 'Tienes espacio disponible en tu plan.',
      StorageLevel.warning =>
        'Has alcanzado el 80% del almacenamiento. Revisa tu uso y las opciones de plan.',
      StorageLevel.critical =>
        'Has alcanzado el 95% del almacenamiento. Te queda poco espacio para nuevos datos.',
      StorageLevel.full =>
        'Alcanzaste el límite. Se conservan tus registros; las operaciones que aumenten el uso pueden bloquearse.',
    };
    final color =
        budget.level == StorageLevel.critical ||
            budget.level == StorageLevel.full
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Almacenamiento',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                VetStatusBadge(
                  label: '${budget.percent}% usado',
                  kind: budget.level == StorageLevel.critical ||
                          budget.level == StorageLevel.full
                      ? VetBadgeKind.danger
                      : budget.level == StorageLevel.warning
                      ? VetBadgeKind.warning
                      : VetBadgeKind.information,
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: budget.fraction,
              color: color,
              semanticsLabel: 'Almacenamiento estimado utilizado',
              semanticsValue: '${budget.percent}%',
            ),
            const SizedBox(height: 6),
            Text(
              VetFormat.joinDistinct([
                '${VetFormat.size(used)} de ${VetFormat.size(limit)}',
                personal ? 'espacio individual' : 'compartido por el equipo',
              ]),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            VetNote(
              text: message,
              icon: budget.level == StorageLevel.normal
                  ? VetIcons.info
                  : VetIcons.alertOctagon,
              color: color,
            ),
            const VetNote(
              text:
                  'El presupuesto incluye datos y archivos contabilizados; las fotos de inventario reservan 4 MiB por foto.',
            ),
            if (budget.level != StorageLevel.normal)
              const VetNote(
                text:
                    'Ampliación de almacenamiento: tarifa pendiente. No hay cobros automáticos por exceso de uso.',
                icon: VetIcons.alertOctagon,
              ),
          ],
        ),
      ),
    );
  }
}

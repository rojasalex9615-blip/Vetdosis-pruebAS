import '../../../core/widgets/accent_glow.dart';
import 'package:flutter/material.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_icons.dart';
import '../../hospital/application/hospital_alerts.dart';

class AlertPreferencesPanel extends StatefulWidget {
  const AlertPreferencesPanel({
    super.key,
    required this.alerts,
    this.onUpdated,
  });
  final HospitalAlerts? alerts;
  final Future<void> Function()? onUpdated;
  @override
  State<AlertPreferencesPanel> createState() => _AlertPreferencesPanelState();
}

class _AlertPreferencesPanelState extends State<AlertPreferencesPanel> {
  bool busy = false;
  String? error;

  Future<void> update({
    bool? sound,
    bool? vibration,
    bool? stockWarnings,
    int? lead,
  }) async {
    if (busy || widget.alerts == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.alerts!.updateOptions(
        sound: sound,
        vibration: vibration,
        stockWarnings: stockWarnings,
        leadMinutes: lead,
      );
      await widget.onUpdated?.call();
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'No se pudo guardar o actualizar los avisos. Revisa hospitalización.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final alerts = widget.alerts;
    if (alerts == null) {
      return const Text('Preferencias de avisos no disponibles.');
    }
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: alerts,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            secondary: const Icon(VetIcons.bell),
            title: const Text('Alerta sonora'),
            subtitle: const Text('Emite un sonido de notificación al vencer un horario'),
            value: alerts.sound,
            onChanged: busy ? null : (value) => update(sound: value),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(VetIcons.phone),
            title: const Text('Vibración'),
            subtitle: const Text(
              'Android; en iPhone depende de los ajustes del sistema.',
            ),
            value: alerts.vibration,
            onChanged: busy ? null : (value) => update(vibration: value),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(VetIcons.box),
            title: const Text('Aviso visual de stock bajo'),
            subtitle: const Text('Señala insumos por agotarse o caducar'),
            value: alerts.stockWarnings,
            onChanged: busy ? null : (value) => update(stockWarnings: value),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(VetIcons.clock, size: 18),
              const SizedBox(width: 8),
              Text(
                'Anticipación de avisos de hospitalización',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final minutes in [0, 5, 10, 15, 30])
                glowChip(
                  ChoiceChip(
                    label: Text(
                      minutes == 0 ? 'Sin anticipación' : '$minutes min',
                    ),
                    selected: alerts.leadMinutes == minutes,
                    onSelected: busy ? null : (_) => update(lead: minutes),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(VetIcons.info, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alerts.status,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const VetNote(
            text:
                'Activa los avisos en Hospitalización. El sonido, vibración y entrega dependen de permisos, canales y batería del teléfono. Al cambiar preferencias, abre la hoja para revisar todos los horarios.',
            icon: VetIcons.bell,
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            VetCallout(
              text: error!,
              kind: VetBadgeKind.danger,
              icon: VetIcons.warningTriangle,
            ),
          ],
          if (busy) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}

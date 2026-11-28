import 'package:flutter/material.dart';
import '../../auth/domain/clinic_membership.dart';
import '../../inventory/domain/inventory_models.dart';
import '../domain/operations_repository.dart';
import 'service_commission_panel.dart';
import '../../../core/widgets/accent_glow.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_icons.dart';
import '../../../vet_ui/vet_theme.dart';

class CommissionPanel extends StatefulWidget {
  const CommissionPanel({super.key, required this.repository, required this.member});
  final CommissionRepository repository;
  final ClinicMembership member;
  @override
  State<CommissionPanel> createState() => _CommissionPanelState();
}

class _CommissionPanelState extends State<CommissionPanel> {
  Map<String, dynamic>? data;
  String? error;
  bool busy = false;
  String cadence = 'semanal';
  DateTime? payOn;
  bool get admin => widget.member.role == ClinicRole.admin;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() { busy = true; error = null; data = null; });
    try {
      final next = await widget.repository.commissionAccount(widget.member.clinicId);
      if (mounted) setState(() => data = next);
    } catch (_) {
      if (mounted) setState(() => error = 'No se pudo consultar el periodo de comisiones. Revisa la conexión y la migración 14E.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> saveSchedule() async {
    final chosen = payOn;
    if (chosen == null) return;
    setState(() { busy = true; error = null; });
    try {
      await widget.repository.saveCommissionSchedule(widget.member.clinicId, cadence, chosen);
      await load();
    } catch (_) {
      if (mounted) setState(() => error = 'No se pudo guardar el calendario de pagos.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> payPeriod() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar pago de comisiones'),
        content: const Text('Se cerrará el periodo y quedará registrada una liquidación por colaborador. Confirma solo después de realizar el pago.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Registrar pago')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() { busy = true; error = null; });
    try {
      await widget.repository.payCommissionPeriod(widget.member.clinicId);
      await load();
    } catch (_) {
      if (mounted) setState(() => error = 'No se pudo registrar el pago. Comprueba que llegó el día elegido y actualiza.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final schedule = data?['schedule'] is Map
        ? Map<String, dynamic>.from(data!['schedule'] as Map)
        : null;
    final accrued = (data?['accrued'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final payments = (data?['payments'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const AccentIcon(VetIcons.coins, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mis comisiones',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Acumulado por servicios cobrados. Los pagos anteriores conservan su historial.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (busy) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (error != null) ...[
            const SizedBox(height: 12),
            VetCallout(
              text: error!,
              kind: VetBadgeKind.danger,
              icon: VetIcons.alertTriangle,
            ),
          ],
          if (schedule != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(VetIcons.calendar, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Periodo actual desde ${schedule['period_start']} · próximo pago ${schedule['next_pay_on']} · ${schedule['cadence']}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (data != null && schedule == null) ...[
            const SizedBox(height: 12),
            const VetNote(
              text: 'El administrador aún no ha configurado un periodo de pago.',
              icon: VetIcons.info,
            ),
          ],
          const SizedBox(height: 12),
          for (final row in accrued)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      admin ? '${row['professional_name']}' : 'Saldo actual',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    Money.parse('${row['amount']}', signed: true).display,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: VetColors.success,
                    ),
                  ),
                ],
              ),
            ),
          if (data != null && accrued.isEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'Sin comisiones acumuladas en este periodo.',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
          if (admin) ...[
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(VetIcons.lock, size: 18, color: VetColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Calendario de pagos · solo administración',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: cadence,
              decoration: const InputDecoration(
                labelText: 'Frecuencia',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'diario', child: Text('Diario')),
                DropdownMenuItem(value: 'semanal', child: Text('Semanal')),
                DropdownMenuItem(value: 'quincenal', child: Text('Cada 15 días')),
                DropdownMenuItem(value: 'mensual', child: Text('Mensual')),
              ],
              onChanged: busy
                  ? null
                  : (value) {
                      if (value != null) setState(() => cadence = value);
                    },
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      final tomorrow = DateUtils.dateOnly(
                        DateTime.now(),
                      ).add(const Duration(days: 1));
                      final date = await showDatePicker(
                        context: context,
                        initialDate: payOn != null && !payOn!.isBefore(tomorrow)
                            ? payOn!
                            : tomorrow,
                        firstDate: tomorrow,
                        lastDate: tomorrow.add(const Duration(days: 365)),
                      );
                      if (date != null && mounted) setState(() => payOn = date);
                    },
              icon: const Icon(VetIcons.calendar),
              label: Text(
                payOn == null
                    ? 'Elegir próximo día de pago'
                    : '${payOn!.day}/${payOn!.month}/${payOn!.year}',
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: busy || payOn == null ? null : saveSchedule,
              child: const Text('Guardar calendario'),
            ),
            if (schedule != null) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: busy ? null : payPeriod,
                child: const Text('Registrar pago y abrir siguiente periodo'),
              ),
            ],
          ],
          if (widget.repository is ServiceCommissionRepository) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: busy
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          appBar: AppBar(
                            title: const Text('Comisiones por servicio'),
                          ),
                          body: SingleChildScrollView(
                            child: ServiceCommissionPanel(
                              repository: widget.repository
                                  as ServiceCommissionRepository,
                              member: widget.member,
                            ),
                          ),
                        ),
                      ),
                    ),
              icon: const Icon(VetIcons.receipt),
              label: const Text('Liquidaciones individuales por servicio (beta)'),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(VetIcons.history, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Liquidaciones registradas',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final row in payments.take(12))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(VetIcons.checkCircle, color: VetColors.success),
              title: Text(
                Money.parse('${row['amount']}').display,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${row['scheduled_on']} · ${admin ? row['professional_name'] : 'Pago registrado'}',
              ),
            ),
        ],
      ),
    );
  }
}

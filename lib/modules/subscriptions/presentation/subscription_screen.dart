import 'storage_budget_panel.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/widgets/accent_glow.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_format.dart';
import '../../../vet_ui/vet_icons.dart';
import '../../../vet_ui/vet_theme.dart';
import '../../auth/domain/clinic_membership.dart';
import '../../patients/presentation/patient_view_model.dart'
    show newOperationId;
import '../domain/subscription_repository.dart';
import 'subscription_view_model.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({
    super.key,
    required this.repository,
    required this.member,
    this.canManageWorkspace = false,
  });
  final SubscriptionRepository repository;
  final ClinicMembership member;
  final bool canManageWorkspace;
  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  late final model = SubscriptionViewModel(
    widget.repository,
    widget.member.clinicId,
  );
  String period = 'monthly';
  bool saving = false;
  bool get canManageWorkspace =>
      widget.canManageWorkspace || model.data['can_manage'] == true;
  @override
  void initState() {
    super.initState();
    model.load();
  }

  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  String price(dynamic cents) => VetFormat.moneyFromCents(cents);

  Future<void> request(String code) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await widget.repository.request(
        widget.member.clinicId,
        code,
        period,
        newOperationId(),
      );
      await model.load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Interés registrado. No hubo cobro ni activación de pago.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo registrar la solicitud.')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> checkout(String id) async {
    try {
      final url = await widget.repository.checkout(id);
      final uri = Uri.parse(url);
      if (uri.scheme != 'https' || uri.host != 'checkout.stripe.com') {
        throw const FormatException('Enlace de pago no válido.');
      }
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw const FormatException('No se pudo abrir el navegador de pago.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is FormatException
                  ? e.message
                  : 'No se pudo abrir el pago seguro.',
            ),
          ),
        );
      }
    }
  }

  Future<void> redeem() async {
    try {
      await widget.repository.redeem(widget.member.clinicId, newOperationId());
      await model.load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo canjear. Revisa puntos, permisos y reglas vigentes.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grants = model.data['grants'] as List? ?? [];
    final effective = model.data['effective'] as Map?;
    final workspace = model.data['workspace'] as Map?;

    return ListenableBuilder(
      listenable: model,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AccentIcon(VetIcons.certificate, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Planes, pagos y beneficios',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      model.data['billing_enabled'] == true
                          ? 'Consulta tu plan, precios y pagos confirmados. El consumo de tu API key depende de tu proveedor.'
                          : 'Precios propuestos de lanzamiento. Los cobros siguen desactivados. El consumo de tu API key depende de tu proveedor.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Actualizar planes y estado',
                onPressed: model.busy ? null : model.load,
                icon: const Icon(VetIcons.refresh),
              ),
            ],
          ),
          if (model.busy || saving) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(),
          ],
          if (model.error != null) ...[
            const SizedBox(height: 10),
            VetCallout(
              text: model.error!,
              kind: VetBadgeKind.danger,
              icon: VetIcons.warningTriangle,
            ),
          ],
          const SizedBox(height: 16),
          if (effective != null) ...[
            AccentGlow(
              color: theme.colorScheme.primary,
              radius: 28,
              emphasis: 0.6,
              child: VetCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(VetIcons.shieldCheck, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${effective['name']}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const VetStatusBadge(
                          label: 'Plan activo',
                          kind: VetBadgeKind.success,
                        ),
                        if (workspace != null &&
                            VetFormat.enumLabel(workspace['kind']).toLowerCase() !=
                                '${effective['name']}'.toLowerCase()) ...[
                          const SizedBox(width: 6),
                          VetStatusBadge(
                            label: VetFormat.enumLabel(workspace['kind']),
                            kind: VetBadgeKind.information,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    VetDataRow(
                      label: 'Pacientes',
                      value:
                          '${model.data['patients']} de ${effective['patient_limit']}',
                      icon: VetIcons.paw,
                    ),
                    VetDataRow(
                      label: 'Almacenamiento',
                      value:
                          '${storagePercent(model.data['usage_bytes'], effective['storage_bytes'])} de ${storageSize(effective['storage_bytes'])}',
                      icon: VetIcons.folder,
                    ),
                    VetDataRow(
                      label: 'Consultas con clave propia por día',
                      value: '${effective['ai_daily']}',
                      icon: VetIcons.robot,
                    ),
                    VetDataRow(
                      label: 'Créditos de lealtad',
                      value: '${model.data['reward_points']}',
                      icon: VetIcons.gift,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            StorageBudgetPanel(
              used: model.data['usage_bytes'],
              limit: effective['storage_bytes'],
              personal: workspace?['kind'] == 'personal',
            ),
            const SizedBox(height: 14),
          ],
          if (canManageWorkspace &&
              widget.repository is PaymentHistoryRepository) ...[
            PaymentHistoryPanel(
              repository: widget.repository as PaymentHistoryRepository,
              clinic: widget.member.clinicId,
            ),
            const SizedBox(height: 14),
          ],
          const VetCallout(
            text:
                'El pago se realiza en una página segura del proveedor. VetDosis no solicita ni guarda número de tarjeta o CVV. El regreso a la app no confirma un pago: actualiza para consultar el estado verificado.',
            icon: VetIcons.lock,
            kind: VetBadgeKind.information,
          ),
          const SizedBox(height: 14),
          Center(
            child: Column(
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'monthly',
                      icon: Icon(VetIcons.calendar),
                      label: Text('Mensual'),
                    ),
                    ButtonSegment(
                      value: 'annual',
                      icon: Icon(VetIcons.certificate),
                      label: Text('Anual'),
                    ),
                  ],
                  selected: {period},
                  onSelectionChanged: (s) => setState(() => period = s.first),
                ),
                if (period == 'annual')
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'El plan anual equivale a 10 mensualidades (ahorras 2 meses).',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final p in model.data['plans'] as List? ?? []) ...[
            AccentGlow(
              color: theme.colorScheme.primary,
              enabled: effective?['code'] == p['code'],
              radius: 26,
              emphasis: 0.5,
              child: VetPlanCard(
                name: '${p['name']}',
                price: p['code'] == 'free'
                    ? 'Gratis'
                    : price(p[period == 'annual' ? 'annual_cents' : 'monthly_cents']),
                current: effective?['code'] == p['code'],
                rows: [
                  VetDataRow(
                    label: 'Pacientes',
                    value: '${p['patient_limit']}',
                    icon: VetIcons.paw,
                  ),
                  VetDataRow(
                    label: 'Almacenamiento',
                    value: storageSize(p['storage_bytes']),
                    icon: VetIcons.folder,
                  ),
                  VetDataRow(
                    label: 'Consultas con clave propia por día',
                    value: '${p['ai_daily']}',
                    icon: VetIcons.robot,
                  ),
                ],
                note: p['team'] == true
                    ? 'Todos los integrantes de la clínica; sin cobro por asiento.'
                    : 'Inventario, ventas y corte manual propios; sin equipo compartido.',
                footer: p['code'] != 'free' &&
                        canManageWorkspace &&
                        (workspace?['kind'] == 'personal') ==
                            (p['code'] == 'individual')
                    ? FilledButton.tonal(
                        onPressed: saving
                            ? null
                            : () => request(p['code'] as String),
                        child: const Text('Registrar interés (sin cobro)'),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (model.data['reward_enabled'] == true && canManageWorkspace) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: FilledButton.tonalIcon(
                onPressed: () => redeem(),
                icon: const Icon(VetIcons.gift),
                label: const Text('Canjear puntos por beneficio temporal'),
              ),
            ),
          ],
          if (model.data['billing_enabled'] == true)
            for (final r in model.data['requests'] as List? ?? [])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: FilledButton.icon(
                  onPressed: r['requested_by'] == widget.member.userId
                      ? () => checkout(r['id'] as String)
                      : null,
                  icon: const Icon(VetIcons.lock),
                  label: Text(
                    'Abrir pago seguro · ${r['plan_code']} ${r['period']}',
                  ),
                ),
              ),
          const SizedBox(height: 12),
          const VetNote(
            text:
                'Los beneficios beta/regalo vencen en la fecha indicada. Un plan vencido conserva tus registros y permite exportar; no borra datos ni modifica tu rol.',
            icon: VetIcons.gift,
          ),
          if (grants.isNotEmpty) ...[
            const SizedBox(height: 14),
            VetCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(VetIcons.gift, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Beneficios y accesos de cortesía',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final g in grants)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(VetIcons.certificate),
                      title: Text(
                        grantTitle(g['source'], g['plan_code']),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${shortDate(g['starts_at'])} → ${shortDate(g['ends_at'])}',
                      ),
                      trailing: VetStatusBadge(
                        label: g['revoked'] == true ? 'Revocado' : 'Vigente',
                        kind: g['revoked'] == true
                            ? VetBadgeKind.warning
                            : VetBadgeKind.success,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PaymentHistoryPanel extends StatefulWidget {
  const PaymentHistoryPanel({
    super.key,
    required this.repository,
    required this.clinic,
  });
  final PaymentHistoryRepository repository;
  final String clinic;
  @override
  State<PaymentHistoryPanel> createState() => _PaymentHistoryPanelState();
}

class _PaymentHistoryPanelState extends State<PaymentHistoryPanel> {
  late Future<List<Map<String, dynamic>>> result = widget.repository
      .paymentHistory(widget.clinic);
  @override
  Widget build(BuildContext context) => VetCard(
    child: ExpansionTile(
      leading: const Icon(VetIcons.receipt),
      title: const Text(
        'Historial de pagos de la suscripción',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      childrenPadding: const EdgeInsets.only(top: 8, bottom: 8),
      children: [
        const Text(
          'Estos pagos corresponden a VetDosis Pro. Los cobros a tus clientes se registran en Inventario y caja.',
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: result,
          builder: (context, s) {
            if (s.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              );
            }
            if (s.hasError) {
              return const Text('No se pudo consultar el historial de pagos.');
            }
            if (s.data == null || s.data!.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Sin pagos confirmados.'),
              );
            }
            return Column(
              children: [
                for (final p in s.data!)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(VetIcons.checkCircle, color: VetColors.success),
                    title: Text(
                      'Pago confirmado · \$${((p['amount_cents'] as num) / 100).toStringAsFixed(2)} ${p['currency']}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${p['provider']} · ${shortDate(p['period_start'])} → ${shortDate(p['period_end'])}',
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(VetIcons.refresh, size: 16),
            onPressed: () => setState(
              () => result = widget.repository.paymentHistory(widget.clinic),
            ),
            label: const Text('Actualizar pagos'),
          ),
        ),
      ],
    ),
  );
}

String storageSize(dynamic value) => VetFormat.size(value);

const _spanishMonths = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

String shortDate(dynamic value) {
  final parsed = DateTime.tryParse('$value');
  if (parsed == null) return '$value';
  final d = parsed.toLocal();
  return '${d.day} ${_spanishMonths[d.month - 1]} ${d.year}';
}

String shortDateTime(dynamic value) {
  final parsed = DateTime.tryParse('$value');
  if (parsed == null) return '$value';
  final d = parsed.toLocal();
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${shortDate(value)}, $hh:$mm';
}

String storagePercent(dynamic used, dynamic limit) {
  final u = (num.tryParse('$used') ?? 0).toDouble();
  final l = (num.tryParse('$limit') ?? 0).toDouble();
  if (l <= 0) return '0.0%';
  return '${(u / l * 100).toStringAsFixed(1)}%';
}

String grantTitle(dynamic source, dynamic planCode) {
  final s = '$source'.toLowerCase() == 'beta' || '$source' == 'beta_grant'
      ? 'Acceso anticipado beta'
      : '$source' == 'founder_gift'
          ? 'Cortesía de lanzamiento'
          : '$source';
  final p = switch ('$planCode'.toLowerCase()) {
    'clinic' => 'Clínica',
    'individual' => 'Individual',
    'free' => 'Gratis',
    _ => '$planCode',
  };
  return '$s · $p';
}

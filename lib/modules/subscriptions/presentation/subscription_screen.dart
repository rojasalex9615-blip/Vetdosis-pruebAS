import 'storage_budget_panel.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/domain/clinic_membership.dart';
import '../../patients/presentation/patient_view_model.dart'
    show newOperationId;
import '../domain/subscription_repository.dart';
import 'subscription_view_model.dart';
import '../../../vet_ui/vet_theme.dart';
import '../../../vet_ui/vet_components.dart';

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

  String price(dynamic cents) =>
      '\$${((cents as num) / 100).toStringAsFixed(2)} MXN';
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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Planes, pagos y beneficios',
          style: VetTypography.headlineSmall,
        ),
        const SizedBox(height: VetSpacing.xs),
        Text(
          model.data['billing_enabled'] == true
              ? 'Consulta tu plan, precios y pagos confirmados. El consumo de tu API key depende de tu proveedor.'
              : 'Precios propuestos de lanzamiento. Los cobros siguen desactivados. El consumo de tu API key depende de tu proveedor.',
          style: VetTypography.bodyMedium.copyWith(color: VetColors.muted),
        ),
        if (model.busy || saving) const LinearProgressIndicator(),
        if (model.error != null)
          Text(model.error!, style: VetTypography.bodyMedium),
        const SizedBox(height: VetSpacing.sm),
        VetSecondaryButton(
          label: 'Actualizar',
          icon: Icons.refresh,
          onPressed: model.busy ? null : model.load,
        ),
        if (model.data['effective'] != null) ...[
          const SizedBox(height: VetSpacing.lg),
          VetSectionCard(
            title: 'Plan efectivo',
            icon: Icons.workspace_premium_outlined,
            accentColor: VetColors.purple,
            padding: const EdgeInsets.all(VetSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plan: ${(model.data['effective'] as Map)['name']} · ${(model.data['workspace'] as Map)['kind'] == 'personal' ? 'espacio personal' : 'clínica'}',
                  style: VetTypography.bodyLarge,
                ),
                const SizedBox(height: VetSpacing.xs),
                Text(
                  'Pacientes: ${model.data['patients']} · máximo ${(model.data['effective'] as Map)['patient_limit']}',
                  style: VetTypography.bodyMedium,
                ),
                const SizedBox(height: VetSpacing.xs),
                Text(
                  'Uso estimado de datos: ${storageSize(model.data['usage_bytes'])} de ${storageSize((model.data['effective'] as Map)['storage_bytes'])}',
                  style: VetTypography.bodyMedium,
                ),
                const SizedBox(height: VetSpacing.md),
                StorageBudgetPanel(
                  used: model.data['usage_bytes'],
                  limit: (model.data['effective'] as Map)['storage_bytes'],
                  personal: (model.data['workspace'] as Map)['kind'] == 'personal',
                ),
                const SizedBox(height: VetSpacing.md),
                Text(
                  'Consultas con clave propia por día: ${(model.data['effective'] as Map)['ai_daily']} · créditos de lealtad: ${model.data['reward_points']}',
                  style: VetTypography.bodyMedium,
                ),
              ],
            ),
          ),
        ],
        if (canManageWorkspace &&
            widget.repository is PaymentHistoryRepository) ...[
          const SizedBox(height: VetSpacing.lg),
          PaymentHistoryPanel(
            repository: widget.repository as PaymentHistoryRepository,
            clinic: widget.member.clinicId,
          ),
        ],
        const SizedBox(height: VetSpacing.lg),
        Text(
          'El pago se realiza en una página segura del proveedor. VetDosis no solicita ni guarda número de tarjeta o CVV. El regreso a la app no confirma un pago: actualiza para consultar el estado verificado.',
          style: VetTypography.bodySmall,
        ),
        const SizedBox(height: VetSpacing.md),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'monthly', label: Text('Mensual')),
            ButtonSegment(value: 'annual', label: Text('Anual')),
          ],
          selected: {period},
          onSelectionChanged: (s) => setState(() => period = s.first),
        ),
        const SizedBox(height: VetSpacing.lg),
        for (final p in model.data['plans'] as List? ?? [])
          VetCard(
            padding: const EdgeInsets.all(VetSpacing.lg),
            elevated: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${p['name']} · ${price(p[period == 'annual' ? 'annual_cents' : 'monthly_cents'])}',
                  style: VetTypography.headlineSmall,
                ),
                const SizedBox(height: VetSpacing.xs),
                Text(
                  '${p['patient_limit']} pacientes · ${storageSize(p['storage_bytes'])} de presupuesto · ${p['ai_daily']} consultas con clave propia/día',
                  style: VetTypography.bodyMedium,
                ),
                const SizedBox(height: VetSpacing.xs),
                Text(
                  p['team'] == true
                      ? 'Todos los integrantes de la clínica; sin cobro por asiento.'
                      : 'Inventario, ventas y corte manual propios; sin equipo compartido.',
                  style: VetTypography.bodySmall,
                ),
                if (p['code'] != 'free' &&
                    canManageWorkspace &&
                    ((model.data['workspace'] as Map?)?['kind'] ==
                            'personal') ==
                        (p['code'] == 'individual')) ...[
                  const SizedBox(height: VetSpacing.md),
                  VetSecondaryButton(
                    label: 'Registrar interés (sin cobro)',
                    onPressed: saving ? null : () => request(p['code'] as String),
                    fullWidth: true,
                  ),
                ],
              ],
            ),
          ),
        if (model.data['reward_enabled'] == true &&
            canManageWorkspace) ...[
          const SizedBox(height: VetSpacing.md),
          VetSecondaryButton(
            label: 'Canjear puntos por beneficio temporal',
            onPressed: redeem,
            fullWidth: true,
          ),
        ],
        if (model.data['billing_enabled'] == true) ...[
          const SizedBox(height: VetSpacing.lg),
          for (final r in model.data['requests'] as List? ?? [])
            VetSecondaryButton(
              label: 'Abrir pago seguro · ${r['plan_code']} ${r['period']}',
              onPressed: r['requested_by'] == widget.member.userId
                  ? () => checkout(r['id'] as String)
                  : null,
              fullWidth: true,
            ),
        ],
        const SizedBox(height: VetSpacing.lg),
        Text(
          'Los beneficios beta/regalo vencen en la fecha indicada. Un plan vencido conserva tus registros y permite exportar; no borra datos ni modifica tu rol.',
          style: VetTypography.bodySmall,
        ),
        for (final g in model.data['grants'] as List? ?? [])
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${g['source']} · ${g['plan_code']}',
                style: VetTypography.bodyMedium),
            subtitle: Text(
              '${g['starts_at']} → ${g['ends_at']} · ${g['revoked'] == true ? 'revocado' : 'registrado'}',
              style: VetTypography.bodySmall,
            ),
          ),
      ],
    ),
  );
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
  Widget build(BuildContext context) => ExpansionTile(
    title: Text('Historial de pagos de la suscripción', style: VetTypography.titleMedium),
    children: [
      Text(
        'Estos pagos corresponden a VetDosis Pro. Los cobros a tus clientes se registran en Inventario y caja.',
        style: VetTypography.bodySmall,
      ),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: result,
        builder: (context, s) {
          if (s.connectionState != ConnectionState.done) {
            return const LinearProgressIndicator();
          }
          if (s.hasError) {
            return Text('No se pudo consultar el historial de pagos.',
                style: VetTypography.bodyMedium);
          }
          if (s.data!.isEmpty)
            return Text('Sin pagos confirmados.',
                style: VetTypography.bodyMedium.copyWith(color: VetColors.muted));
          return Column(
            children: [
              for (final p in s.data!)
                VetCard(
                  padding: const EdgeInsets.all(VetSpacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pago confirmado · \$${((p['amount_cents'] as num) / 100).toStringAsFixed(2)} ${p['currency']}',
                              style: VetTypography.bodyLarge,
                            ),
                            const SizedBox(height: VetSpacing.xs),
                            Text(
                              '${p['provider']} · ${p['period_start']} → ${p['period_end']}',
                              style: VetTypography.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: VetSpacing.md),
      VetSecondaryButton(
        label: 'Actualizar pagos',
        icon: Icons.refresh,
        onPressed: () => setState(
          () => result = widget.repository.paymentHistory(widget.clinic),
        ),
      ),
    ],
  );
}

String storageSize(dynamic value) {
  final bytes = num.tryParse('$value') ?? 0;
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GiB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
}

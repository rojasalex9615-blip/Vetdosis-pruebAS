import 'storage_budget_panel.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/domain/clinic_membership.dart';
import '../../patients/presentation/patient_view_model.dart'
    show newOperationId;
import '../domain/subscription_repository.dart';
import 'subscription_view_model.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_format.dart';
import '../../../vet_ui/vet_icons.dart';

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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Planes, pagos y beneficios',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(
          model.data['billing_enabled'] == true
              ? 'Consulta tu plan, precios y pagos confirmados. El consumo de tu API key depende de tu proveedor.'
              : 'Precios propuestos de lanzamiento. Los cobros siguen desactivados. El consumo de tu API key depende de tu proveedor.',
        ),
        if (model.busy || saving) const LinearProgressIndicator(),
        if (model.error != null) Text(model.error!),
        IconButton(
          onPressed: model.busy ? null : model.load,
          icon: const Icon(VetIcons.refresh),
        ),
        if (model.data['effective'] != null) ...[
          VetCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${(model.data['effective'] as Map)['name']}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    VetStatusBadge(
                      label: VetFormat.enumLabel(
                        (model.data['workspace'] as Map)['kind'],
                      ),
                      kind: VetBadgeKind.information,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                VetDataRow(
                  label: 'Pacientes',
                  value:
                      '${model.data['patients']} de ${(model.data['effective'] as Map)['patient_limit']}',
                  icon: VetIcons.paw,
                ),
                VetDataRow(
                  label: 'Almacenamiento',
                  value:
                      '${storageSize(model.data['usage_bytes'])} de ${storageSize((model.data['effective'] as Map)['storage_bytes'])}',
                  icon: VetIcons.folder,
                ),
                VetDataRow(
                  label: 'Consultas con clave propia por día',
                  value: '${(model.data['effective'] as Map)['ai_daily']}',
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
          const SizedBox(height: 12),
          StorageBudgetPanel(
            used: model.data['usage_bytes'],
            limit: (model.data['effective'] as Map)['storage_bytes'],
            personal: (model.data['workspace'] as Map)['kind'] == 'personal',
          ),
        ],
        if (canManageWorkspace &&
            widget.repository is PaymentHistoryRepository)
          PaymentHistoryPanel(
            repository: widget.repository as PaymentHistoryRepository,
            clinic: widget.member.clinicId,
          ),
        const Text(
          'El pago se realiza en una página segura del proveedor. VetDosis no solicita ni guarda número de tarjeta o CVV. El regreso a la app no confirma un pago: actualiza para consultar el estado verificado.',
        ),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'monthly', label: Text('Mensual')),
            ButtonSegment(value: 'annual', label: Text('Anual')),
          ],
          selected: {period},
          onSelectionChanged: (s) => setState(() => period = s.first),
        ),
        for (final p in model.data['plans'] as List? ?? [])
          VetPlanCard(
            name: '${p['name']}',
            price: price(p[period == 'annual' ? 'annual_cents' : 'monthly_cents']),
            current: (model.data['effective'] as Map?)?['code'] == p['code'],
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
            footer:
                p['code'] != 'free' &&
                    canManageWorkspace &&
                    ((model.data['workspace'] as Map?)?['kind'] ==
                            'personal') ==
                        (p['code'] == 'individual')
                ? TextButton(
                    onPressed: saving
                        ? null
                        : () => request(p['code'] as String),
                    child: const Text('Registrar interés (sin cobro)'),
                  )
                : null,
          ),
        if (model.data['reward_enabled'] == true &&
            canManageWorkspace)
          TextButton(
            onPressed: () => redeem(),
            child: const Text('Canjear puntos por beneficio temporal'),
          ),
        if (model.data['billing_enabled'] == true)
          for (final r in model.data['requests'] as List? ?? [])
            TextButton(
              onPressed: r['requested_by'] == widget.member.userId
                  ? () => checkout(r['id'] as String)
                  : null,
              child: Text(
                'Abrir pago seguro · ${r['plan_code']} ${r['period']}',
              ),
            ),
        const VetNote(
          text:
              'Los beneficios beta/regalo vencen en la fecha indicada. Un plan vencido conserva tus registros y permite exportar; no borra datos ni modifica tu rol.',
          icon: VetIcons.gift,
        ),
        for (final g in model.data['grants'] as List? ?? [])
          ListTile(
            title: Text('${g['source']} · ${g['plan_code']}'),
            subtitle: Text(
              '${g['starts_at']} → ${g['ends_at']} · ${g['revoked'] == true ? 'revocado' : 'registrado'}',
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
    title: const Text('Historial de pagos de la suscripción'),
    children: [
      const Text(
        'Estos pagos corresponden a VetDosis Pro. Los cobros a tus clientes se registran en Inventario y caja.',
      ),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: result,
        builder: (context, s) {
          if (s.connectionState != ConnectionState.done) {
            return const LinearProgressIndicator();
          }
          if (s.hasError) {
            return const Text('No se pudo consultar el historial de pagos.');
          }
          if (s.data!.isEmpty) return const Text('Sin pagos confirmados.');
          return Column(
            children: [
              for (final p in s.data!)
                ListTile(
                  title: Text(
                    'Pago confirmado · \$${((p['amount_cents'] as num) / 100).toStringAsFixed(2)} ${p['currency']}',
                  ),
                  subtitle: Text(
                    '${p['provider']} · ${p['period_start']} → ${p['period_end']}',
                  ),
                ),
            ],
          );
        },
      ),
      TextButton(
        onPressed: () => setState(
          () => result = widget.repository.paymentHistory(widget.clinic),
        ),
        child: const Text('Actualizar pagos'),
      ),
    ],
  );
}

String storageSize(dynamic value) => VetFormat.size(value);

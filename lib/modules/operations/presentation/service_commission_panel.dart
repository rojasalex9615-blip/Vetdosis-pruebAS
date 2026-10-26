import 'package:flutter/material.dart';
import '../../auth/domain/clinic_membership.dart';
import '../../inventory/domain/inventory_models.dart';
import '../../patients/presentation/patient_view_model.dart' show newOperationId;
import '../domain/operations_repository.dart';

class ServiceCommissionPanel extends StatefulWidget {
  const ServiceCommissionPanel({super.key, required this.repository, required this.member});
  final ServiceCommissionRepository repository;
  final ClinicMembership member;

  @override
  State<ServiceCommissionPanel> createState() => _ServiceCommissionPanelState();
}

class _ServiceCommissionPanelState extends State<ServiceCommissionPanel> {
  Map<String, dynamic>? data;
  List<Map<String, dynamic>> items = [];
  bool hasMore = false;
  bool busy = false;
  String? error;
  String? retryKey, retryOperation;
  bool get admin => widget.member.role == ClinicRole.admin;
  String worker(Map<String, dynamic> item) {
    final id = '${item['professional_id']}';
    final suffix = id.length > 8 ? id.substring(id.length - 8) : id;
    return '${item['professional_name']} · $suffix';
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (busy) return;
    setState(() { busy = true; error = null; data = null; items = []; hasMore = false; });
    try {
      final next = await widget.repository.commissionServiceAccount(widget.member.clinicId);
      final page = (next['items'] as List? ?? [])
          .map((row) => Map<String, dynamic>.from(row as Map)).toList();
      if (mounted) setState(() { data = next; items = page; hasMore = page.length == 200; });
    } catch (_) {
      if (mounted) setState(() => error = 'No se pudieron consultar las comisiones. Revisa la conexión y la actualización de la clínica.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> loadMore() async {
    if (busy || !hasMore) return;
    setState(() { busy = true; error = null; });
    try {
      final next = await widget.repository.commissionServiceAccount(widget.member.clinicId, offset: items.length);
      final page = (next['items'] as List? ?? [])
          .map((row) => Map<String, dynamic>.from(row as Map)).toList();
      if (mounted) setState(() { data = next; items.addAll(page); hasMore = page.length == 200; });
    } catch (_) {
      if (mounted) setState(() => error = 'No se pudo cargar el resto del historial.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> settle(Map<String, dynamic> item) async {
    if (busy || !admin || item['sale_collected'] != true || item['settlement_id'] != null) return;
    final reference = TextEditingController();
    String method = 'transferencia';
    final confirmed = await showDialog<bool>(context: context, builder: (context) =>
      StatefulBuilder(builder: (context, update) => AlertDialog(
        title: const Text('Registrar comisión pagada'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${worker(item)} · ${item['service_name']} · ${Money.parse('${item['commission']}').display}'),
          const Text('Confirma únicamente cuando hayas entregado este pago al colaborador.'),
          DropdownButtonFormField<String>(
            initialValue: method,
            decoration: const InputDecoration(labelText: 'Medio de pago'),
            items: const [
              DropdownMenuItem(value: 'transferencia', child: Text('Transferencia')),
              DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
              DropdownMenuItem(value: 'otro', child: Text('Otro')),
            ],
            onChanged: (value) { if (value != null) update(() => method = value); },
          ),
          TextField(controller: reference, maxLength: 150,
            decoration: const InputDecoration(labelText: 'Referencia (opcional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Registrar pago')),
        ],
      )),
    );
    final paymentReference = reference.text.trim();
    reference.dispose();
    if (confirmed != true || !mounted) return;
    final key = '${item['id']}|$method|$paymentReference';
    if (retryKey != key) { retryKey = key; retryOperation = newOperationId(); }
    setState(() { busy = true; error = null; });
    try {
      await widget.repository.settleServiceCommission(widget.member.clinicId,
        '${item['id']}', method, paymentReference, retryOperation!);
      retryKey = null;
      retryOperation = null;
      if (!mounted) return;
      setState(() => busy = false);
      await load();
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'No se pudo registrar el pago. Actualiza y comprueba el cobro antes de reintentar.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child:
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(admin ? 'Comisiones del equipo' : 'Mis comisiones',
          style: Theme.of(context).textTheme.titleLarge),
        const Text('El cobro del servicio y el pago al colaborador se registran por separado.'),
        if (busy) const LinearProgressIndicator(),
        if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (data != null) ...[
          Text('Por liquidar (servicios cobrados): ${Money.parse('${data!['outstanding']}').display}'),
          Text('Servicios aún sin cobrar: ${Money.parse('${data!['awaiting_collection']}').display}'),
          if (items.isEmpty) const Text('No hay comisiones registradas.'),
          for (final item in items)
            ListTile(
              title: Text('${admin ? '${worker(item)} · ' : ''}${item['service_name']} · ${Money.parse('${item['commission']}').display}'),
              subtitle: Text(item['settlement_id'] != null
                ? (item['sale_collected'] == true ? 'Liquidada' : 'Liquidada; venta revertida, revisar ajuste')
                : item['sale_collected'] == true ? 'Cobrada; pendiente de liquidar' : 'Pendiente de cobro'),
              trailing: admin && item['sale_collected'] == true && item['settlement_id'] == null
                ? TextButton(onPressed: busy ? null : () => settle(item), child: const Text('Registrar pago'))
                : null,
            ),
          if (hasMore) TextButton(onPressed: busy ? null : loadMore,
            child: const Text('Cargar más comisiones')),
          const Text('Las comisiones pendientes aparecen primero. Los totales incluyen todo el historial.'),
        ],
        TextButton.icon(onPressed: busy ? null : load,
          icon: const Icon(Icons.refresh), label: const Text('Actualizar comisiones')),
      ])));
  }
}

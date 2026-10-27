import 'package:flutter/material.dart';
import '../../auth/domain/clinic_membership.dart';
import '../../inventory/domain/inventory_models.dart';
import '../../patients/presentation/patient_view_model.dart'
    show newOperationId;
import '../domain/operations_repository.dart';

class ServiceCommissionPanel extends StatefulWidget {
  const ServiceCommissionPanel({
    super.key,
    required this.repository,
    required this.member,
  });
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

  Money recoverable(Map<String, dynamic> item) =>
      Money.parse(
        '${item['recovery_limit'] ?? item['settled_amount'] ?? '0'}',
      ) -
      Money.parse('${item['recovered_amount'] ?? '0'}');
  bool hasAdjustment(Map<String, dynamic> item) =>
      item['settlement_sale_reversed'] == true ||
      (item['recovery_limit'] != null &&
          Money.parse('${item['recovery_limit']}').cents > BigInt.zero);

  int scopeGeneration = 0;
  bool current(int generation) => mounted && generation == scopeGeneration;

  @override
  void didUpdateWidget(covariant ServiceCommissionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.member.userId != widget.member.userId ||
        oldWidget.member.clinicId != widget.member.clinicId ||
        oldWidget.member.role != widget.member.role ||
        oldWidget.repository != widget.repository) {
      scopeGeneration++;
      busy = false;
      data = null;
      items = [];
      retryKey = null;
      retryOperation = null;
      load();
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final generation = scopeGeneration;
    final member = widget.member;
    final repository = widget.repository;
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      data = null;
      items = [];
      hasMore = false;
    });
    try {
      final next = await repository.commissionServiceAccount(member.clinicId);
      final page = (next['items'] as List? ?? [])
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      if (current(generation)) {
        setState(() {
          data = next;
          items = page;
          hasMore = page.length == 200;
        });
      }
    } catch (_) {
      if (current(generation)) {
        setState(
          () => error =
              'No se pudieron consultar las comisiones. Revisa la conexión y la actualización de la clínica.',
        );
      }
    } finally {
      if (current(generation)) setState(() => busy = false);
    }
  }

  Future<void> loadMore() async {
    final generation = scopeGeneration;
    final member = widget.member;
    final repository = widget.repository;
    if (busy || !hasMore) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final next = await repository.commissionServiceAccount(
        member.clinicId,
        offset: items.length,
      );
      final page = (next['items'] as List? ?? [])
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      if (current(generation)) {
        setState(() {
          data = next;
          items.addAll(page);
          hasMore = page.length == 200;
        });
      }
    } catch (_) {
      if (current(generation)) {
        setState(() => error = 'No se pudo cargar el resto del historial.');
      }
    } finally {
      if (current(generation)) setState(() => busy = false);
    }
  }

  Future<void> settle(Map<String, dynamic> item) async {
    final generation = scopeGeneration;
    final member = widget.member;
    final repository = widget.repository;
    if (busy ||
        !admin ||
        item['sale_collected'] != true ||
        Money.parse('${item['commission']}').cents <= BigInt.zero ||
        item['settlement_id'] != null) {
      return;
    }
    final reference = TextEditingController();
    String method = 'transferencia';
    final dialog = DialogRoute<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Registrar comisión pagada'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${worker(item)} · ${item['service_name']} · ${Money.parse('${item['commission']}').display}',
              ),
              const Text(
                'Confirma únicamente cuando hayas entregado este pago al colaborador.',
              ),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'Medio de pago'),
                items: const [
                  DropdownMenuItem(
                    value: 'transferencia',
                    child: Text('Transferencia'),
                  ),
                  DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
                  DropdownMenuItem(value: 'otro', child: Text('Otro')),
                ],
                onChanged: (value) {
                  if (value != null) update(() => method = value);
                },
              ),
              TextField(
                controller: reference,
                maxLength: 150,
                decoration: const InputDecoration(
                  labelText: 'Referencia (opcional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Registrar pago'),
            ),
          ],
        ),
      ),
    );
    final confirmed = await Navigator.of(
      context,
      rootNavigator: true,
    ).push(dialog);
    await dialog.completed;
    final paymentReference = reference.text.trim();
    reference.dispose();
    if (confirmed != true || !current(generation)) return;
    final key = '${item['id']}|$method|$paymentReference';
    if (retryKey != key) {
      retryKey = key;
      retryOperation = newOperationId();
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repository.settleServiceCommission(
        member.clinicId,
        '${item['id']}',
        method,
        paymentReference,
        retryOperation!,
      );
      if (!current(generation)) return;
      retryKey = null;
      retryOperation = null;
      setState(() => busy = false);
      await load();
    } catch (_) {
      if (current(generation)) {
        setState(() {
          busy = false;
          error =
              'No se pudo registrar el pago. Actualiza y comprueba el cobro antes de reintentar.';
        });
      }
    }
  }

  Future<void> recover(Map<String, dynamic> item) async {
    final generation = scopeGeneration;
    final member = widget.member;
    final repository = widget.repository;
    if (busy ||
        !admin ||
        !hasAdjustment(item) ||
        data?['recovery_supported'] != true) {
      return;
    }
    final maximum = recoverable(item);
    if (maximum.cents <= BigInt.zero) return;
    final amount = TextEditingController(),
        reference = TextEditingController(),
        reason = TextEditingController();
    var method = 'transferencia';
    String? validation;
    final dialog = DialogRoute<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Registrar reintegro recibido'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${worker(item)} · ${item['service_name']}'),
                Text('Máximo sin registrar: ${maximum.display}'),
                const Text(
                  'Confirma solo dinero ya recibido del colaborador. La entrada de caja se registra por separado.',
                ),
                TextField(
                  controller: amount,
                  decoration: const InputDecoration(
                    labelText: 'Importe recibido MXN',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: const InputDecoration(labelText: 'Medio'),
                  items: const [
                    DropdownMenuItem(
                      value: 'transferencia',
                      child: Text('Transferencia'),
                    ),
                    DropdownMenuItem(
                      value: 'efectivo',
                      child: Text('Efectivo'),
                    ),
                    DropdownMenuItem(value: 'otro', child: Text('Otro')),
                  ],
                  onChanged: (value) {
                    if (value != null) update(() => method = value);
                  },
                ),
                TextField(
                  controller: reference,
                  maxLength: 150,
                  decoration: const InputDecoration(labelText: 'Referencia'),
                ),
                TextField(
                  controller: reason,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Motivo del reintegro',
                  ),
                ),
                if (validation != null)
                  Text(
                    validation!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                try {
                  final value = Money.parse(amount.text);
                  if (value.cents <= BigInt.zero ||
                      value.cents > maximum.cents ||
                      reason.text.trim().isEmpty) {
                    throw const FormatException(
                      'Indica un importe positivo dentro del máximo y un motivo.',
                    );
                  }
                  Navigator.pop(context, true);
                } on FormatException catch (error) {
                  update(() => validation = error.message);
                }
              },
              child: const Text('Confirmar reintegro recibido'),
            ),
          ],
        ),
      ),
    );
    final confirmed = await Navigator.of(
      context,
      rootNavigator: true,
    ).push(dialog);
    await dialog.completed;
    final amountText = amount.text,
        referenceText = reference.text.trim(),
        reasonText = reason.text.trim();
    amount.dispose();
    reference.dispose();
    reason.dispose();
    if (confirmed != true || !current(generation)) return;
    final normalizedAmount = Money.parse(amountText).decimal;
    final key =
        'recovery|${item['settlement_id']}|$normalizedAmount|$method|$referenceText|$reasonText';
    if (retryKey != key) {
      retryKey = key;
      retryOperation = newOperationId();
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repository.recordServiceCommissionRecovery(
        member.clinicId,
        '${item['settlement_id']}',
        normalizedAmount,
        method,
        referenceText,
        reasonText,
        retryOperation!,
      );
      if (!current(generation)) return;
      retryKey = null;
      retryOperation = null;
      setState(() => busy = false);
      await load();
    } catch (_) {
      if (current(generation)) {
        setState(() {
          busy = false;
          error =
              'No se pudo registrar el reintegro. Actualiza y comprueba el historial antes de reintentar.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              admin ? 'Comisiones del equipo' : 'Mis comisiones',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'El cobro del servicio y el pago al colaborador se registran por separado.',
            ),
            if (busy) const LinearProgressIndicator(),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (data != null) ...[
              Text(
                'Por liquidar (servicios cobrados): ${Money.parse('${data!['outstanding']}').display}',
              ),
              Text(
                'Servicios aún sin cobrar: ${Money.parse('${data!['awaiting_collection']}').display}',
              ),
              if (items.isEmpty) const Text('No hay comisiones registradas.'),
              for (final item in items) ...[
                if (item['original_commission'] != null)
                  Text(
                    'Comisión original: ${Money.parse('${item['original_commission']}').display} · vigente: ${Money.parse('${item['commission']}').display}',
                  ),
                ListTile(
                  title: Text(
                    '${admin ? '${worker(item)} · ' : ''}${item['service_name']} · ${Money.parse('${item['commission']}').display}',
                  ),
                  subtitle: Text(
                    item['settlement_id'] != null
                        ? (item['sale_collected'] == true
                              ? 'Liquidada'
                              : 'Liquidada; revisar cobros y devoluciones')
                        : item['sale_collected'] == true
                        ? 'Cobrada; pendiente de liquidar'
                        : 'Pendiente de cobro',
                  ),
                  trailing:
                      admin &&
                          item['sale_collected'] == true &&
                          item['settlement_id'] == null &&
                          Money.parse('${item['commission']}').cents >
                              BigInt.zero
                      ? TextButton(
                          onPressed: busy ? null : () => settle(item),
                          child: const Text('Registrar pago'),
                        )
                      : null,
                ),
              ],
              for (final item in items.where(hasAdjustment))
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item['service_name']} · comisión pagada; ajuste por devolución',
                        ),
                        Text(
                          'Reintegros recibidos: ${Money.parse('${item['recovered_amount'] ?? '0'}').display}',
                        ),
                        if (admin &&
                            data?['recovery_supported'] == true &&
                            recoverable(item).cents > BigInt.zero)
                          TextButton(
                            onPressed: busy ? null : () => recover(item),
                            child: const Text('Registrar reintegro recibido'),
                          ),
                        for (final recovery
                            in item['recoveries'] as List? ?? [])
                          Text(
                            '${recovery['recorded_at']} · ${Money.parse('${recovery['amount']}').display} · ${recovery['method']} · ${recovery['reason']}',
                          ),
                        if ((item['recoveries'] as List? ?? []).isNotEmpty)
                          const Text(
                            'Últimos 20 registros. El pago original se conserva.',
                          ),
                      ],
                    ),
                  ),
                ),
              if (hasMore)
                TextButton(
                  onPressed: busy ? null : loadMore,
                  child: const Text('Cargar más comisiones'),
                ),
              const Text(
                'Las comisiones pendientes aparecen primero. Los totales incluyen todo el historial.',
              ),
            ],
            TextButton.icon(
              onPressed: busy ? null : load,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar comisiones'),
            ),
          ],
        ),
      ),
    );
  }
}

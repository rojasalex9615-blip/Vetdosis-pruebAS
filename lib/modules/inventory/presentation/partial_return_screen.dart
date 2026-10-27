import '../../doses/domain/quantity.dart';
import 'package:flutter/material.dart';
import '../../auth/domain/clinic_membership.dart';
import '../../patients/presentation/patient_view_model.dart'
    show newOperationId;
import '../domain/inventory_repository.dart';
import '../domain/partial_return.dart';
import '../domain/inventory_models.dart';

class PartialReturnScreen extends StatefulWidget {
  const PartialReturnScreen({
    super.key,
    required this.repository,
    required this.member,
    required this.sale,
    required this.shift,
  });
  final InventoryRepository repository;
  final ClinicMembership member;
  final String sale, shift;
  @override
  State<PartialReturnScreen> createState() => _PartialReturnScreenState();
}

class _PartialReturnScreenState extends State<PartialReturnScreen> {
  final quantity = TextEditingController(), reason = TextEditingController();
  List<Map<String, dynamic>>? lines;
  Map<String, dynamic>? selected, account;
  bool version2 = false;
  String method = 'efectivo';
  bool busy = false, restock = false, confirmed = false;
  String? error, retryKey, operation;
  @override
  void initState() {
    super.initState();
    load();
  }

  int generation = 0;
  bool current(int revision) => mounted && generation == revision;
  @override
  void didUpdateWidget(covariant PartialReturnScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.member.userId != widget.member.userId ||
        oldWidget.member.clinicId != widget.member.clinicId ||
        oldWidget.sale != widget.sale ||
        oldWidget.shift != widget.shift ||
        oldWidget.repository != widget.repository) {
      generation++;
      lines = null;
      selected = null;
      account = null;
      version2 = false;
      busy = false;
      restock = false;
      confirmed = false;
      error = null;
      retryKey = null;
      operation = null;
      quantity.clear();
      reason.clear();
      load();
    }
  }

  @override
  void dispose() {
    quantity.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final revision = generation;
    try {
      final raw = Map<String, dynamic>.from(
        await widget.repository.read('inv_sale_return_workspace', {
              'p_sale': widget.sale,
              'p_shift': widget.shift,
            })
            as Map,
      );
      if (!current(revision)) return;
      if (raw['clinic_id'] != widget.member.clinicId ||
          raw['actor_id'] != widget.member.userId) {
        throw StateError('session_changed');
      }
      if (current(revision)) {
        version2 = raw['schema_version'] == 2;
        account = version2
            ? Map<String, dynamic>.from(raw['account'] as Map)
            : null;
        setState(
          () => lines = (raw['lines'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
        );
      }
    } catch (_) {
      if (current(revision)) {
        setState(
          () => error =
              'Esta venta no está disponible para devolución parcial. Requiere turno propio abierto y permisos; se admiten productos no farmacológicos y servicios, con permisos adicionales para servicios.',
        );
      }
    }
  }

  void changed() => setState(() {
    confirmed = false;
    error = null;
  });
  Future<void> submit() async {
    if (busy || !confirmed || selected == null) return;
    final revision = generation;
    try {
      final amount = partialReturnQuote(selected!, quantity.text);
      final advanced = version2
          ? saleReturnQuote(selected!, quantity.text, account!)
          : null;
      if (reason.text.trim().isEmpty) {
        throw const FormatException('Indica el motivo de la devolución.');
      }
      final canonical = Quantity.parse(
        quantity.text,
      ).display(places: 9).replaceAll(',', '.');
      final key =
          '${selected!['id']}|$canonical|$method|$restock|${reason.text.trim()}|${amount.decimal}|${advanced?.refund.decimal}|${advanced?.commission.decimal}';
      if (retryKey != key) {
        retryKey = key;
        operation = newOperationId();
      }
      setState(() {
        busy = true;
        error = null;
      });
      await widget.repository.write(
        version2 ? 'inv_sale_return_v2' : 'inv_sale_return',
        {
          'p_sale': widget.sale,
          'p_shift': widget.shift,
          'p_line': selected!['id'],
          'p_quantity': canonical,
          'p_method': method,
          'p_restock': restock,
          'p_reason': reason.text.trim(),
          'p_expected_amount': amount.decimal,
          if (advanced != null) ...{
            'p_expected_refund': advanced.refund.decimal,
            'p_expected_commission': advanced.commission.decimal,
          },
          'p_actor': widget.member.userId,
          'p_operation': operation,
        },
      );
      if (mounted && revision == generation) Navigator.pop(context, true);
    } on FormatException catch (e) {
      if (current(revision)) setState(() => error = e.message);
    } catch (_) {
      if (current(revision)) {
        setState(
          () => error =
              'No se confirmó el registro. Revisa el historial antes de cambiar datos o iniciar otra devolución; reintentar los mismos datos conserva la operación.',
        );
      }
    } finally {
      if (current(revision)) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Money? quote;
    SaleReturnQuote? advanced;
    if (selected != null && quantity.text.isNotEmpty) {
      try {
        quote = partialReturnQuote(selected!, quantity.text);
        if (version2) {
          advanced = saleReturnQuote(selected!, quantity.text, account!);
        }
      } on FormatException {
        /* Shown on submission. */
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Devolución por líneas')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Productos no farmacológicos y servicios; admite ventas mixtas. No cambia el registro clínico. Primero reduce el saldo pendiente y solo reembolsa lo cobrado de más. Los servicios requieren administración y ajustan su comisión proporcionalmente.',
          ),
          if (busy || lines == null && error == null)
            const LinearProgressIndicator(),
          if (lines != null) ...[
            DropdownButtonFormField<Map<String, dynamic>>(
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Línea de la venta'),
              items: [
                for (final line in lines!)
                  DropdownMenuItem(
                    value: line,
                    child: Text(
                      '${line['name']} · lote ${line['lot']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: busy
                  ? null
                  : (value) => setState(() {
                      selected = value;
                      restock = false;
                      quantity.clear();
                      confirmed = false;
                      error = null;
                    }),
            ),
            if (selected != null)
              Text(
                'Vendida: ${selected!['quantity']} ${selected!['unit']} · Ya devuelta: ${selected!['returned_quantity']}',
              ),
            TextField(
              controller: quantity,
              enabled: !busy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Cantidad a devolver',
              ),
              onChanged: (_) => changed(),
            ),
            TextField(
              controller: reason,
              enabled: !busy,
              maxLength: 1000,
              decoration: const InputDecoration(labelText: 'Motivo'),
              onChanged: (_) => changed(),
            ),
            DropdownButtonFormField<String>(
              initialValue: method,
              decoration: const InputDecoration(
                labelText: 'Medio del importe devuelto',
              ),
              items: const [
                DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
                DropdownMenuItem(value: 'tarjeta', child: Text('Tarjeta')),
                DropdownMenuItem(
                  value: 'transferencia',
                  child: Text('Transferencia'),
                ),
              ],
              onChanged: busy
                  ? null
                  : (value) => setState(() {
                      method = value ?? method;
                      confirmed = false;
                    }),
            ),
            CheckboxListTile(
              value: restock,
              title: const Text(
                'Mercancía físicamente devuelta y apta para reingresar al mismo lote',
              ),
              onChanged: busy || selected?['kind'] == 'servicio'
                  ? null
                  : (value) => setState(() {
                      restock = value ?? false;
                      confirmed = false;
                    }),
            ),
            if (advanced != null) ...[
              Text('Importe cancelado: ${advanced.credit.display}'),
              Text(
                'Reducción del saldo pendiente: ${advanced.balanceReduction.display}',
              ),
              Text('Dinero a devolver al cliente: ${advanced.refund.display}'),
              Text(
                'Ajuste proporcional de comisión: ${advanced.commission.display}',
              ),
              const Text(
                'Los costos del servicio y su registro clínico se conservan. Un reintegro del colaborador se registra por separado.',
              ),
            ] else if (quote != null)
              Text('Importe a registrar: ${quote.display}'),
            CheckboxListTile(
              value: confirmed,
              title: Text(
                version2
                    ? 'Confirmo cantidad, motivo, saldo, comisión y dinero devuelto al cliente'
                    : 'Confirmo cantidad, motivo e importe que devolví al cliente',
              ),
              onChanged: busy
                  ? null
                  : (value) => setState(() => confirmed = value ?? false),
            ),
            FilledButton(
              onPressed: busy || !confirmed || selected == null ? null : submit,
              child: const Text('Registrar devolución'),
            ),
          ],
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }
}

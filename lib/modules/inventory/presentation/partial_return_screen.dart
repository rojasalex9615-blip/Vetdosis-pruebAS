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
  Map<String, dynamic>? selected;
  String method = 'efectivo';
  bool busy = false, restock = false, confirmed = false;
  String? error, retryKey, operation;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    quantity.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final raw = Map<String, dynamic>.from(
        await widget.repository.read('inv_sale_return_workspace', {
              'p_sale': widget.sale,
              'p_shift': widget.shift,
            })
            as Map,
      );
      if (raw['clinic_id'] != widget.member.clinicId ||
          raw['actor_id'] != widget.member.userId) {
        throw StateError('session_changed');
      }
      if (mounted) {
        setState(
          () => lines = (raw['lines'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Esta venta no está disponible para devolución parcial. Requiere turno propio abierto y permisos; solo se admiten ventas de productos no farmacológicos.',
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
    try {
      final amount = partialReturnQuote(selected!, quantity.text);
      if (reason.text.trim().isEmpty) {
        throw const FormatException('Indica el motivo de la devolución.');
      }
      final canonical = Quantity.parse(
        quantity.text,
      ).display(places: 9).replaceAll(',', '.');
      final key =
          '${selected!['id']}|$canonical|$method|$restock|${reason.text.trim()}|${amount.decimal}';
      if (retryKey != key) {
        retryKey = key;
        operation = newOperationId();
      }
      setState(() {
        busy = true;
        error = null;
      });
      await widget.repository.write('inv_sale_return', {
        'p_sale': widget.sale,
        'p_shift': widget.shift,
        'p_line': selected!['id'],
        'p_quantity': canonical,
        'p_method': method,
        'p_restock': restock,
        'p_reason': reason.text.trim(),
        'p_expected_amount': amount.decimal,
        'p_actor': widget.member.userId,
        'p_operation': operation,
      });
      if (mounted) Navigator.pop(context, true);
    } on FormatException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'No se confirmó el registro. Revisa el historial antes de cambiar datos o iniciar otra devolución; reintentar los mismos datos conserva la operación.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Money? quote;
    if (selected != null && quantity.text.isNotEmpty) {
      try {
        quote = partialReturnQuote(selected!, quantity.text);
      } on FormatException {
        /* Shown on submission. */
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Devolución parcial de productos')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Solo productos no farmacológicos. No modifica recetas, aplicaciones ni servicios. El importe se calcula sobre la venta original.',
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
              onChanged: busy
                  ? null
                  : (value) => setState(() {
                      restock = value ?? false;
                      confirmed = false;
                    }),
            ),
            if (quote != null) Text('Importe a registrar: ${quote.display}'),
            CheckboxListTile(
              value: confirmed,
              title: const Text(
                'Confirmo cantidad, motivo e importe que devolví al cliente',
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

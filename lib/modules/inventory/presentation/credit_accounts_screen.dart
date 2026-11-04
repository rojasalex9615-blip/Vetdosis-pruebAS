import 'package:flutter/material.dart';
import '../../auth/domain/clinic_membership.dart';
import '../../patients/presentation/patient_view_model.dart'
    show newOperationId;
import '../domain/inventory_models.dart';
import '../domain/inventory_repository.dart';
import 'partial_return_screen.dart';

class CreditAccountsScreen extends StatefulWidget {
  const CreditAccountsScreen({
    super.key,
    required this.repository,
    required this.member,
    required this.shift,
    required this.canReturn,
  });
  final InventoryRepository repository;
  final ClinicMembership member;
  final String shift;
  final bool canReturn;
  @override
  State<CreditAccountsScreen> createState() => _CreditAccountsScreenState();
}

class _CreditAccountsScreenState extends State<CreditAccountsScreen> {
  List<Map<String, dynamic>> rows = [];
  bool busy = false, more = false;
  String? error, selected, key, operation;
  int generation = 0;
  final amount = TextEditingController(), reference = TextEditingController();
  String method = 'efectivo';
  bool confirmed = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant CreditAccountsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.member.userId != widget.member.userId ||
        oldWidget.member.clinicId != widget.member.clinicId ||
        oldWidget.shift != widget.shift ||
        oldWidget.repository != widget.repository) {
      generation++;
      rows = [];
      selected = null;
      key = null;
      operation = null;
      amount.clear();
      reference.clear();
      confirmed = false;
      busy = false;
      load();
    }
  }

  @override
  void dispose() {
    generation++;
    amount.dispose();
    reference.dispose();
    super.dispose();
  }

  bool current(int revision) => mounted && revision == generation;
  Future<void> load({bool append = false}) async {
    final revision = generation;
    setState(() {
      busy = true;
      error = null;
      if (!append) {
        rows = [];
        more = false;
      }
    });
    try {
      final raw = Map<String, dynamic>.from(
        await widget.repository.read('inv_credit_accounts', {
              'p_clinic': widget.member.clinicId,
              'p_offset': append ? rows.length : 0,
            })
            as Map,
      );
      if (!current(revision)) return;
      if (raw['clinic_id'] != widget.member.clinicId ||
          raw['actor_id'] != widget.member.userId) {
        throw StateError('session_changed');
      }
      final page = (raw['items'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() {
        rows.addAll(page);
        more = page.length == 100;
      });
    } catch (_) {
      if (current(revision)) {
        setState(() {
          rows = [];
          more = false;
          error =
              'No se pudieron consultar las cuentas. Revisa conexión y permisos de consulta y cobro.';
        });
      }
    } finally {
      if (current(revision)) setState(() => busy = false);
    }
  }

  Future<void> collect() async {
    if (busy || !confirmed || selected == null) return;
    final revision = generation;
    try {
      final money = Money.parse(amount.text);
      final row = rows.firstWhere((r) => r['sale_id'] == selected);
      if (money.cents <= BigInt.zero ||
          money.cents > Money.parse('${row['account']['balance']}').cents ||
          reference.text.trim().isEmpty) {
        throw const FormatException(
          'Indica un abono positivo dentro del saldo y una referencia.',
        );
      }
      final payloadKey =
          '$selected|${widget.shift}|${money.decimal}|$method|${reference.text.trim()}';
      if (key != payloadKey) {
        key = payloadKey;
        operation = newOperationId();
      }
      setState(() {
        busy = true;
        error = null;
      });
      await widget.repository.write('inv_sale_collect', {
        'p_sale': selected,
        'p_shift': widget.shift,
        'p_amount': money.decimal,
        'p_method': method,
        'p_reference': reference.text.trim(),
        'p_actor': widget.member.userId,
        'p_operation': operation,
      });
      if (!current(revision)) return;
      setState(() {
        busy = false;
        selected = null;
        key = null;
        operation = null;
        confirmed = false;
        amount.clear();
        reference.clear();
      });
      await load();
    } on FormatException catch (e) {
      if (current(revision)) setState(() => error = e.message);
    } catch (_) {
      if (current(revision)) {
        setState(
          () => error =
              'No se confirmó el abono. Actualiza el historial antes de cambiar los datos; el mismo intento conserva la operación.',
        );
      }
    } finally {
      if (current(revision)) setState(() => busy = false);
    }
  }

  Future<void> returnSale(String sale) async {
    final revision = generation;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PartialReturnScreen(
          repository: widget.repository,
          member: widget.member,
          sale: sale,
          shift: widget.shift,
        ),
      ),
    );
    if (current(revision)) {
      setState(() {
        selected = null;
        confirmed = false;
      });
      await load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cuentas y abonos')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Registra únicamente dinero ya recibido. Cada abono conserva su medio y turno; no genera otra venta ni mueve inventario.',
        ),
        if (busy) const LinearProgressIndicator(),
        TextButton(
          onPressed: busy ? null : () => load(),
          child: const Text('Actualizar historial'),
        ),
        for (final row in rows)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${row['debtor']} · ${row['sale_id']}'),
                  Text(
                    'Venta neta: ${Money.parse('${row['account']['net_total']}').display} · Saldo: ${Money.parse('${row['account']['balance']}').display}',
                  ),
                  Text(
                    'Cobrado: ${Money.parse('${row['account']['paid']}').display} · Reembolsado: ${Money.parse('${row['account']['refunded']}').display}',
                  ),
                  for (final r in (row['returns'] as List? ?? []).cast<Map>())
                    Text(
                      'Devolución: ${Money.parse('${r['amount']}').display} · Dinero devuelto: ${Money.parse('${r['refund_amount']}').display} · Comisión ajustada: ${Money.parse('${r['commission_reduction']}').display} · ${r['reason']} · ${r['created_at']}',
                    ),
                  for (final c
                      in (row['collections'] as List? ?? []).cast<Map>())
                    Text(
                      'Abono ${Money.parse('${c['amount']}').display} · ${c['method']} · ${c['reference']} · ${c['created_at']}',
                    ),
                  if (Money.parse('${row['account']['balance']}').cents >
                      BigInt.zero)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              selected = row['sale_id'] as String;
                              confirmed = false;
                              amount.clear();
                              reference.clear();
                            }),
                      child: const Text('Registrar abono'),
                    ),
                  if (widget.canReturn)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => returnSale('${row['sale_id']}'),
                      child: const Text('Devolver líneas de esta venta'),
                    ),
                ],
              ),
            ),
          ),
        if (more)
          TextButton(
            onPressed: busy ? null : () => load(append: true),
            child: const Text('Cargar más cuentas'),
          ),
        if (selected != null) ...[
          Text('Abono para $selected'),
          TextField(
            controller: amount,
            enabled: !busy,
            decoration: const InputDecoration(labelText: 'Abono recibido MXN'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() => confirmed = false),
          ),
          TextField(
            controller: reference,
            enabled: !busy,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Referencia del abono',
            ),
            onChanged: (_) => setState(() => confirmed = false),
          ),
          DropdownButtonFormField<String>(
            initialValue: method,
            items: [
              for (final m in ['efectivo', 'tarjeta', 'transferencia'])
                DropdownMenuItem(value: m, child: Text(m)),
            ],
            onChanged: busy
                ? null
                : (v) => setState(() {
                    method = v!;
                    confirmed = false;
                  }),
          ),
          CheckboxListTile(
            value: confirmed,
            title: const Text(
              'Confirmo el importe y medio del dinero recibido',
            ),
            onChanged: busy
                ? null
                : (v) => setState(() => confirmed = v ?? false),
          ),
          FilledButton(
            onPressed: busy || !confirmed ? null : collect,
            child: const Text('Confirmar abono'),
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

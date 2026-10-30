import '../../core/domain/plan_errors.dart';
import 'package:flutter/material.dart';
import '../../doses/domain/quantity.dart';
import '../../prescribing/presentation/rx_entry_screen.dart';
import '../../patients/presentation/patient_view_model.dart'
    show newOperationId;
import '../domain/inventory_models.dart';
import '../domain/inventory_repository.dart';
import 'barcode_screen.dart';

String inventoryError(Object error) {
  final text = error.toString();
  final planMessage = planActionError(error);
  if (planMessage != null) return planMessage;
  if (text.contains('quantified_dispensing_professional_only')) {
    return 'Esta dispensación requiere un MVZ habilitado.';
  }
  if (text.contains('dispensing_authorized_quantity_exceeded')) {
    return 'La cantidad excede el total autorizado en ventas anteriores.';
  }
  if (text.contains('ordinary_dispensing_delegation_required')) {
    return 'Se requiere un permiso vigente para delegar esta dispensación.';
  }
  return 'No se pudo completar la operación. Comprueba conexión y permisos antes de reintentar.';
}

class SaleScreen extends StatefulWidget {
  const SaleScreen({
    super.key,
    required this.repository,
    required this.shift,
    required this.products,
    required this.prescriptions,
    required this.staff,
    required this.admin,
    this.charges = const [],
    this.deliveries = const [],
    this.acts = const [],
    this.scanBarcode,
  });
  final InventoryRepository repository;
  final String shift;
  final List<Map<String, dynamic>> products, prescriptions, staff;
  final bool admin;
  final List<Map<String, dynamic>> charges, deliveries, acts;
  @visibleForTesting
  final Future<String?> Function(BuildContext context)? scanBarcode;
  @override
  State<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends State<SaleScreen> {
  final lines = <Map<String, dynamic>>[];
  String method = 'efectivo', operation = newOperationId();
  String cashInput = '';
  String? error;
  bool busy = false, reviewed = false;

  Money get total => lines.fold(
    Money(BigInt.zero),
    (a, l) => a + Money.parse(l['price'] as String).times(Quantity.parse(l['quantity'] as String)),
  );

  Money? get cashReceived {
    if (cashInput.isEmpty) return null;
    try {
      return Money.parse(cashInput.replaceAll(',', '.'));
    } catch (_) {
      return null;
    }
  }

  Money? get change {
    final received = cashReceived;
    if (received == null) return null;
    return Money(received.cents - total.cents);
  }

  void changed() {
    reviewed = false;
    operation = newOperationId();
    error = null;
  }

  void onKey(String key) {
    setState(() {
      if (key == 'C') {
        cashInput = '';
      } else if (key == '⌫') {
        if (cashInput.isNotEmpty) {
          cashInput = cashInput.substring(0, cashInput.length - 1);
        }
      } else if (key == '.') {
        if (!cashInput.contains('.')) {
          cashInput = cashInput.isEmpty ? '0.' : '$cashInput.';
        }
      } else {
        final parts = cashInput.split('.');
        if (parts.length == 2 && parts[1].length >= 2) return;
        cashInput = (cashInput == '0') ? key : '$cashInput$key';
      }
      error = null;
    });
  }

  Future<void> scanProduct() async {
    final code = widget.scanBarcode != null
        ? await widget.scanBarcode!(context)
        : await Navigator.push<String>(
            context,
            MaterialPageRoute<String>(
              builder: (_) => const BarcodeScreen(),
            ),
          );
    if (!mounted || code == null) return;
    final normalized = code.trim();
    final matches = widget.products.where(
      (p) =>
          p['active'] == true &&
          p['m8_enabled'] == true &&
          p['codigo_barras']?.toString().trim() == normalized,
    ).toList();

    if (matches.length != 1) {
      final message = matches.isEmpty
          ? 'No encontré un producto activo con el código escaneado. Revisa el código de barras en inventario.'
          : 'El código de barras está asignado a más de un producto. Corrige el inventario antes de vender.';
      setState(() => error = message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    setState(() => error = null);
    // Reutiliza el flujo de venta manual: elegir lote y cantidad, revisar y
    // confirmar el cobro. Escanear nunca modifica el inventario por sí solo.
    await addProduct(matches.single);
  }

  Future<void> addProduct(Map<String, dynamic> p) async {
    final lots = (p['lots'] as List)
        .map((e) => Map<String, dynamic>.from(e))
        .where((l) => l['expired'] != true && Quantity.parse(l['cantidad'] as String).positive)
        .toList();
    final rx = widget.prescriptions
        .where((r) => r['product_version_id'] == p['medication_version_id'])
        .toList();
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RxEntryScreen(
          title: 'Agregar ${p['nombre']}',
          fields: [
            RxField(
              'lot',
              'Lote exacto',
              type: 'select',
              required: true,
              options: {
                for (final l in lots)
                  l['id'] as String:
                      '${l['lote']} · ${l['cantidad']} · ${l['caducidad'] ?? 'sin fecha'}',
              },
            ),
            const RxField(
              'quantity',
              'Cantidad de stock (no dosis)',
              type: 'quantity',
              required: true,
            ),
            if (p['m8_kind'] == 'farmaco')
              RxField(
                'rx',
                'Receta emitida / producto exacto',
                type: 'select',
                required: true,
                options: {
                  for (final r in rx)
                    r['id'] as String:
                        '${r['folio'] ?? 'Receta ordinaria'} · ${r['prescription_id']}',
                },
              ),
          ],
          submit: (d, _) async {
            final q = Quantity.parse(d['quantity'] as String);
            if (['unidad', 'frasco', 'caja'].contains(p['stock_unit']) &&
                q.n % q.d != BigInt.zero) {
              throw const FormatException('Cantidad entera por envase.');
            }
            final lot = lots.firstWhere((l) => l['id'] == d['lot']);
            setState(() {
              lines.add({
                'kind': 'producto',
                'item_id': p['id'],
                'lot_id': lot['id'],
                'quantity': d['quantity'],
                'price': p['precio_venta'],
                'prescription_item_id': d['rx'],
                'display': p['nombre'],
                'lot_display': lot['lote'],
                'unit': p['stock_unit'],
              });
              changed();
            });
          },
        ),
      ),
    );
  }

  Future<void> addService() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RxEntryScreen(
          title: 'Servicio manual',
          fields: [
            const RxField('name', 'Servicio', required: true),
            const RxField('quantity', 'Cantidad', type: 'quantity', required: true),
            const RxField('price', 'Precio unitario MXN', required: true),
            const RxField('cost', 'Costo total capturado MXN', required: true),
            const RxField('commission', 'Comisión total capturada MXN', required: true),
            RxField(
              'professional_id',
              'Profesional de la clínica',
              type: 'select',
              options: {
                for (final s in widget.staff)
                  s['id'] as String: '${s['label'] ?? s['id']} · ${s['role']}',
              },
            ),
          ],
          submit: (d, _) async {
            for (final key in ['price', 'cost', 'commission']) {
              d[key] = Money.parse(d[key] as String).decimal;
            }
            setState(() {
              lines.add({...d, 'kind': 'servicio', 'display': d['name']});
              changed();
            });
          },
        ),
      ),
    );
  }

  Future<void> post() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.write('inv_sale_post', {
        'p_shift': widget.shift,
        'p_method': method,
        'p_lines': [
          for (final l in lines)
            Map<String, dynamic>.from(l)
              ..remove('display')
              ..remove('lot_display')
              ..remove('unit'),
        ],
        'p_expected_total': total.decimal,
        'p_operation': operation,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = inventoryError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String get methodLabel => switch (method) {
        'efectivo' => 'Efectivo',
        'tarjeta' => 'Tarjeta',
        'transferencia' => 'Transferencia',
        _ => method,
      };

  Widget _methodChip(String value, String label, IconData icon) {
    final selected = method == value;
    final theme = Theme.of(context);
    const accent = Color(0xFF2BBBAD);
    return Expanded(
      child: Material(
        color: selected
            ? accent.withValues(alpha: 0.18)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: busy
              ? null
              : () => setState(() {
                    method = value;
                    changed();
                  }),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: selected ? accent : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? accent : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cartLine(int index) {
    final line = lines[index];
    final lineTotal = Money.parse(line['price'] as String)
        .times(Quantity.parse(line['quantity'] as String));
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF9B6DFF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              line['kind'] == 'producto'
                  ? Icons.medication_outlined
                  : Icons.medical_services_outlined,
              color: const Color(0xFF9B6DFF),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${line['display']}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${line['quantity']} ${line['unit'] ?? 'servicio'}'
                  '${line['lot_display'] != null ? ' · Lote ${line['lot_display']}' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            lineTotal.display,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          IconButton(
            tooltip: 'Quitar del carrito',
            onPressed: busy
                ? null
                : () => setState(() {
                      lines.removeAt(index);
                      changed();
                    }),
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const accent = Color(0xFF2BBBAD);
    const indigo = Color(0xFF5B8DEF);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Caja registradora'),
        actions: [
          IconButton(
            tooltip: 'Escanear código de barras',
            onPressed: busy ? null : scanProduct,
            icon: const Icon(Icons.qr_code_scanner),
          ),
          if (widget.admin)
            IconButton(
              tooltip: 'Agregar servicio manual',
              onPressed: busy ? null : addService,
              icon: const Icon(Icons.add_business_outlined),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                Text(
                  'Carrito actual',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (lines.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.shopping_bag_outlined,
                          size: 40,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Aún no hay artículos. Agrega productos o servicios abajo.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  for (var i = 0; i < lines.length; i++) _cartLine(i),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.22),
                        indigo.withValues(alpha: 0.18),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Total a pagar',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            total.display,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: indigo,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Método de pago',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _methodChip('efectivo', 'Efectivo', Icons.payments_outlined),
                    const SizedBox(width: 8),
                    _methodChip('tarjeta', 'Tarjeta', Icons.credit_card),
                    const SizedBox(width: 8),
                    _methodChip(
                      'transferencia',
                      'Transferencia',
                      Icons.swap_horiz,
                    ),
                  ],
                ),
                if (method == 'efectivo') ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Recibido', style: theme.textTheme.labelMedium),
                              Text(
                                cashReceived?.display ??
                                    (cashInput.isEmpty ? r'$0.00' : '\$$cashInput'),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: (change != null &&
                                    change!.cents >= BigInt.zero)
                                ? accent.withValues(alpha: 0.15)
                                : theme.colorScheme.errorContainer
                                    .withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Cambio', style: theme.textTheme.labelMedium),
                              Text(
                                change == null ? '—' : change!.display,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: change != null &&
                                          change!.cents < BigInt.zero
                                      ? theme.colorScheme.error
                                      : accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _NumericKeypad(onKey: busy ? null : onKey),
                ],
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Agregar al carrito',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Venta en MXN. El servidor confirma lote, stock, precio y permisos al cobrar.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                for (final p in widget.products.where(
                  (p) => p['m8_enabled'] == true && p['active'] == true,
                ))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: accent.withValues(alpha: 0.15),
                      child: const Icon(
                        Icons.medication_liquid_outlined,
                        color: accent,
                        size: 20,
                      ),
                    ),
                    title: Text('${p['nombre']}'),
                    subtitle: Text(
                      '${Money.parse(p['precio_venta']).display} · ${p['stock_unit']} · stock ${p['stock']}',
                    ),
                    trailing: IconButton.filledTonal(
                      onPressed: busy ? null : () => addProduct(p),
                      icon: const Icon(Icons.add),
                    ),
                  ),
                if (widget.charges.isNotEmpty ||
                    widget.acts.isNotEmpty ||
                    widget.deliveries.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Cobrar aplicaciones y entregas ya registradas',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  for (final entry in [
                    ...widget.charges
                        .where((c) => c['paid'] != true)
                        .map((c) => (c, 'charge_id')),
                    ...widget.acts
                        .where((c) => c['paid'] != true)
                        .map((c) => (c, 'service_act_id')),
                    ...widget.deliveries
                        .where((c) => c['paid'] != true)
                        .map((c) => (c, 'delivery_id')),
                  ])
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${entry.$1['name']}'),
                      subtitle: Text(displayMoney(entry.$1['price'])),
                      trailing: IconButton(
                        onPressed: busy
                            ? null
                            : () {
                                if (lines.any(
                                  (l) => l[entry.$2] == entry.$1['id'],
                                )) {
                                  return;
                                }
                                setState(() {
                                  lines.add({
                                    'kind': 'servicio',
                                    entry.$2: entry.$1['id'],
                                    'quantity': '1',
                                    'price': entry.$1['price'],
                                    'display': entry.$1['name'],
                                  });
                                  changed();
                                });
                              },
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ),
                ],
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: reviewed,
                  title: const Text(
                    'Revisé cantidades, lotes, receta y total a cobrar.',
                  ),
                  onChanged: busy
                      ? null
                      : (v) => setState(() => reviewed = v ?? false),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: indigo,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: busy ||
                          !reviewed ||
                          lines.isEmpty ||
                          (method == 'efectivo' &&
                              cashInput.isNotEmpty &&
                              (change == null || change!.cents < BigInt.zero))
                      ? null
                      : post,
                  child: Text(
                    busy
                        ? 'Registrando…'
                        : 'Cobrar · ${total.display} · $methodLabel',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumericKeypad extends StatelessWidget {
  const _NumericKeypad({this.onKey});
  final void Function(String key)? onKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['.', '0', '⌫'],
    ];
    return Column(
      children: [
        for (final row in keys)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                for (var i = 0; i < row.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: Material(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: onKey == null ? null : () => onKey!(row[i]),
                        onLongPress: onKey == null || row[i] != '⌫'
                            ? null
                            : () => onKey!('C'),
                        child: SizedBox(
                          height: 48,
                          child: Center(
                            child: Text(
                              row[i],
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onKey == null ? null : () => onKey!('C'),
            child: const Text('Limpiar'),
          ),
        ),
      ],
    );
  }
}

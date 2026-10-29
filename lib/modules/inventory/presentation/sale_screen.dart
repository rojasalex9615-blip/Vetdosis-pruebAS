import '../../core/domain/plan_errors.dart';
import 'package:flutter/material.dart';
import '../../doses/domain/quantity.dart';
import '../../prescribing/presentation/rx_entry_screen.dart';
import '../../patients/presentation/patient_view_model.dart'
    show newOperationId;
import '../domain/inventory_models.dart';
import '../domain/inventory_repository.dart';

String inventoryError(Object error) {
  final planMessage = planActionError(error);
  if (planMessage != null) return planMessage;
  final text = error.toString();
  const messages = {
    'explicit_permission_required':
        'Falta un permiso vigente para esta acción. Actualiza o consulta con la administración.',
    'inventory_read_permission_required':
        'Tu acceso de consulta a inventario no está vigente.',
    'cash_collection_permission_required':
        'Cobrar requiere un permiso vigente de caja.',
    'verified_dispensing_permission_required':
        'Dispensar requiere MVZ habilitado y permiso vigente; cobrar una entrega ya registrada es un acto separado.',
    'dispensing_limit_reauthorization_required':
        'El MVZ responsable debe revisar y autorizar nuevamente la cantidad; el límite histórico no concede autoridad.',
    'dispensing_limit_authority_changed':
        'La autorización de cantidad perdió vigencia. Actualiza y solicita revisión del MVZ responsable.',
    'legacy_delivery_delegation_disabled':
        'Las delegaciones antiguas no habilitan dispensación. Se requiere habilitación profesional y permiso por persona.',
    'controlled_or_unverified_stock_adjustment_denied':
        'Este producto controlado o sin clasificación verificada no admite ajustes libres.',
    'dispensing_quantity_authorization_required':
        'El MVZ responsable debe autorizar la cantidad total de stock a dispensar para esta receta.',
    'dispensing_authorized_quantity_exceeded':
        'La cantidad supera el total autorizado para esta receta, incluyendo ventas anteriores.',
    'application_already_paid':
        'Esta aplicación ya tiene un cobro activo. Actualiza antes de cobrar.',
    'delivery_already_paid': 'Esta entrega ya tiene un cobro activo.',
    'application_tariff_required':
        'El administrador debe configurar el precio por aplicación.',
    'use_current_application_record':
        'Usa la corrección vigente del registro clínico.',
    'expired_lot_blocked':
        'Lote caducado o sin caducidad exigida; dispensación bloqueada.',
    'insufficient_stock':
        'El stock cambió o no alcanza. Actualiza el inventario.',
    'sale_price_changed': 'El precio cambió. Actualiza antes de cobrar.',
    'sale_total_changed':
        'El total no coincide. Revisa el carrito antes de cobrar.',
    'closed_shift': 'El turno está cerrado. Abre un turno nuevo.',
    'verified_medication_reference_required':
        'Falta clasificación verificada de la presentación comercial. No se dispensa.',
    'quantified_dispensing_professional_only':
        'Solo un MVZ habilitado puede dispensar este producto.',
    'issued_matching_prescription_required':
        'Selecciona una receta emitida de esta presentación exacta.',
    'ordinary_dispensing_delegation_required':
        'Se requiere permiso vigente del MVZ responsable para este caso.',
    'whole_package_required':
        'La venta por envase requiere una cantidad entera.',
    'cash_discrepancy_reason_required':
        'Explica la diferencia entre efectivo esperado y contado.',
    'product_revision_conflict_or_legacy':
        'El producto cambió o necesita revisión de sus saldos anteriores.',
    'legacy_stock_reconciliation_required':
        'El stock anterior no coincide con los lotes; requiere conciliación antes de habilitarlo.',
    'inventory_admin_required':
        'Esta operación requiere administrador de la clínica.',
    'controlled_reversal_professional_only':
        'Este reverso requiere un administrador con habilitación profesional.',
    'vial_inventory_identity_mismatch':
        'El frasco, producto, lote o unidad no coinciden.',
    'reorder_below_minimum':
        'El punto de reorden debe ser igual o mayor al stock mínimo.',
    'operation_content_changed':
        'La operación anterior tenía otros datos. Actualiza y vuelve a revisar.',
  };
  for (final e in messages.entries) {
    if (text.contains(e.key)) return e.value;
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
  });
  final InventoryRepository repository;
  final String shift;
  final List<Map<String, dynamic>> products, prescriptions, staff;
  final bool admin;
  final List<Map<String, dynamic>> charges, deliveries, acts;
  @override
  State<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends State<SaleScreen> {
  final lines = <Map<String, dynamic>>[];
  String method = 'efectivo', operation = newOperationId();
  String? error;
  bool busy = false, reviewed = false;
  Money get total => lines.fold(
    Money(BigInt.zero),
    (a, l) =>
        a +
        Money.parse(
          l['price'] as String,
        ).times(Quantity.parse(l['quantity'] as String)),
  );
  void changed() {
    reviewed = false;
    operation = newOperationId();
    error = null;
  }

  Future<void> addProduct(Map<String, dynamic> p) async {
    final lots = (p['lots'] as List)
        .map((e) => Map<String, dynamic>.from(e))
        .where(
          (l) =>
              l['expired'] != true &&
              Quantity.parse(l['cantidad'] as String).positive,
        )
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
            final already = lines
                .where((l) => l['lot_id'] == lot['id'])
                .fold(
                  Quantity.parse('0'),
                  (a, l) => Quantity(
                    a.n * Quantity.parse(l['quantity']).d +
                        Quantity.parse(l['quantity']).n * a.d,
                    a.d * Quantity.parse(l['quantity']).d,
                  ),
                );
            if (Quantity(
                  already.n * q.d + q.n * already.d,
                  already.d * q.d,
                ).compareTo(Quantity.parse(lot['cantidad'])) >
                0) {
              throw const FormatException(
                'El lote no alcanza para el carrito.',
              );
            }
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
            const RxField(
              'quantity',
              'Cantidad',
              type: 'quantity',
              required: true,
            ),
            const RxField('price', 'Precio unitario MXN', required: true),
            const RxField('cost', 'Costo total capturado MXN', required: true),
            const RxField(
              'commission',
              'Comisión total capturada MXN',
              required: true,
            ),
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
            if (Money.parse(d['commission']).cents > BigInt.zero &&
                d['professional_id'] == null) {
              throw const FormatException(
                'Selecciona al profesional para la comisión.',
              );
            }
            if (Money.parse(d['commission']).cents >
                Money.parse(
                  d['price'],
                ).times(Quantity.parse(d['quantity'])).cents) {
              throw const FormatException('La comisión supera el importe.');
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
    final accent = const Color(0xFF2BBBAD);
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
    final accent = const Color(0xFF2BBBAD);
    final indigo = const Color(0xFF5B8DEF);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Caja registradora'),
        actions: [
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
                      Text(
                        'Total a pagar',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        total.display,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: indigo,
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
                      child: Icon(
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
                  onPressed:
                      busy || !reviewed || lines.isEmpty ? null : post,
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

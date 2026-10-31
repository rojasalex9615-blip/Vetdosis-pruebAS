# Devoluciones parciales de productos

Entrega apilada sobre PR #44. Permite devolver cantidades de una línea de una
venta compuesta exclusivamente de productos no farmacológicos sin comisión.
Excluye ventas mixtas, servicios, medicamentos, recetas y aplicaciones.
Los cobros parciales de clientes y ajustes de comisiones por devolución parcial
siguen pendientes; este flujo no intenta resolverlos.

El usuario requiere sales.reverse y sales.collect, turno propio abierto y sesión
vigente. Confirma cantidad, motivo, importe y medio del dinero ya devuelto.
Registrar no ejecuta reembolsos bancarios. El importe procede del precio original
con redondeo acumulativo exacto; el servidor contrasta la cotización mostrada.
Por defecto no reingresa mercancía. Solo una confirmación de devolución física y
aptitud restaura cantidad al lote original y revierte su costo proporcional.
La mercancía dañada conserva su costo como pérdida, sin aumentar existencias.

Los recibos idempotentes y bloqueos de clínica, turno y venta impiden duplicación
por reintentos y concurrencia. Tras cualquier devolución parcial se bloquea el
reverso total; el resto de unidades se devuelve mediante este mismo flujo.
El registro es inmutable; una corrección requiere un flujo auditable futuro.

El movimiento afecta el turno y fecha de devolución, sus medios de cobro, CSV,
estadísticas, tendencias de productos y respaldo operacional. Los importes de
cortes cerrados permanecen congelados. El estado de devolución de cada venta es
contexto actual separado del corte. El respaldo personal no amplía su alcance.
La interfaz ofrece la acción solo cuando el backend anuncia soporte.

## Validación y entrega

- Flutter: redondeo por centavos, límites/unidades, sesión incorrecta,
  confirmación, reingreso desactivado y reintento tras respuesta perdida.
- PostgreSQL aislado: límites, idempotencia, cotización/sesión, inventario,
  costo de mercancía dañada, medios, cortes congelados, respaldo y permisos.
- Concurrencia: dos devoluciones de una unidad y devolución parcial frente a
  reverso completo producen exactamente un registro de devolución.
- Ejecución: `bash supabase/tests/run_partial_product_returns.sh`. Incluye los
  contratos financieros anteriores y la carrera de reintegros de comisiones.

Migración candidata generada con Supabase CLI:
`supabase/migrations/20261027024532_partial_product_returns.sql`.
Requiere la cadena de inventario/permisos/respaldo y la migración de PR #44.
No aplicada a Pruebas ni producción. Falta revisión, integración y prueba real
con APK consolidada, dos clínicas y sus permisos.

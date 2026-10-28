# Liquidación de comisiones de servicios

`13B5_service_commission_settlements.sql` y luego
`13B6_service_commission_fk_indexes.sql` se instalan después de 13B4 en
Supabase **Pruebas**. La pantalla «Mi cuenta y clínicas» muestra a cada
colaborador sus comisiones: servicios todavía sin cobrar, servicios cobrados
pendientes de liquidar y pagos registrados. El administrador ve la misma
consulta para el equipo y puede registrar la liquidación de cada servicio
cobrado, después de confirmar que entregó el dinero. Se guarda importe
congelado del acto, medio, referencia opcional, autor y hora del servidor.

Una venta cobrada no marca la comisión como pagada. Solo una liquidación
registrada la retira del saldo pendiente. La operación es idempotente y
una comisión no puede liquidarse dos veces. Los registros son inmutables.
Una devolución posterior conserva el pago y muestra que requiere revisión;
no genera automáticamente un cargo al colaborador ni altera la caja.

La consulta y la escritura son RPC con autorización del servidor. Una
persona solo puede leer sus propios servicios; el administrador puede leer
los de la clínica y necesita además `service.manage` para registrar pagos.
La tabla no concede lectura ni escritura directa a `authenticated`.
La pantalla carga 200 movimientos por página, con los no liquidados primero;
los saldos se calculan sobre todo el historial. El nombre y el sufijo del ID
identifican al colaborador antes de confirmar cada pago. Las comisiones manuales que no estén
vinculadas a un acto de servicio del catálogo quedan fuera de este flujo.

Este módulo registra pagos hechos fuera de VetDosis. No transfiere fondos,
no crea una nómina fiscal ni calcula impuestos. La prueba SQL cubre permiso
individual, cobro previo, doble intento, historial tras devolución e
inmutabilidad.

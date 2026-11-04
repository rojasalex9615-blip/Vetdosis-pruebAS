# Reintegros recibidos de comisiones por venta revertida

Primera entrega contable independiente, sobre PR #43. No cierra cobros ni
devoluciones parciales de clientes: siguen pendientes. Se aplica a los reversos
totales de venta que ya existen.

## Registro explícito

Un administrador con permiso service.manage puede registrar dinero que ya
recibió del colaborador, vinculado al pago original de una comisión cuya venta
fue revertida. Exige importe positivo exacto, medio, motivo y confirmación.
Admite varios reintegros parciales hasta el importe originalmente pagado.
No declara una deuda, descuenta salarios ni mueve efectivo automáticamente.
La entrada de caja se registra por separado; las referencias permiten conciliarla.

El pago original y los nuevos registros son inmutables. El colaborador puede
consultar su propio historial, pero no registrar reintegros. La cuenta muestra
el total recibido y los últimos 20 movimientos por comisión. No borra ni reduce
el importe histórico de la comisión pagada. Las correcciones de captura y
contrapartidas adicionales quedan pendientes de un flujo auditable específico.

Las operaciones se serializan por pago y tienen recibo idempotente. La interfaz
conserva la misma operación al reintentar un importe con formato decimal distinto.
Los cambios de usuario/clínica/rol descartan respuestas anteriores y parámetros
pendientes de la pantalla.

## Respaldos

El respaldo operacional de clínica ahora añade pagos de comisiones y reintegros,
con los mismos controles de autorización del exportador existente. La tabla de
pagos no estaba en su listado anterior. El respaldo personal no se amplía con
datos de otros colaboradores. Esto no equivale a restauración integral validada.

## Migración candidata

Generada con Supabase CLI:
`supabase/migrations/20261027021257_service_commission_recoveries.sql`.
Requiere el contrato 13B5/13B6 y el exportador de respaldo 13O ya instalados.
No ejecutar db push sobre una base sin reconciliar las propuestas anteriores.
No se aplicó a Pruebas ni producción. La migración incluye RLS, revocación de
acceso directo, índices, auditoría y controles de permiso en los RPC.

## Pruebas

15 pruebas Flutter de reintegros, permisos de interfaz, respuesta tardía entre
clínicas, reintento tras respuesta perdida y respaldo protegido aprobadas.
Flutter analyze sin incidencias.

PostgreSQL 17 aislado: operación idempotente, bloqueo de exceso/cero y venta no
revertida, historial propio, inmutabilidad, exportación financiera y permisos.
Dos reintegros simultáneos de 7 sobre un pago de 10: se acepta uno y se rechaza
el otro. Suites previas de permisos de operaciones/comisiones también pasan.

CI añade estas consultas antes de publicar el artefacto de preview. Pendientes
revisión y validación de negocio con dos clínicas y la APK consolidada.

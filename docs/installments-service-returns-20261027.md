# Abonos y devoluciones de servicios y ventas mixtas

Cambio apilado sobre PR #45. Migración candidata generada con Supabase CLI:
`supabase/migrations/20261027031218_installments_service_returns.sql`.
No aplicada a Pruebas ni producción. No integra ni publica una APK firmada.

## Cobros parciales

Una venta nueva puede tener abono inicial, incluso cero, y saldo pendiente. El
cajero identifica al titular mediante una referencia interna de hasta 200
caracteres; no constituye un contrato de crédito ni identifica automáticamente
un tutor/paciente. Requiere sales.collect y turno propio abierto. La consulta
completa de cuentas exige también sales.read. Cada pago registra importe, medio,
referencia, actor, fecha y turno. No se aceptan sobrepagos ni importes negativos.

El alta invoca la validación original de venta e inventario en la misma
transacción. Los abonos posteriores no generan otra venta ni descuentan stock.
La cuenta y sus movimientos son inmutables; el saldo se deriva de sus registros.
Las ventas anteriores sin cuenta siguen considerándose pagadas íntegramente.

El total vendido y su costo se reconocen al registrar la venta. Efectivo,
tarjeta y transferencia solo suman dinero efectivamente recibido, menos
reembolsos por ese medio. Una venta de $100 con abono de $40 aumenta ventas en
$100, pagos recibidos en $40 y saldo por cobrar en $60. La interfaz y nota PDF
distinguen estos importes. No se conectan procesadores bancarios.

## Devoluciones y comisiones

Admite productos no farmacológicos y servicios, incluidos carritos mixtos de
ambos. Una línea puede devolverse por cantidad, con redondeo acumulativo sobre
su importe original. Cualquier venta con medicamentos, recetas, cargos por
aplicación o entregas clínicas queda fuera de esta ampliación.

Una devolución primero cancela principal pendiente. Solo el exceso ya cobrado
se registra como dinero devuelto. Ejemplos para una venta de $100 y abono de $40:

- Cancelar $25 deja venta neta $75, saldo $35 y reembolso $0.
- Cancelar $80 deja venta neta $20, saldo $0 y reembolso $20.

La pantalla muestra importe cancelado, reducción de saldo, dinero devuelto y
ajuste de comisión por separado. El servidor contrasta todos los importes antes
de guardar. Solo el producto físicamente recibido y apto, confirmado por el
usuario, vuelve al lote original. Un servicio nunca reingresa a inventario,
conserva sus costos y no modifica el registro clínico de su realización.

Los servicios requieren administrador y service.manage, además de los permisos
de devolución/cobro. Se aplica una regla proporcional explícita sobre la comisión
original, incluso si la regla original era bono fijo. Ejemplo: devolver la mitad
de una línea con comisión original $20 reduce la comisión vigente a $10.
La regla se muestra antes de confirmar y queda documentada en el registro.

No se liquida comisión hasta cobrar el total neto de la venta completa: no hay
asignación de abonos a líneas individuales. La liquidación posterior registra
la comisión vigente, no la original. Si el colaborador ya recibió un pago mayor,
se conserva intacto y se admite registrar dinero efectivamente reintegrado hasta
la diferencia. No declara una deuda, descuenta salarios ni genera entradas de
caja automáticamente. El acto de servicio y su comisión original se conservan.

Los reversos completos de cuentas a crédito y de ventas de servicios dentro de
este alcance se bloquean: se usa la devolución
por líneas, que conoce cuánto se cobró realmente. Los clientes anteriores solo
pueden devolver productos de ventas pagadas sin servicios mediante el contrato
viejo; deben actualizar para cuentas, servicios y ventas mixtas.

## Historial y seguridad

Cada movimiento afecta el turno/fecha en que ocurre. Se incluyen abonos,
créditos, reembolsos y reducciones de comisión en corte, CSV e historial de la
cuenta. Las estadísticas de venta usan el importe neto cancelado, no solo el
dinero reembolsado. Los cortes cerrados conservan sus importes; el saldo actual
de cada venta se muestra como contexto separado.

El respaldo operacional incluye cuentas y abonos, además de la tabla de
devoluciones ampliada y los registros previos de comisiones. No amplía el
respaldo personal. No equivale a una recuperación integral ya validada.

Las funciones verifican actor, clínica, permisos vigentes y turno propio.
RLS y revocación de acceso directo protegen las tablas. Los recibos idempotentes
conservan las operaciones ante reintentos; los importes usan centavos exactos.
Los bloqueos comunes de clínica, turno y venta serializan cobros, devoluciones,
reversos y liquidaciones. La interfaz descarta respuestas de una sesión/clínica
anterior y conserva el recibo al reintentar el mismo importe con otro formato.

## Validación y pendientes

`bash supabase/tests/run_installments_service_returns.sh` ejecuta PostgreSQL
sin red con las cadenas financieras anteriores, migración candidata y pruebas
de cuentas, medios, límites, idempotencia, sesiones, cortes congelados, respaldo,
servicios, comisiones originales/vigentes y reintegros. Incluye carreras reales
entre abonos y entre abono/devolución. Valida servicios del catálogo con los
contratos 14D y 14F; 14F es necesario para vender del catálogo con precio especial.

Flutter verifica cotizaciones exactas, confirmaciones, límites, sesión/clínica,
reintentos, stock desactivado para servicios y el límite de reintegro proporcional.

Falta revisión, integración y validación con APK consolidada y dos clínicas.
Se mantienen fuera correcciones auditables de capturas, sobrepagos, descuentos
negociados, vinculación formal de deudor/tutor, cartera con intereses/vencimientos,
CFDI/notas fiscales, reversión clínica y control de fármacos. Las cuentas se
consultan por páginas; su historial no se edita ni elimina.

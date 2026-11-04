# Estado de entrega hospitalaria y reutilización de token FCM

Propuesta sobre PR #42; sin despliegue SQL ni Edge Functions.

## Estado de servidor

La propuesta 14J conserva el workspace anterior como función privada con
acceso revocado a roles de cliente. Un wrapper público con los mismos argumentos
llama esa función (incluyendo sus comprobaciones de permisos) y añade
runtime.external_delivery_enabled. Se mantienen enabled, last_run_at, acciones
y el resto del contenido. El cliente deja de interpretar un campo ausente como
entrega apagada cuando en realidad estaba habilitada.

## Token OAuth FCM

El transporte reutiliza en memoria un único token OAuth de Google mientras
queden más de 60 segundos de vigencia. Usa expires_in, limitado a una hora; si
Google omite ese campo, utiliza una hora como respaldo. Proyecto, correo de
cuenta de servicio y huella de la clave forman la identidad de caché: cambios
de configuración no reutilizan un token de otra identidad. La caché no guarda
claves privadas como índices ni se persiste en archivos o tablas.

No se almacenan errores como tokens ni se reutiliza un token vencido tras un
fallo de renovación. El comportamiento de adquisición original se conserva si
no hay una entrada válida. No cambia la autenticación de Drive o de Supabase.

## Verificación

- Nueve tests Node aprobados: transporte, autenticación, reutilización,
  renovación anticipada, cambios de identidad y fallos al renovar.
- Deno check del entrypoint hospital-delivery aprobado.
- PostgreSQL 17 local: estado de entrega false/true, conservación de campos
  anteriores y rechazo de anon aprobados dentro de las suites hospitalarias.
- También pasan permisos/concurrencia de resolución, aislamiento, cuidados,
  automatización, transferencia FCM, reintentos, turnos e historial.

Pendiente revisión de la propuesta, CI, migración incremental según esquema
remoto y prueba real de entrega con dos clínicas/dispositivos. No se afirma
hospitalización cerrada por pasar estas pruebas locales.

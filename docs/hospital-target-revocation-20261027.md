# Revocación de destinos FCM y reintentos agotados

Propuesta sobre PR #41, sin aplicar SQL a proyectos remotos.

## Cambios

- Al registrar un destino FCM o rotar a uno existente, se revocan los registros
  activos del mismo token pertenecientes a otros usuarios, después de validar
  identidad, permisos y consentimiento. Se conservan otros dispositivos, los
  registros del mismo usuario en otras clínicas y los destinos WhatsApp.
- Un bloqueo transaccional por token serializa registros simultáneos para que
  dos cuentas no dejen activo el mismo destino. También se limpia un duplicado
  heredado cuando se renueva sin cambiar el token.
- El claim finaliza como dead/lease_expired los leases vencidos con ocho
  intentos. No adelanta el vencimiento del último intento ni elimina el
  último reintento disponible después del séptimo.
- La prueba de entrega asocia resultados por canal, evitando depender del
  orden aleatorio de IDs.

## Cobertura real en PostgreSQL local

El runner anterior no ejecutaba las pruebas SQL de entrega externa. Ahora
HOSPITAL_TEST_CHANNELS=1 aplica las propuestas 14J/14K/14L y ejecuta entrega,
revocación propia, transferencia entre usuarios y canales. Los tests de
transferencia y dispositivos revierten su fixture para no contaminar otros.

Se añade una prueba concurrente en una base clonada dentro del contenedor de
pruebas. Dos cuentas registran el mismo destino; se exige un único usuario
activo. La base clonada se elimina al terminar.

Comando ejecutado con éxito:

```
HOSPITAL_TEST_CHANNELS=1 HOSPITAL_TEST_DUTY=1 HOSPITAL_TEST_HISTORY=1 bash supabase/tests/run_hospital_automation.sh
```

Incluye permisos y concurrencia de resolución, aislamiento, cuidados,
automatización, transferencia FCM, turnos e historial. Usa PostgreSQL 17 local
sin red. La preview requiere estas pruebas antes de publicar su artefacto.

## Pendientes

No hay despliegue a Pruebas ni producción, envíos reales, cambios en alarmas
locales ni activación del reparto por turnos. Los archivos siguen siendo SQL
candidato; al promoverlos habrá que revisar el esquema remoto y preparar las
migraciones incrementales correspondientes. Sigue pendiente la revisión del
conjunto y QA real de dos clínicas/dispositivos.

# Por qué el respaldo a Drive no funciona en el APK

Verificado el 2026-11-18 sobre `integracion/todo-en-uno-muse-20261118`.

## Respuesta corta

El código del respaldo a Drive **existe y está completo**, pero **no puede
funcionar en el APK que produce el CI**. No es un fallo de programación: es un
problema de configuración de Google. Hay tres bloqueos, y basta uno para que
falle.

## Bloqueo 1: el SHA-1 cambia en cada compilación

Google exige que el cliente OAuth de Android esté atado al **SHA-1 del
certificado** con el que se firma la APK. Si el SHA-1 no coincide, el teléfono
rechaza la autorización.

El pipeline compila con `flutter build apk --debug`. Flutter genera un
almacén de claves de depuración **nuevo en cada contenedor**, y el CI no lo
guarda en caché (la caché solo cubre `.flutter` y `.pub-cache`).

Comprobado con dos APK reales descargados de pipelines correctos:

| Job | Rama | SHA-1 de firma |
|---|---|---|
| 18094970169 | `fix/pantalla-roja-boundary-20261115-gl` | `A4:97:4D:34:90:3E:14:38:0A:A5:F5:A3:F6:08:0F:57:51:05:A0:48` |
| 18090760111 | `integracion/todo-en-uno-20261116` | `04:7E:C4:E8:34:D8:0E:34:77:63:98:18:E8:2F:4D:01:C2:17:7A:EC` |

Dos compilaciones, dos huellas distintas. Consecuencia: **ninguna APK del CI
podrá autorizar Drive**, porque el SHA-1 de mañana no será el de hoy. Aunque se
registre la huella actual en Google Cloud, la siguiente compilación la invalida.

Esto ya estaba anotado como pendiente en `docs/drive-backup-authorization.md`
(«una APK debug usa otro certificado y no acredita OAuth»). Aquí queda
confirmado con medición.

## Bloqueo 2: falta la variable del Client ID

El pipeline pasa:

```
--dart-define=GOOGLE_DRIVE_WEB_CLIENT_ID="${GOOGLE_DRIVE_WEB_CLIENT_ID:-}"
```

La variable **no existe** entre las variables de CI/CD del proyecto (hay cinco:
`SUPABASE_TEST_PUBLISHABLE_KEY`, `GCP_PROJECT_ID`, `GCP_SERVICE_ACCOUNT`,
`GCP_SERVICE_ACCOUNT_KEY`, `GCP_REGION`). Se compila vacía.

El código tiene un valor por defecto escrito a mano
(`137670819-4skobkrkoqpk3leupqmns4aav5aahkpb.apps.googleusercontent.com`), así
que en la práctica se usa ese. Pero el valor vacío indica que nadie configuró
nada a propósito, y ese ID por defecto nunca se contrastó contra una APK
firmada.

## Bloqueo 3: `google-services.json` no declara cliente OAuth

`android/app/src/beta/google-services.json` pertenece al proyecto
`vetdosis-pro-155db` y su paquete `io.github.alexcore123r.vetdosis.beta` tiene
`oauth_client: []` (lista vacía). El flujo pide `serverClientId` de forma
explícita, así que no depende de ese archivo, pero confirma que el cliente
OAuth de Android no está registrado en la configuración que viaja en el APK.

## Qué sí está bien

- `drive_backup_authorization.dart`: pide cuenta, cierra sesión previa (no
  reutiliza cuenta entre clínicas) y pide el alcance `drive.file`.
- `drive_backup_client.dart`: sube solo archivos cifrados, descarga por ID y
  compara longitud y SHA-256. Si no coincide, avisa de que la copia **pudo
  quedar creada** y no la borra.
- `backup_screen.dart`: exige contraseña y confirmación antes de autorizar.
- 9 pruebas de Drive pasan, pero usan dobles de prueba: verifican la lógica, no
  el servicio real de Google.

## Qué haría falta para que funcione

1. **Firmar la APK con un certificado fijo** (no el de depuración) y guardar ese
   almacén como variable protegida del CI. Sin esto, nada más importa.
2. Registrar en Google Cloud el **SHA-1 de ese certificado fijo** para el
   paquete `io.github.alexcore123r.vetdosis.beta`.
3. Configurar `GOOGLE_DRIVE_WEB_CLIENT_ID` como variable de CI en vez de
   depender del valor escrito a mano.
4. Añadir las cuentas de prueba en la pantalla de consentimiento (si la app
   OAuth sigue en estado «Pruebas»).
5. Probar en un teléfono real: autorizar, ver el archivo en Drive y abrirlo con
   la contraseña.

## Límite de esta nota

No se modificó el código ni la configuración de Google. Es un diagnóstico con
evidencia: sin un certificado fijo, el respaldo a Drive seguirá fallando en
cualquier APK del CI, y esto no se arregla programando.

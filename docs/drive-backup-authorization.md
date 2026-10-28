# Copia cifrada autorizada en Google Drive (Android)

Base: consolidación `37392447dd263cd012c78f41513d1b648703dae6` (PR #36).
La pantalla Respaldo ofrece «Guardar copia cifrada en Drive» en Android. Exige
contraseña y reconocimiento de acceso restringido. Solicita cuenta Google y
confirmación del destino por copia y alcance; revalida permisos antes de subir.
No guarda una asociación permanente entre cuenta Google y clínica.

El token se usa en memoria; no se guarda en la base clínica, preferencias,
archivo ni logs. El SDK gestiona su autorización nativa y se cierra su sesión
local al terminar. Cerrar sesión no revoca el permiso concedido en Google;
puede revocarse en la cuenta Google, apartado conexiones con terceros.
No cambia el inicio de sesión de Supabase.

## Configuración pública confirmada por la responsable

- OAuth Web / serverClientId:
  `137670819-4skobkrkoqpk3leupqmns4aav5aahkpb.apps.googleusercontent.com`.
- OAuth Android:
  `137670819-o7oo9hcue4ao9logpsnsncq8rkt8bi61.apps.googleusercontent.com`.
- Paquete beta: `io.github.alexcore123r.vetdosis.beta`.
- El cliente Android debe coincidir con el SHA-1 del certificado de la APK
  instalada. La huella configurada en Cloud aún requiere contraste con la
  próxima APK firmada; una APK debug usa otro certificado y no acredita OAuth.
- Drive API habilitada y permiso `https://www.googleapis.com/auth/drive.file`.
- En consentimiento Externo/Pruebas, añadir los correos de prueba autorizados.
- Nunca incorporar el secreto OAuth Web: no se necesita para el flujo nativo.
- El ID Web se puede sustituir al compilar con `GOOGLE_DRIVE_WEB_CLIENT_ID`.
- La configuración Firebase FCM existente pertenece a otro proyecto; este
  flujo declara serverClientId explícitamente y no cambia FCM.

## Integridad y límites

Solo se envía el archivo .vetbackup ya cifrado con el mecanismo existente.
Se crea un archivo nuevo, sin permisos públicos ni identificadores clínicos en
el nombre. Se descarga por ID y se compara longitud y SHA-256 con el original.
Si falla la comprobación se informa «NO quedó verificada»; el archivo puede
existir y no se borra ni se reintenta automáticamente. Verificar un hash no
prueba que el contenido del respaldo sea completo ni restaurable.

Esta es una copia manual del respaldo operacional, no un respaldo automático
ni una restauración integral PostgreSQL+Storage. iOS y web conservan el flujo
manual existente; no se habilita OAuth Drive allí en esta entrega.

## Comprobación en dispositivo (pendiente)

1. Instalar beta firmada cuyo certificado corresponda al cliente Android.
2. En clínica A, autorizar una copia con una cuenta de prueba. Confirmar archivo
   en Mi unidad y mensaje de descarga/SHA-256 comprobados.
3. Cancelar contraseña, selector de cuenta y confirmación: no crear copia.
4. Cambiar a clínica B: exigir nueva selección/confirmación, sin reutilizar
   destino ni mostrar resultados de A. Cambiar sesión durante operación cancela
   la pantalla y cierra su cliente HTTP.
5. Revocar permisos de respaldo, permiso Google, desconectar red y simular
   cuota insuficiente: no anunciar éxito ni reintentar automáticamente.
6. Descargar .vetbackup desde Drive y abrirlo con la contraseña en «Revisar
   respaldo para recuperación». Contraseña nunca se envía a Google.

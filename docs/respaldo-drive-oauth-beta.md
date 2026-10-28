# Drive autenticado para respaldos cifrados (beta Android)

## Alcance

La persona con permiso de respaldo vincula una cuenta Google en el teléfono, autoriza `drive.file` y sube un archivo `.vetbackup` cifrado con contraseña. La app comprueba tamaño y MD5 de la respuesta de Drive y descarga el archivo para comparar SHA-256 antes de confirmar la copia. El vínculo usuario/clínica/cuenta se guarda en este dispositivo; los tokens de Google y la contraseña no se envían al servidor VetDosis. Desconectar solicita la revocación del permiso y borra el vínculo local; los archivos ya subidos permanecen en Drive. Esta función requiere abrir la app y conexión. No reemplaza el respaldo programado de PostgreSQL y Storage ni la restauración ensayada del servidor.

## Activación en Google Cloud y GitHub

1. Abrir el proyecto de Google Cloud asociado al Firebase beta `vetdosis-pro-155db` y habilitar **Google Drive API**.
2. Configurar la pantalla de consentimiento OAuth. Agregar `https://www.googleapis.com/auth/drive.file` y, si la aplicación sigue en pruebas, registrar las cuentas Google de las personas que probarán Drive. Revisar las condiciones de publicación de Google antes de ofrecer la función fuera de la beta.
3. En **Google Auth Platform → Clients** crear o localizar un cliente OAuth de tipo **Aplicación web**. Copiar únicamente el **Client ID** terminado en `.apps.googleusercontent.com`; no copiar ni subir el client secret.
4. Confirmar el cliente OAuth Android para `io.github.alexcore123r.vetdosis.beta` con el SHA-1 del certificado de **firma beta de GitHub Actions**. No usar el SHA-1 de debug ni Play si se probará el APK de Actions. Volver a descargar `google-services.json` beta si Google/Firebase lo exige para el cliente Android. No sustituir la configuración de producción.
5. En GitHub, repositorio `Vet-dosis-pruebas`, **Settings → Secrets and variables → Actions → Variables**, crear `GOOGLE_DRIVE_WEB_CLIENT_ID` con el Client ID web. El workflow de beta lo pasa como `--dart-define`; si la variable falta, la app muestra que Drive aún requiere configuración y mantiene disponible la exportación manual.
6. Compilar una beta desde el commit consolidado que incluya también la rama visual/clínica. Probar conectar, subir un respaldo cifrado, verificarlo en Drive, consultar historial, desconectar/revocar y volver a conectar con otra cuenta. Probar además falta de red, cuota, permiso revocado y cuenta distinta.

El inicio de sesión Google de Firebase/Supabase y el permiso `drive.file` son autorizaciones distintas. El `google-services.json` beta previo tiene `oauth_client` vacío; por sí solo no activa Drive.

## Límites actuales

- Los archivos se crean en el Drive de la cuenta elegida; `drive.file` limita la app a los archivos que ella crea o abre.
- El historial se filtra por el identificador de clínica guardado como metadato del archivo. La cuenta Google podría acceder a archivos de varias clínicas; los permisos de VetDosis se comprueban al generar cada respaldo.
- La contraseña del `.vetbackup` debe conservarse por separado. La verificación de descarga comprueba integridad, pero no prueba una restauración completa.
- El vínculo local no constituye autorización OAuth de servidor ni permite respaldos automáticos en Drive con la app cerrada.

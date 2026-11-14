# Google login: proyecto de pruebas

Supabase: wtrelwtztkddfktrfdpb. El flujo actual es OAuth de navegador mediante Supabase, no SDK nativo Google. Por eso se crea cliente OAuth de tipo aplicación web, aunque se pruebe en Android. No requiere configurar SHA del APK para este flujo.

1. Abrir https://console.cloud.google.com/ y crear/seleccionar proyecto para VetDosis pruebas.
2. En Google Auth Platform (o APIs y servicios → Pantalla de consentimiento OAuth), configurar marca/nombre VetDosis Pro Pruebas y correos de soporte/desarrollador. Audiencia externa si no es una organización interna. Mantener estado de prueba y añadir las dos cuentas Google de prueba en usuarios de prueba. No añadir permisos de Drive; login usa identidad básica.
3. En Clientes/Credenciales, crear ID de cliente OAuth de tipo Aplicación web. URI de redireccionamiento autorizado EXACTO:
   https://wtrelwtztkddfktrfdpb.supabase.co/auth/v1/callback
   Comprobarlo también en la pantalla Google de Supabase. No poner aquí el esquema móvil.
4. Guardar Client ID y Client Secret exclusivamente en Supabase → Authentication → Sign In / Providers → Google. Activar proveedor y guardar. No pegar secreto en chat, repositorio ni variables de APK. No cambiar opciones de seguridad como saltar nonce o permitir usuarios sin correo salvo justificación independiente.
5. Supabase → Authentication → URL Configuration → Redirect URLs: añadir exactamente
   com.vetdosis.pro://login-callback/
   Cuando se publique web, añadir su URL exacta. No inventar dominio ni usar comodines generales.
6. Avisar que Google y redirect están guardados. Codex comprobará configuración pública de Auth y ejecutará Compilar APK de pruebas con enable_google=true. El flujo se niega a habilitar el botón si Supabase no anuncia Google habilitado. Esta comprobación no valida el secreto ni toda la configuración Google.
7. Probar con cuentas autorizadas: navegador → selección cuenta → Supabase → app, sesión y membresías del usuario correcto. Confirmar casos de correo ya registrado y cuenta nueva sin dar roles automáticamente. Nunca atribuir habilitación MVZ por login Google.

Antes del lanzamiento se revisan marca, dominio/contacto, aviso de privacidad, URLs web y requisitos de publicación de Google que correspondan. Las pruebas con audiencia restringida pueden preceder dominio propio. No se activa acceso a Drive para respaldos por configurar login Google.

Los APK actuales usan firma debug del runner, que puede cambiar entre ejecuciones. Antes de reemplazar instalación evaluar firma persistente o desinstalación controlada; no prometer actualización que conserve caché hasta resolverlo.

## Revisión del 12 de noviembre de 2026: por qué no aparece o no regresa

Consultado en la configuración de Auth del proyecto de pruebas, sin cambiar nada:

- El proveedor Google **sí está activado** y tiene Client ID y secreto guardados (pasos 1 a 4 hechos).
- La lista de **Redirect URLs está vacía** y `site_url` sigue en `http://localhost:3000`. Falta el paso 5. Sin él, al terminar con Google, Supabase manda al navegador a `localhost` y la sesión nunca vuelve a la app.
- El paso 5 de arriba nombra `com.vetdosis.pro://login-callback/`, pero el APK beta **no usa ese esquema**. Usa el de su paquete (`lib/modules/core/domain/build_channel.dart` y `AndroidManifest.xml`):

  ```
  io.github.alexcore123r.vetdosis.beta://login-callback/
  ```

  Ese es el que hay que agregar en Supabase → Authentication → URL Configuration → Redirect URLs. El de `com.vetdosis.pro` solo aplica a una compilación que no sea del canal beta.
- El botón «Inicio con Google» solo se dibuja si el APK se compiló con `enable_google` marcado (`build-apk-main.yml` o `build-test-apk.yml`). `build-debug-apk.yml` y `.gitlab-ci.yml` lo dejan fijo en `false`: un APK salido de ahí nunca lo muestra.

No se modificó la configuración de Supabase desde la sesión que hizo esta revisión: el cambio queda para quien administra el proyecto.

# Estado del respaldo a Drive: qué falta de verdad

Corregido el 2026-11-18. La primera versión de esta nota decía que «ninguna APK
podrá autorizar Drive» porque el SHA-1 cambia en cada compilación. **Eso era
falso para el APK que importa.** Medí el APK de pruebas (debug) y saqué
conclusiones sobre todo el sistema. Ale señaló el error y aquí queda corregido.

## Lo que ya está hecho y no hay que rehacer

- **OAuth integrado en el código**: `DriveBackupAuthorization` pide cuenta,
  cierra la sesión previa y solicita `drive.file`. Hay un segundo flujo con
  cuenta vinculada (`GoogleDriveBackupClient`) con historial y desconexión.
- **Firma fija para release**: `android/app/build.gradle.kts` **prohíbe** firmar
  release con el certificado de depuración. Si faltan los secretos
  `ANDROID_BETA_*`, la compilación falla a propósito.
- **Verificación de la huella**: `scripts/android/check_keystore.py` compara el
  certificado real con la huella pública `ANDROID_BETA_CERT_SHA256` y aborta si
  no coinciden. Ese valor existe en las variables de GitHub Actions.
- **Workflow de release firmado**: `.github/workflows/build-apk-main.yml`
  compila `flutter build apk --release --flavor beta` con el keystore fijo y
  verifica la firma con `scripts/android/verify_apk.py`.

Es decir: la pieza difícil del OAuth (certificado estable + huella comprobada)
**ya está resuelta**. El SHA-1 no cambia entre releases porque el keystore es el
mismo.

## Lo que faltaba y ya está corregido

El release **no pasaba el Client ID de Drive**: en `build-apk-main.yml` la orden
incluía `--dart-define=APP_CHANNEL=beta` y `--dart-define-from-file=...`, pero no
`--dart-define=GOOGLE_DRIVE_WEB_CLIENT_ID=...`.

Al arreglarlo apareció un defecto peor, que era el causante real del fallo en el
APK de GitLab. Comprobado con Dart:

```
sin define            -> "ID-POR-DEFECTO"   (usa defaultValue)
define vacío          -> ""                 (ANULA defaultValue)
define con valor      -> "REAL-ID"
```

GitLab pasa la variable **siempre**, aunque no exista, y la pasa vacía. Eso
**anulaba el valor por defecto** y dejaba `serverClientId` en cadena vacía. El
`defaultValue` de `String.fromEnvironment` no protege de ese caso.

Corregido en `drive_backup_authorization.dart`: el ID se resuelve con una
comparación explícita contra vacío, y `GoogleDriveBackupClient` reutiliza el
mismo valor en vez de leer el define por su cuenta. Así los dos flujos coinciden
y ninguno recibe un ID vacío. Cubierto por `test/drive_client_id_test.dart`, que
pasa con define ausente, vacío y con valor.

También se añadió el `--dart-define` al build de release, con la variable
`GOOGLE_DRIVE_WEB_CLIENT_ID` en GitHub Actions. Mientras esa variable no exista,
el respaldo usa el ID público confirmado; en cuanto se cree, manda la variable.

## Lo que no puedo afirmar

No he probado el OAuth en un teléfono real. Por tanto no sé si el cliente OAuth
de Android ya está registrado en Google Cloud con el SHA-1 del certificado beta,
ni si la pantalla de consentimiento tiene las cuentas de prueba. Eso solo se
verifica instalando la beta firmada y autorizando.

El `google-services.json` del paquete beta tiene `oauth_client: []`, pero el
flujo declara `serverClientId` explícitamente, así que ese archivo no decide el
resultado.

## Qué queda

1. ~~Pasar el Client ID al build de release~~: hecho.
2. ~~Evitar que un define vacío anule el ID~~: hecho y probado.
3. Probar en teléfono: autorizar, ver el archivo en Drive y abrirlo con la
   contraseña. **Sigue pendiente y es lo único que falta para decir que
   funciona.**

## Sobre el APK de pruebas

El pipeline de GitLab compila `--debug`, y ahí sí cambia el SHA-1 en cada
compilación (medido: `A4:97:4D:...` y `04:7E:C4:...` en dos jobs). Ese APK no
sirve para validar Drive. No invalida el OAuth: solo indica que la vista previa
debug no es el artefacto con el que se prueba esta función.

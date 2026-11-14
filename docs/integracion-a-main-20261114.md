# Integración a `main` e incidencias — 2026-11-14

Nota local para no perder el hilo. Estado: **pendiente de aprobación del orden**.
No se ha fusionado nada a `main`.

## 1. Compilación #3067915169 — diagnosticada y corregida

- Pipeline `3067915169`, job `apk-depuracion` (id `18030132894`), rama
  `feature/avicultura-postura-m15`, SHA `0afa59c`. Resultado: **failed**.
- Causa: `test/aviculture_records_test.dart:174` usaba `find.text('Caseta 1')`.
  La tarjeta de parvada compone casa y línea genética en **un solo** `Text`
  (`'Caseta 1 · Lohmann Brown'`) y la sección «Casetas» queda fuera del `ListView`
  visible, así que nunca se construye. `find.text` exige coincidencia exacta.
- **El fallo era de la prueba, no de la pantalla.** No se tocó producción.
- Arreglo: `find.textContaining('Caseta 1')`. Commit `f47fae4`, subido a
  `origin/feature/avicultura-postura-m15`. Suite de esa rama: 752 pasan, 1 omitida.
- El resto del pipeline (analyze, pub get) no falló por esta causa.

## 2. Integración a `main` — pendiente de orden aprobado

Pedido: integrar a `main` las ramas **exportadas para probar en el teléfono**,
del 13-nov hacia atrás, en un orden que no rompa ramas ni visualización.

Evidencia disponible: el CI de este repo es **manual** (`workflow.rules` solo
`web`/`api`), así que **un pipeline = un APK construido a propósito**. Último
pipeline por rama (fuente: API de GitLab):

| Fecha | Estado | Rama |
| --- | --- | --- |
| 2026-11-14 | failed | feature/avicultura-postura-m15 (ya corregida) |
| 2026-11-13 | success | claude/espacio-personal-duplicado-qdipjy |
| 2026-11-12 | success | claude/icons-constants-notifications-nb53v5 |
| 2026-11-12 | success | ccr-0f0a9753-f1m11o |
| 2026-11-11 | success | integracion/apk-completo-20261111 |
| 2026-11-11 | success | feature/laboratorio-20261110 |
| 2026-11-11 | failed | feature/small-animals-clinic-admin |
| 2026-11-11 | success | feature/catalog-review-scopes |
| 2026-11-11 | success | tema/morado-primario-20261108 |
| 2026-11-11 | success | fix/security-anon-grants-20261110 |
| 2026-11-11 | success | fix/ci-drive-oauth-define-20261110 |
| 2026-11-11 | success | fix/lab-value-ceiling-reviewed-20261110 |
| 2026-11-10 | success | fix/lab-value-ceiling-20261110 |
| 2026-11-09 | success | fix/stable-materialapp-identity |
| 2026-11-08 | success | apk/beta-20261108 |
| 2026-11-08 | success | propuesta/precios-busqueda-20261108 |
| 2026-11-08 | success | ccr-22dd3e42-xrykk6 |

Riesgos detectados (topología real, no supuesta):

- Las ramas están **apiladas**: `audit/combined-notif-production-20261110` es
  ancestro de 14 ramas; `integracion/apk-completo-20261111` es ancestro de 6.
  Fusionar un padre **antes** que un hijo puede invalidar el hijo.
- `main` está **protegida** (push/merge nivel 40). El MR `!13`
  (`apk/beta-20261108` → `main`) ya está abierto y es fusionable.
- 13 MRs abiertos; 5 ramas ya están fusionadas a `main`.

Acción: **no fusionar sin aprobar el orden.** Falta confirmar la lista exacta y
el orden deseado.

## 3. Acuerdo de trabajo del tablón (verificado)

Enlace aportado por Ale:
https://github.com/rojasalex9615-blip/Vetdosis-pruebAS/issues/31#issuecomment-6680638203
(autor `rojasalex9615-blip`, 2026-11-06 08:29 UTC). No es una decisión de
«no dejar integrar a Ale». Es un **acuerdo de interpretación y de estados**.
Lo esencial, casi literal:

- «Un clic, una reacción o una acción accidental en la interfaz **no se considera
  evidencia de revisión, aprobación técnica, aceptación de cambios ni autorización
  para fusionar**.»
- «Nadie debe afirmar que un trabajo está terminado, integrado o validado basándose
  únicamente en una acción de Ale en GitHub.»
- «La aprobación técnica debe apoyarse en revisión del código, pruebas y evidencia
  verificable.»
- «Si una acción implica integrar código, modificar la rama principal, cerrar una
  propuesta o cambiar el estado oficial del proyecto, el equipo debe verificar
  primero que existe la revisión y evidencia necesarias.»
- Estados a distinguir: propuesto, en revisión, aprobado, fusionado, verificado.

**Consecuencia para la integración a `main`:** para fusionar hace falta revisión
técnica y evidencia (pruebas), no solo un «adelante». Esto no bloquea el trabajo;
fija **cómo** se aprueba cada fusión.

Lectura honesta: el comentario **no dice** que Ale no pueda integrar ni que sus
revisiones no se acepten. Dice que sus acciones en GitHub (clics) no valen como
aprobación técnica. Es una diferencia importante; se registra tal como está, sin
exagerarla en ningún sentido.

Nota de método: mi búsqueda previa no lo halló porque busqué el texto literal
«no dejar integrar a Ale», que el comentario no contiene. Queda corregido aquí.

## 4. Integración de las ramas — conflicto semántico de tema (2026-11-14)

Al fusionar todas las ramas en una sola (`integracion/rc-20261114`, base
`2beae7b`, sin tocar `main`) apareció un conflicto que Git **no** marcó como tal,
porque los bloques no se solapaban textualmente. Es el tipo de fallo que solo
sale al ejecutar las pruebas.

- La rama `tema/morado-primario-20261108` (11-nov 01:16) añade la prueba
  `Dark purple primary text maintains WCAG AA contrast`, que fija el primario por
  defecto a `#B69BFF`. Esa prueba se escribió contra el diseño de `main`, que
  **forzaba `primary` a mano** (`dark ? #B69BFF : VetColors.purple`).
- El commit `bca56d8` —«Ajustes: el tono por omisión vuelve al verdeazulado»
  (11-nov 07:27, autor Alex, «Ale lo pidió así viendo el morado ya aplicado»)—
  es **posterior** y está en la columna vertebral (13-nov). Ahí se **elimina** el
  forzado de `primary` y el esquema pasa a `ColorScheme.fromSeed`, con la paleta
  «Turquesa» en el índice 0. El comentario del propio `theme()` lo dice literal:
  «ya no hace falta escoger a mano el #B69BFF de oscuro ni el #2A1055».
- La prueba `Dark purple…` **no existe** en `main`, ni en `apk/beta-20261108`, ni
  en la columna vertebral: solo en `tema/morado`. Afirma un comportamiento que el
  trabajo posterior eliminó.

Resolución: se conserva el código posterior (semilla → `ColorScheme.fromSeed`) y
la prueba pasa a comprobar lo que sigue siendo cierto —el tema oscuro por defecto
mantiene 4.5:1 entre `primary` y `onPrimary`— sin fijar un color concreto. El
contraste de las cinco paletas en los dos brillos ya lo cubre `platform_review_test`.

Además se corrigió un **import duplicado** en `lib/core/app.dart`
(`starter_help_panel.dart`, líneas 49 y 97) que la fusión introdujo y que
`flutter analyze` marcaba como warning.

Segundo fallo real del merge: `pubspec.lock` quedó con bloques duplicados
(archivo generado). Se restauró a la versión de `apk/beta-20261108`, que es la
que usa el CI (Flutter 3.47.6).

Verificación (Flutter 3.47.6, la del CI; el local 3.50.0 rompe el paquete
`image` y produce 68 fallos de compilación ajenos al código):

- `flutter analyze`: **No issues found**.
- `flutter test`: **882 pruebas pasan, 1 omitida, 0 fallos**.


# Chat de IA: historial lateral y separación de la IA de soporte

## Actualización 2026-11-13 (segunda sesión) — separación en datos y panel lateral

La primera entrega separó las pantallas (la ayuda dejó de abrir el Asistente),
pero la **causa de datos** seguía: `ai_chats` guardaba en la misma tabla el chat
del asistente, la ayuda incluida y los borradores de soporte, y `ai_dashboard`
los listaba juntos. Con Postgres 17 se comprobó: aparecían "Chat real",
"Ayuda de soporte" y "Ayuda incluida · Primeros pasos" mezclados en el historial
del asistente.

Cambios de esta sesión:

- `ai_chats.kind` (`assistant` / `help` / `support`). `ai_chat_create` recibe el
  tipo; el borrador de soporte se crea con `kind=support` y la ayuda incluida
  (`starter_ai_prepare`) con `kind=help`. Migración:
  `supabase/proposed/16B_ai_chat_kinds.sql`.
- La pantalla del asistente filtra el historial por `kind` (`AiViewModel.history`).
  El chat abierto (soporte/ayuda) se resuelve por id (`chatById`) sin entrar al
  historial. El servidor no se toca en `ai_dashboard` a propósito: ya devuelve
  `kind` en cada fila y 13P lo recrea, así que redefinirlo aquí perdería
  `can_manage`.
- Historial lateral: riel de 260 px en pantalla ancha; en teléfono, antes chips,
  ahora **panel lateral deslizante** (botón «Historial», `showModalBottomSheet`).

Verificación: `flutter test` completo 895 pruebas (EXIT=0); suite SQL
`supabase/tests/run.sh ai_plans` pasa; nueva prueba `supabase/tests/ai_chat_kinds.sql`;
`flutter analyze` sin errores nuevos.

Publicación: rama `integracion/rc-20261114` (no `main`), commits `6940377`
(IA) y `2354c4d` (porcino reubicado), subidos a GitLab. Nota en el issue #1
de GitLab (id 4235789345).

Límites: no probado en teléfono físico ni desplegado.

Actualización 2026-11-14 (tercera sesión): **sí hay acceso de escritura a
GitHub** en esta sesión (el token autentica como `rojasalex9615-blip` con
`admin`/`push` en `rojasalex9615-blip/Vetdosis-pruebAS`). Queda corregido el
límite anterior: la novedad se publicó en el tablón de GitHub #31
(comentario id 6882067738) y ya no está solo en el espejo de GitLab.

---

## Primera sesión — estado previo (2026-11-13)

Estado: **publicado en GitLab** (2026-11-13). El tablero
[GitHub issue #31](https://github.com/rojasalex9615-blip/Vetdosis-pruebAS/issues/31)
sigue **sin** actualizarse: desde esta sesión no hay escritura en GitHub (sin
`GITHUB_TOKEN`; el token disponible solo sirve para GitLab). La novedad se
registró en el tablón de GitLab,
[issue #1](https://gitlab.com/rojasalex9615/vetdosispro/-/work_items/1), y el
código se subió a `apk/beta-20261108`. Falta replicar en GitHub cuando haya
acceso. No se notificó a nadie por GitHub.

## Contexto

El encargo de Ale tenía dos partes:

1. Corregir la aserción de Flutter en `dashboard`
   (`InheritedElement.notifyDependent`, `framework.dart:6430`) que además
   "duplica pantalla encima de la otra".
2. Crear la pantalla del chat de IA y mostrar su historial lateralmente, porque
   "la atención a clientes con IA se mezcló con el chat con IA de la app".

## Parte 2 — ENTREGADO (en esta rama de trabajo)

Repositorio `Vetdosis-pruebAS` / rama local (aún sin publicar). Archivos:

- `lib/modules/ai/presentation/ai_screen.dart` (historial lateral; ya sin el panel de ayuda)
- `lib/modules/ai/presentation/starter_help_panel.dart` (muestra la respuesta en el propio panel)
- `lib/modules/support/presentation/support_screen.dart` (ranura `helpPanel`)
- `lib/core/app.dart` (rellena la ranura desde el repositorio de IA)
- `test/ai_plans_test.dart`, `test/platform_review_test.dart`,
  `test/support_welcome_test.dart`

Cambios:

- **Historial lateral.** En pantallas anchas (≥ 720 px) el historial de chats se
  muestra como panel lateral (`_AiHistoryRail`), con selección por lista,
  "Nuevo chat" y "Actualizar historial". En teléfono se mantiene una fila de
  chips encima de la conversación. La elección es por ancho con
  `MediaQuery.sizeOf`, sin ramas por plataforma.
- **Separación soporte ↔ app.** La ayuda de uso de la app (`StarterHelpPanel`)
  se muda a «Ayuda y soporte», que es su sitio, y muestra su respuesta ahí
  mismo: ya no entrega un id de chat que abra el Asistente, así que las dudas de
  uso ya no dejan entradas en el historial de conversaciones. Entra por ranura
  (`SupportScreen.helpPanel`) que rellena `app.dart`, para que soporte no
  dependa del módulo de IA. Una consulta de soporte o un borrador
  (`initialDraft`/`returnDraft`) que reutiliza `AiScreen` tampoco comparte el
  historial de chats de la app.
- Avisos de uso y privacidad de la pantalla de IA agrupados en un widget
  `_AiNotice` para que se lean como avisos.

Verificación realizada (Flutter 3.50.0, Dart 3.14.0):

- `flutter analyze`: solo avisos `deprecated_member_use` de `package:flutter/
  material.dart` (preexistentes en todo el repo tras el SDK 3.50.0); sin errores
  ni avisos nuevos en los archivos tocados.
- `flutter test` completo: 816 pruebas pasan (`+816 ~1: All tests passed!`),
  incluidas cuatro nuevas:
  - "Wide layout shows the history as a lateral rail and switching chats loads
    its messages".
  - "A support/draft query does not share the app chat history".
  - "Support screen shows the injected app-help slot before the ticket form".
  - "Support screen hides the app-help slot when none is injected".
  - Y las dos de `platform_review_test` pasan a comprobar que la respuesta se ve
    en la propia ayuda, no que entregue un id para abrir el Asistente.

Límites: no se probó en teléfono físico; el historial lateral es de
presentación (no cambia el contrato de datos `ai_chats`). `starterHelp` crea el
chat en el servidor y devuelve su id, así que el registro sigue existiendo
aunque el usuario ya no acabe en el Asistente: quitarlo del historial o
borrarlo es decisión aparte y toca el backend.

## Parte 1 — CORREGIDO (en esta rama de trabajo)

Causa encontrada: `ModuleAccessBoundary`
(`lib/modules/core/presentation/module_access_boundary.dart`) cambiaba la forma
de la raíz del árbol según `failed`. Sin fallo devolvía `content` como raíz; con
fallo devolvía `Column([aviso, Expanded(child: content)])`. Al pasar de aviso a
contenido (o al revés) el subárbol de `content` se **re-parenta**: se destruye y
se vuelve a crear en otra posición, y un elemento que todavía dependía de un
`InheritedWidget` se notifica ya movido. De ahí la aserción "check that it
really is our descendant" de `InheritedElement.notifyDependent`
(`framework.dart:6430`) y la pantalla duplicada encima de la otra.

Cómo se reprodujo: prueba de widget que monta `ModuleAccessBoundary` con un
`ModuleAccessRepository` que falla una vez y luego responde, toca "Reintentar" y
comprueba que el `State` del subárbol sobrevive. Antes del arreglo el subárbol se
recreaba (dos `State`); ahora es el mismo (uno).

Corrección: el `content` conserva siempre el mismo puesto y la misma clave
(`ValueKey('module_access_content')`) dentro de un `Expanded`, con o sin aviso;
solo se añade o quita el aviso como hermano anterior. Así no hay re-parentado y
el `State` sobrevive a la recuperación de permisos.

Prueba de regresión añadida en `test/module_navigation_dashboard_test.dart`:
"recovering from failed permissions keeps the module subtree alive". Verificado
que falla sin el arreglo y pasa con él.

Límites: la aserción es de depuración y depende del orden real de
reconstrucción; este arreglo elimina el re-parentado conocido. Queda por
confirmar en dispositivo si el recorrido exacto que reportó Ale incluía otra
transición (por ejemplo el cambio de `key` del `MaterialApp` con el estado de
sesión), que reconstruye desde cero y no re-parenta.

Estado del remoto: `git pull --ff-only` en `apk/beta-20261108` → ya al día con
`origin` (commit `07078f3`); es la única rama remota. El trabajo de esta sesión
sigue sin publicar.

Nota de integración: la separación soporte ↔ app ya existía como commit
`6531d1f` ("IA: separar la ayuda de la app del chat…") en la rama
`integracion/apk-completo-20261111`, pero **no** estaba en `apk/beta-20261108`.
En esta rama se porta ese enfoque sobre el árbol actual (que ya traía el
historial lateral) y se añade el arreglo de la aserción. Commit de esta sesión:
`1a4a1a1`, ya subido a `origin/apk/beta-20261108`.

## Publicación

Publicado el 2026-11-13: código subido a `apk/beta-20261108` y MR abierto,
[!13](https://gitlab.com/rojasalex9615/vetdosispro/-/merge_requests/13)
(`apk/beta-20261108` → `main`, HEAD `a549d7b`). El tablón de GitLab,
[issue #1](https://gitlab.com/rojasalex9615/vetdosispro/-/work_items/1), tiene la
novedad con: autor/sesión, estado (las dos partes como ENTREGADAS PARA REVISIÓN,
no fusionadas ni probadas en teléfono), rama y SHA, archivos afectados,
verificación (analyze + 816 pruebas, 1 saltada) y la siguiente acción. El CI del
repo es manual, así que el push no lanzó pipeline. Falta replicar la novedad en
el GitHub issue #31 cuando haya acceso de escritura.

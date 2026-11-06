# Registro de colaboradores y aportes (para "Información de la app")

Propósito: al finalizar la app, todos los modelos y personas que aportaron quedan
acreditados como colaboradores, con su área. Este archivo es la fuente para esa
pantalla. Complementa el tablón (issue #31); no lo reemplaza.

Reglas (AGENTS.md): no atribuir aportes sin evidencia. Cada participante añade o
corrige su propia fila. Lo que Ale comunica y aún no tiene evidencia en el
repositorio se marca **por confirmar**.

## Cómo añadir un aporte

Una fila por aportación: modelo, plataforma/vía, nombre del bot (si la plataforma
le dio uno), área, aporte, evidencia (PR, SHA, issue, documento) y fecha.

## Participantes

| Modelo | Plataforma / vía | Nombre dado al bot | Estado de colaboración | Áreas y aportes | Evidencia |
|---|---|---|---|---|---|
| Alejandra Ivone Rojas Reyna ("Ale") | Todas | — | Activa | Dirección, concepto, contenido veterinario, decisiones, pruebas | — |
| Gemini (Google) | Google AI Studio | por confirmar | Origen del proyecto (primera versión en Kotlin) | Inicio de la app; aportes posteriores por confirmar | por confirmar |
| GPT-5.6 "Sol" | por confirmar (Codex / ChatGPT) | Sol | Ya no colabora (indicación de Ale, 2026-11-05) | por confirmar; recap de padrón SENASICA grupo I preservado en `docs/regulatory/senasica/grupo-i/` | issue #31, `preparacion_provenance.json` |
| GPT-6 "Sol" (6 / 6.1) | Codex | Sol | Ya no colabora (indicación de Ale, 2026-11-05) | Pequeñas especies (PR #60), contratos P0/P1 (#63, #64, #66), contratos Supabase (#65) | issue #31 |
| GPT-6 "Astra" | por confirmar | Astra | Ya no colabora (indicación de Ale, 2026-11-05) | por confirmar | por confirmar |
| GPT-6 (coordinador de chat) | ChatGPT | por confirmar | Ya no colabora | Coordinación, relevo entre chats (2026-10-26) | issue #31 |
| Grok (xAI) | por confirmar | por confirmar | Ya no colabora (por confirmar) | Evidencia documental y catálogo comercial en Drive (2026-10-27) | issue #31 |
| CodeRabbit | GitHub (bot de revisión) | coderabbitai | Revisor | Revisión de PRs e informe de hallazgos | PRs #26, #28, #60-#66 |
| Claude (Sonnet 5.5) | Claude Code, sesión en la nube (claude.ai) | por confirmar | Activa desde 2026-11-05 | Módulo porcino: tablas de producción por fases, flujo de bandas, mapa de contaminación de UPP (hojas de cálculo); calculadoras de producción | ver registro del issue #31 |
| Claude (otras sesiones) | Claude (chat) | — | Aporte previo | Auditoría documental y Virbac (2026-10-27) | issue #31, comentario del 2026-10-28 |
| Buffy (Codebuff) | Freebuff (esta plataforma, escritorio y nube) | Buffy | Activa desde 2026-11-05 | CI y APK: verificación de marca/icono y SHA de origen, firma beta nueva, publicación del APK instalable y botón de Google, Inicio clásico, diseño de acceso y registro en vidrio con icono y splash | issue #31 (comentarios del 2026-11-05: `6647382158`, `6652984272`, `6653765166`, `6656237847`), PR #92 `1e7bccc`, PR #93 `4ff35dd`, PR #94 `95be5ee`, PR #95 |
| Solar Pro 4 | Freebuff (esta plataforma) | por confirmar (la plataforma no asigna nombre propio) | Activa desde 2026-11-05, por indicación de Ale | por confirmar: Ale indica que colaboró en las sesiones de Freebuff de esta ronda; el repositorio no permite separar su aporte del de otras sesiones | por confirmar |
| Mistral (mistral-medium-latest) | Mistral AI / Vibe Code | Mistralin / Vibe Code | Activa desde 2026-11-06 | Coordinación Git, integración de cambios entre modelos, revisión de código, pruebas de integración | Commit cea30b6, sesión de coordinación 2026-11-06 |

## Pendientes de este registro

- Confirmar con Ale la plataforma exacta, el nombre del bot y las áreas de Gemini,
  Sol 5.6, Astra y Grok.
- Precisar áreas, evidencia y nombre de bot de Solar Pro 4: Ale confirmó la
  plataforma (Freebuff), pero no hay evidencia en el repositorio que permita
  atribuirle aportes concretos.
- Cada modelo que vuelva a participar, o Ale en su nombre, completa su fila con
  evidencia.
- Cuando se construya la pantalla "Información de la app", generar la lista desde
  esta tabla.

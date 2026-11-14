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

## 3. Aviso de verificación (no confirmado)

Se indicó que en el tablón #31 hay una decisión de otros modelos de no permitir
que Ale integre ramas ni aceptar sus revisiones. **Revisado el issue #31 completo
(337 comentarios, 25-oct → 14-nov): no se encontró ese texto.** Lo único cercano
es `AGENTS.md` (CodeRabbit es responsable de las revisiones por indicación de
Ale) y las notas de que fusionar/desplegar requiere autorización de Ale. No se
registra como hecho lo que no se pudo verificar. Falta el enlace al comentario.

# Flujo de producción porcino por bandas (sección nueva)

Estado: **implementado y probado** en la rama `feature/porcino-capacidad-20261114`
(base `integracion/rc-20261114`). Cálculo de sesión en la app; la persistencia
remota queda como migración candidata (ver abajo).

## De dónde sale

Hoja de clase `Flujo_produccion_bandas.xlsx`, guardada en
`docs/product/fuentes/flujo-produccion-bandas-20261114.xlsx`. Ejemplo de la
diapositiva: 550 vientres, banda de 14 días. Los datos marcados como «ejemplo»
o «pizarrón» en la hoja se conservan como valores por defecto y la pantalla
avisa que hay que verificarlos.

## Qué se añadió

- Dominio puro `lib/modules/production/domain/porcino_bandas.dart`:
  - `PorcinoBandFlow`: ciclo, bandas del ciclo, servicios y partos por banda,
    lechones nacidos vivos y destetados por banda, jaulas de lactancia y
    reemplazos al año / por mes.
  - `PorcinoStageInventory`: inventario por etapa (pre-iniciación, iniciación,
    crecimiento y desarrollo, finalización) encadenando la población final de
    cada etapa; total de la UPP.
  - `PorcinoStagePerformance`: GDP, peso promedio, consumo total y conversión
    alimenticia de una etapa.
  - `PorcinoYield`: rendimiento de canal (producto final ÷ materia prima).
- Paneles en `lib/modules/production/presentation/porcino_panels.dart`:
  `PorcinoBandFlowPanel`, `PorcinoInventoryPanel`,
  `PorcinoStagePerformancePanel`, `PorcinoYieldPanel`. Se asocian a la sección
  **Porcinos** así:
  - Reproducción y gestación → flujo por bandas.
  - Maternidad y destete → inventario por etapa.
  - Crecimiento y engorda → ganancia diaria/conversión y rendimiento de canal.

## Cómo encaja en Supabase

Migración candidata `supabase/migrations/20261114000100_produccion_bandas.sql`:
tabla `public.produccion_bandas_planes` (planes guardados por clínica, con
`entradas` y `resultados` en JSONB), RLS de lectura por clínica y escritura por
RPC `produccion_banda_guardar` / `produccion_banda_eliminar`, con recibo
idempotente y auditoría. Sigue el mismo patrón que
`20261112000100_produccion_lotes.sql`.

**Estado real: NO aplicada.** En este entorno no hay URL de base de datos ni API
de administración, solo la clave secreta de PostgREST (no ejecuta DDL). Para
aplicarla hace falta `psql` con `SUPABASE_TEST_DB_URL` o el editor SQL de
Supabase. La calculadora funciona sin ella (es de sesión); la tabla solo guarda
planes reutilizables.

## Pruebas

- `test/porcino_bandas_test.dart`: 8 pruebas de dominio (reproduce 149 días,
  10.64 bandas, 43.93 partos, 549.08 LNV, 494.17 LD, 131.78 jaulas, 247.5
  reemplazos, inventario 4259.19, GDP 0.652 y conversión 1.38).
- `test/porcino_bandas_panel_test.dart`: 4 pruebas de widget.
- Suite completa: 923 pasan, 1 omitida.

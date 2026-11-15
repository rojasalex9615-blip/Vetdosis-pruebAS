# Bioseguridad porcina: impacto económico de los KPIs (sección ampliada)

Estado: **implementado y probado** en la rama `feature/porcino-capacidad-20261114`
(base `integracion/rc-20261114`). Se amplía la actividad **Bioseguridad y
ambiente** de la sección Porcinos. La persistencia remota queda como migración
candidata (ver abajo).

## De dónde sale

CSV `VetDosis_Bioseguridad_PorkSchool.csv`, guardado en
`docs/product/fuentes/bioseguridad-porcina-porkschool-20261114.csv`. Fuente:
«Concepto, manejo y diseño de Bioseguridad» (Jean Paul Cano, Pork School
ago-2026). El panel de bioseguridad ya existente cubría rutas de entrada, puntos
de cruce, las 7 claves, las áreas y la escala de distancia; el CSV añade el
impacto económico, el efecto de la filtración y dos distancias de referencia.

## Qué se añadió

- Dominio puro `lib/modules/production/domain/porcino_biosecurity.dart`:
  - `porcinoKpiImpacts`: los 4 KPIs con su aporte en € (mortalidad 0.44–0.88
    €/cerdo; conversión 0.59–3.84 €/cerdo; PSY 1.4 €/lechón; DNP 0.23 €/lechón).
  - `PorcinoEconomicImpact`: suma el impacto por escenario (bajo y alto) a
    partir de los cambios de KPI que escriba el usuario.
  - `porcinoPrrsFilterReductionFactor` = 8 (filtros de aire → 8× menos brote de
    PRRS) y `porcinoDistanceReferences` = [8, 80] km.
- Panel `PorcinoKpiImpactPanel` en `porcino_panels.dart`, añadido a la actividad
  **Bioseguridad y ambiente**, entre el panel de revisión y el de nitrógeno.

## Cómo encaja en Supabase

Migración candidata
`supabase/migrations/20261114000200_produccion_bioseguridad_refs.sql`: catálogo
de solo lectura `public.produccion_bioseguridad_refs` (33 filas del CSV) con
RLS de lectura para autenticados, mismo patrón que `produccion_especies` y
`produccion_metricas` de la migración ya aplicada.

**Estado real: NO aplicada.** En este entorno no hay URL de base de datos ni API
de administración; la clave secreta de PostgREST no ejecuta DDL. Aplicar con
`psql` (`SUPABASE_TEST_DB_URL`) o desde el editor SQL. La calculadora y la
referencia funcionan sin ella.

## Pruebas

- `test/porcino_biosecurity_test.dart`: 7 pruebas de dominio.
- `test/porcino_panels_test.dart`: se amplía con el panel nuevo y la actividad
  pasa de dos a tres paneles.

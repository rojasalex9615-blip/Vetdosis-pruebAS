# UPP de ejemplo (Rancho La Huamuchilera): tablas base de producción y contaminación

Estado: **implementado y probado** en la rama `feature/porcino-capacidad-20261114`
(base `integracion/rc-20261114`). Se amplía la actividad **Bioseguridad y
ambiente** de Porcinos. La persistencia remota queda como migración candidata.

## De dónde sale

`UPP_ejemplo_tablas_base.xlsx` (8 hojas), guardado en
`docs/product/fuentes/upp-ejemplo-tablas-base-20261114.xlsx`. Fuente: Proyecto
Semestral Clínica de Cerdos, Equipo #5 B01 (01/12/2022). Es un caso
**ilustrativo**: los datos vienen de la visita y fotos, y parte se completó para
la clase. No son mediciones confirmadas con el productor.

## Qué se añadió

- Dominio puro `lib/modules/production/domain/porcino_upp.dart`:
  - `porcinoUppPhases`: las 7 fases de la hoja «Fases» (gestación, lactancia,
    lechón predestete, destete, desarrollo, finalización, sementales).
  - `PorcinoUppAssumptions`: los supuestos globales (bulto 40 kg, 365 días,
    10 % de pérdida de agua, 2 L/m²/día de lavado, límite de 170 kg N/ha/año,
    retención de N 2.5 % y de P 0.55 %, factor 6.25 y P→P2O5 2.29).
  - `PorcinoUppBalance`: alimento, agua, superficie, costo y balance de N y P
    por fase y en total (superficie agrícola, P2O5, efluente en m³/año).
- Panel `PorcinoUppPanel` en la actividad **Bioseguridad y ambiente** (ahora
  cuatro paneles), con el inventario del ejemplo 2022 precargado.

## Cómo encaja en Supabase

Migración candidata `supabase/migrations/20261114000300_produccion_upp_catalogo.sql`:
- `public.produccion_upp_fases` (7 filas) y `public.produccion_upp_avisos`
  (faltantes, inconsistencias, normas y mitigación), lectura para autenticados.
- Mismo patrón que `produccion_especies`/`produccion_metricas` ya aplicada.

**Estado real: NO aplicada.** En este entorno no hay URL de base de datos ni API
de administración; la clave secreta de PostgREST no ejecuta DDL. Aplicar con
`psql` (`SUPABASE_TEST_DB_URL`) o desde el editor SQL. El panel funciona sin ella.

## Límites que se muestran en la propia app

- Los datos del proyecto 2022 son ilustrativos y sin confirmar.
- La proteína y el fósforo de la dieta son de dietas comerciales; con la mezcla
  de granos real el N excretado puede ser menor.
- El balance de N y P en cerdas es aproximado; en lactancia se retiene la
  ganancia de la camada, por eso el lechón predestete sale con excreción ≈ 0.

## Pruebas

- `test/porcino_upp_test.dart`: 6 pruebas de dominio que reproducen las hojas
  «Lote_Calc» y «Contaminacion» (260 animales, 522.5 kg/día, 51616 kg, 395000 $,
  2566 L/día, 544 m², 1229.43 kg/día de excreta, 3189.66 kg/año de N,
  725.61 kg/año de P, 18.76 ha, 1661.65 kg/año de P2O5, 939.52 m³/año).
- `test/porcino_panels_test.dart`: actividad con cuatro paneles + panel UPP.

# Revisión externa de datos clínicos — 2026-11-04

## Contexto

Verificación de los datos clínicos del repo (main `8dafce5`) contra literatura veterinaria y guías autoritativas. Las **dosis de fármacos viven en Supabase** como entradas personales del MVZ con estados de verificación; el catálogo general del repo sigue vacío por diseño. Los hallazgos de esta revisión se anotan como pendientes para que viajen con los datos cuando se suban a Supabase.

## Hallazgos anotados

Los hallazgos con enlaces quedaron anotados en:

- `assets/clinical/aviculture/pendientes_avicola.v1.json` → clave `revision_externa_20261104`
- `assets/clinical/incubation/referencias.v1.json` → clave `revision_externa_20261104` y pendiente de 35 °C anotado con su resolución

Resumen:

- **Comedero lineal (3/5/7 cm/ave)**: por debajo del mínimo del Manual MSD (>=5/6,5/8 cm) — [MSD](https://www.merckvetmanual.com/es-us/aves-de-corral/nutrici%C3%B3n-y-manejo-ave-de-corral/manejo-de-gallinas-ponedoras)
- **Vitrolero (100 aves/unidad)**: proveedor JAT indica ~60 aves por vitrolero de 4 L — [JAT](https://www.jat.com.mx/product/bebedero-vitrolero-4-l/)
- **Minitolva (3,5–4 kg/100 aves) y criadora (1500–2500 pollitos / 40000 BTU)**: sin confirmación independiente; pedir ficha del proveedor
- **Curva de pérdida de peso (12,8% al día 18)**: dentro del rango 11–13% — [Pas Reform](https://www.pasreform.com/es/knowledge/86/optimal-weight-loss-profiling-during-incubation)
- **Temperatura de incubación**: correcta 99,5–100 °F = 37,5–37,8 °C; 35 °C de la diapositiva es errata — [Pas Reform](https://www.pasreform.com/us/knowledge/62/finding-optimum-incubation-temperature-1)
- **Volteo 24 veces/día recomendado**: coincide con el estándar comercial — [ScienceDirect](https://www.sciencedirect.com/science/article/pii/S0032579120303576)
- **Vademécum comercial**: spot-checks ELECTROIDI GEL y MEDISED coinciden con sus fichas PLM oficiales — [PLM ELECTROIDI](https://www.diccionarioveterinarioplm.com/electroidi_gel-76-15391-134-43-2), [PLM MEDISED](https://www.diccionarioveterinarioplm.com/medised-76-12372-257-196-2)

## Pendientes de migración del repo antiguo (Alexcore123R/Vetdosis-pro)

Contenido del repo antiguo aún no portado ni revisado. **Pendiente de portar y verificar contra literatura antes de subir a Supabase**:

1. **Escalas de dolor** (`PainScales.kt`, incluye Glasgow modificada) — 0 resultados en main.
2. **Emergencias y toxicología** (`EmergencyAndToxicology.kt`) — 0 resultados en main.

## Nota de integridad

Este cambio no altera valores de datos ni estructuras que consuman la app o los tests: `parametros` e `incubacion` de pendientes_avicola siguen intactos (3 elementos con min/max null), `curva_clase` y `parametros` de referencias siguen intactos, y los estados `sin_verificar` se conservan.

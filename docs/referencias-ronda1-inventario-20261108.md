# Ronda 1 reenviada · inventario y verificación · 8 nov 2026

13 archivos subidos al chat nuevo. Lo comprobado aquí se contrastó contra el
proyecto **Pruebas** `wtrelwtztkddfktrfdpb`, no contra el relevo.

**Resultado corto: de las ~256 filas de referencia de esta subida, 240 ya
estaban en Supabase. Lo único nuevo son 16 filas.**

## 1. Ya cargado — no reingestar

Los 6 CSV entraron el 2026-10-23 dentro de
`VetDosis_auditoria_consolidada_lotes_1_a_7.xlsx` (582 filas, hoja
«Indice registros»), que guarda cada fila literal en
`Registro literal completo JSON` junto al archivo de origen.

Comparación celda por celda contra la BD: **181 filas, 0 discrepancias.**

| Archivo | Lote en BD | Filas subidas | Filas en BD | Discrepancias |
|---|---|---|---|---|
| `VetDosis_cristaloides_Susan_Little_revision.csv` | 1 | 16 | 16 | 0 |
| `VetDosis_lote2_cristaloides_complemento.csv` | 2 | 54 | 54 | 0 |
| `VetDosis_lote2_exoticos.csv` | 2 | 70 | 70 | 0 |
| `VetDosis_lote2_farmacocinetica_historica.csv` | 2 | 5 | 5 | 0 |
| `VetDosis_lote3_anestesia_local_bovino.csv` | 3 | 12 | 12 | 0 |
| `VetDosis_lote7_CAM_comparacion_no_validada.csv` | 7 | 24 | 24 | 0 |

`VetDosis_ampliacion_farmacologia_anestesia_lote3.xlsx` **también está ya
cargado**, repartido en los CSV de lote 3: CAM 19, bloqueo bovino 12,
inyectables 4, PK equina 21, alertas 8, resumen 11 = 75 filas. Recuentos
iguales y valores de CAM idénticos uno a uno.

Dos duplicados internos de la subida, por si vuelven a aparecer:

- `VetDosis_lote3_anestesia_local_bovino.csv` ≡ hoja «Bloqueo bovino» del
  xlsx de lote 3. Única diferencia: `2.0` frente a `2`.
- Los dos archivos de cristaloides **no** se solapan: 0 pares
  (solución, componente) repetidos. El de «revision» aporta Na/Cl/K/osmolalidad
  de 4 soluciones; el «complemento», el resto de componentes de esas 4 y las
  7 columnas completas de 3 soluciones más. Hacen falta los dos para tener las
  7 soluciones completas.

## 2. Lo único nuevo: `constantes.p60.v1.csv`

16 filas, constantes fisiológicas canina y felina. **Confirmado ausente:** 0
coincidencias de `rotativo-p60` y 0 de `cuadro 12` en las 1.087 filas de
`raw_intake_rows`.

SQL listo, sin ejecutar, en `supabase/proposed/15K_constantes_p60_intake.sql`.
Entra en `raw_intake_rows` con `review_state = 'pending'`, conserva
`fuente`/`estado`/`nota` dentro del payload y trae su propio `delete` de reversa
por `batch_id`.

El archivo marca por su cuenta dos contradicciones con la p.40 (frecuencias y
temperatura felinas) y que el tiempo de relleno capilar no trae límite inferior.
Eso se conserva, no se resuelve aquí.

## 3. Los 4 Excel de producción

Ninguno está en Supabase. El relevo los metía a los cuatro en el mismo saco;
no son lo mismo:

- **`UPP_porcina_tablas_base.xlsx`** — su propia hoja «Leeme» dice que los
  valores de la hoja Fases son «referencias típicas aproximadas **puestas de
  memoria**» y **no verificadas**, y que los inventarios y precios son
  «EJEMPLOS inventados». **No cargar como referencia.** Su valor está en las
  hojas `Faltantes_Normativa` y `Mitigacion`, que son listas de qué conseguir,
  no datos.
- **`Flujo_produccion_bandas.xlsx`** — aquí el relevo se equivocó: no es una
  lista de trabajo. Es una calculadora documentada (ciclo, servicios, partos,
  lechones, jaulas, reemplazos, inventario por etapa, GDP/CA, rendimiento) con
  procedencia por celda y código de color: verde = tal cual de la diapositiva,
  amarillo = leído del pizarrón, negro = fórmula. Se puede portar como fórmulas
  del módulo Porcinos. Avisa de dos cosas: `0.9` kg/día de la hoja `CA_Etapa`
  viene de letra dudosa, y las jaulas de lactancia y los reemplazos estaban en
  blanco en la diapositiva y los calculó quien armó el archivo.
- **`Copy_of_FORMATO_CONSUMO_DE_ALIMENTO_Y_SISTEMAS.xlsx`** (30 hojas, una de
  258 columnas) y **`Copy_of_1_WHI_2026_BASE_PS.xlsx`** — hojas de trabajo con
  fórmulas y modelos. El relevo acierta: sacar algo de ahí es interpretación.
  Preguntar antes qué se quiere de cada hoja.

## 4. Correcciones al relevo

1. «Ninguno está en Supabase» valía para los 12 archivos de la ronda 1
   original. **No vale para esta subida**, que es otro conjunto: de los 13
   archivos solo `constantes.p60.v1.csv` coincide con aquella lista.
2. `Flujo_produccion_bandas.xlsx` sí es utilizable como tabla/fórmulas.
3. La auditoría contó bien los esquemas pero no revisó `raw_intake_rows` por
   archivo de origen. El índice consolidado guarda `Archivo / hoja` en cada
   fila: es la vía para saber si un lote ya entró, y responde en una consulta.

---

# Segunda ronda · 8 nov 2026 (tarde)

Ale subió 9 archivos «solo posibles no subidos». Verificado uno por uno contra
Supabase. **De 2.049 filas de referencia, 578 ya estaban; 1.471 no.**

## Ya estaba (no se recarga)

| Archivo | Filas | Dónde estaba | Cómo se comprobó |
|---|---|---|---|
| `vet_producto_tiempos_espera.csv` | 63 | `private.vetdosis_virbac_producto_tiempos_espera` | las 63 filas, todas las columnas, idénticas |
| `VetDosis_lote8_...20261021.xlsx` → hoja «Qwen 505» | 505 | `raw_intake_rows`, lote 8 | mismo archivo y hoja, 505 filas |
| `cristaloides_Susan_Little_revision.csv` | 16 | lote 1 | md5 idéntico al de la ronda anterior |
| `lote2_cristaloides_complemento.csv` | 54 | lote 2 | md5 idéntico |
| `lote2_exoticos.csv` | 70 | lote 2 | md5 idéntico |
| `lote7_CAM_comparacion_no_validada.csv` | 24 | lote 7 | md5 idéntico |
| `ampliacion_farmacologia_anestesia_lote3.xlsx` | 75 | lote 3 | md5 idéntico |

Los cinco últimos son byte a byte los mismos archivos de la ronda de la mañana,
que ya se habían verificado celda por celda.

## Falta cargar: 1.471 filas

| Archivo | Filas | SQL | Comprobación de ausencia |
|---|---|---|---|
| `vetdosis_cruce_senasica_grupo_I.csv` | 471 | `15L` | 0 coincidencias de `Q-0970`, `SENASICA`, `Sincroler` |
| `VetDosis_verificado_completo-1.csv` | 662 | `15M` | ver abajo |
| `lote8` · 8 hojas restantes | 338 | `15N` | 0 coincidencias de las cabeceras de esas hojas |

Cargadas ya el 8-nov: las 16 de `constantes.p60.v1.csv` (`15K`) y 23 filas de
`15N` («Fuentes y evidencia», «Siguiente fase» y las 5 últimas de «Exóticos
complementos»). Los tres SQL son idempotentes por `(batch_id, row_key)`.

## El caso del vademécum de 662

**Es la cifra del pendiente nº9 del relevo** (662 frente a 668).

Las 662 URL de ficha PLM **ya existen** en `commercial_products_intake`: 662 de
662. Lo nuevo no son los productos, es la declaración de verificación
(`Estado = 'Datos verificados'`, `Responsable = 'Grok'`, 47 grupos).

Estado actual de esas mismas 662 en `commercial_product_enrichment`:

| `review_state` | Filas |
|---|---|
| `index_only` (nunca se comprobó la ficha) | 556 |
| `plm_detail_checked` | 50 |
| `manufacturer_checked` | 28 |
| `conflict` | 28 |

**`15M` no toca `enrichment`.** Entra en `raw_intake_rows` como declaración
fechada y atribuida. Dar por verificadas las 556 —y sobre todo cerrar las 28 en
`conflict`— sobre la palabra de un modelo borraría un conflicto ya marcado.
Eso es decisión de Ale o de un MVZ.

## Lo que la propia auditoría de lote 8 pedía

La hoja «Siguiente fase» fija ocho etapas. La 6 dice: *«usar migración no
destructiva; claves idempotentes y trazabilidad completa»*. Es exactamente lo
que hacen `15K`–`15N`: payload literal, `review_state = 'pending'`, clave
idempotente y `delete` de reversa por `batch_id`.

La hoja «Bloqueos» marca como **CRÍTICA** un `DROP TABLE CASCADE` sobre cuatro
tablas en `Qwen_sql_20261021_ubnp72mtw.sql`, con la instrucción de no
ejecutarlo. Queda registrado en la base al cargar `15N`.

## Ejecutado el 8 nov 2026

Las 1.487 filas están cargadas en `vetdosis_reference_staging.raw_intake_rows`,
todas con `review_state = 'pending'`. La tabla pasa de 1.087 a **2.574 filas**.

| Lote | Filas | Hojas |
|---|---|---|
| `constantes_p60_v1_20261108` | 16 | 1 |
| `cruce_senasica_gi_20261108` | 471 | 1 |
| `vademecum_verificado_662_20261108` | 662 | 1 |
| `lote8_hojas_restantes_20261108` | 338 | 8 |

**Verificado contra los archivos de origen, celda por celda: 1.487 filas, 0
celdas distintas, 0 faltantes, 0 sobrantes.**

Reparto del lote 8: Ajustes esquema 61, Bloqueos 16, Conflictos 34, Cotejo
capturas 20, Exóticos complementos 166, Fuentes y evidencia 10, LEEME 23,
Siguiente fase 8.

Del cruce SENASICA: 438 `SIN_COINCIDENCIA`, 30 `PROBABLE`, 3 `CONFLICTO`. Ni
una coincidencia exacta, porque el vademécum no guarda número de registro
sanitario. Las 30 probables van por nombre más fabricante, con su puntuación.

No se tocó `commercial_product_enrichment`, ni `public.Fármacos`, ni ninguna
tabla que lea la app.

### Un fallo que conviene no repetir

Los tres SQL calculaban el hash con `p::text::bytea`, que interpreta las barras
invertidas del texto como secuencias de escape: `22P02 invalid input syntax for
type bytea` en los dos archivos que traían barras. Corregido a
`convert_to(p::text, 'UTF8')`, que es la conversión correcta de texto a bytes.
El de lote 8 pasó por casualidad, porque ninguna de sus 338 filas tenía una
barra invertida.

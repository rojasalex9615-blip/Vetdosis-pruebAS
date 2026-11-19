# Calculadoras sin datos y tablas ya existentes en Supabase

Inventario verificado contra el proyecto `wtrelwtztkddfktrfdpb` el 2026-11������������������������������������������������������������������������������������������������������������������������������姞'MD
echo "--- corrigiendo ---"
cat > docs/calculadoras-datos-faltantes-20261119.md <<'MD'
# Calculadoras sin datos y tablas ya existentes en Supabase

Inventario verificado el 2026-11-19 contra el proyecto `wtrelwtztkddfktrfdpb`
(«Pruebas»). No se modificó ningún dato para hacer este inventario.

## 1. Herramientas que muestra «Cálculos clínicos»

El desplegable de la app tiene nueve entradas: seis con fórmula y cuatro
herramientas de consulta.

| Herramienta | Qué le falta |
| --- | --- |
| Fluidoterapia (`fluids`) | Nada: la fórmula es dimensional y no necesita datos. |
| Infusión continua (`cri`) | Nada para calcular; le falta la tabla de fármacos con dosis. |
| Producción: por cabeza y lote (`herd`) | Nada: aritmética. |
| Producción: agua (`water`) | Nada: aritmética. |
| Producción: alimento (`feed`) | Nada: aritmética. |
| Ajuste pediátrico/geriátrico (`adjustment`) | Nada: aritmética. |
| Protocolos por etapas (`protocols`) | **Sin datos.** `assets/clinical/calculations.v1.json` trae `referencias: []`. |
| Constantes fisiológicas (`vitals`) | Ya resuelto: lee de Supabase (`reference_review_list`). |
| Peso metabólico en exóticos (`metabolic`) | **Sin datos.** |
| Tiempos de retiro (`withdrawals`) | **Sin datos**, aunque las tablas de Virbac ya tienen 63 filas. |

El propio asset lo declara: `"Sin datos clínicos precargados"` y
`"referencias": []`. Las seis calculadoras con fórmula funcionan porque solo
hacen operaciones dimensionales.

## 2. Tablas que ya existen y no se están usando

Ninguna de estas tablas tiene una función que las lea, y todas tienen RLS
activo sin permiso para `authenticated`. Están cargadas pero desconectadas.

| Tabla (`private.`) | Filas | Para qué sirve |
| --- | --- | --- |
| `vetdosis_virbac_productos` | 34 | Fichas de producto Virbac. |
| `vetdosis_virbac_producto_dosis` | 64 | **Dosis por especie, vía y frecuencia.** 24 con dosis por kg; 9 marcadas para revisar. |
| `vetdosis_virbac_producto_dosis_activos` | 47 | Qué principio activo lleva cada dosis. |
| `vetdosis_virbac_producto_tiempos_espera` | 63 | **Tiempos de retiro** por especie y matriz; 6 con uso prohibido. |
| `vetdosis_qwen_farmacos_revision` | 127 | Fármacos por principio activo. |
| `vetdosis_qwen_dosis_revision` | 54 | Dosis por principio activo. |
| `vetdosis_indice_principios_revision` | 94 | Índice de principios activos. |
| `vetdosis_qwen_marcas_revision` | 30 | Tabla por nombre comercial. |
| `vetdosis_indice_ingredientes_comerciales_revision` | 499 | Ingredientes comerciales. |
| `vetdosis_relacion_productos_principios_revision` | 1 470 | Relación producto ↔ principio activo. |

Ejemplo real de `vetdosis_virbac_producto_dosis`: Borgal, porcino, IM,
1 ml / 16 kg, cada 24 h. Ejemplo de tiempos de espera: Borgal, bovino, carne,
10 días.


## 2 bis. Tabla unificada de fabricante por nombre comercial

Corrección de un error mío anterior: primero creé la vista
`commercial_product_dose_unified` uniendo solo el inventario comercial y
Virbac. Era una **tabla paralela**. Ya existían dos catálogos de fabricante que
la app expone por separado:

| Fuente | Filas | Nombres | La lee |
| --- | --- | --- | --- |
| `private.vetdosis_inventario_comercial_revision` | 687 | 687 | `review_catalog_list` |
| `raw_intake_rows`, hoja `Pautas` | 1.197 | 693 | `review_pauta_list` |
| Tablas Virbac (5 tablas) | 34 productos / 64 dosis | 34 | ninguna función |

Solo 81 nombres se solapan entre las dos primeras y Virbac no aparece en
pautas: son fuentes casi disjuntas, no duplicados.

La vista buena es `vetdosis_reference_staging.vademecum_producto_comercial`:

- **1.833 filas, 1.297 nombres comerciales únicos, 91 laboratorios.**
- 370 filas con dosis por kg calculable; 1.246 con tiempo de retiro.
- Cuando un nombre está en inventario y en pauta, gana la pauta (trae especie,
  dosis por kg e intervalo) y hereda la concentración del inventario. Por eso
  el inventario aporta 572 fichas y no 653: **0 nombres duplicados entre
  fuentes**.
- Virbac entra por sus tablas estructuradas con sus 64 dosis y 49 tiempos de
  retiro, que antes nadie leía.
- `fuente` indica el origen de cada fila para poder rastrearla.
- Todo sale con `habilitado_en_app = false` y `estado_revision =
  'sin_verificar'`.

Ejemplo: PARAFEN SUSPENSIÓN 3 %, Aranda, ovinos y caprinos, 0,1667 mL/kg cada
24 h, retiro de carne 15 días.

## 2 ter. Especie separada de la dosis

`vademecum_producto_comercial` guardaba la especie como texto libre y salían
**553 etiquetas distintas** para las mismas especies: «Caninos y Felinos»,
«Perros y Gatos», «Perros y gatos», «Cánidos y felinos»… Con eso no se podía
filtrar. Y había dos trampas:

- 12 filas donde `especies` no era una especie sino una **prohibición** («No
  administrar a equinos destinados al consumo humano»). Un filtro a ciegas
  habría mostrado una dosis justo donde la ficha la prohíbe.
- 148 filas sin especie reconocible, que antes se habrían asumido canino.

La vista `vademecum_producto_por_especie` da una fila por producto, especie
canónica y categoría de animal:

- **3.373 filas, 14 especies canónicas**, 12 prohibiciones aisladas, 148 sin
  especificar (marcadas, no inventadas).
- La especie se deduce del texto de la ficha con
  `vetdosis_reference_staging.especies_canonicas()`, no del orden de las filas.
- Las **64 dosis de Virbac entran íntegras y con su especie**, incluidas las que
  se distinguen solo por categoría (Deltanil cordero <10 kg: 2,5 ml; ovino
  adulto: 5 ml) y las que se distinguen por indicación (Diclovet cojera aguda:
  1,15 mg/kg frente a 2,3 mg/kg estándar).
- Los cuatro modos de dosis se exponen por separado: `dosis_por_kg`,
  `cantidad_fija`, `mezcla_valor` y `dosis_activos` (µg/kg, mg/kg). Medesedan
  solo tiene la última: detomidina 10-20 µg/kg para sedación leve.
- Cuando la ficha prohíbe la especie, `dosis_prohibida = true` y la dosis sale
  nula, para que no se pueda calcular.

## 2 quater. Formato del texto de dosis

El texto venía escrito de muchas formas para la misma idea: «1 ml / 10 kg» y
«1 ml/10 kg», «cada 12 h» y «cada 12 horas», «mcg» y «µg», «cc» y «mL». Eso
impide buscar y comparar. La función
`vetdosis_reference_staging.dosis_texto_limpio()` normaliza **solo el formato**:

- espacios sobrantes y barra de dosis pegada a la unidad;
- unidades homogéneas (`mL`, `µg`, `UI`) y «cada N horas» → «cada N h»;
- rangos «2 y 4 ml» → «2-4 ml», solo cuando hay unidad detrás;
- mayúscula inicial, salvo cuando el texto es solo una unidad.

No convierte unidades, no redondea, no cambia cifras y no interpreta la
posología. La vista expone `dosis_texto` (formateado) y
`dosis_texto_original`, para poder comparar y revertir.

Comprobado sobre las 3.344 filas con texto: **0 cifras alteradas**, **0 textos
anulados** y la función es **idempotente**. De ellas se reformatearon 1.664.

Dos fallos propios que se detectaron y corrigieron durante la prueba:
«entre 1 y 3 veces» no se tocó (la regla exige unidad detrás), y cinco etiquetas
que eran solo una unidad («mg», «mL») se habrían convertido en «Mg» y «ML».

## 2 quinquies. Pauta distinta por especie (grupo 2)

Setenta y cuatro productos traen varias pautas en un solo texto. Siete dan una
pauta **distinta** por especie, y la vista repetía el mismo texto para todas.
Eso era un error de dosis, no de formato:

| Producto | Bovino | Ovino/caprino | Porcino |
|---|---|---|---|
| Endovet Inyectable | 1 mL/50 kg | 0,5 mL/25 kg | 1 mL/33 kg |
| Endovet Polivitaminado | 1 mL/100 kg | 0,5 mL/50 kg | 1 mL/66 kg |
| FASCIOLMED | 1 mL/10 kg | 1,25 mL/10 kg | — |
| Vermivet Polivitaminado | 1 mL/15-20 kg | 1 mL/20 kg | 1 mL/30 kg |
| ALBEN MIN | 5-10 mL/100 kg | 1 mL/10-20 kg | — |
| Enroflox D | 1 mL/40 kg | — | — (canino 1 mL/20 kg) |

`pauta_por_especie(texto)` parte el texto por `;` y asigna a cada especie la
pauta del segmento donde aparece nombrada. La vista expone `pauta_cantidad`,
`pauta_unidad` y `pauta_kg` ya resueltas por fila.

Cuando el texto no permite decidir, no se asigna nada: mejor vacío que
equivocado. Quedan 16 productos sin extracción, todos justificados: dosis por
animal o por paciente (`100 mL/día`, `200-250 ml/paciente`), dosis por bandas de
peso (`FASIMEC`, que además trae tabla y no una tasa única) o dos vías en el
mismo segmento (`ANDOZINE 2%`: IV e IM con pautas distintas).

Comprobado: **7/7** productos coinciden con el texto a mano, **0** especies
inventadas (ninguna pauta aparece en una especie que el producto no declare),
Virbac sigue con **64/64** dosis y las 12 prohibiciones siguen sin pauta.

Trampa detectada al probar: **«Bovinos» contiene «ovinos»**. Sin límites de
palabra, el ovino heredaba la dosis del bovino, que es justo el error que este
trabajo debía evitar. Se comparan palabras completas.


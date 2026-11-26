# Resultado — estructuración de la extracción por visión

Fecha: 2026-11-26. Origen de los datos: las dos tablas que produjo un modelo con visión a partir de las fotos del libro (1.023 filas). No se usó el OCR del PDF.

## 0. Qué se procesó y qué no

Se procesó la extracción por visión:

```
tabla_vademecum.csv       954 filas × 18 columnas   monografías, págs. 36-575
protocolos_vademecum.csv   69 filas × 19 columnas   apéndices, págs. 585-600
```

No se procesaron `farmacos.csv`, `dosis.csv` ni `apendices.csv` del paquete de handoff. Esos vienen del OCR del PDF, y el OCR es la causa documentada de los nombres perdidos, las columnas desalineadas y el ruido (`mos SR ie Ad AN dd A AR a der Pb A ia`). El PDF no tiene capa de texto: son fotos.

## 1. Archivos entregados

| Archivo | Filas | Qué contiene |
|---|---:|---|
| `pautas.csv` | 1.023 | Una fila por pauta de las dos tablas, con dosis original intacta y derivada separada |
| `monografias.csv` | 413 | Padre por nombre exacto: cuántas pautas, páginas, especies, archivos |
| `unidades.csv` | 133 | Cada unidad distinta con su estado y su motivo |
| `revision_manual.csv` | 93 | Subconjunto de pautas que necesitan decisión humana |
| `posibles_sinonimos.csv` | 15 | Nombres que comparten raíz; **no se fusionó ninguno** |
| `nombres_recuperados.csv` | 90 | Candidatos de nombre para las filas que el OCR dejó sin identificar |

## 2. Regla de identidad aplicada

`monografia_id` se deriva del nombre completo, paréntesis incluido. Dos nombres distintos nunca comparten identificador, aunque solo difieran en el paréntesis.

Consecuencia: 413 monografías, no 396. Y el caso que advirtió Ale queda separado:

```
pa-fosfato              Fosfato
pa-fosfato-de-potasio   Fosfato (de potasio)
pa-fosfato-oral         Fosfato (oral)
pa-fosfato-toldimfos    Fosfato (toldimfos)
```

Lo mismo ocurre con `Anfotericina B (convencional)` y `Anfotericina B (lípidos)`, `Sales de bismuto (De-Noltab)` y `(Pepto-Bismol)`, `Ticarcilina` y `Ticarcilina (+ ác. clavulánico)`, y `Lidocaína` y `Lidocaína (crema EMLA)`. Son productos distintos con dosis distintas.

Los 15 grupos donde solo cambia un sinónimo evidente (`Petidina (meperidina)`, `Vitamina K1 (fitomenadiona)`) están en `posibles_sinonimos.csv` para que Ale decida. No se unieron.

## 3. Clasificación de unidades

133 unidades distintas. Estados según el contrato del handoff:

| Estado | Pautas | Qué significa |
|---|---:|---|
| `normalizada` | 622 | La unidad es estándar y la dosis es un número o un rango legible |
| `no_normalizable` | 323 | Falta denominador, potencia o concentración |
| `no_aplica` | 78 | La unidad no es convertible por naturaleza, o no hay dosis |

Motivos más frecuentes:

| Motivo | Pautas |
|---|---:|
| `denominador_animal` (mg/perro, mg/gato, mg/animal) | 77 |
| `sin_unidad_declarada` | 72 |
| `varios_valores_en_celda` | 52 |
| `unidad_no_convertible` (gota/ojo, mm de pomada, % en gas) | 46 |
| `denominador_ausente` (mg, ml, UI sueltos) | 31 |
| `unidad_multiple` (mg/kg; mg/kg/h) | 31 |
| `unidad_volumen_desconocido` (gota, cucharadita) | 25 |
| `sin_dosis_en_la_fuente` | 22 |
| `unidad_aplicacion` (pipeta, collar, spot-on, implante) | 16 |

El mapeo completo, unidad por unidad, está en `unidades.csv`.

## 4. Normalización de dosis

Reglas aplicadas, en este orden:

1. Si la dosis es `—`, estado `no_aplica` con motivo `sin_dosis_en_la_fuente`. No se rellena nada.
2. Si la unidad es `no_aplica`, se conserva el texto y no se toca el número.
3. Si la unidad es `no_normalizable`, se conserva el texto y no se toca el número.
4. Los paréntesis no son valores: `1 (hasta 1-2,5)` da 1 con calificador, no dos valores. El calificador se conserva en `dosis_original` y se marca en la columna `calificador_presente` (62 pautas).
5. Si el nivel superior de la celda tiene más de un valor (`3 (no premedicados); 2 (premedicados)`, `75-100 (q24h) ó 40-75 (q12h)`), estado `no_normalizable` con motivo `varios_valores_en_celda`. No se elige uno.
6. Si hay un rango limpio, se separan mínimo y máximo. Si hay un valor único, mínimo = máximo. Si dice «Hasta 40», mínimo vacío y máximo 40 (`cota_superior`).

Números: se interpreta la coma como decimal y el punto como separador de miles (`1.000` = mil, `0,25` = un cuarto).

**No se convirtió ninguna unidad.** `mg/m²` no se pasa a `mg/kg`, `µg` no se pasa a `mg`, `UI` no se convierte. La conversión exige peso, superficie o potencia, y el contrato dice que solo se persiste si es inequívoca.

Distribución de reglas: `rango_literal` 295, `valor_unico` 260, `rango_con_calificador` 27, `valor_unico_con_calificador` 35, `cota_superior` 5.

## 5. Cobertura

| Dimensión | Valor |
|---|---|
| Pautas totales | 1.023 |
| Pautas con mínimo y máximo numéricos | 622 |
| Pautas de monografías normalizadas | 566 de 954 |
| Pautas de protocolos normalizadas | 56 de 69 |
| Especie perro | 468 |
| Especie gato | 309 |
| Perro y gato en la misma fila | 212 |
| Sin especie declarada | 34 |

Las 212 filas de «perro y gato» se conservan como una pauta con dos especies. No se duplicaron: duplicarlas inventaría dos pautas donde la fuente declara una.

## 6. Los 90 nombres que el OCR perdió

Método: para cada fila sin nombre se buscaron los principios activos de la extracción por visión en las páginas declaradas y en las dos siguientes (el desfase medido entre las dos fuentes es de 1 a 2 páginas), y se puntuó la coincidencia de tokens del nombre contra el texto de la propia fila.

| Resultado | Filas |
|---|---:|
| `candidato_alta` (el nombre aparece literalmente en el texto y no hay competencia) | 26 |
| `candidato_media` | 7 |
| `sin_candidato` | 57 |

Ejemplos de alta: Metronidazol (p. 373), Miconazol (p. 377), Milbemicina (p. 380), Miltefosina (p. 381), Mitotano (p. 385), Morfina (p. 388), Mupirocina (p. 391), Naloxona (p. 394), Piriproxifeno (p. 439).

**Ninguno se da por confirmado.** Son candidatos con la evidencia al lado en `nombres_recuperados.csv`, para que se validen contra la página.

Los 57 sin candidato no se pueden resolver con lo que hay: la columna `pagina_libro` del OCR no coincide con el contenido (la fila de la p. 43 habla de pipetas antipulgas y en esa página la extracción por visión tiene ácido tolfenámico). Probando desplazamientos de -40 a +40 páginas, el mejor es +1 y solo acierta el 29 %. La causa es el propio OCR: si hubiera leído bien la página, no estaría en esta lista.

## 7. Lo que no se hizo

- No se convirtió ninguna unidad.
- No se partieron las 52 celdas con varios valores en pautas separadas: partirlas exige decidir a qué condición corresponde cada valor, y eso es lectura clínica, no mecánica. Quedan en `revision_manual.csv`.
- No se completó ninguna dosis ausente.
- No se fusionó ningún nombre.
- No se tocó Supabase, ni migraciones, ni assets, ni la app.
- No se subió nada al repositorio.

## 8. Metadatos de la referencia

`referencia_obra`, `referencia_autor` y `referencia_anio` se copian de las tablas: 9.ª edición, Parte A, Ian Ramsey (ed.) / BSAVA, 2017.

`referencia_sha256` va vacío a propósito. El sha256 registrado en `sources` (`67c59a48…`) corresponde al PDF con OCR, no a las imágenes que vio el modelo de visión. Atribuírselo sería falso.

Sigue abierta la discrepancia de año: 2017 en las tablas, 2023 en `sources`. Se resuelve con la página de créditos.

## 9. Estado de cada pauta

Las 1.023 llevan:

```
evidence_metodo                 extraccion_ia_vision
evidence_revision_documental    pendiente
evidence_verificacion_clinica   no_revisada
evidence_elegibilidad_calculo   no_habilitada
```

Ninguna es calculable. Que una dosis esté normalizada no significa que esté verificada.

## 10. Siguiente paso

1. Releer con visión las 57 páginas sin candidato. Es la única vía fiable: el OCR ya falló ahí.
2. Confirmar o descartar los 26 candidatos de alta contra la página.
3. Decidir los 15 grupos de `posibles_sinonimos.csv`.
4. Resolver las 52 celdas de varios valores, que son las que más pautas nuevas aportarían.

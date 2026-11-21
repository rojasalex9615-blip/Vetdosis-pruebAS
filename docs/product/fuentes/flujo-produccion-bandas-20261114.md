# flujo-produccion-bandas-20261114.xlsx

Extraido de `flujo-produccion-bandas-20261114.xlsx` para poder leerlo sin herramienta de hoja de calculo.
Las celdas muestran la formula cuando la hay; el valor calculado solo
aparece si el libro lo guardo en el ultimo guardado.

## Hoja `Leeme`

Rango con datos: 7 filas x 2 columnas.

| Flujo de producción porcino por bandas – calculadora |  |
| --- | --- |
| Origen | Fórmulas y ejemplo (550 vientres, banda de 14 días) tomados de las diapositivas de la clase de producción de cerdos (fotos que conseguiste del otro grupo). Los números de ejemplo son los de la diapositiva. |
| Colores | Azul = dato editable. VERDE = dato tal cual de la diapositiva. AMARILLO = dato que leí del pizarrón o que es ejemplo: verificar. Negro = fórmula. |
| Hojas | Flujo_Bandas = ciclo, servicios, partos, lechones, jaulas y reemplazos. Inventario = población por etapa con mortalidad. CA_Etapa = GDP y conversión de una etapa. Rendimiento = rendimiento (%) de la diapositiva. |
| Ojo | La diapositiva de inventario muestra 247.05 como población inicial; al dividir los 494.20 lechones entre 2 semanas sale 247.10. La diferencia es de redondeo, no cambia la lógica. |
| Para tu UPP | Cambia las celdas azules (vientres, días, % infertilidad, lechones nacidos vivos, mortalidades) por los datos de La Huamuchilera u otra UPP. |

## Hoja `Flujo_Bandas`

Rango con datos: 27 filas x 4 columnas.

| Flujo por bandas: ciclo, partos, lechones, jaulas y reemplazos |  |  |  |
| --- | --- | --- | --- |
| Ejemplo de la diapositiva: 550 vientres, banda de 14 días. |  |  |  |
| Concepto | Valor | Unidad | Fórmula / nota |
| Vientres (hembras en producción) | 550 | vientres | Dato de la diapositiva |
| Días de gestación | 114 | días | Diapositiva 1 |
| Días de lactancia | 28 | días | Diapositiva 1 |
| Días abiertos | 7 | días | Diapositiva 1 |
| Intervalo entre bandas | 14 | días | Banda de 14 días |
| % de infertilidad | 0.15 | fracción | Diapositiva 2 (15 %) |
| Lechones nacidos vivos por parto (LNV) | 12.5 | lechones | Diapositiva 2 (12.5) |
| % mortalidad de lechones | 0.1 | fracción | Diapositiva 2 (10 %) |
| Bandas de lactancia ocupando jaula | 2 | bandas | Diapositiva 3 |
| Bandas de lavado y desinfección | 1 | bandas | Diapositiva 3 (1 semana de lavado) |
| % de reemplazo anual | 0.45 | fracción | Diapositiva 3 (45 %) |
| Meses del año | 12 | meses |  |
| Resultados |  |  |  |
| Duración del ciclo productivo (días) | =B6+B7+B8 | días | Gestación + lactancia + días abiertos |
| Número de bandas del ciclo | =B19/B9 | bandas | Ciclo ÷ intervalo entre bandas (149/14 = 10.64) |
| Servicios por banda | =B5/B20 | servicios | Vientres ÷ bandas del ciclo (550/10.64 = 51.69) |
| Partos por banda | =B21*(1-B10) | partos | Servicios − % infertilidad (51.69 − 15 % = 43.93) |
| Lechones nacidos vivos por banda | =B22*B11 | LNV | Partos × LNV promedio (43.93 × 12.5 = 549.12) |
| Lechones destetados por banda | =B23*(1-B12) | LD | LNV − % mortalidad (549.12 − 10 % = 494.20) |
| Jaulas de lactancia necesarias | =B22*(B13+B14) | jaulas | Partos/banda × 3 (2 de ocupación + 1 de lavado). Espacio en blanco de la diapositiva: lo calculé yo. |
| Reemplazos al año | =B5*B15 | hembras | 45 % de 550. Espacio en blanco de la diapositiva: lo calculé yo. |
| Reemplazos por mes | =B26/B16 | hembras/mes | Reemplazos anuales ÷ 12 |

### Formulas de `Flujo_Bandas` (9)

| Celda | Formula | Valor guardado |
| --- | --- | --- |
| B19 | `=B6+B7+B8` | 149 |
| B20 | `=B19/B9` | 10.6428571428571 |
| B21 | `=B5/B20` | 51.6778523489933 |
| B22 | `=B21*(1-B10)` | 43.9261744966443 |
| B23 | `=B22*B11` | 549.077181208054 |
| B24 | `=B23*(1-B12)` | 494.169463087248 |
| B25 | `=B22*(B13+B14)` | 131.778523489933 |
| B26 | `=B5*B15` | 247.5 |
| B27 | `=B26/B16` | 20.625 |

## Hoja `Inventario`

Rango con datos: 11 filas x 6 columnas.

| Cálculo de inventario por etapa |  |  |  |  |  |
| --- | --- | --- | --- | --- | --- |
| Población inicial de la primera etapa = lechones destetados por banda ÷ semanas por banda. Cada etapa hereda la población final de la anterior. |  |  |  |  |  |
| Etapa | Duración (semanas) | Población inicial por semana | Mortalidad (%) | Población final por semana | Población total por etapa |
| Pre-iniciación | 3 | =Flujo_Bandas!B24/(Flujo_Bandas!B9/7) | 0.03 | =C5*(1-D5) | =B5*E5 |
| Iniciación | 3 | =E5 | 0.01 | =C6*(1-D6) | =B6*E6 |
| Crecimiento y desarrollo | 8 | =E6 | 0.005 | =C7*(1-D7) | =B7*E7 |
| Finalización | 4 | =E7 | 0.005 | =C8*(1-D8) | =B8*E8 |
| Inventario total |  |  |  |  | =SUM(F5:F8) |
| Mortalidades y duraciones: de la diapositiva (pre-iniciación 3 %, iniciación 1 %, crecimiento 0.5 %, finalización 0.5 %). Las filas 2-4 estaban en blanco en la diapositiva; aquí se calculan con el mismo método (total = semanas × población final). |  |  |  |  |  |

### Formulas de `Inventario` (13)

| Celda | Formula | Valor guardado |
| --- | --- | --- |
| C5 | `=Flujo_Bandas!B24/(Flujo_Bandas!B9/7)` | 247.084731543624 |
| E5 | `=C5*(1-D5)` | 239.672189597315 |
| F5 | `=B5*E5` | 719.016568791946 |
| C6 | `=E5` | 239.672189597315 |
| E6 | `=C6*(1-D6)` | 237.275467701342 |
| F6 | `=B6*E6` | 711.826403104027 |
| C7 | `=E6` | 237.275467701342 |
| E7 | `=C7*(1-D7)` | 236.089090362836 |
| F7 | `=B7*E7` | 1888.71272290268 |
| C8 | `=E7` | 236.089090362836 |
| E8 | `=C8*(1-D8)` | 234.908644911021 |
| F8 | `=B8*E8` | 939.634579644086 |
| F9 | `=SUM(F5:F8)` | 4259.19027444274 |

## Hoja `CA_Etapa`

Rango con datos: 13 filas x 4 columnas.

| GDP y conversión alimenticia de una etapa |  |  |  |
| --- | --- | --- | --- |
| Ejemplo del pizarrón: etapa de inicio, 15–30 kg en 23 días. Letra difícil: verificar cifras. |  |  |  |
| Concepto | Valor | Unidad | Fórmula / nota |
| Peso inicial | 15 | kg | Pizarrón |
| Peso final | 30 | kg | Pizarrón |
| Días de la etapa | 23 | días | Pizarrón |
| Consumo diario de alimento | 0.9 | kg/día | Pizarrón (leído '0.9'; verificar) |
| Ganancia diaria de peso (GDP) | =(B6-B5)/B7 | kg/día | (Peso final − inicial) ÷ días (15/23 = 0.65) |
| Peso promedio de la etapa | =(B5+B6)/2 | kg | (15 + 30) ÷ 2 = 22.5 |
| Consumo total de la etapa | =B8*B7 | kg/animal | 0.9 × 23 = 20.7 |
| Conversión alimenticia | =IFERROR(B8/B10,0) | kg alim./kg | Consumo diario ÷ GDP (0.9/0.65 = 1.38) |

### Formulas de `CA_Etapa` (4)

| Celda | Formula | Valor guardado |
| --- | --- | --- |
| B10 | `=(B6-B5)/B7` | 0.652173913043478 |
| B11 | `=(B5+B6)/2` | 22.5 |
| B12 | `=B8*B7` | 20.7 |
| B13 | `=IFERROR(B8/B10,0)` | 1.38 |

## Hoja `Rendimiento`

Rango con datos: 7 filas x 4 columnas.

| Rendimiento (%) = peso producto final / materia prima inicial × 100 |  |  |  |
| --- | --- | --- | --- |
| Ejemplo con datos de tu UPP (canal 75 % a 90 kg, Rancho La Huamuchilera). |  |  |  |
| Concepto | Valor | Unidad | Nota |
| Peso de materia prima inicial | 90 | kg | Peso vivo previo al sacrificio (ejemplo) |
| Peso producto final / transformado | 67.5 | kg | Peso de la canal (ejemplo: 75 % de 90 kg) |
| Rendimiento (%) | =IFERROR(B6/B5*100,0) | % | Fórmula de la diapositiva |

### Formulas de `Rendimiento` (1)

| Celda | Formula | Valor guardado |
| --- | --- | --- |
| B7 | `=IFERROR(B6/B5*100,0)` | 75 |

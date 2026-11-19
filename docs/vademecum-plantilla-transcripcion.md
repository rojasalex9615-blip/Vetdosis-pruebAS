# Plantilla de transcripción de vademécum

Para que una tabla transcrita entre directa al motor de cálculo sin retrabajo.
La app exige `unidad_dosis = mg/kg`; si el libro da otra unidad, se convierte en
la transcripción, no después.

## Columnas obligatorias

| Columna | Ejemplo | Regla |
|---|---|---|
| `principio_activo` | `Fenilbutazona` | Nombre de la molécula, no la marca |
| `especie` | `Equino` | Una especie por fila; si el libro dice «perros y gatos», dos filas |
| `via` | `IV`, `IM`, `SC`, `VO` | Normalizar a estas cuatro |
| `dosis_min` | `1.5` | Número sin unidad, punto decimal, sin separador de miles |
| `dosis_max` | `2` | Igual que `dosis_min` si la dosis es única |
| `unidad_dosis` | `mg/kg` | **Siempre `mg/kg`**; convertir antes de transcribir |
| `intervalo` | `12 h`, `24 h`, `dosis única` | Texto corto y uniforme |
| `duracion` | `5 días` | Vacío si el libro no lo dice |
| `indicacion` | `Antiinflamatorio` | Del libro, sin inventar |
| `fuente` | `RIRDC 11/117` | Obra de donde sale el dato |
| `pagina` | `12` | Página impresa, no la del PDF |
| `nota` | `No usar en potros` | Contraindicaciones y avisos |

## Opcionales útiles

`nombre_comercial`, `presentacion`, `registro_sanitario`, `condiciones`,
`tiempo_espera`, `matriz_espera` (carne, leche, huevo).

## Conversiones que hay que hacer al transcribir

El motor no acepta estas unidades; si aparecen, se convierten:

| El libro dice | Convertir a mg/kg |
|---|---|
| `g/100 kg` | × 10 |
| `mg/lb` | ÷ 2.2046 |
| `µg/kg` | ÷ 1000 |
| `mL/kg` de una solución al X % | mL × X × 10 |
| `UI/kg` | No convertir: dejar fuera del motor y anotar en `nota` |
| `mg/animal` | Dejar fuera salvo que se conozca el peso de referencia |

Cuando la conversión no sea limpia, **no adivinar**: dejar la fila con
`unidad_dosis` original y `nota = REVISAR CONVERSION`.

## Reglas de calidad

1. Una dosis por fila. Si el libro da un rango por especie, una fila por especie.
2. `dosis_min` nunca mayor que `dosis_max`.
3. No mezclar indicaciones distintas en la misma fila.
4. Si el libro no da dosis numérica, no inventarla: dejar la fila fuera.
5. Anotar siempre `fuente` y `pagina`: sin eso el dato no es auditable y no
   puede pasar de `pendiente`.

## Destino de los datos

Toda transcripción entra como `estado_revision = 'pendiente'`. Ninguna dosis se
activa para cálculo hasta que un MVZ la valide. Es posología: un error ahí es un
error de medicación.

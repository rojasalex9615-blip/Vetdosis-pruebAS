# Calculadoras: qué datos faltan y qué catálogo ya existe

Corregido el 2026-11-18. La primera versión de esta nota decía que había que
«poblar `catalog.v1.json`» y daba a entender que no había catálogo. **Ale
corrigió: el catálogo de fármacos ya existe y está integrado.** Aquí queda
medido qué hay y qué falta de verdad.

## Lo que ya existe (no hay que crearlo)

| Recurso | Contenido | Estado |
|---|---|---|
| `manufacturer_research.v1.json` | **662 productos** con fabricante, ingredientes, forma farmacéutica y ficha PLM | Todos «Datos verificados» |
| `manufacturer_pautas.v1.json` | **1197 pautas** con dosis, especie, vía, intervalo, retiro y avisos | 1168 «Pauta documentada» |
| Pantalla de catálogo | `ManufacturerCatalogScreen`, enlazada desde el vademécum y desde la dosis de empaque | En uso |

Esto es un catálogo real y grande, no un hueco. Mi error fue mirar solo
`catalog.v1.json` (que sí está vacío) y concluir que no había datos.

## Los dos catálogos no son lo mismo

Hay dos catálogos con propósitos distintos, y no se sustituyen entre sí:

- **Catálogo de fabricantes** (`manufacturer_research` + `manufacturer_pautas`):
  productos comerciales con su posología de empaque. Alimenta la calculadora de
  **dosis de empaque** (mL o tableta por kg) y el vademécum. Es el que existe.
- **Catálogo de principios activos** (`catalog.v1.json`): fármacos por principio
  activo, con dosis en **mg/kg** y concentración en **mg/ml**. Alimenta la
  calculadora de **agente farmacéutico** y los **protocolos por etapas**. Está
  vacío (`farmacos: []`).

Por eso la calculadora de agente y los protocolos no funcionan, aunque haya 662
productos: el motor de protocolos busca
`catalog.drugs.where((d) => d.id == stage['dosis_id'] && d.species == species)`
y exige `unidad_dosis == 'mg/kg'` y `unidad_concentracion == 'mg/ml'`. Las pautas
no tienen esa forma.

**No hace falta una tabla aparte.** La pregunta correcta no es «¿creamos un
catálogo?» sino «¿cómo pasamos las pautas que ya tenemos a la forma que el motor
de protocolos espera?».

## Cuánto del catálogo existente se podría convertir

De las 1197 pautas, 461 son «proporcional al peso». Pero la unidad de dosis no
siempre es masa:

| Dosis / ingrediente | Pautas |
|---|---|
| mL / mg | 220 |
| mL / g | 57 |
| tableta / mg | 34 |
| **mg / mg** | **24** |
| otras combinaciones | resto |

Solo **24 pautas** traen dosis en mg y concentración en mg. Las 220 en mL son
perfectamente calculables, pero con **dosis de empaque**, no con el motor de
principios activos. Es decir: el catálogo que existe cubre bien el camino de
empaque y casi nada el camino de mg/kg.

## Calculadoras: estado real

| Calculadora | Área | ¿Funciona? | Qué falta |
|---|---|---|---|
| Fluidoterapia | Clínica | Sí | Nada |
| Infusión continua (CRI) | Clínica | Sí | Nada |
| Ajuste pediátrico / geriátrico | Clínica | Sí, con reserva | El «factor» lo teclea la persona |
| Producción: cabeza y lote | Producción | Sí | Nada |
| Producción: agua | Producción | Sí | Nada |
| Producción: alimento | Producción | Sí | Nada |
| Peso metabólico | Exóticos | **No** | Referencia `metabolico` |
| Constantes fisiológicas | Clínica | **No** | Referencias `constante` |
| Protocolos por etapas | Clínica | **No** | Referencias `protocolo` + fármacos mg/kg |
| Tiempos de retiro | Clínica | **No** | Referencias `retiro` |

Verificado con el parser real: `referencias: 0` en `calculations.v1.json`. Ese
arreglo vacío es lo que deja sin contenido a las cuatro últimas.

## Detalles que importan

- **Exóticos tiene una sola calculadora y no funciona.** Es la que se movió a
  ese menú; le falta la referencia metabólica.
- **Las 14 referencias vitales existen**, pero las usa la pantalla de signos
  vitales, no la calculadora de constantes. Se podrían enlazar en vez de
  duplicarlas.
- **Las 1197 pautas no alimentan los protocolos** porque son otro modelo, no
  porque falten datos.
- **Producción es el único bloque completo.**

## Qué haría falta

1. Decidir si las referencias `metabolico`, `constante` y `retiro` se cargan en
   `calculations.v1.json` o se enlazan desde sus fuentes actuales.
2. Si se quieren protocolos con principios activos, convertir las pautas
   compatibles (24 directas, más las que se puedan normalizar a mg/ml) a la forma
   de `catalog.v1.json`. Las de dosis en mL no aplican a ese motor.
3. Revisar clínicamente cada dato antes de marcarlo `verified`; el motor rechaza
   protocolos no verificados.

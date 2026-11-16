# Integración de las pautas de Grok — propuesta del 15 de noviembre de 2026

Responde a: «Integrémoslos de la manera más adecuada. ¿Cómo recomiendas
integrarlas y cómo se verían en la app?»

## Qué hay hoy

- **662 fichas comerciales** en el asset `manufacturer_research.v1.json`
  (investigación Grok, importada 2026-10-27). Las lee `ManufacturerCatalog.load()`
  y las pinta «Catálogo de fabricantes» / «Investigación Grok».
- **1197 pautas** en el CSV maestro de Grok (`Pautas_VetDosis_MAESTRO.csv`),
  35 columnas, sin ningún destino en la app ni en Supabase. **Ese es el hueco.**
- El asset de fichas **no trae dosis**. Lo dice su propio documento
  (`manufacturer-vademecum-grok-20261027.md`): «para precargar numéricamente se
  necesita reconciliar cada pauta con producto/presentación/especie/vía/intervalo».
  Grok ya hizo esa reconciliación: es exactamente el CSV de pautas.

## Las dos calculadoras (confirmado por Ale)

La app tiene varias calculadoras de dosis. Las dos que reciben estas pautas son:

1. **Dosis de empaque** (`CommercialPackageDoseScreen`). Usa el **nombre comercial**
   y la indicación del empaque: «1 mL por 20 kg», «2 mL por kg en perros»,
   «1 tableta por 10 kg». Es aritmética proporcional sobre la posología literal.
2. **Agente farmacéutico** (`DoseScreen` + `DoseEngine`). Usa el **fármaco por
   principio activo** y su dosis en **mg/kg** (p. ej. amoxicilina en perro).

Por eso el nombre comercial pertenece a la primera y el principio activo a la
segunda. Una pauta no se copia a las dos: se **enruta** a la que corresponde.

## Cómo se enruta cada pauta

La regla `tipo_regla` decide si la pauta es calculable; la **unidad de
administración** decide la calculadora:

| `tipo_regla` | ¿Calculable? | Destino |
|---|---|---|
| proporcional al peso + unidad de empaque (mL, tableta, sobre) | Sí | Calculadora de empaque |
| proporcional al peso + unidad de masa (mg, g) | Sí | Calculadora por agente |
| proporcional al peso + unidad ambigua (UI, atomización, mcg/mg) | No | Solo ficha |
| fija por animal | No | Solo ficha (no se convierte a proporcional) |
| bandas de peso | No | Solo ficha (requiere su propia tabla) |
| agua/alimento | No | Solo ficha (requiere regla de consumo) |
| esquema vacunal | No | Solo ficha |
| otra / no especificado | No | Solo ficha |

Reparto de las **1197 pautas**:

- 452 proporcionales al peso sin avisos de integridad → **386 a empaque**,
  **57 a agente**, 9 sin calculadora fiable por unidad ambigua.
- 439 de esas pautas calculables pertenecen a productos **que ya están** en la
  app (mismo URL PLM). El resto son de los 34 productos aún sin integrar.

## Qué se implementó (esta entrega)

1. **Asset de pautas**: `assets/clinical/manufacturer_pautas.v1.json`
   (1197 pautas, 701 productos). Se genera con
   `scripts/build/build_pautas_asset.py` desde el CSV de Grok. Es copia literal
   de los 35 campos: **no se inventa ni se reescribe ninguna dosis**.
2. **Modelo** `lib/modules/doses/domain/manufacturer_pauta.dart`: clasifica la
   regla (`PautaRule`) y la calculadora (`PautaCalculator`). `canCalculate` exige
   proporcional + sin avisos + referencia única en kg + unidad inequívoca.
3. **Lectura en la app**: al abrir una ficha del catálogo de fabricantes se
   listan sus pautas con posología literal, especie, vía, intervalo, duración,
   retiro, contraindicaciones, estado y fuente. La ficha indica a qué calculadora
   pertenece cada pauta.
4. **Precarga**: «Calcular según el empaque» aparece solo si hay una pauta
   proporcional de empaque. Precarga presentación, especie, vía, intervalo y
   referencia, y el profesional confirma antes de calcular. Las pautas de agente
   se muestran y se marcan, pero **no** se precargan: el catálogo general
   (`catalog.v1.json`) sigue vacío y sin verificar.

## Cómo se ve en la app

- **Catálogo de fabricantes** → buscas «FLORGEN 300» → abres la ficha.
- Bajo la ficha aparece **«N pauta(s) documentada(s) por el fabricante»**, con
  un aviso de que son datos de investigación **sin verificar en la clínica**.
- Cada pauta es una tarjeta: presentación, especie, vía, principios activos,
  **posología literal**, referencia, regla, **calculadora de destino**, intervalo,
  duración, retiro, contraindicaciones, discrepancias y estado.
- Si la pauta es proporcional de empaque, abajo aparece **«Calcular según el
  empaque»**, que abre la calculadora con los campos precargados y un recordatorio
  de confirmar presentación, especie y peso.
- Si la pauta es fija, por bandas, de agua/alimento o vacunal, **no** hay botón:
  solo se muestra el texto literal. La app nunca convierte una pauta fija o por
  bandas en proporcional.
- Si el producto no tiene pauta, se avisa: «Sin pauta estructurada para esta
  ficha. Usa la posología del empaque.»

## Qué falta y decisiones abiertas

1. **Los 34 productos sin integrar**. Vienen de `origen=gpt_integracion` y
   arrastran errores de la lista maestra: 12 con fabricante malformado
   («registro Q-…») o vacío, y 2 con URL PLM sin `www.` que el parser rechazaría
   (BRONQUIVO NF, EMULMAX -C N5). Hay que limpiar esas filas antes de ampliar el
   asset, o darlos de alta aparte.
2. **Las 1197 pautas no están verificadas por un MVZ**. Entran como
   `review_state = pending`. Se propone reutilizar el **modo revisión** que ya
   existe en el servidor (RPC `review_catalog_list`, `reference_review_list`) en
   vez de crear un tablero nuevo.
3. **Ruta servidor vs asset**. Esta entrega es **solo asset offline**: no toca
   Supabase. El modo revisión requiere una migración candidata nueva (no
   aplicada), con las pautas en una tabla privada y una vista de revisión.
4. **Las 294 filas de `VetDosis_Vademecum_Sustancias_Tabla2.csv`** (farmacocinética
   por sustancia/especie) alimentan la calculadora por agente; van con el
   `catalog.v1.json`, no con las pautas comerciales.

## Límites de esta entrega

- **Implementado y probado localmente** (23 pruebas de dosis + suite completa
  de 1060). **No integrado, no desplegado, no probado en teléfono.**
- No se modificó Supabase ni se activaron reglas regulatorias.
- El asset de pautas es copia literal de Grok; no sustituye la revisión clínica.

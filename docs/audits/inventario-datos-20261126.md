# Inventario verificado de datos — 2026-11-26

Comprobación contra el código y los assets de la rama `docs/handoff-extraccion-20261126`.
Solo lectura: no se modificó ningún asset ni dato.

Método: para cada asset se cuenta lo que contiene y se busca con `grep -rl` qué archivo Dart lo carga. Un asset sin consumidor es huérfano: llega al APK pero ninguna pantalla lo lee.

## 1. Assets clínicos

| Asset | Registros | Consumidor |
|---|---:|---|
| `catalog.v1.json` | **0** | `catalog_repository.dart` |
| `monografias.v1.json` | 53 monografías · 83 dosis | **ninguno** |
| `clasificacion_regulatoria.v1.json` | 1.286 entradas · 815 activos | **ninguno** |
| `regulatory.catalog.v1.json` | **0** | `backup_screen.dart` |
| `manufacturer_pautas.v1.json` | 1.197 pautas | `manufacturer_pauta.dart` |
| `manufacturer_research.v1.json` | 662 | `manufacturer_catalog.dart` |
| `calculations.v1.json` | 6 cálculos · 0 referencias | `calculation_repository.dart` |
| `vital_references.v1.json` | 14 | `vital_reference_repository.dart` |
| `referencias.v1.json` | 34 | `incubation_repository.dart` |
| `forms.clinical.v1.json` | 3 | `backup_screen.dart` |
| `forms.reference.v1.json` | 5 | `backup_screen.dart` |
| `capacidad_avicola.v1.csv` | 12 | `aviculture_repository.dart` |
| `engorda_avicola.v1.csv` | 51 | `aviculture_repository.dart` |
| `equipos_avicola.v1.csv` | 7 | `aviculture_repository.dart` |
| `formulas_avicola.v1.csv` | 12 | `aviculture_repository.dart` |
| `pendientes_avicola.v1.json` | 6 | `aviculture_repository.dart` |
| `postura_avicola_adicional.v1.csv` | 37 | `aviculture_repository.dart` |

## 2. Los dos huérfanos

**`monografias.v1.json`** — 53 monografías con 83 dosis, `estado: sin verificar`. Es el vademécum farmacológico completo. Ninguna pantalla lo lee.

**`clasificacion_regulatoria.v1.json`** — 1.286 entradas, 815 activos, con cruce contra las pautas de la app:

```
app_clasificados        103
app_condicionales         8
app_revision            448
app_no_clasificables    283
```

Tampoco lo lee nadie.

## 3. El catálogo que usa la calculadora está vacío

```json
// assets/clinical/catalog.v1.json
{"schema_version": 1, "catalog_version": "0.1.0",
 "estado": "sin verificar", "fuentes": [], "farmacos": []}
```

Lo carga `AssetCatalogRepository` y alimenta la calculadora de dosis. Con `farmacos: []` no hay nada que calcular.

La pantalla lo maneja bien, no falla en silencio:

> «El Vademécum no tiene fármacos disponibles para calcular. Importa un catálogo con fuente, dosis por peso y concentración por presentación. No se calculará una dosis ingresada libremente en este modo.»

**Es correcto que esté vacío.** Un catálogo vacío no es un fallo: es la negativa a calcular sin datos verificados. El problema es que las 53 monografías que sí existen están en un asset que nadie conecta.

## 4. Cadena rota

```
monografias.v1.json  (53 monografías, 83 dosis)
        │
        └── nadie lo lee ────✗

catalog.v1.json  (0 fármacos)
        │
        └── catalog_repository.dart ──→ calculadora ──→ "no hay fármacos"
```

El trabajo de extracción existe. La conexión no.

## 5. Lo que sí está sano

- **Todos los assets citados en `docs/` existen.** Cero referencias rotas.
- **`pubspec.yaml` declara `assets/clinical/` como directorio**, así que ningún asset queda fuera del APK por falta de declaración.
- **Módulo de exóticos:** el documento afirma 166 filas; el código las tiene en un string `_data` parseado por `|`, y `test/exotics_reference_test.dart` verifica exactamente 166. Coincide.
- **`manufacturer_pautas.v1.json`: 1.197 pautas.** Corrijo una cifra mía anterior: dije 1.229. Son 1.197.

## 6. Pendiente de decidir

Conectar `monografias.v1.json` a la calculadora requiere resolver antes el bloqueo de `Presentation.read` (exige `mg/ml` incondicionalmente) y el de `DoseResult` (exige volumen). Sin eso, conectar el asset solo trasladaría el fallo.

El orden correcto es:

```
1. Presentation.read acepta presentación sin concentración
2. DoseResult permite calcular solo masa
3. monografias.v1.json se transforma al formato de catalog.v1.json
4. Recién entonces la calculadora tiene datos
```

---

*Documento generado por un agente de IA (OpenHands/DeepSeek) a petición de Ale. Solo lectura.*

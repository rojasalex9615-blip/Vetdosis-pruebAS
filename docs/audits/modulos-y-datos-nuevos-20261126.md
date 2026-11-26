# Módulos y datos nuevos — inventario al 2026-11-26

Todo medido contra el repositorio, no de memoria. Rama `docs/handoff-extraccion-20261126`.

## 1. Módulos, por fecha de creación

`flutter test` no está disponible en este entorno; los conteos de pruebas son archivos de prueba que importan cada módulo, no ejecuciones.

| Fecha | Módulo | Archivos | Pantallas | Pruebas | Qué hace |
|---|---|---:|---:|---:|---|
| 2026-10-08 | `ai` | 9 | 1 | 4 | Asistente conversacional |
| 2026-10-08 | `attendance` | 4 | 1 | 0 | Agenda y citas |
| 2026-10-08 | `auth` | 14 | 5 | 1 | Acceso, registro, recuperación |
| 2026-10-08 | `backup` | 12 | 1 | 3 | Exportación e importación |
| 2026-10-08 | `calculations` | 12 | 3 | 0 | Cálculos clínicos (9 herramientas) |
| 2026-10-08 | `core` | 12 | 1 | 0 | Tema, navegación, común |
| 2026-10-08 | `doses` | 19 | 6 | 25 | Vademécum y motor de dosis |
| 2026-10-08 | `forms` | 23 | 8 | 2 | Formularios clínicos |
| 2026-10-08 | `hospital` | 24 | 6 | 19 | Hospitalización |
| 2026-10-08 | `inventory` | 15 | 9 | 2 | Inventario y almacén |
| 2026-10-08 | `offline` | 7 | 0 | 1 | Sincronización sin red |
| 2026-10-08 | `operations` | 23 | 9 | 0 | Quirófano y procedimientos |
| 2026-10-08 | `patients` | 26 | 2 | 2 | Fichas de pacientes |
| 2026-10-08 | `prescribing` | 6 | 2 | 1 | Recetas |
| 2026-10-08 | `subscriptions` | 6 | 1 | 0 | Planes |
| 2026-10-08 | `support` | 5 | 2 | 2 | Ayuda |
| 2026-10-08 | `welcome` | 5 | 3 | 2 | Bienvenida e intro |
| 2026-10-13 | `aviculture` | 15 | 5 | 10 | Avicultura: engorda, postura, capacidad |
| 2026-10-13 | `incubation` | 4 | 1 | 3 | Incubación |
| 2026-10-14 | `dashboard` | 5 | 2 | 4 | Inicio |
| 2026-10-15 | `beta` | 6 | 3 | 3 | Programa beta |
| 2026-10-15 | `exports` | 2 | 0 | 0 | Exportación |
| 2026-10-15 | `identity` | 4 | 0 | 2 | Identidad y perfiles |
| 2026-10-16 | `permissions` | 2 | 1 | 1 | Permisos |
| 2026-10-25 | `review` | 3 | 1 | 1 | Revisión clínica |
| 2026-11-04 | `clinic_experience` | 5 | 1 | 0 | Experiencia de clínica |
| 2026-11-04 | `finance` | 3 | 0 | 0 | Finanzas |
| 2026-11-04 | `production` | 33 | 3 | 30 | Producción pecuaria |
| 2026-11-08 | `laboratory` | 8 | 1 | 2 | Laboratorio |
| 2026-11-12 | `notifications` | 3 | 1 | 1 | Notificaciones |
| 2026-11-12 | `personal_space` | 3 | 1 | 1 | Espacio personal |
| 2026-11-15 | `exotics` | 2 | 1 | 3 | Exóticos: mamíferos pequeños |
| 2026-11-22 | `about` | 1 | 1 | 1 | Acerca de |
| 2026-11-22 | `legal` | 5 | 1 | 1 | Legal y privacidad |

**36 módulos · 180 archivos de prueba en total.**

### Módulos nuevos desde el 1 de noviembre

```
clinic_experience   2026-11-04    1 pantalla
finance             2026-11-04    0 pantallas (solo dominio)
production          2026-11-04    3 pantallas, 33 archivos
laboratory          2026-11-08    1 pantalla
notifications       2026-11-12    1 pantalla
personal_space      2026-11-12    1 pantalla
exotics             2026-11-15    1 pantalla
about               2026-11-22    1 pantalla
legal               2026-11-22    1 pantalla
```

## 2. Datos clínicos nuevos, por fecha de alta

| Fecha | Asset | Registros | Contenido |
|---|---|---:|---|
| 2026-11-21 | `vital_references.v1.json` | 14 | Constantes fisiológicas |
| 2026-11-16 | `manufacturer_pautas.v1.json` | **1.197** | Pautas de fabricante |
| 2026-11-15 | `postura_avicola_adicional.v1.csv` | 37 | Luz, huevos, calidad |
| 2026-11-15 | `engorda_avicola.v1.csv` | 51 | Engorda e índices |
| 2026-11-15 | `formulas_avicola.v1.csv` | 12 | Fórmulas |
| 2026-11-04 | `manufacturer_research.v1.json` | 662 productos | Investigación de fichas |
| 2026-10-13 | `capacidad_avicola.v1.csv` | 12 | Capacidad por etapa |
| 2026-10-13 | `equipos_avicola.v1.csv` | 7 | Equipos |
| 2026-10-13 | `pendientes_avicola.v1.json` | 6 | Pendientes |
| 2026-10-13 | `incubation/referencias.v1.json` | 34 | Referencias de incubación |

**Sin trackear en git** (existen en disco, no están commiteados):

```
assets/clinical/monografias.v1.json               53 monografías · 83 dosis
assets/clinical/clasificacion_regulatoria.v1.json 1.286 entradas · 815 activos
```

## 3. `manufacturer_pautas.v1.json` en detalle

Origen: `Pautas_VetDosis_MAESTRO.csv`, investigador declarado **Grok**.

```
pautas                     1.197
productos distintos          693
fabricantes distintos         79
con dose_reference         1.194
con discrepancies          1.184
con warnings declarados       57
```

Reparto por especie — **el campo no está normalizado**. Tiene **435 valores distintos** para 1.197 pautas, de los cuales **326 aparecen una sola vez**:

| Especie (valor literal) | Pautas |
|---|---:|
| Bovinos | 83 |
| Porcinos | 69 |
| Caninos y felinos | 59 |
| Caninos | 58 |
| no especificado | 40 |
| Equinos | 36 |
| Ovinos y caprinos | 36 |
| Aves | 33 |

Estos ocho valores cubren 414 de 1.197. El resto son variantes de escritura: combinaciones de especies, mayúsculas, listas separadas por comas y frases libres. **No sirve como clave de búsqueda sin normalizar.**

### Campos que parecen llenos y no lo están

Todos los campos son `string`. «no aplica» y «ninguna» son valores de relleno, no ausencias. Contando solo valores reales:

| Campo | Reales de 1.197 |
|---|---:|
| `weight_bands` | **128** |
| `tablet_split` | 113 |
| `site_max` | 666 |
| `withdrawal` | 999 |
| `dose_amount` | 1.195 |
| `dose_reference` | 1.194 |

**`weight_bands` solo tiene datos en 128 pautas.** El resto dice «no aplica». Si una pantalla asume bandas de peso, falla en el 89 % de los casos.

### El campo `state` está contaminado

Debería ser un enum. Tiene 13 valores distintos y 14 vacíos:

```
"Pauta documentada"                         1.168
""                                             14
"2026-11-09"                                    3   ← una fecha
"Extraído literalmente de ficha PLM oficial..."  2   ← un párrafo
"ninguna"                                       2
"no especificado / no aplica"                   1
"agron) dan rangos"                             1   ← texto cortado
...
```

`state` mezcla estado con notas y con fechas. No sirve como filtro fiable.

`discrepancies` es un `string` en las 1.197, no una lista. Ejemplo real:

> «Listado comercial en difesa.mx incluye Difenhidramina y dosis simplificada sin distinción de intervalo; ficha PLM oficial no lo incluye. Se prioriza PLM.»

Es texto útil, pero no se puede consultar por estructura.

## 4. Módulo de producción

El más grande del último mes: 33 archivos, 3 pantallas, 30 archivos de prueba.

```
porcino_capacity.dart          porcino_biosecurity.dart
porcino_environment.dart       porcino_facilities.dart
porcino_feeding.dart           porcino_productive_models.dart
porcino_bandas.dart            porcino_calculators.dart
porcino_reference.dart         porcino_repository.dart
porcino_semen.dart             porcino_upp.dart
aquaculture_reference.dart     aquaculture_management_reference.dart
aquaculture_species.dart       feeding_calculation.dart
growth_calculation.dart        production_catalog.dart
production_unit.dart           production_unit_repository.dart
```

Acuicultura cubre cuatro especies: **tilapia, trucha, cachama, bagre**.

## 5. Módulo de exóticos

Verificado, coincide con su documentación:

```
lib/modules/exotics/domain/exotic_reference.dart    166 filas
lib/modules/exotics/presentation/exotics_menu.dart  1 pantalla
test/exotics_reference_test.dart                    3 pruebas
```

Seis especies: ratón, rata, hámster, jerbo, cuyo, chinchilla. Cuatro secciones: fisiología, reproducción, hematología, bioquímica.

Los datos viven en un string `_data` delimitado por `|` dentro del `.dart`, no en un asset aparte. Funciona, pero no se puede editar sin tocar código.

Dos valores marcados «Corroborar valor y unidad» (fósforo y potasio del cuyo) y dos obras citadas en paralelo sin fusionar, como pidió Ale.

## 6. Documentos de avances que existen

```
docs/avances-2026-11-15.md                  corte del 15 nov, 1021 pruebas
docs/avance-pendientes.md
docs/pendientes-revision-final.md
docs/exoticos-modulo-20261115.md
docs/m15-avicultura-postura.md
docs/m-produccion-lotes-fase1.md
docs/integracion-a-main-20261114.md
docs/calculadoras-datos-faltantes-20261119.md   reparado hoy
docs/colaboradores-y-aportes.md
docs/comentarios-colaboradores.md
docs/coordination-board.md
```

## 7. Discrepancias entre lo declarado y lo real

**`avances-2026-11-15.md` dice «1021 pruebas pasan».** No se puede comprobar aquí: no hay Flutter. Hay 180 archivos de prueba; el número de casos no es verificable sin ejecutar.

**Los conteos de la tabla de arriba son archivos de prueba, no casos.** Un archivo puede tener 1 caso o 40.

**`monografias.v1.json` y `clasificacion_regulatoria.v1.json` no están en git.** Si el sandbox se reinicia, se pierden. Son los dos assets que contienen el vademécum farmacológico completo.

## 8. Lo que esto significa

El trabajo nuevo de las últimas semanas se concentra en:

```
producción pecuaria     el bloque más grande (33 archivos, 30 pruebas)
pautas de fabricante    1.197 pautas de Grok, con calidad de campos irregular
exóticos                módulo cerrado y verificado
avicultura              engorda, postura, capacidad
```

Y el vademécum farmacológico sigue sin conectar:

```
monografias.v1.json     53 monografías, 83 dosis  →  sin consumidor, sin commit
catalog.v1.json         0 fármacos                →  calculadora vacía
```

---

*Documento generado por un agente de IA (OpenHands/DeepSeek) a petición de Ale. Solo lectura.*

# Propuesta: dos vademécums, dos calculadoras

Auditoría previa a cualquier cambio. No se ha creado ninguna migración, no se ha
fusionado ninguna tabla y no se ha tocado el vademécum comercial.

Fecha: 2026-11-26 · Base: `wtrelwtztkddfktrfdpb` · 258 tablas, 77 con datos.

---

## 1. Lo que ya existe

### 1.1 Vademécum comercial (otra calculadora, ya hecha)

| Tabla | Filas |
|---|---:|
| `staging.commercial_products_intake` | 1.384 |
| `staging.commercial_product_enrichment` | 1.384 |
| `staging.commercial_label_regimens` | 563 |
| `staging.raw_intake_rows` | 4.819 |
| `private.vetdosis_catalogos_laboratorios_revision` | 332 |
| `private.vetdosis_mederilab_catalogo_revision` | 189 |
| `private.vetdosis_zoetis_holland_catalogo_revision` | 132 |
| `private.vetdosis_virbac_productos` / `_dosis` / `_activos` | 34 / 64 / 49 |

Ninguna fila tiene `habilitado_en_app = true`. Nada está publicado.

En la app ya funcionan `ManufacturerPauta`, `PautaRule`
(proporcional, fija, bandas, agua/alimento, vacunal, otra) y
`PautaCalculator.package` / `PautaCalculator.agent`. Es decir, la separación
entre las dos calculadoras ya está prevista en el código.

### 1.2 Vademécum farmacológico

| Tabla | Filas | Contenido |
|---|---:|---|
| `private.vetdosis_qwen_farmacos_revision` | 540 | 127 previos + 413 Ramsey (`R0001`…`R0413`) |
| `private.vetdosis_qwen_dosis_revision` | 1.077 | 54 previos + 1.023 Ramsey |
| `private.vetdosis_indice_principios_revision` | 94 | claves normalizadas de principio activo |
| `private.vetdosis_ramsey_pautas_revision` | 1.023 | copia de trabajo con bibliografía y estado |
| `private.vetdosis_ramsey_monografias_revision` | 413 | nombre canónico, variantes, clave de búsqueda |

Puente entre vademécums (hoy sin usar para Ramsey):

- `private.vetdosis_productos_componentes_revision` — 1.465 filas
- `private.vetdosis_relacion_productos_principios_revision` — vacía

### 1.3 App

- `catalog.dart` → `DrugDose(id, name, species, min, max, route, interval, evidence, presentations, contraindications)`
- `dose_engine.dart` → `mass = peso × dosis`, `volume = mass / concentración`
- `pauta_review_gate.dart` → beta muestra, integración oculta

---

## 2. Brechas contra la especificación

| Requisito | Estado actual | Falta |
|---|---|---|
| Especie → principio activo → pautas | `DrugDose` es una dosis por fármaco y especie | lista de pautas por especie |
| Elegir entre varias pautas | no existe | selección explícita, sin campo de dosis libre |
| No bloquear el cálculo | `canConfirm` exige cero alertas y «sin verificar» es alerta | separar aviso de bloqueo |
| Concentración opcional | el motor lanza excepción si falta | permitir resultado solo en mg |
| mg/kg y mL/kg | solo mg/kg | ambas direcciones |
| Autor, título, edición, año, página por pauta | `DrugDose` no los tiene; `qwen_dosis` solo tiene `fuente_original` y `edicion_pagina` | columnas bibliográficas |
| Conservar la expresión original | `dosis_original` solo vive en `ramsey_pautas` | campo en la tabla de pautas |

Consecuencia: hoy la calculadora farmacológica no puede cumplir la regla de
«cada pauta conserva su identidad y procedencia», porque el modelo de datos no
tiene dónde guardarla.

---

## 3. Propuesta de integración

Sin tablas nuevas de pautas y sin tocar el comercial.

### 3.1 Pautas: una sola tabla, con la bibliografía dentro

`vetdosis_qwen_dosis_revision` pasa a ser la tabla de pautas de la calculadora
farmacológica. Se le añaden, de forma aditiva:

```
autor              text
titulo             text
edicion            text
anio               smallint
seccion            text
dosis_original     text      -- la expresión tal como está en la fuente
unidad_original    text
regla              text      -- proporcional | fija | bandas | otra
estado_normalizacion text    -- normalizada | no_normalizable | no_aplica
motivo_no_normalizado text
especies           text[]    -- para que «Perro y gato» sea una pauta, no dos
canal              text      -- beta | integracion
```

Los valores del bloque Ramsey ya están calculados y se rellenan en el mismo
`ALTER`, sin reprocesar el PDF.

Alternativa si prefieres no tocar la tabla existente: dejarla como está y unirla
por `pauta_id` con `vetdosis_ramsey_pautas_revision`. Funciona igual, pero
obliga a un `JOIN` en cada consulta y deja la bibliografía en una tabla que solo
sirve para Ramsey. **Decisión 1.**

### 3.2 Monografías: dejar de ser de Ramsey

`vetdosis_ramsey_monografias_revision` ya tiene lo que la búsqueda necesita
(nombre canónico, variantes, clave sin acentos). Propongo promoverla a
`vetdosis_monografias_revision`, sin prefijo de fuente, y que cualquier fuente
futura escriba ahí. **Decisión 2.**

### 3.3 Índice de principios activos

Extender de 94 a 435 claves: 341 nuevas y 55 que ya existen y solo ganan una
referencia. Dos claves recibirían dos monografías distintas y deben quedar como
dos referencias, no como una fila fusionada:

```
acepromazina → Acepromazina · Acepromazina (ACP)
lidocaina    → Lidocaína · Lidocaína (crema EMLA)
```

**Decisión 3.**

### 3.4 Enlace con el comercial

Usar `vetdosis_relacion_productos_principios_revision`, que está vacía, para el
«desde el principio activo hacia sus productos». Los catálogos comerciales no se
tocan. La ausencia de relación no bloquea nada, como pide la especificación.

---

## 4. Cómo funcionarán las dos calculadoras

**Comercial** (sin cambios): producto → presentación → pauta de etiqueta → mL.

**Farmacológica** (nueva):

1. Seleccionar especie.
2. Seleccionar principio activo (búsqueda por nombre canónico o variante).
3. Ver las pautas de esa especie. Cada tarjeta muestra indicación, dosis,
   unidad, vía, frecuencia, duración, autor, título, edición, año y página.
4. Elegir una pauta. Si hay una sola, se muestra igualmente: nada se
   preselecciona.
5. Introducir peso. Resultado en mg.
6. Concentración: del catálogo comercial si existe, o la que introduzca el MVZ.
   Sin concentración no hay mL, y eso no impide el cálculo en mg.
7. Si la pauta viene en mL/kg, se invierte: primero volumen, y masa si hay
   concentración.

Ninguna pauta se convierte en rango. Si dos autores discrepan, son dos tarjetas.

---

## 5. Conflictos detectados

1. **El gate actual contradice la especificación.** `pauta_review_gate.dart`
   oculta las pautas sin revisar en el canal de integración, y la
   especificación pide que el MVZ siempre pueda elegir. Requiere decisión de
   producto, no solo técnica.
2. **Aviso frente a bloqueo.** Hoy «fuente sin verificar» es una alerta que
   impide confirmar. La especificación separa «no alimentar automáticamente»
   de «no bloquear».
3. **Especie única frente a «Perro y gato».** 212 pautas del Ramsey declaran dos
   especies en una sola fila. Con `especie text` habría que duplicarlas; con
   `text[]` se muestran en ambas sin duplicar.
4. **Nombre de la tabla.** El bloque Ramsey vive en tablas llamadas `qwen`, que
   se refieren al modelo que transcribió el otro libro. Confunde a cualquiera
   que llegue después. **Decisión 4.**
5. **401 pautas no calculables.** 323 con varios valores en una celda o unidad
   múltiple, y 78 con unidad no convertible (gota/ojo, mg/m²). Deben mostrarse
   como texto literal sin cálculo, no ocultarse ni convertirse en un campo
   libre. **Decisión 5.**

---

## 6. Decisiones que necesitan autorización

| # | Decisión | Opciones |
|---|---|---|
| 1 | Bibliografía de las pautas | `ALTER` aditivo a `qwen_dosis` · tabla aparte unida por `pauta_id` |
| 2 | Monografías | promover a nombre neutro · dejar como `ramsey_*` |
| 3 | Índice de principios | extender a 435 · dejar en 94 |
| 4 | Nombre de las tablas de pautas | renombrar a neutro · dejar `qwen_*` |
| 5 | Pautas no calculables | mostrar como texto · ocultar |
| 6 | Fuente de la app | asset JSON versionado · lectura de Supabase |
| 7 | Gate beta/integración | mantener · alinear con la especificación |
| 8 | Tablas `vetdosis_ramsey_*` | conservar como copia de trabajo · borrar |

Sin respuesta a 1, 2 y 4 no conviene escribir código: cambian el esquema y la
pantalla.

---

## 7. Lo que no se hará sin aprobación

- Crear migraciones.
- Fusionar o renombrar tablas.
- Sobrescribir assets.
- Publicar datos (`habilitado_en_app = true`).
- Tocar los catálogos comerciales.
- Modificar la pantalla comercial.

# Handoff para la sesión de extracción

Paquete autocontenido para otra sesión de agente que trabaje en un sandbox distinto. Lee este archivo primero.

Fecha: 2026-11-26 · Origen: sesión de auditoría del issue #41.

---

## 0. Qué hay aquí y qué no

```
handoff-extraccion/
  contexto.md                          ← este archivo
  senasica_productos_vigentes_oct2026.csv    7.959 filas
  lista-completa.csv                         1.341 filas
  tablas/
    farmacos.csv                       398 filas × 18 columnas
    dosis.csv                          329 filas × 6 columnas
    apendices.csv                       39 filas × 3 columnas
    nombres_faltantes.csv               90 filas
```

Todo es **solo lectura**. Nada de esto está cargado en Supabase ni conectado a la app.

---

## 1. Reglas que ya están decididas — no las reabras

Estas vienen del issue #41 y de la especificación conceptual. Si tu propuesta las contradice, está mal.

**1.1 Dos vademécums separados, no uno fusionado.**

```
comercial        unidad = producto/marca     (registro, especies autorizadas, concentración)
farmacológico    unidad = principio activo   (dosis, indicaciones, bibliografía)
```

Cada uno con su calculadora. La relación entre ellos es navegación, no dependencia. La ausencia de un producto comercial no puede impedir consultar una monografía, ni al revés.

**1.2 No fusionar autores distintos.** Si Ramsey dice 5 mg/kg y otro autor dice 10, son dos pautas con sus citas. No se promedian, no se convierten en rango 5-10.

**1.3 Conservar siempre el original.** Valor y unidad originales intactos. El normalizado va aparte, como derivado, y solo si la conversión es inequívoca.

**1.4 Especies autorizadas ≠ especies con evidencia.** El padrón SENASICA dice para qué especie está autorizado un producto en México. Eso no es evidencia farmacológica. Nunca se cruzan como validación.

**1.5 El campo `grupo` A/B/C/D no se usa.** Decisión de Ale. Ignóralo si aparece.

**1.6 No inventar datos clínicos.** Toda dosis lleva fuente. Si falta, se declara la falta.

**1.7 Presencia no es verificación.** Que un dato exista no significa que sirva para calcular. Cuatro dimensiones distintas: método de extracción, revisión documental, verificación clínica, elegibilidad de cálculo.

---

## 2. Trampas ya detectadas — no vuelvas a caer

**2.1 El 4,95 frente a 5 no es redondeo.**

```
0,0333333 × 150 mg = 4,9499955 mg/kg   ← decimal truncado a 7 cifras al guardar
1/30      × 150 mg = 5,0 mg/kg          ← valor real de la etiqueta
```

La etiqueta dice «1 tableta por cada 30 kg». Es 1/30 exacto. Al persistirlo como decimal se perdió precisión. **No declares equivalencia por aproximación.** Conserva la fracción o el texto original.

**2.2 Las unidades están mezcladas en la fuente.** En las 83 dosis de `monografias.v1.json`:

```
mg/kg           55   ← solo estas entran al motor mg/kg
mg/animal        9
UI/animal, UI/kg 4
mg/m2            2
gota (3 tipos)   4
aplicación       2
ml/kg            1
mg/kg/h          1
mm de pomada     1
ng/kg            1
% en mezcla O2   1
vacío            2
```

**28 de 83 no son mg/kg.** No las fuerces. `gota/ojo`, `mm de pomada` y `% en mezcla con O2` no tienen conversión posible: son `no_aplica`.

**2.3 Un token compartido no es el mismo producto.** Al conciliar nombres, `ENROVET INYECTABLE` coincide con media base solo por el token `inyectable`. 409 de 1.714 candidatas del padrón caen en esta trampa. Marca siempre el motivo.

**2.4 No propagar datos entre nombres parecidos.** Si dos registros se parecen, son dos registros hasta que se demuestre lo contrario.

**2.5 El nombre comercial está haciendo de clave de variante.** En `vademecum_producto_comercial` hay 1.298 productos y 1.298 producto+concentración: la concentración no varía dentro de un mismo nombre porque la dosis va en el nombre (`Enroxol tabs 50` / `Enroxol tabs 150`). No asumas que un nombre = una presentación.

---

## 3. Estado real de los datos

### 3.1 Vademécum farmacológico — extraído por OCR

Fuente: *Vademécum Farmacológico para perros y gatos, 9.ª ed.* (ed. Ian Ramsey), Parte A.

```
farmacos.csv     398 filas · 18 columnas
dosis.csv        329 filas · 6 columnas
apendices.csv     39 filas · 3 columnas (páginas 548-591)
```

Columnas de `farmacos.csv`:

```
num · Fármaco · Pág. libro · Categoría legal · Presentación · Acción/mecanismo ·
Indicaciones · DOSIS perros · DOSIS gatos · DOSIS otras especies ·
Precauciones/Seguridad · Contraindicaciones · Reacciones adversas ·
Interacciones · Dosis (texto completo) · Nombre confirmado en el índice ·
Fiabilidad del nombre · Notas
```

Calidad medida:

```
con alguna dosis            382 de 398
dosis perro                 320 de 329
dosis gato                  318 de 329
texto completo              329 de 329
filas sin número                0
nombre fiable ("del índice")  308
nombre "sin identificar"       90
```

**Las 90 sin identificar no están vacías.** Tienen dosis y contenido; les falta el nombre. Están en `tablas/nombres_faltantes.csv`. Van de la página 43 a la 556, dispersas. Causa documentada en la propia hoja del xlsx: el índice impreso del libro tiene un salto de páginas.

### 3.2 Padrón SENASICA — universo de referencia

```
senasica_productos_vigentes_oct2026.csv
columnas: razon_social, nombre_producto, numero_registro, especies
```

```
filas                          7.959
registros únicos               7.901   (58 repetidos)
nombres distintos              7.693   (266 repetidos)
registros sin especie              0
```

Partición provisional contra el catálogo comercial, excluyente y exhaustiva:

| Categoría | Filas |
|---|---:|
| identificada | 705 |
| candidata | 1.714 |
| sin_correspondencia | 5.540 |
| **TOTAL** | **7.959** |

De las 1.714 candidatas, **409 (23,9 %) se sostienen solo en un token genérico** (`inyectable`, `shampoo`, `tabletas`…): son falsos positivos probables. Descontándolas quedan 1.305 candidatas con fundamento específico.

**Las 5.540 sin correspondencia no se descartan.** Son inventario de lo que existe fuera de nuestro catálogo. Ale lo decidió explícitamente.

### 3.3 Catálogo comercial — en Supabase, no en este paquete

Está en `vetdosis_reference_staging` del proyecto `wtrelwtztkddfktrfdpb`. No se copia aquí porque es grande y cambiante. Resumen:

```
vademecum_producto_comercial        1.833 filas · 755 con concentración (41 %)
vademecum_producto_por_especie      3.373 filas · 950 con dosis/kg · 0 habilitadas
relacion_productos_principios       1.470 filas
productos_componentes               1.465 filas
```

Todas en `sin_verificar`. Ninguna alimenta cálculos.

### 3.4 `lista-completa.csv`

```
1.341 filas · sustancia declarada, laboratorio
sin registro sanitario, sin especies
```

Sirve para enlazar producto → principio activo. Cruzada con SENASICA: 702 productos identificados, 642 con componente que mapea a un activo del Acuerdo DOF, cubriendo 344 activos distintos.

---

## 4. Contrato de datos ya acordado

### 4.1 Jerarquía

```
monografia (53)   identidad bibliográfica padre, una por principio activo
  └── pauta (83)  dosis hija: especie, vía, rango, unidad, indicación
```

**No se crean 83 fármacos.** Las 53 monografías son el padre; las 83 dosis son pautas hijas.

### 4.2 Campos obligatorios de una pauta

```
pauta_id · monografia_id · principio_activo
especie · indicacion · via · frecuencia · duracion
dosis_original { min, max, unidad }        ← nunca se altera
dosis_normalizada { min, max, unidad, regla, estado }   ← derivado
referencia { obra, autor, anio, ubicacion, sha256 }
texto_original · nota · evidence
```

`catalog.v1.json` **no tiene** `indicacion`, `duracion`, `texto_original`, `nota` ni `referencia.ubicacion`. El contrato nuevo los recupera.

### 4.3 Estados de normalización

```
normalizada       conversión inequívoca, derivado persistido
no_normalizable   falta concentración, potencia o denominador
no_aplica         la unidad no es convertible (gota/ojo, mm de pomada, % en gas)
```

### 4.4 Evidence — cuatro dimensiones, nunca un enum plano

```
metodo                 ocr / transcripcion_manual / extraccion_ia /
                       importacion_estructurada / etiqueta_fabricante
revision_documental    pendiente / contrastada / discrepante / ilegible
verificacion_clinica   no_revisada / en_revision / verificada / rechazada
elegibilidad_calculo   derivada, con regla_version e invalidada_por
```

Derivación:

```
habilitada = verificacion_clinica.estado == "verificada"
          && revision_documental.estado == "contrastada"
          && verificador != null && rol != null && fecha != null
          && contra_fuente != null
```

`contrastada` documentalmente **no** implica `verificada` clínicamente. `verificada` debe identificar quién, cuándo y contra qué fuente.

---

## 5. Lo que la app hace hoy

### 5.1 Dos motores separados

```
lib/modules/doses/domain/dose_engine.dart              motor mg/kg genérico
lib/modules/doses/domain/commercial_package_dose.dart  motor de etiqueta comercial
```

El comentario del segundo lo declara: «intentionally separate from the generic mg/kg drug engine». Bandas de peso, pautas fijas y calendarios **no** se convierten a regla proporcional.

### 5.2 El asset farmacológico está vacío

```json
// assets/clinical/catalog.v1.json
{"schema_version": 1, "catalog_version": "0.1.0",
 "estado": "sin verificar", "fuentes": [], "farmacos": []}
```

Es el asset que carga la calculadora farmacológica. `monografias.v1.json` **no lo lee ningún código Dart** (verificado con `grep -rl`). Las 53 monografías están en un asset huérfano.

### 5.3 Bloqueo técnico conocido

`Presentation.read` en `catalog.dart` exige `unidad_concentracion == 'mg/ml'` de forma incondicional y previa:

```dart
if (map['unidad_concentracion'] != 'mg/ml') {
  throw const FormatException('Esta versión requiere concentración explícita en mg/ml.');
}
```

Aunque `concentracion` es nullable, nunca se llega a esa línea sin unidad. Como las monografías no tienen concentración, no pueden entrar. Hay un parche propuesto en `docs/audits/propuestas/presentation-read.patch`, **no aplicado**.

Segundo bloqueo: `DoseResult` exige volumen en el constructor, así que calcular solo masa (mg sin mL) requiere otra migración.

---

## 6. Qué se espera de la sesión de extracción

Prioridad, en orden:

**6.1 Recuperar los 90 nombres faltantes.** Es lo único que impide usar 90 monografías con dosis válida. Requiere cruzar el índice del libro con las páginas 43-556. No re-extraigas el PDF completo: usa `tablas/nombres_faltantes.csv` y busca solo el nombre de cada página.

**6.2 Estructurar dosis por especie, vía e indicación.** Las columnas `DOSIS perros` / `DOSIS gatos` ya separan especie, pero el contenido es texto libre. Cada dosis debe ser una pauta con `dosis_original` intacta.

**6.3 Clasificar unidades.** Aplicar los estados `normalizada` / `no_normalizable` / `no_aplica` de la sección 4.3. No forzar nada.

**6.4 No tocar.** Supabase, migraciones, assets conectados, habilitación de pautas. Solo producir CSV/JSON de trabajo y documentar.

---

## 7. Cómo dejar el resultado

Deja los artefactos en el repositorio para que la otra sesión los lea:

```
docs/audits/handoff-extraccion/resultado/
```

Formato preferido: CSV con cabecera y UTF-8, más un `LEEME.md` que explique qué hiciste, qué no pudiste y por qué.

**No hagas commit de nada clínico sin aprobación de Ale.** Los datos extraídos no son verdad clínica hasta que un MVZ los revise.

---

## 8. Contacto entre sesiones

Las sesiones no se hablan directamente. El puente es el repositorio:

```
repo    rojasalex9615-blip/Vet-dosis-pruebas
issue   #41  Coordinación GPT-6 ↔ DeepSeek: auditoría integral de los dos vademécums
```

Deja preguntas y hallazgos como comentario en el issue #41. La otra sesión los lee desde ahí.

---

*Documento generado por un agente de IA (OpenHands/DeepSeek) a petición de Ale. Solo lectura.*

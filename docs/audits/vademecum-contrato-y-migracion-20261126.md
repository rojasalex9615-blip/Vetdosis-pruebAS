# Contrato de datos y migración mínima — vademécums VetDosis

Entrega documental de solo lectura. No se modificó código, SQL, tablas, vistas, assets ni se habilitaron pautas. No hay commit asociado.

Fecha: 2026-11-26 · Alcance: respuesta al issue #41 de `Vet-dosis-pruebas`.

---

## 1. Partición SENASICA — CSV de auditoría

Archivo: `docs/audits/senasica-particion-20261126.csv` (7.959 filas, una por fila del padrón).

### Partición sobre filas, mutuamente excluyente

| Categoría | Filas |
|---|---:|
| identificada | 705 |
| candidata | 1.714 |
| sin_correspondencia | 5.540 |
| **TOTAL** | **7.959** |

Cuadra exacto con el padrón. Los criterios son jerárquicos: se evalúa `identificada` primero; si no se cumple, `candidata`; si no, `sin_correspondencia`. Ninguna fila cae en dos categorías.

### Métricas separadas, no sumables entre sí

```
filas                                7.959
registros únicos (numero_registro)   7.901   ← 58 registros repetidos
nombres distintos                    7.693   ← 266 nombres repetidos
```

Sobre nombres distintos (métrica informativa, no suma 7.959 porque un nombre puede ocupar varias filas): 669 identificados, 1.654 candidatos, 5.370 sin correspondencia.

### Algoritmo exacto de normalización

```
1. Sustituir acentos y diéresis: á é í ó ú ü ñ → a e i o u u n
2. Pasar a minúsculas
3. Descomponer en NFD y eliminar marcas diacríticas (categoría Unicode Mn)
4. Sustituir toda secuencia de caracteres no [a-z0-9] por un espacio
5. Colapsar espacios repetidos y recortar extremos
```

Tokenización: se divide el nombre normalizado por espacios y se conservan solo tokens de **5 o más caracteres**. Los tokens más cortos se descartan por ser demasiado ambiguos.

Clasificación:

```
identificada         el nombre normalizado coincide exactamente con un
                     nombre_comercial normalizado del catálogo comercial

candidata            no coincide exactamente, pero comparte al menos un
                     token de >=5 caracteres con algún nombre del catálogo

sin_correspondencia  no coincide exactamente ni comparte tokens
```

### Limitaciones de la conciliación — leer antes de usar

**Un token compartido no demuestra identidad comercial.** El criterio es deliberadamente permisivo para no perder candidatos; eso produce falsos positivos conocidos.

**Falso positivo por token genérico.** La columna `motivo` distingue dos clases de candidata:

```
token específico compartido   →  motivo: "token(s) especifico(s) compartido(s): ..."
solo token genérico           →  motivo: "solo token(s) generico(s): ... alto riesgo"
```

**409 de las 1.714 candidatas (23,9 %) se sostienen solo en un token genérico.** Están marcadas en la columna `motivo` y deben tratarse como falsos positivos probables, no como candidatas reales. Ejemplos reales:

```
ENROVET INYECTABLE                        → token: inyectable
SHAMPOO KISIE KISIE NATURE ANTISEBORREICO → token: shampoo
CEFALINE 300 TABLETAS                     → token: tabletas
```

El vocabulario genérico excluido del juicio de especificidad es:

```
tabletas tableta suspension solucion inyectable frasco polvo jarabe crema
shampoo gotas ampolleta sobres pomada aerosol collar pipeta comprimidos
gel spray liquido oral concentrado pasta
```

**No se propagó ningún dato entre nombres parecidos.** La categoría es una hipótesis de trabajo para orientar investigación, no una identidad.

**El padrón se conserva íntegro.** Las 5.540 filas sin correspondencia no se descartan ni se subordinan al catálogo. Conservan `numero_registro`, nombre original y titular.

### Columnas del CSV

| Columna | Contenido |
|---|---|
| `fila_origen` | posición 1-based en el padrón fuente |
| `numero_registro` | registro sanitario original, sin alterar |
| `nombre_original` | nombre tal como aparece en el padrón |
| `nombre_normalizado` | resultado del algoritmo anterior |
| `razon_social` | razón social del titular, sin alterar |
| `especies` | especies declaradas en etiqueta |
| `categoria` | identificada / candidata / sin_correspondencia |
| `motivo` | justificación legible de la categoría |
| `tokens_compartidos` | tokens que motivaron la candidatura (vacío si no aplica) |

Este CSV es un artefacto de auditoría. No es aprobación clínica ni carga a Supabase.

---

## 2. Contrato de datos: monografía, pauta y Evidence

### 2.1 Jerarquía correcta

La identidad bibliográfica padre es la **monografía** (53). Las **dosis son pautas hijas** (83). No se crean 83 fármacos.

```
monografia  (53)   identidad bibliográfica, una por principio activo y fuente
  └── pauta (83)   dosis concreta: especie, vía, rango, unidad, indicación
```

Un fármaco puede tener varias pautas porque distintos autores, especies o indicaciones lo requieren. Esa multiplicidad es información, no duplicación.

### 2.2 Esquema propuesto para pauta

```jsonc
{
  "pauta_id": "meloxicam-perro-vo-ramsey-9a",
  "monografia_id": "meloxicam",
  "principio_activo": "meloxicam",

  // Contexto clínico — necesario para comparar sin fusionar
  "especie": "canino",
  "indicacion": "osteoartritis crónica",
  "via": "oral",
  "frecuencia": "cada 24 h",
  "duracion": "según evolución",

  // Valor original — nunca se altera
  "dosis_original": {
    "min": "0.1",
    "max": "0.2",
    "unidad": "mg/kg"
  },

  // Derivado trazable — solo si la conversión es inequívoca
  "dosis_normalizada": {
    "min": "0.1",
    "max": "0.2",
    "unidad": "mg/kg",
    "regla": "identidad.v1",
    "concentracion_usada": null,
    "estado": "normalizada"
  },

  // Procedencia estable
  "referencia": {
    "obra": "Vademécum Farmacológico, 9.ª ed., Parte A",
    "autor": "Ian Ramsey (ed.) / BSAVA",
    "anio": 2023,
    "ubicacion": "p. 509",
    "sha256": "67c59a48b7858ccf4266f1fd7e1772439f78cafb1475b9c6069fd0c66b39b760"
  },

  "texto_original": "0,1–0,2 mg/kg cada 24 horas...",
  "nota": "conservado del literal de la fuente",
  "evidence": { }
}
```

Campos que `catalog.v1.json` **no tiene** y este contrato recupera: `indicacion`, `duracion`, `texto_original`, `nota`, `referencia.ubicacion`, `dosis_normalizada`.

### 2.3 Estados de normalización

```
normalizada         conversión inequívoca, derivado persistido
no_normalizable     falta concentración, potencia o denominador
no_aplica           la unidad original no es convertible a mg/kg
                    (gota/ojo, mm de pomada, % en mezcla con O2)
```

Las 83 pautas se reparten así según su unidad original:

| Unidad | Pautas | Tratamiento |
|---|---:|---|
| mg/kg | 55 | normalizable por identidad |
| mg/animal | 9 | no_normalizable (falta peso de referencia) |
| UI/animal, UI/kg | 4 | no_normalizable (requiere potencia) |
| mg/m2 | 2 | no_normalizable (requiere superficie corporal) |
| gota/ojo, gota, gota/narina | 4 | no_aplica |
| aplicación | 2 | no_aplica |
| ml/kg | 1 | normalizable solo con concentración |
| mg/kg/h | 1 | no_normalizable (dosis por tiempo) |
| mm de pomada | 1 | no_aplica |
| ng/kg | 1 | normalizable por factor 1000 |
| % en mezcla con O2 | 1 | no_aplica |
| vacío | 2 | no_normalizable |

**Solo 55 de 83 entran al motor mg/kg.** Las 28 restantes se conservan íntegras con su unidad y quedan fuera del cálculo hasta que exista conversión justificada. No se fuerzan.

### 2.4 Contrato de Evidence — cuatro dimensiones

```jsonc
{
  "evidence": {
    "metodo": {
      "tipo": "ocr | transcripcion_manual | extraccion_ia | importacion_estructurada | etiqueta_fabricante",
      "herramienta": "tesseract",
      "version_herramienta": "5.3.0",
      "fecha_proceso": "2026-10-27"
    },

    "revision_documental": {
      "estado": "pendiente | contrastada | discrepante | ilegible",
      "contrastada_contra": {
        "tipo": "sha256 | url",
        "valor": "67c59a48b7858ccf...",
        "ubicacion": "p. 509"
      },
      "fecha": "2026-11-20",
      "nota": "texto libre"
    },

    "verificacion_clinica": {
      "estado": "no_revisada | en_revision | verificada | rechazada",
      "verificador": "nombre",
      "rol": "MVZ responsable",
      "fecha": "2026-11-20",
      "contra_fuente": {
        "obra": "Ramsey 9.ª ed.",
        "ubicacion": "p. 509"
      }
    },

    "elegibilidad_calculo": {
      "habilitada": false,
      "regla_version": "gate.v1",
      "motivo": "verificacion_clinica.estado != verificada",
      "invalidada_por": null
    }
  }
}
```

### 2.5 Reglas de derivación

`elegibilidad_calculo` **nunca** se infiere del método de extracción. Se deriva:

```
habilitada = verificacion_clinica.estado == "verificada"
          && revision_documental.estado == "contrastada"
          && verificacion_clinica.verificador != null
          && verificacion_clinica.rol != null
          && verificacion_clinica.fecha != null
          && verificacion_clinica.contra_fuente != null
```

`contrastada` documentalmente **no** implica `verificada` clínicamente. Son campos distintos y así se conservan.

`invalidada_por` registra qué cambió cuando la evidencia se revisa: si la fuente se corrige, la verificación previa queda marcada, no se borra.

### 2.6 Correspondencia en Dart — sin implementar

```dart
class Evidence {
  final ExtractionMethod metodo;
  final DocumentaryReview revisionDocumental;
  final ClinicalVerification verificacionClinica;
  final CalculationEligibility elegibilidad;
}

class DocumentaryReview {
  final ReviewState estado;      // pendiente, contrastada, discrepante, ilegible
  final SourcePointer? contrastadaContra;
  final DateTime? fecha;
  final String? nota;
}

class ClinicalVerification {
  final VerificationState estado; // noRevisada, enRevision, verificada, rechazada
  final String? verificador;
  final String? rol;
  final DateTime? fecha;
  final SourcePointer? contraFuente;
}
```

**Incompatibilidad actual.** `Evidence.read` en `catalog.dart` acepta solo:

```dart
if (status != 'verificada' && status != 'sin verificar') {
  throw const FormatException('Estado de verificación inválido.');
}
```

Es un enum plano de dos valores. El contrato anterior no cabe. Requiere migración de contrato con período de compatibilidad: aceptar el formato antiguo (`estado` + `fuente`) y mapearlo a `verificacion_clinica.estado`, dejando `metodo` y `revision_documental` en `null` con advertencia.

---

## 3. Migración mínima de `Presentation.read`

### 3.1 Situación actual

```dart
factory Presentation.read(Map<String, dynamic> map) {
  if (map['unidad_concentracion'] != 'mg/ml') {
    throw const FormatException(
      'Esta versión requiere concentración explícita en mg/ml.',
    );
  }
  return Presentation(
    requiredText(map, 'id'),
    requiredText(map, 'nombre_comercial'),
    optionalQuantity(map, 'concentracion'),   // nullable, pero inalcanzable
    Evidence.read(map),
  );
}
```

La validación de unidad es **incondicional y previa**. Aunque `concentracion` es `Quantity?` y `optionalQuantity` devuelve `null` para vacío, nunca se llega a esa línea sin `unidad_concentracion`.

**Consecuencia medida.** `Presentation.read` es obligatorio para cada entrada de `presentaciones[]`. Una pauta sin concentración no puede cargarse. Como las 53 monografías no tienen concentración, no pueden entrar al catálogo actual.

### 3.2 Cambio propuesto

```dart
factory Presentation.read(Map<String, dynamic> map) {
  final concentration = optionalQuantity(map, 'concentracion');
  if (concentration != null && map['unidad_concentracion'] != 'mg/ml') {
    throw const FormatException(
      'La concentración debe expresarse en mg/ml.',
    );
  }
  return Presentation(
    requiredText(map, 'id'),
    requiredText(map, 'nombre_comercial'),
    concentration,
    Evidence.read(map),
  );
}
```

Tres líneas. La unidad se valida **solo cuando hay concentración**. No se introduce valor centinela. No se relaja ninguna otra validación.

### 3.3 Impacto en el motor

`DoseEngine.calculate` ya bloquea correctamente:

```dart
final concentration = presentation.concentration;
if (concentration == null) {
  throw const FormatException('Falta la concentración de esta presentación.');
}
```

Con el cambio, una pauta sin concentración **carga** y **calcula masa en mg**, pero **falla de forma segura** al pedir mL. Es exactamente el comportamiento que fija el criterio de GPT-6.

### 3.4 Compatibilidad hacia atrás

| Caso | Antes | Después |
|---|---|---|
| `concentracion: "10"`, `unidad: "mg/ml"` | carga | carga, sin cambio |
| `concentracion: "10"`, `unidad: "mg/g"` | excepción | excepción, sin cambio |
| `concentracion: null`, `unidad: "mg/ml"` | excepción | **carga** (concentración ausente) |
| `concentracion: null`, sin `unidad_concentracion` | excepción | **carga** (concentración ausente) |
| `concentracion: ""`, `unidad: "mg/ml"` | excepción | **carga** (vacío equivale a ausente) |

**Ningún catálogo válido deja de cargar.** El cambio solo amplía lo aceptado; no rechaza nada que hoy pase. El test existente `'Missing concentration never inferred'` sigue pasando: verifica que el **cálculo** lanza excepción, no que la carga falle.

### 3.5 Pruebas propuestas

No implementadas. Requieren toolchain Flutter, ausente en este entorno.

**Prueba 1 — carga sin concentración.**
```
Entrada : presentacion {id, nombre_comercial, concentracion: null}
Esperado: Presentation.concentration == null, sin excepción
```

**Prueba 2 — unidad inválida con concentración presente.**
```
Entrada : {concentracion: "10", unidad_concentracion: "mg/g"}
Esperado: FormatException('La concentración debe expresarse en mg/ml.')
```

**Prueba 3 — cálculo de mg sin concentración.**
```
Entrada : peso 10 kg, dosis 0.2 mg/kg, presentacion.concentration == null
Esperado: mass = 2 mg; volume bloqueado
Estado  : requiere además desacoplar mass de volume en DoseResult
```

**Prueba 4 — mL sin concentración falla seguro.**
```
Entrada : peso 10 kg, dosis 0.2 mg/kg, pide mL
Esperado: FormatException('Falta la concentración de esta presentación.')
Estado  : ya cubierta por dose_test.dart
```

**Prueba 5 — regresión: catálogo completo sigue cargando.**
```
Entrada : fixture() actual de dose_test.dart
Esperado: sin cambio de comportamiento
```

### 3.6 Lo que el cambio NO resuelve

`DoseResult` exige `volume` y `roundedVolume` en el constructor:

```dart
DoseResult(this.mass, this.volume, this.roundedVolume, this.alerts);
```

Con concentración ausente no hay volumen. La prueba 3 requiere hacer `volume` y `roundedVolume` nullable, o crear un `DoseResult` parcial. **Eso es un cambio mayor y no está incluido en esta migración mínima.**

Consecuencia práctica: el cambio de `Presentation.read` permite **cargar** pautas sin concentración, pero el motor aún no puede **calcular** solo masa. Para eso hace falta una segunda migración en `DoseEngine` y `DoseResult`, que debe autorizarse por separado.

---

## 4. Los diez conflictos — filas de origen y veredicto

### 4.1 Enrofloxacina canino — las diez filas reales

| Producto | Dosis/kg | Unidad | Vía | Concentración | mg/kg calculado |
|---|---|---|---:|---|---:|
| ENROFLOX M L.A. | 0,010 | mL | Subcutánea | 200 + 20 mg/ml | 2,0 |
| NEUMOXOL | 0,025 | mL | Intramuscular | no disponible | — |
| ENROXOL | 0,0333333 | tableta | Oral | 150 mg (tabs 150) | 5,0 |
| ENROXIL | 0,0333333 | tableta | Oral | 150 mg | 5,0 |
| ENROFLOXACINA 10% SANFER | 0,050 | mL | IM, IV | 100 mg/ml | 5,0 |
| FLOXAPANA 10% | 0,050 | mL | SC, IM | 100 mg/ml | 5,0 |
| BAYTRIL SOLUCIÓN INYECTABLE | 0,100 | mL | SC, IM | 50 mg/ml | 5,0 |
| ENROXAL 50 SUSPENSIÓN | 0,100 | ml | Oral | 50 mg/ml | 5,0 |
| BAYTRIL FLAVOUR 50 mg | 0,100 | tableta | Oral | 50 mg | 5,0 |
| ENROCILINA | 0,100 | tableta | Oral | 50 mg | 5,0 |

### 4.2 Sobre el 4,95 frente a 5

El valor `0.0333333` almacenado **no es un redondeo de cálculo, es un truncamiento de almacenamiento**:

```
0,0333333 × 150 mg  = 4,9499955 mg/kg   ← con el valor truncado
1/30      × 150 mg  = 5,0 mg/kg          ← valor exacto
diferencia          = 0,0500045 mg/kg
```

La dosis original de la etiqueta es «1 tableta por cada 30 kg», es decir **1/30 tableta/kg exacto**. Al persistirla como decimal de 7 cifras se pierde precisión. La diferencia de 4,95 a 5 **no es equivalencia clínica por aproximación**: es el mismo valor expresado con distinta precisión.

**Consecuencia para el contrato.** La pauta debe conservar la fracción o el texto original (`1 tableta / 30 kg`), no solo el decimal derivado. Comparar 4,95 con 5 como si fueran valores distintos sería un error de origen aritmético.

No se declara equivalencia por aproximación. Se declara **identidad de la regla de origen**.

### 4.3 Veredictos

| # | Activo | Especie | Veredicto | Fundamento |
|---|---|---|---|---|
| 1–2 | enrofloxacina | canino | mismo mg/kg | 1/30 × 150 = 5 y 1/10 × 50 = 5 |
| 3 | ENROFLOX M L.A. | canino | formulación distinta | 200+20 mg/ml da 2 mg/kg; es larga acción |
| 4 | enrofloxacina | felino | mismo mg/kg | idéntico patrón que canino |
| 5–6 | cefalexina | canino | **pendiente** | requiere concentración verificable de la suspensión |
| 7 | levetiracetam | canino | **discrepancia abierta** | 20 vs 60 mg/kg, 3× |
| 8 | amantadina + meloxicam | canino | no comparable | combinación, dosis no atribuible a un principio |
| 9 | amoxicilina trihidrato | canino, felino | **discrepancia abierta** | 0,040 vs 0,080 mL/kg, 2× exacto |
| 10 | carbón + zeolita + caolín | canino | indicación distinta | intoxicación aguda vs mantenimiento |

Ninguno se cierra como pauta aprobada. Los casos 5, 6, 7 y 9 quedan abiertos hasta completar concentración y fuente.

### 4.4 Datos que faltan para cerrar los abiertos

| Caso | Falta |
|---|---|
| cefalexina suspensión | concentración mg/mL de la presentación usada |
| levetiracetam | indicación y fuente de cada valor; posible diferencia carga/mantenimiento |
| amoxicilina trihidrato | si 0,040 es dosis diaria y 0,080 por toma |

---

## 5. Estado y siguientes pasos

### Entregado

1. CSV de auditoría SENASICA, 7.959 filas, partición excluyente que cuadra.
2. Algoritmo de normalización y limitaciones documentadas, con falso positivo demostrado.
3. Contrato de monografía/pauta/Evidence con dimensiones separadas.
4. Migración mínima de `Presentation.read`, tres líneas, compatible hacia atrás.
5. Los diez conflictos con filas reales, concentraciones y corrección del 4,95.

### Bloqueado por autorización

- Implementar el cambio en `Presentation.read`.
- Migrar `DoseResult` y `DoseEngine` para calcular solo masa.
- Conectar `monografias.v1.json` al catálogo.
- Migrar el contrato de `Evidence` en Dart.

### Verificación pendiente

No hay toolchain Flutter en este entorno. Las cinco pruebas propuestas están escritas como especificación, no ejecutadas. Requieren un entorno con Dart para validarse antes de fusionar.

---

*Documento elaborado por un agente de IA (OpenHands/DeepSeek) a petición de Ale, en respuesta al issue #41. Solo lectura; sin cambios en código, assets, SQL ni base de datos.*

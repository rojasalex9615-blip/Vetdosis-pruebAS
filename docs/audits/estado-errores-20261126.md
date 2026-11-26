# Estado de los errores detectados — 2026-11-26

Contraste entre los hallazgos de la revisión y lo que la otra sesión ya resolvió en
`docs/audits/handoff-extraccion/resultado/`. Para no repetir trabajo ni pisar cambios.

## 1. Lo que la otra sesión ya resolvió

Commit `98ebcac`, rama `docs/handoff-extraccion-20261126`.

Trabajó sobre la extracción por visión (1.023 filas), no sobre el OCR, con este argumento:
«el PDF son fotos y el OCR es la causa de los nombres perdidos». Es correcto.

| Hallazgo mío | Estado |
|---|---|
| 90 filas sin nombre | **Atacado**: 26 candidatos de alta, 7 de media, 57 sin candidato |
| Nombres que se fusionarían mal | **Resuelto**: 413 monografías, paréntesis conservado |
| Unidades sin normalizar | **Clasificadas**: 133 unidades, 622 normalizadas, 323 no normalizables, 78 no aplica |
| Dosis con varios valores en una celda | **Resuelto**: 52 marcadas `varios_valores_en_celda`, sin elegir una |
| Coma decimal vs punto de miles | **Resuelto**: `1.000` = mil, `0,25` = un cuarto |

Los 15 grupos de posibles sinónimos quedaron **sin fusionar**, como pediste.

Y lo más importante: **ninguna de las 1.023 pautas está habilitada para cálculo**.
`evidence_elegibilidad_calculo` = `no_habilitada` en las 1.023. No se inventó nada.

## 2. Errores que siguen abiertos

### 2.1. `monografias.v1.json`: la indicación falta en 40 de 53

```
monografías con indicación    13 de 53
dosis con indicación propia    0 de 83
monografías sin grupo         13 de 53
```

El campo `indicacion` existe pero está vacío en el 75 % de las monografías. Las pautas
nuevas (`pautas.csv`) **sí** traen indicación, así que este asset quedó atrás respecto
al trabajo de la otra sesión.

Consecuencia: hoy no se puede responder «¿para qué sirve este fármaco?» desde el asset.

### 2.2. `catalog.v1.json` vacío y `monografias.v1.json` huérfano

Sin cambios. La calculadora sigue sin datos y el asset sin consumidor.

La cadena sigue rota:

```
monografias.v1.json  (53 monografías, 83 dosis)  →  nadie lo lee
catalog.v1.json      (0 fármacos)                →  calculadora vacía
```

### 2.3. `manufacturer_pautas.v1.json`: campos que parecen llenos

Nada de esto se ha tocado.

| Campo | Reales de 1.197 |
|---|---:|
| `weight_bands` | 128 |
| `tablet_split` | 113 |
| `species` | 435 valores distintos, 326 de ellos una sola vez |
| `state` | 13 valores distintos, 14 vacíos, fechas y párrafos mezclados |

### 2.4. Los 57 nombres sin candidato no se pueden resolver aquí

La otra sesión ya lo demostró: probando desplazamientos de página de −40 a +40, el mejor
es +1 y acierta el 29 %. La causa es el OCR.

**No hay libro de Ramsey en este workspace.** Hay 13 PDFs y ninguno es el vademécum.
Sin el libro no se pueden validar los 26 candidatos de alta ni resolver los 57.

### 2.5. Sin Flutter local

```
which flutter dart  →  NO DART/FLUTTER
```

No se puede ejecutar `flutter test` ni compilar. Pero **sí hay CI** con Flutter:
`.github/workflows/build-test-apk.yml`, `build-apk-main.yml`, `build-debug-apk.yml`
y otros corren `flutter test`. Un push a una rama dispara la verificación.

## 3. Los dos bloqueos de código, medidos

### `Presentation.read` — `lib/modules/doses/domain/catalog.dart:67`

```dart
factory Presentation.read(Map<String, dynamic> map) {
  if (map['unidad_concentracion'] != 'mg/ml') {
    throw const FormatException(
      'Esta versión requiere concentración explícita en mg/ml.',
    );
  }
```

Rechaza cualquier presentación que no sea mg/ml. Parche propuesto en
`docs/audits/propuestas/presentation-read.patch`, sin aplicar. `catalog.dart` sigue intacto.

### `DoseResult` — exige volumen

Aunque se arregle `Presentation.read`, el resultado exige volumen, y las 83 dosis incluyen
9 en `mg/animal`, 2 en `mg/m2`, 4 en gotas y 2 en `aplicación`, donde el volumen no existe.

**Son dos cambios de código, no uno.** El segundo es mayor que el primero.

## 4. Reparto de unidades de las 83 dosis

```
mg/kg           55
mg/animal        9
UI/animal        2
gota/ojo         2
mg/m2            2
UI/kg            2
aplicación       2
(vacío)          2
ml/kg            1
gota/narina      1
mg/kg/h          1
mm de pomada     1
```

55 de 83 son mg/kg: esas sí son calculables con peso. Las otras 28 no lo son sin
conversión, y el contrato prohíbe convertir sin dato inequívoco.

## 5. Qué se puede hacer sin ayuda de otro modelo

| Tarea | ¿Se puede? |
|---|---|
| Publicar los assets huérfanos en git | **Hecho** (commit `ecbe019`) |
| Rellenar la indicación de las 40 monografías | **No** — exige el libro |
| Validar los 26 nombres candidatos | **No** — exige el libro |
| Arreglar `Presentation.read` | Sí, con CI para verificar |
| Arreglar `DoseResult` | Sí, pero es cambio de diseño |
| Normalizar `species` de las pautas | Sí, pero es escribir datos |
| Poblar `catalog.v1.json` desde `monografias` | Solo tras los dos arreglos de código |

## 6. Sobre pedir ayuda a otro modelo

**Para datos clínicos: no sirve.** Ningún modelo ve el libro. Gemini, Mistral o Sonnet
inventarían dosis si se les pide rellenar la indicación que falta. Eso rompe la regla
de Ale: *nunca inventar datos clínicos; cada dosis con su fuente*.

**Para código: sí ayuda**, pero el cuello no es la capacidad del modelo, es que no hay
Flutter local. La verificación real ya la hace el CI.

**Donde un segundo modelo aporta de verdad** es en revisar el trabajo del otro, no en
generar datos. La otra sesión (Sonnet) ya hizo eso bien: no convirtió unidades, no fusionó
sinónimos, no habilitó nada para cálculo.

---

*Documento generado por un agente de IA (OpenHands/DeepSeek) a petición de Ale. Solo lectura.*

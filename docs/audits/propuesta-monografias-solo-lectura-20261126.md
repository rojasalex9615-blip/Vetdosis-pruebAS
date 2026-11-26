# Propuesta: conectar monografías sin romper la separación

2026-11-26. Basada en el código real, no en suposiciones.

## 1. El paso 2 no es como lo planteé

Dije que el siguiente paso era «`DoseResult` exige volumen». Al leer el código, el
problema es más grande y el arreglo más pequeño de lo que pensé.

### Lo que encontré midiendo

```
dosis totales en monografias.v1.json        83
dosis en rango (min != max)                 55
dosis con valor único (min == max)          28
dosis mg/kg + única + calculable            16
monografías con presentaciones               0
dosis con concentración                      0
```

Y dos puertas más que no había visto:

```dart
// catalog.dart:124 — DrugDose.read
if (map['unidad_dosis'] != 'mg/kg') {
  throw const FormatException(
    'Esta versión requiere dosis explícita en mg/kg.',
  );
}
```

```dart
// dose_view_model.dart:66
final prescribed = drug!.prescribedDose;   // solo si min == max
if (prescribed == null || dose.trim().isEmpty) {
  throw const FormatException(
    'Este producto no tiene una dosis única y verificada. '
    'No se puede calcular automáticamente.',
  );
}
```

Así que no hay **un** bloqueo de volumen. Hay **cuatro** bloqueos en serie:

```
1. DrugDose.read rechaza toda unidad que no sea mg/kg
2. Presentation.read exige concentración (ya arreglado, PR #148)
3. dose_view_model exige dosis única: descarta 55 de 83
4. DoseResult exige volumen: descarta las que no son mg/ml
```

Además, el campo de dosis que teclea el usuario **no se usa**:

```dart
doseMgKg: prescribed,   // no `dose`
```

El texto tecleado solo se valida como no vacío. La aritmética usa la dosis del
catálogo. Si la dosis es un rango, no hay con qué calcular.

### Conclusión

Forzar las monografías por el motor de cálculo daría **16 de 83 dosis** como mucho,
y exigiría inventar la concentración de las otras 67. Eso rompe tu regla.

## 2. Lo que propongo: no calcular, mostrar

La app **ya tiene** el patrón correcto, y lo usa para las pautas del fabricante.

`vademecum_screen.dart` tiene dos modos separados desde antes:

```
[ Por principio activo ]  [ Por nombre comercial ]
```

Y el modo «por principio activo» ya renderiza pautas como lista de solo lectura:

```dart
VademecumDrugView(
  pautas: pautaList,
  canCalculate: canCalculateDrug,
  onOpenDrugCalculator: canCalculateDrug ? ... : null,
)
```

Y hay un gate de canal que ya decide si se muestran datos sin revisar:

```dart
// pauta_review_gate.dart
bool mostrarPautasSinRevisar([String canal = _canal]) =>
    !canal.startsWith('integr');
```

Las monografías encajan exactamente ahí: son principio activo, de Ramsey, marcadas
`sin verificar`. **No hay que tocar el motor de cálculo.**

## 3. El cambio concreto

### Paso A — cargar el asset (nuevo archivo)

`lib/modules/doses/domain/monografia.dart`, copiando el patrón de
`manufacturer_pauta.dart:253`:

```dart
static Future<MonografiaCatalog> load() async => parse(
  await rootBundle.loadString('assets/clinical/monografias.v1.json'),
);
```

Campos: `id`, `farmaco`, `grupo`, `indicacion`, `dosis[]`. Cada dosis con `especie`,
`via`, `min`, `max`, `unidad`, `frecuencia`, `calculable`, `nota`, `texto_original`.

Nada se interpreta. `texto_original` se muestra tal cual.

### Paso B — mostrarlo en el modo «por principio activo»

Reutilizar `VademecumDrugView` o una vista gemela. Cada dosis se pinta con:

```
Oxantel · Perro, Gato · VO · 20 mg/kg · una vez
[sin verificar] Ramsey, 9ª ed., Parte A
```

Sin botón de calcular. Sin campo de peso. Sin volumen.

### Paso C — el gate de revisión, sin inventar uno nuevo

Reutilizar `pauta_review_gate.dart`. Las monografías son `sin verificar`, así que:

```
canal beta        → se muestran con «Dato en revisión, no usar en pacientes»
canal integration → no se muestran
```

Es la misma regla que ya rige las pautas. No hace falta una segunda.

## 4. Un error en el LEEME que conviene corregir

Al rebasar encontré el commit `bfc5b1c` de la otra sesión, que aplica la regla de canal.
Está bien encaminado, pero su LEEME afirma algo que el código no sostiene:

> «Las 622 sí entran al motor de masa (peso × mg/kg).»

Medido sobre `pautas.csv`:

```
habilitada_con_aviso            622
de esas, unidad mg/kg exacto    471
resto                           151
```

Y `catalog.dart:124` rechaza cualquier unidad distinta de `mg/kg` exacto:

```dart
if (map['unidad_dosis'] != 'mg/kg') {
  throw const FormatException('Esta versión requiere dosis explícita en mg/kg.');
}
```

Las 151 restantes son:

```
mg/m²      40      UI/kg       9      ng/kg        5
µg/kg      33      mg/kg/h     7      mmol/kg      5
ml/kg      13      µg/kg/min   7      mg/kg/día    4
g/kg        6      mg/kg/min   5      otras       17
```

Ninguna entra al motor tal cual. Necesitarían conversión, y el contrato la prohíbe sin
dato explícito. La cifra honesta es **471**, no 622.

No lo digo para señalar a nadie: es el mismo error que yo cometí al hablar de «un solo
bloqueo de volumen». Las unidades son más variadas de lo que parece desde fuera.

## 5. Por qué esto respeta tus reglas

| Regla | Cómo se cumple |
|---|---|
| Nunca inventar datos clínicos | No se calcula nada; se muestra `texto_original` |
| Cada dosis con su fuente | El asset ya trae Ramsey + edición + parte |
| Dos vademécums separados | Principio activo va al modo `farmaco`; comercial no se toca |
| Comercial no cae en Ramsey | El motor comercial no se modifica |
| No mezclar pautas con Ramsey | Van en listas distintas, con gate distinto |

Y algo importante: **las 55 dosis en rango no se convierten en una dosis única.**
Se muestran como rango. Eso es lo que dice el libro.

## 6. Lo que sigue sin resolverse

Mostrar no arregla los datos. Sigue pendiente:

```
indicación vacía en 40 de 53 monografías   → exige el libro
3 dosis con nota «VERIFICAR»               → exige el libro
13 monografías sin grupo                   → exige el libro
57 nombres sin candidato                   → exige el libro
```

Ninguna de esas se arregla con código. Por eso propongo mostrar lo que hay, marcado,
antes que fingir que está completo.

## 7. Alcance del PR

```
nuevo   lib/modules/doses/domain/monografia.dart
nuevo   lib/modules/doses/presentation/monografia_view.dart
edita   lib/modules/doses/presentation/vademecum_screen.dart   (solo el modo farmaco)
nuevo   test/monografia_test.dart

NO toca pubspec.yaml: assets/clinical/ ya esta registrado (pubspec.yaml:53)
NO toca lib/modules/doses/domain/dose_engine.dart
NO toca catalog.dart
NO toca nada del vademécum comercial
```

Riesgo bajo: son archivos nuevos más un punto de inserción en una pantalla.

## 8. Dependencia que hay que resolver antes

El asset **no está en `main`**:

```
git cat-file -e gh/main:assets/clinical/monografias.v1.json   →  no existe
```

Solo existe en `docs/handoff-extraccion-20261126`, junto con los commits de la otra
sesión. Un PR contra `main` que cargue el asset fallaría en tiempo de ejecución.

Dos salidas:

**A. Fusionar primero la rama de docs.** Más limpio: `monografias.v1.json` y
`pautas.csv` entran juntos, y el PR de solo lectura los consume ya presentes.

**B. Incluir el asset en el PR.** Funciona, pero duplica el archivo en dos ramas y
el merge posterior se complica.

Recomiendo **A**. Pero la rama de docs la tocó la otra sesión, así que esa fusión
es una decisión tuya, no mía.

## 9. Orden recomendado

```
1. PR #148 (hecho, CI verde)         ← desbloquea leer presentaciones sin concentración
2. Este PR: monografías de solo lectura
3. Después: decidir si el motor de cálculo aprende rangos
```

El paso 3 es una decisión clínica, no técnica. Un rango de dosis calculado a un peso
concreto exige que alguien decida qué punto del rango usar. Eso no lo decide un agente.

---

*Documento generado por un agente de IA (OpenHands/DeepSeek) a petición de Ale.*

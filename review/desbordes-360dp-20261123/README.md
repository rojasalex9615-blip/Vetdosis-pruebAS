# Desbordes y texto cortado · 23 nov 2026

Encargo: corregir errores visuales de desbordamiento y texto cortado en toda la
app, estilo Neu, en teléfono. Base: `a60b081` de `beta/profesores-20261115`.

No se tocó color, tipografía, jerarquía, textos clínicos ni la estructura de las
pantallas. Todos los cambios son de reparto de ancho.

## Cómo se midieron

En este entorno no hay SDK de Flutter ni acceso a `pub.dev`, así que no se pudo
compilar para reproducir los `RenderFlex overflow` en ejecución. En su lugar se
escribió `scripts/validation/audit_overflow.py`, que enmascara cadenas y
comentarios, recorre las llamadas a widgets, extrae la lista real de `children`
de cada `Row` y estima el ancho pintado de cada hijo (tamaño del `TextTheme` o
`fontSize`, grosor, interpolaciones como valor corto, y en los ternarios solo la
rama más larga).

Presupuesto de referencia: **294 dp**, que es lo que queda dentro de una
`VetCard` en un teléfono de **360 dp** (360 − 16×2 de pantalla − 17×2 de la
tarjeta con su borde).

Barrido inicial sobre 347 archivos: 47 candidatos, de los que **7 filas
desbordaban** en 360 dp con la escala de texto normal, más dos rejillas que
cortaban casi todos sus rótulos.

## Lo que estaba cortado

| Medido | Dónde | Qué se veía |
|---|---|---|
| 345 dp | Leyenda del gráfico de producción | «Rendimiento Real en Granja» cortado |
| 334 dp | «ALERTA CRÍTICA: TIEMPOS DE RETIRO ACTIVOS» | el rótulo no cabía junto al contador |
| 330 dp | «Anticipación de avisos de hospitalización» | cabecera cortada en Ajustes |
| 330 dp | «Calendario de pagos · solo administración» | cabecera cortada en Comisiones |
| 311 dp | Silo: «Autonomía: N días ⚠️ ¡URGENTE!» | se cortaba justo en el aviso |
| 308 dp | «Notificaciones de hospitalización» | cabecera cortada |
| 299 dp | «Beneficios y accesos de cortesía» | cabecera cortada |
| 153 dp en celda de 133 | Rejilla de herramientas de producción | «Capacidad de Caseta/Nav…», «Factor conversión aliment…» y casi todos los subtítulos con puntos suspensivos |

## Qué se cambió

Se siguió la convención que ya usa el propio sistema de diseño: `VetSectionHeader`
resuelve este caso con `Expanded(child: Text(...))`.

- **Cabeceras de sección** (`Row` de icono + hueco + título, sin ningún hijo
  flexible): el título pasa a `Expanded` y baja de renglón en vez de cortarse.
  En `clinic_experience` (3), `alert_preferences_panel`, `commission_panel` (2),
  `subscription_screen`, `statistics_screen`, `personal_space_screen`,
  `review_catalog_screen` (2) y `production_dashboard`.
- **Leyenda del gráfico**: de `Row` a `Wrap`; las dos entradas bajan a un segundo
  renglón y se leen enteras.
- **Filas de dato y valor** (silos y tarjetas de instalación): la etiqueta cede
  el espacio que pida el dato en vez de empujarlo fuera del borde.
- **Rejilla de herramientas de producción**: los rótulos pasan a dos líneas y la
  celda crece de 118 a 132 dp para que quepan (`childAspectRatio` 1.35 → 1.2).
  El contenido ocupa 92 dp, así que quedan 14 dp de holgura.
- **Filas dentro de botones** (Google, herramientas, filtro de especie): el texto
  pasa a `Flexible`, que es lo que faltaba para escalas de texto grandes.

Un detalle que apareció al corregir: en la alerta de tiempos de retiro convivían
`Expanded` y `Spacer` en la misma `Row`. El reparto flexible era mitad y mitad y
el título caía a cuatro líneas, así que se quitó el `Spacer`, que ya era
redundante. Se comprobó que ese antipatrón no se repite en ningún otro sitio.

## Estado

`python3 scripts/validation/audit_overflow.py --fail-on-overflow` → **0 filas
fuera del ancho de 360 dp** (antes 7). Se comprobó que el guardián falla de
verdad: al reintroducir una de las correcciones, sale con error 1 y señala el
archivo y la línea.

Los 30 hallazgos que siguen listados son el patrón correcto de dato y valor
(`Expanded` en la etiqueta y un valor corto a la derecha) o contenedores de alto
fijo que sí caben; se dejan como referencia, no son errores.

El analizador quedó enganchado a la etapa `verify` de `.gitlab-ci.yml`. Es
análisis estático en Python, no necesita Flutter ni el SDK de Android y termina
en segundos, así que adelanta el fallo antes de la compilación larga.

## Pendiente

- **Sin compilar ni probar en teléfono**: las medidas son estimadas sobre el
  código, no capturas de ejecución. Falta `flutter analyze`, `flutter test` y una
  ronda de capturas en un equipo con el SDK.
- No revisado por CodeRabbit, no integrado y no desplegado.

# Familia de calculadoras · cabeceras pastel aprobadas

Ale confirmó el volumen de #55 y pidió ajustar las cabeceras al sombreado de las
propias tarjetas de la app. Las cabeceras usan una franja pastel uniforme, con
texto oscuro y esquinas redondeadas; se conservan las superficies acolchadas,
campos hundidos y botones cápsula.

La paleta compartida usa cian, aqua, turquesa/menta, azul/índigo, violeta, lila y
morado. Se retiraron los tonos decorativos arena/naranja/verde oliva del mapa de
calculadoras. Los colores semánticos de advertencia/error no se modifican.

Se extiende el mismo conjunto de componentes a las cuatro operaciones de dosis,
cálculo de producto, herramientas clínicas, fluidoterapia, cálculo comercial del
empaque y calculadoras avícolas/incubación. El acceso manual desde dosis personales
hereda el estilo seleccionado. El modo estándar conserva sus controles Material.

Se reutilizan CalculatorSurface, CalculatorSelectorCard, NeuHeaderCard,
NeuInputBorder, WorkspacePanel y NeuPrimaryButton. CalculatorActionButton es el
punto común para acciones en Neu/estándar; no contiene cálculos. Las etiquetas
clínicas se disponen fuera del campo para permitir varias líneas. Conversión usa
un selector expandido para que ambas unidades quepan en móvil.

No se cambian motores, fuentes, valores, validaciones, permisos ni los enlaces
paciente/peso/fármaco/hospitalización. Los controladores y callbacks son los mismos.
La comprobación aritmética de los cuatro modos se repite con los controles Neu.

Capturas reales con sombras difuminadas, sin datos clínicos:
[claro](light.png) y [oscuro](dark.png).

Reproducir:
`flutter test test/previews/capture_calculator_pastels.dart --dart-define=CALCULATOR_PREVIEW_DIR=review/calculator-neu-family-20261027`

Validaciones focalizadas: 53 regresiones de calculadoras/peso/temas, 4 casos de
aritmética Neu a 320 dp y 4 renderizados (claro/oscuro y 320 dp/texto 1.6) pasaron.
Analyze limpio. La suite completa y el resultado de CodeRabbit se registran en #31.
Migración de estilo autorizada por Ale; no equivale a merge, despliegue o APK nueva.

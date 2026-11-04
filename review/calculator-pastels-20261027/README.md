# Primera adaptación visual de calculadoras

Referencia: imágenes pastel/neumórficas aportadas por Ale. Base: #51.

La identidad por herramienta ya existía, pero CalculatorSurface solo era utilizado
por fluidoterapia. Ahora el cálculo de producto, las operaciones de dosis y los
cálculos clínicos utilizan fondos pastel estables por herramienta, encabezado con
icono y superficies suaves. Fluidoterapia conserva su contenedor para no anidarlo.
Los cuatro modos aritméticos tienen identidades propias. El modo oscuro usa tonos
profundos y acentos aclarados. El estilo estándar conserva su presentación sin
sombras neumórficas. El color no reemplaza títulos ni iconos.

Las unidades de los campos aritméticos y clínicos se repiten como ayuda multilínea
para que sigan visibles cuando una etiqueta larga se recorta en móvil. Se conserva
la advertencia de valores cero cuando corresponda. No se cambian motores, entradas,
fuentes, reglas de confirmación, dosis ni resultados.

Capturas reales de widgets con catálogos locales, sin datos de pacientes ni clínica:
[claro](light.png) y [oscuro](dark.png). No son capturas de una APK instalada.

Reproducir:
`flutter test test/previews/capture_calculator_pastels.dart`

Validado: 45 pruebas existentes de cálculo, peso y tema; dos capturas renderizadas
y dos comprobaciones a 320 dp con texto 1.6. Analyze limpio. La revisión de
CodeRabbit, integración y validación visual de APK siguen pendientes. Esta primera
entrega se limita a las pantallas indicadas; no rediseña vademécum, inicio ni otros
módulos de las referencias.

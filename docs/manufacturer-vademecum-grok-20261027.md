# Catálogo comercial Grok integrado al vademécum

Se incorporan 662 filas del archivo VetDosis_verificado_completo.csv (Drive ID
1zDjes473bV6_Xbat8rDfAzL5UtX6xelw), los 47 informes VERIFICACION_GRUPO y el
historial actualizado hasta 2026-10-27. El asset conserva cada fila, URL PLM,
URL principal, notas, estado documental, referencia al informe y contenido del
informe/historial. La raíz del asset incluye SHA-256 del CSV y URL de origen.
No se usa como fuente de estados la hoja original, que aún tiene index_only.

## Comportamiento

- Vademécum → Catálogo comercial y dosis del fabricante: búsqueda local por
  producto, laboratorio, ingrediente o forma, con resultados paginados.
- Una ficha muestra la fuente PLM, datos del índice, notas de Grok e informe
  completo con fuentes. La consulta funciona sin conexión; abrir URLs externas
  requiere red y los enlaces privados de Drive requieren acceso de su titular.
- Las 662 URLs son distintas. Se conservan nombres comerciales repetidos,
  porque no identifican por sí solos la formulación/presentación.
- El acceso a cálculo se muestra solo cuando el vademécum recibe canCalculate.
- Desde el cálculo comercial también se puede seleccionar una ficha. Cambiar
  producto descarta todos los parámetros, confirmaciones y resultados previos.
  El nombre seleccionado queda ligado a su fuente hasta volver a entrada manual.

## Dosis del fabricante y límites del material recibido

El CSV tiene 10 columnas de identificación/procedencia y no trae dosis,
especie, concentración, vía e intervalo como campos estructurados. Los informes
sí contienen información clínica textual, con cobertura desigual y algunos
resúmenes por muestras. Por tanto no se genera automáticamente una pauta para
las 662 filas ni se transforma el estado Datos verificados en aprobación de
cálculo clínico.

La integración permite consultar esa evidencia junto a la calculadora existente
y transcribir la pauta exacta del empaque para calcular cantidades proporcionales
al peso. No mezcla dosis genéricas de principio activo con posología comercial,
ni convierte vacunación, bandas de peso, pautas fijas o calendarios en reglas
proporcionales. Se conservan las verificaciones y aritmética exacta existentes.

Para precargar numéricamente más adelante se necesita reconciliar cada pauta
con producto/presentación/especie/vía/intervalo, restricciones y fuente explícita;
los informes ya disponibles son el punto de partida, sin reinvestigar por defecto.
No se modificó Supabase ni se activaron nuevas dosis en el motor genérico.

## Verificación

Pruebas de integridad de las 662 URLs y 47 informes, búsqueda sin acentos,
conservación de nombres repetidos, rechazo de fuentes duplicadas/informes
faltantes, consulta sin botón de cálculo y selección sin dosis inventada.
Se mantienen las pruebas de aritmética proporcional y fraccionamiento.

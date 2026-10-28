# Selector y recorrido de dosis con paciente

Entrega sobre #52. No integrada en main ni en una APK nueva.

## Presentación

Herramienta/Tipo de cálculo usa una tarjeta independiente con cabecera de color.
El título queda fuera del campo y no flota sobre el valor. Texto de selección y
etiquetas: 14; etiquetas flotantes y unidades: 12, respetando la ampliación del
sistema. Unidades multilínea, iconos/nombres y foco de teclado conservados.
Los acentos verdes, petróleo y violeta se combinan con la superficie clara y el
relieve previo; el modo oscuro sigue disponible. Capturas reales de widgets:
[claro](light.png), [oscuro](dark.png).

Reproducir sin sobrescribir las capturas de #52:
`flutter test test/previews/capture_calculator_pastels.dart --dart-define=CALCULATOR_PREVIEW_DIR=review/calculator-selector-20261027`

## Paciente, peso y fármaco

Desde Cálculo rápido y desde el modo Volumen desde dosis y concentración se puede
abrir un selector de pacientes hospitalizados accesibles de la clínica actual.
Reutiliza la pantalla de peso diario: se revisa una medición guardada y se abre
el cálculo de producto sin cerrar la pantalla que conserva su validador. Usar el
peso sigue siendo explícito. La fuente se revalida al calcular y confirmar.

El cálculo de producto ya busca principio activo/nombre comercial y combina
Vademécum con dosis personales; ahora muestra las presentaciones en los resultados.
La entrada al vademécum comercial conserva también el peso y su validador: se elige explícitamente la medición y se vuelve a comprobar antes de calcular según el empaque. Cambiar los datos durante esa comprobación descarta el resultado. No se elige automáticamente un fármaco al cambiar de paciente. No se convierte una
pauta mg/kg en mcg/kg/min, UI/kg o una frecuencia de tratamiento. Las dosis sin
pauta única verificada siguen bloqueadas.

Después de la doble confirmación hay acceso a las indicaciones del paciente en
hospitalización, con nueva validación de peso y sesión. Las indicaciones, revisiones
y el registro de medicación ya existen. Esta entrega no crea una orden, receta,
aplicación ni transferencia automática de un valor calculado a una indicación.
Tampoco interpreta texto libre de órdenes existentes como pauta calculable.

La navegación revisa clínica, actor y revisión de acceso. El selector descarta
respuestas antiguas, rechaza una estancia de otra clínica y borra nombres/búsqueda
al revocar contexto o pasar a segundo plano. La lectura clínica sigue validándose
por las vías existentes. Pacientes ambulatorios sin estancia no se incluyen en
este primer acceso de peso hospitalario; pueden seguir usando el cálculo manual.

## APK de referencia aportado por Ale

Archivo Drive: https://drive.google.com/file/d/1qxpzJkUdjm_6TrNOwnG2vQhwv7cS2Bca/view

Nombre: `app-arm64-v8a-beta-release.apk`. Tamaño: 51,216,517 bytes.
SHA-256: `99fb5aeb288300d3294bfad4c8a47f40dccc4fec91ba07dd2bfb622a04fb07b3`.
Se descargó y se inspeccionó la estructura del APK y sus assets, sin ejecutarlo. Logo, catálogo farmacológico y definiciones de cálculos coinciden en bytes con esta rama; esto no acredita equivalencia del código ni de otras funciones.
La referencia visual observable es también la captura de Ale. No se atribuye una
rama/SHA de código al binario ni se afirma haber probado sus pantallas en Android.
No se sube el APK ni sus credenciales al repositorio.

## Validación

Pruebas existentes de cálculo y peso: 57 pasaron. Nuevas: selección de paciente y
validador vivo, respuesta de otra clínica, revocación/respuesta tardía y segundo
plano; acceso a indicaciones tras confirmar y rechazo de peso invalidado. Capturas
en claro/oscuro y renderizado a 320 dp con texto 1.6. Analyze sin incidencias.
La comprobación comercial cubre peso explícito, revocación, ausencia de validador y cambios de parámetros durante la espera. Suite completa y revisión CodeRabbit se registran en #31 al finalizar.

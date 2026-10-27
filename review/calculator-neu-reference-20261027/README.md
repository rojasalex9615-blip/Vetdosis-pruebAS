# Referencia neumórfica: una sola calculadora

Ale solicita confirmar el estilo antes de extenderlo. Base: #53.

Esta referencia usa el modo **Volumen desde dosis y concentración** de
DoseMathTools, con `visualReference: true`. La navegación normal no activa esa
opción y los otros modos conservan su presentación. No se aplicó el cambio al
resto de calculadoras ni se generó una APK nueva.

Se reutilizan y parametrizan los componentes existentes:

- WorkspacePanel y neuShadows: radios amplios, iluminación suave y profundidad.
- NeuHeaderCard: cabecera integrada mediante degradado hacia el cuerpo.
- NeuInputBorder: mayor profundidad interior y foco visible.
- NeuPrimaryButton: cápsula elevada, transición de relieve al presionar.

Los parámetros nuevos son optativos; sus valores predeterminados conservan las
vistas anteriores. No hay otra implementación de cálculo: se mantienen los mismos
controladores, validaciones, cambio de modo y callback de paciente. Etiquetas fuera
de la cavidad, unidades secundarias dentro, sin recortes en esta referencia.

[Captura real](reference.png), con valores ficticios para comprobar la operación
12.5 × 2 ÷ 25 = 1 mL. No es recomendación de dosis ni dato de un paciente.
El renderizado activa el difuminado real de sombras, que Flutter desactiva por
defecto en pruebas. No se ha editado la captura ni generado una imagen de diseño.

Reproducir: `flutter test test/previews/capture_neu_calculator_reference.dart`.
Siete comprobaciones pasaron: referencia funcional y a 320 dp/texto 1.6, acceso
rápido, resultado exacto, invalidación y cero rechazado; más regresiones de
operaciones de dosis y temas claro/oscuro. Analyze limpio.

Pendiente: confirmación visual de Ale para extender la familia al resto y revisión
CodeRabbit. No merge, despliegue ni aplicación global del estilo.

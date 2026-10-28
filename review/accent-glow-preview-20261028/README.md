# Vista previa de glow suave · una pantalla

Ale pidió revisar primero una pantalla antes de aplicar el halo a toda la app.
Base: #56. El efecto está desactivado por defecto y **no se añadió al tema de la
aplicación**; solo el generador de esta vista previa activa AccentGlowStyle.

- Halo estático tenue del mismo tono del acento; no cambia el relleno ni el texto.
- Se conserva la sombra neumórfica, el relieve y los estados de pulsación.
- La vista muestra tarjetas con cabeceras coloreadas, botones y el distintivo.
- Los controles deshabilitados no reciben el halo del botón.
- No toca valores, cálculos, validaciones, áreas pulsables ni permisos.
- La envoltura permanece estable al alternar la opción para preservar el contenido.

Capturas reales de la misma calculadora y valores ficticios:
[con glow](glow.png) · [sin glow](sin-glow.png).

Reproducir: `flutter test test/previews/capture_calculator_glow.dart`.
Se habilitan sombras reales de Flutter y se restaura la configuración de pruebas.
Se comprueban cálculo exacto, acceso rápido, invalidación, rechazo de cero y una
pantalla de 320 dp con texto ampliado. Regresiones de los cuatro modos aritméticos
y temas claro/oscuro ejecutadas; resultado final en #31.

Pendiente confirmación visual de Ale para la intensidad antes de extender el
halo a otros componentes o pantallas. Sin activación global, merge, SQL o APK nueva.

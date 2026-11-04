# Glow: prioridad de cabeceras según las marcas de Ale

Base #57. El efecto continúa limitado a la pantalla de vista previa; no se ha
activado el tema de glow en la app.

- Icono superior: se conserva exactamente la intensidad anterior (1).
- Cabeceras: halo local concentrado en la franja coloreada (1.4).
- Cuerpo de tarjetas: intensidad 0.65 respecto a la referencia anterior.
- Botones: intensidad 0.8; al pulsar conserva la reducción proporcional.
- Otros acentos sin intensidad explícita: 0.75.

Las cifras son factores de un halo ya tenue, no opacidad de las superficies.
No cambian los rellenos, letras, relieve, geometría, cálculos ni accesos.
La cabecera se mide por su propio contenedor: no hay alturas fijas inferidas
para el halo. El recorte de la tarjeta mantiene sus esquinas redondeadas.

[Vista ajustada](glow.png) · [misma pantalla sin glow](sin-glow.png).

Verificación de imagen: captura de 430×1420, misma geometría que #57; la región
(325,125)-(395,197), que contiene icono y halo superior, es idéntica píxel a píxel
respecto a `review/accent-glow-preview-20261028/glow.png`. Es una comprobación de
lectura de imágenes; no se retocó la captura.

Reproducir:
`flutter test test/previews/capture_calculator_glow.dart --dart-define=GLOW_PREVIEW_DIR=review/glow-header-hierarchy-20261028`

12 comprobaciones de captura, móvil/texto ampliado, cálculo, invalidación,
acceso rápido, cuatro modos aritméticos y temas pasaron; analyze limpio.
Pendientes confirmación visual y revisión CodeRabbit. Sin activación global,
merge, SQL remoto ni APK nueva.

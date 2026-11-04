# Glow compartido de VetDosis

Activación del estilo aprobado en #58 para la familia Neu, en modo claro y oscuro. Conserva el estilo estándar y la paleta elegida. Cabeceras con énfasis 1.4, iconos de calculadora 1, cuerpo .65 y botones .8; controles seleccionados .6–.75. Sin animación.

- `light.png` / `dark.png`: widgets reales de operaciones de dosis, CRI y agua de producción; campos vacíos y datos de referencia de los assets.
- `mas.png`, `aves.png`, `produccion.png`: navegación real con cuenta ficticia, sin datos clínicos. Solo los acentos existentes emiten halo; las superficies neutras conservan su apariencia.
- Se comparten los componentes AccentGlow, NeuHeaderCard, NeuPrimaryButton, VetButton, VetModuleTile, VetKpiCard y las tarjetas de registros. Los chips seleccionados conservan sus callbacks y estado; los deshabilitados no emiten halo.
- Los FilledButton genéricos reciben sombra de color discreta mediante el tema; los botones neumórficos con halo propio evitan duplicarla.

Capturas Flutter renderizadas con sombras reales. No son capturas de una APK instalada. Pendiente revisión CodeRabbit y validación en teléfono.

Reproducir:

```sh
flutter test --dart-define=CALCULATOR_PREVIEW_DIR=review/app-wide-accent-glow-20261028 test/previews/capture_calculator_pastels.dart
APP_GLOW_PREVIEW_DIR=review/app-wide-accent-glow-20261028 flutter test test/previews/capture_app_glow.dart
flutter test test/accent_glow_states_test.dart
```

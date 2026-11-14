import 'accent_glow.dart';
import 'package:flutter/material.dart';
import 'workspace_panel.dart';

class NeuHeaderCard extends StatelessWidget {
  const NeuHeaderCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
    this.onTap,
    this.trailing,
    this.soft = false,
  });
  final bool soft;
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = Theme.of(context).scaffoldBackgroundColor;
    // El tono de la franja sale del color de la seccion, pero apagado: los
    // colores de marca son muy luminosos y al 20% dejaban la cabecera mas
    // cargada que el resto de la tarjeta. Se baja saturacion y luminosidad
    // antes de mezclar, como en las cabeceras que Ale dio por buenas.
    final hsl = HSLColor.fromColor(color);
    final quiet = hsl
        .withSaturation(hsl.saturation.clamp(0, .6).toDouble())
        .withLightness(dark ? .62 : .42)
        .toColor();
    // El halo vive solo en la franja de la cabecera y muy tenue. La tarjeta
    // entera ya no brilla: por indicacion de Ale el glow marca el titulo del
    // apartado, no su contenido.
    return WorkspacePanel(
      radius: soft ? 32 : 24,
      depth: soft ? 1.35 : 1,
      softLighting: soft,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AccentGlow(
              color: color,
              radius: 0,
              emphasis: .55,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color.lerp(base, quiet, dark ? .26 : .2),
                ),
                child: Row(
                  children: [
                    Icon(icon),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    ?trailing,
                  ],
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

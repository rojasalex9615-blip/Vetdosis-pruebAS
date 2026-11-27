import 'package:flutter/material.dart';
import '../../vet_ui/vet_theme.dart';
import 'contrast.dart';
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
    // antes de mezclar.
    final hsl = HSLColor.fromColor(color);
    final quiet = hsl
        .withSaturation(hsl.saturation.clamp(0, .6).toDouble())
        .withLightness(dark ? .62 : .42)
        .toColor();
    final banda = Color.lerp(base, quiet, dark ? .22 : .12)!;

    return WorkspacePanel(
      radius: soft ? 32 : 24,
      depth: soft ? 1.35 : 1,
      softLighting: soft,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: banda),
              child: Row(
                children: [
                  // El glifo va en el gris del menu, no en el tono de la
                  // seccion: la franja ya lleva el color.
                  Icon(
                    icon,
                    color: readableOn(VetColors.muted, banda),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

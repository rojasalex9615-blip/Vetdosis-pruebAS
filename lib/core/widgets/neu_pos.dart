import 'package:flutter/material.dart';

import 'contrast.dart';
import 'neu_identity.dart';
import 'workspace_panel.dart';
import '../../vet_ui/vet_icons.dart';

/// Piezas del punto de venta segun las maquetas de «Caja» que entrego Ale:
/// mosaicos de resumen, el boton redondo de «Nueva venta» y el teclado
/// numerico. Solo dan forma; los importes y las acciones los pone quien llama.

bool _neu(BuildContext context) =>
    Theme.of(context).extension<WorkspaceStyle>()?.neumorphic == true;

/// Mosaico de una cifra: placa con icono, el valor y su etiqueta debajo.
class NeuStatTile extends StatelessWidget {
  const NeuStatTile({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    this.value,
    this.selected = false,
    this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;

  /// El importe o dato. Sin el, el mosaico es solo un acceso con su nombre.
  final String? value;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final surface = selected
        ? composite(color, dark ? .2 : .14, theme.colorScheme.surface)
        : theme.colorScheme.surface;
    final plate = composite(color, dark ? .24 : .18, surface);
    return Semantics(
      button: onTap != null,
      selected: onTap != null ? selected : null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: _neu(context)
              ? neuShadows(dark, depth: selected ? .4 : .9)
              : null,
          border: selected
              ? Border.all(color: readableOn(color, surface), width: 1.2)
              : null,
        ),
        child: Material(
          color: surface,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: plate,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: readableOn(color, plate)),
                  ),
                  const SizedBox(height: 8),
                  if (value != null)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        value!,
                        maxLines: 1,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      letterSpacing: 0,
                      color: value == null
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: value == null ? FontWeight.w600 : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fila de mosaicos que se reparte el ancho; con texto grande baja a columna.
class NeuStatRow extends StatelessWidget {
  const NeuStatRow({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final columns = constraints.maxWidth < 280 || scale > 1.5
          ? 1
          : children.length.clamp(1, 3);
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final child in children)
            SizedBox(
              width: (constraints.maxWidth - 12 * (columns - 1)) / columns,
              child: child,
            ),
        ],
      );
    },
  );
}

/// Boton redondo grande con el recorrido de marca: la accion de la pantalla.
class NeuRoundAction extends StatelessWidget {
  const NeuRoundAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = 148,
  });
  final String label;
  final VoidCallback? onPressed;
  final double size;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final off = onPressed == null;
    final colors = neuActionGradient(dark);
    return Semantics(
      button: true,
      enabled: !off,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: off ? theme.colorScheme.surfaceContainerHighest : null,
          gradient: off
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors,
                ),
          boxShadow: off
              ? null
              : [
                  BoxShadow(
                    color: colors.last.withValues(alpha: .28),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: off
                        ? theme.colorScheme.onSurfaceVariant
                        : neuActionInk(dark),
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Teclado numerico de la maqueta: digitos grandes sin caja, punto y borrar.
///
/// Escribe en [controller] y nada mas: no valida ni redondea. Admite un solo
/// separador decimal y [decimals] cifras despues de el.
class NeuKeypad extends StatelessWidget {
  const NeuKeypad({
    super.key,
    required this.controller,
    this.enabled = true,
    this.decimals = 2,
    this.maxLength = 12,
    this.onChanged,
  });
  final TextEditingController controller;
  final bool enabled;
  final int decimals, maxLength;
  final VoidCallback? onChanged;

  void _press(String key) {
    var text = controller.text;
    if (key == '<') {
      if (text.isEmpty) return;
      text = text.substring(0, text.length - 1);
    } else if (key == '.') {
      if (decimals == 0 || text.contains('.')) return;
      text = text.isEmpty ? '0.' : '$text.';
    } else {
      final dot = text.indexOf('.');
      if (dot >= 0 && text.length - dot - 1 >= decimals) return;
      if (text.length >= maxLength) return;
      text = text == '0' ? key : '$text$key';
    }
    controller.text = text;
    onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', '<'];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth / 3;
        return Wrap(
          children: [
            for (final key in keys)
              SizedBox(
                width: width,
                height: 60,
                child: Semantics(
                  button: true,
                  label: switch (key) {
                    '<' => 'Borrar',
                    '.' => 'Punto decimal',
                    _ => key,
                  },
                  child: ExcludeSemantics(
                    child: InkWell(
                      key: ValueKey('keypad-$key'),
                      borderRadius: BorderRadius.circular(18),
                      onTap: enabled ? () => _press(key) : null,
                      child: Center(
                        child: key == '<'
                            ? Icon(
                                VetIcons.backspace,
                                color: theme.colorScheme.onSurfaceVariant,
                              )
                            : Text(
                                key,
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: enabled
                                      ? theme.colorScheme.onSurface
                                      : theme.disabledColor,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

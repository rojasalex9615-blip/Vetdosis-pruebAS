import '../core/widgets/accent_glow.dart';
import 'package:flutter/material.dart';

import 'vet_theme.dart';

enum VetActionStyle { primary, secondary, neutral, destructive }

enum VetBadgeKind { information, success, warning, danger, unverified }

/// Card base unificada con estilo consistente.
class VetCard extends StatelessWidget {
  const VetCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(VetSpacing.lg),
    this.radius = VetSpacing.radiusLg,
    this.elevated = false,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: dark ? Colors.black26 : VetColors.softShadow,
                  offset: const Offset(2, 4),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

/// Card con header coloreado para secciones principales.
class VetSectionCard extends StatelessWidget {
  const VetSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.child,
    this.onTap,
    this.trailing,
    this.padding = const EdgeInsets.all(VetSpacing.lg),
    this.radius = VetSpacing.radiusXl,
  });
  final String title;
  final IconData icon;
  final Color accentColor;
  final Widget child;
  final VoidCallback? onTap;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return AccentGlow(
      color: accentColor,
      radius: radius,
      emphasis: .65,
      child: VetCard(
        radius: radius,
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AccentGlow(
                color: accentColor,
                radius: 0,
                emphasis: 1.4,
                child: Container(
                  padding: const EdgeInsets.all(VetSpacing.lg),
                  decoration: BoxDecoration(
                    color: dark
                        ? accentColor.withValues(alpha: .25)
                        : accentColor.withValues(alpha: .20),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(radius),
                      topRight: Radius.circular(radius),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, color: accentColor),
                      const SizedBox(width: VetSpacing.md),
                      Expanded(
                        child: Text(
                          title,
                          style: VetTypography.headlineSmall.copyWith(
                            color: dark ? VetColors.ink : VetColors.ink,
                          ),
                        ),
                      ),
                      if (trailing != null) trailing!,
                    ],
                  ),
                ),
              ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class VetActionButton extends StatelessWidget {
  const VetActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = VetActionStyle.primary,
    this.loading = false,
    this.fullWidth = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final VetActionStyle style;
  final bool loading;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (background, foreground) = switch (style) {
      VetActionStyle.primary => (colors.primary, colors.onPrimary),
      VetActionStyle.secondary => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
      VetActionStyle.neutral => (colors.surfaceContainerLow, colors.onSurface),
      VetActionStyle.destructive => (colors.error, colors.onError),
    };
    final enabled = !loading && onPressed != null;

    return AccentGlow(
      color: background,
      enabled: enabled && style != VetActionStyle.neutral,
      emphasis: .8,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          minimumSize: Size(fullWidth ? double.infinity : 48, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: VetSpacing.lg,
            vertical: VetSpacing.md,
          ),
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (icon != null)
              Icon(icon, size: 20),
            if (icon != null || loading) const SizedBox(width: VetSpacing.sm),
            Flexible(child: Text(label, textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
  }
}

class VetSecondaryButton extends StatelessWidget {
  const VetSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.fullWidth = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = !loading && onPressed != null;

    return OutlinedButton(
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        minimumSize: Size(fullWidth ? double.infinity : 48, 48),
        padding: const EdgeInsets.symmetric(
          horizontal: VetSpacing.lg,
          vertical: VetSpacing.md,
        ),
        shape: const StadiumBorder(),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (icon != null)
            Icon(icon, size: 20),
          if (icon != null || loading) const SizedBox(width: VetSpacing.sm),
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

class VetStatusBadge extends StatelessWidget {
  const VetStatusBadge({
    super.key,
    required this.label,
    this.kind = VetBadgeKind.information,
    this.compact = false,
  });
  final String label;
  final VetBadgeKind kind;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final color = switch (kind) {
      VetBadgeKind.information => cs.primary,
      VetBadgeKind.success =>
        dark ? const Color(0xFF7DE1B8) : VetColors.success,
      VetBadgeKind.warning =>
        dark ? const Color(0xFFFFD580) : VetColors.warning,
      VetBadgeKind.danger => cs.error,
      VetBadgeKind.unverified => cs.onSurfaceVariant,
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? VetSpacing.sm : VetSpacing.md,
        vertical: compact ? VetSpacing.xs : VetSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(VetSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Text(
        label,
        style: (compact ? VetTypography.labelSmall : VetTypography.labelMedium)
            .copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class VetModuleTile extends StatelessWidget {
  const VetModuleTile({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.accent = VetColors.turquoise,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => VetCard(
    padding: EdgeInsets.zero,
    radius: VetSpacing.radiusLg,
    elevated: onTap != null,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(VetSpacing.radiusLg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 112),
          child: Padding(
            padding: const EdgeInsets.all(VetSpacing.md),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AccentGlow(
                  color: accent,
                  radius: VetSpacing.radiusMd,
                  emphasis: 1,
                  enabled: onTap != null,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(VetSpacing.radiusMd),
                    ),
                    child: Icon(icon, color: accent, size: 24),
                  ),
                ),
                const SizedBox(height: VetSpacing.sm),
                Text(
                  title,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: VetTypography.titleSmall,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: VetSpacing.xs),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VetTypography.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class VetPracticeSelector extends StatelessWidget {
  const VetPracticeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  final int selected;
  final ValueChanged<int> onChanged;
  static const labels = ['Pequeñas especies', 'Exóticos', 'Producción'];
  static const icons = [
    Icons.pets_outlined,
    Icons.cruelty_free_outlined,
    Icons.agriculture_outlined,
  ];

  @override
  Widget build(BuildContext context) => Row(
    children: List.generate(3, (i) {
      final active = i == selected;
      final cs = Theme.of(context).colorScheme;
      return Expanded(
        child: Padding(
          padding: EdgeInsets.only(right: i == 2 ? 0 : VetSpacing.sm),
          child: Semantics(
            selected: active,
            button: true,
            label: labels[i],
            child: Material(
              color: active
                  ? VetColors.lavender.withValues(alpha: .22)
                  : cs.surface,
              borderRadius: BorderRadius.circular(VetSpacing.radiusLg),
              child: InkWell(
                borderRadius: BorderRadius.circular(VetSpacing.radiusLg),
                onTap: () => onChanged(i),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 88),
                  padding: const EdgeInsets.symmetric(
                    horizontal: VetSpacing.sm,
                    vertical: VetSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(VetSpacing.radiusLg),
                    border: Border.all(
                      color: active ? VetColors.purple : cs.outlineVariant,
                      width: active ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AccentIcon(
                        icons[i],
                        enabled: active,
                        emphasis: .75,
                        color: active ? VetColors.purple : VetColors.turquoise,
                        size: 28,
                      ),
                      const SizedBox(height: VetSpacing.xs),
                      Text(
                        labels[i],
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: VetTypography.labelMedium.copyWith(
                          fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }),
  );
}

class VetKpiCard extends StatelessWidget {
  const VetKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accent = VetColors.purple,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) => VetCard(
    radius: VetSpacing.radiusMd,
    padding: const EdgeInsets.symmetric(
      horizontal: VetSpacing.md,
      vertical: VetSpacing.lg,
    ),
    child: Column(
      children: [
        AccentIcon(icon, color: accent, size: 28),
        const SizedBox(height: VetSpacing.xs),
        Text(value, style: VetTypography.displaySmall),
        Text(
          label,
          textAlign: TextAlign.center,
          style: VetTypography.bodySmall,
        ),
      ],
    ),
  );
}

/// Chip de acción consistente con glow opcional.
class VetActionChip extends StatelessWidget {
  const VetActionChip({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.selected = false,
    this.accentColor,
  });
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool selected;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = accentColor ?? cs.primary;
    final isActive = onPressed != null;

    return AccentGlow(
      color: color,
      enabled: selected && isActive,
      emphasis: .6,
      radius: VetSpacing.radiusMd,
      child: ActionChip(
        avatar: icon != null ? Icon(icon, size: 16, color: color) : null,
        label: Text(label, style: VetTypography.labelMedium),
        onPressed: onPressed,
        backgroundColor: selected
            ? color.withValues(alpha: .15)
            : isActive
                ? cs.surface
                : cs.surfaceContainerLow,
        side: BorderSide(
          color: selected ? color : cs.outlineVariant,
        ),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: VetSpacing.md,
          vertical: VetSpacing.xs,
        ),
      ),
    );
  }
}

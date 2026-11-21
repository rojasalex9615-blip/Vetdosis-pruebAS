import 'package:flutter/material.dart';

import 'vet_theme.dart';

/// Navegación únicamente visual; el proyecto anfitrión decide destinos y permisos.
class VetBottomNav extends StatelessWidget {
  const VetBottomNav({super.key, required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: NavigationBar(
      selectedIndex: index,
      onDestinationSelected: onChanged,
      height: 78,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Inicio',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_today_outlined),
          selectedIcon: Icon(Icons.calendar_today),
          label: 'Agenda',
        ),
        NavigationDestination(
          icon: Icon(Icons.pets_outlined),
          selectedIcon: Icon(Icons.pets),
          label: 'Registros',
        ),
        NavigationDestination(
          icon: Icon(Icons.calculate_outlined),
          selectedIcon: Icon(Icons.calculate),
          label: 'Cálculos',
        ),
        NavigationDestination(
          icon: Icon(Icons.grid_view_rounded),
          selectedIcon: Icon(Icons.grid_view_rounded),
          label: 'Más',
        ),
      ],
    ),
  );
}

class VetWorkspaceHeader extends StatelessWidget {
  const VetWorkspaceHeader({
    super.key,
    required this.displayName,
    required this.workspaceName,
    this.onWorkspaceTap,
    this.onNotificationsTap,
  });
  final String displayName;
  final String workspaceName;
  final VoidCallback? onWorkspaceTap;
  final VoidCallback? onNotificationsTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.brightness == Brightness.dark
        ? VetColors.onDarkMuted
        : VetColors.muted;
    final greeting = displayName.trim().isEmpty
        ? 'Hola'
        : 'Hola, $displayName';
    return Row(
      children: [
        CircleAvatar(
          radius: 23,
          backgroundColor: VetColors.lavender,
          child: Text(
            displayName.trim().isEmpty
                ? '?'
                : displayName.trim().characters.first.toUpperCase(),
            style: const TextStyle(
              color: VetColors.ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Semantics(
            button: onWorkspaceTap != null,
            label: '$greeting. Espacio: $workspaceName',
            child: InkWell(
              onTap: onWorkspaceTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            greeting,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                            ),
                          ),
                        ),
                        if (onWorkspaceTap != null) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.unfold_more_rounded,
                            size: 18,
                            color: muted,
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.business_outlined,
                          size: 13,
                          color: muted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            workspaceName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: onNotificationsTap,
          tooltip: 'Notificaciones',
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }
}

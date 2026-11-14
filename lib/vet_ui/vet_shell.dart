import 'package:flutter/material.dart';

import 'vet_theme.dart';
import 'vet_icons.dart';

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
      height: 76,
      destinations: const [
        NavigationDestination(
          icon: Icon(VetIcons.home),
          selectedIcon: Icon(VetIcons.home),
          label: 'Inicio',
        ),
        NavigationDestination(icon: Icon(VetIcons.calendar), label: 'Agenda'),
        NavigationDestination(icon: Icon(VetIcons.paw), label: 'Registros'),
        NavigationDestination(
          icon: Icon(VetIcons.calculator),
          label: 'Cálculos',
        ),
        NavigationDestination(icon: Icon(VetIcons.grid), label: 'Más'),
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
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(
        radius: 23,
        backgroundColor: VetColors.lavender,
        child: Text(
          displayName.isEmpty
              ? '?'
              : displayName.characters.first.toUpperCase(),
          style: const TextStyle(
            color: VetColors.ink,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: InkWell(
          onTap: onWorkspaceTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hola, $displayName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                workspaceName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      IconButton(
        onPressed: onNotificationsTap,
        tooltip: 'Notificaciones',
        icon: const Icon(VetIcons.bell),
      ),
    ],
  );
}

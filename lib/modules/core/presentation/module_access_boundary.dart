import 'package:flutter/material.dart';
import '../../auth/domain/clinic_membership.dart';
import '../domain/module_access.dart';
import '../../../vet_ui/vet_icons.dart';

class ModuleAccessBoundary extends StatefulWidget {
  const ModuleAccessBoundary({
    super.key,
    required this.member,
    required this.repository,
    required this.revision,
    required this.builder,
  });

  final ClinicMembership? member;
  final ModuleAccessRepository? repository;
  final int revision;
  final Widget Function(ModuleAccess? access) builder;

  @override
  State<ModuleAccessBoundary> createState() => _ModuleAccessBoundaryState();
}

class _ModuleAccessBoundaryState extends State<ModuleAccessBoundary> {
  ModuleAccess? access;
  int generation = 0;
  bool failed = false;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant ModuleAccessBoundary oldWidget) {
    super.didUpdateWidget(oldWidget);
    final identityChanged =
        oldWidget.member?.userId != widget.member?.userId ||
        oldWidget.member?.clinicId != widget.member?.clinicId ||
        oldWidget.repository != widget.repository;
    if (identityChanged) {
      access = null;
      load();
    } else if (oldWidget.revision != widget.revision) {
      // Un refresco periodico de permisos no debe vaciar el acceso ya leido:
      // al pasar por `denied` la pantalla se sustituia por el aviso de
      // permisos y volvia, y el usuario veia recargarse el apartado cada 30 s.
      load();
    }
  }

  Future<void> load() async {
    final request = ++generation;
    final member = widget.member;
    final repository = widget.repository;
    if (member == null || repository == null) return;
    failed = false;
    loading = true;
    try {
      final next = ModuleAccess.read(
        await repository.workspace(member.clinicId),
      );
      if (mounted && request == generation) {
        setState(() {
          access = next;
          loading = false;
        });
      }
    } catch (_) {
      // Fail closed for reviewed modules. A stale contract is never retained.
      if (mounted && request == generation) {
        setState(() {
          access = null;
          failed = true;
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.builder(
      widget.member != null && widget.repository != null
          ? access ?? ModuleAccess.denied
          : access,
    );
    final banner = failed && widget.member != null && widget.repository != null;
    // El contenido conserva siempre el mismo puesto y la misma clave, con o
    // sin aviso. Antes el aviso sustituia la raiz (`content` o `Column(...)`),
    // asi que al aparecer o desaparecer se reparentaba el subarbol completo y
    // un elemento que aun dependia de un InheritedWidget se notificaba ya
    // movido: de ahi la asercion de `InheritedElement` y la pantalla duplicada.
    return Column(
      children: [
        if (banner)
          Material(
            color: Theme.of(context).colorScheme.errorContainer,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(VetIcons.info),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'No se pudieron comprobar los permisos de tu espacio. '
                        'Algunos accesos y resúmenes están ocultos. '
                        'Revisa tu conexión; si persiste, contacta a soporte.',
                      ),
                    ),
                    TextButton(
                      onPressed: loading
                          ? null
                          : () {
                              setState(() => loading = true);
                              load();
                            },
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(key: const ValueKey('module_access_content'), child: content),
      ],
    );
  }
}

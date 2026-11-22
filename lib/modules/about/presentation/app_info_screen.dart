import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/app_version_label.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_icons.dart';

/// Fila del registro de colaboradores (`assets/app/collaborators.v1.json`).
class AppCollaborator {
  const AppCollaborator({
    required this.name,
    required this.platform,
    required this.bot,
    required this.status,
    required this.areas,
    required this.evidence,
  });

  final String name, platform, bot, status, areas, evidence;

  factory AppCollaborator.read(Map<String, dynamic> row) => AppCollaborator(
    name: (row['name'] ?? '').toString(),
    platform: (row['platform'] ?? '').toString(),
    bot: (row['bot'] ?? '').toString(),
    status: (row['status'] ?? '').toString(),
    areas: (row['areas'] ?? '').toString(),
    evidence: (row['evidence'] ?? '').toString(),
  );
}

/// Información de la app: datos que maneja, privacidad, fuentes, licencias y
/// colaboradores. Es consulta: no envía datos ni cambia permisos.
class AppInfoScreen extends StatefulWidget {
  const AppInfoScreen({super.key, this.collaborators});
  final List<AppCollaborator>? collaborators;
  @override
  State<AppInfoScreen> createState() => _AppInfoScreenState();
}

class _AppInfoScreenState extends State<AppInfoScreen> {
  List<AppCollaborator> collaborators = const [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.collaborators != null) {
      collaborators = widget.collaborators!;
      loading = false;
    } else {
      load();
    }
  }

  Future<void> load() async {
    try {
      final raw = await rootBundle.loadString(
        'assets/app/collaborators.v1.json',
      );
      final data = json.decode(raw) as Map<String, dynamic>;
      final rows = (data['collaborators'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => AppCollaborator.read(Map<String, dynamic>.from(row)))
          .toList();
      if (mounted) {
        setState(() {
          collaborators = rows;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget card({
    required IconData icon,
    required String title,
    required Widget child,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              VetIconBox(icon: icon, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    ),
  );

  Widget bullet(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2, right: 6),
          child: Icon(VetIcons.checkCircle, size: 16),
        ),
        Expanded(child: Text(text)),
      ],
    ),
  );

  VetBadgeKind kind(String status) {
    final value = status.toLowerCase();
    if (value.startsWith('activa')) return VetBadgeKind.success;
    if (value.contains('revisor')) return VetBadgeKind.information;
    if (value.contains('ya no')) return VetBadgeKind.unverified;
    return VetBadgeKind.information;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const VetSectionHeader(
          title: 'Información de la app',
          subtitle:
              'Qué datos usa VetDosis, de dónde salen, con qué licencias y '
              'quién colabora.',
          icon: VetIcons.shieldCheck,
          large: true,
        ),
        card(
          icon: VetIcons.info,
          title: 'Qué es VetDosis Pro',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Apoyo para la consulta y el cálculo veterinario: vademécum, '
                'dosis, referencias, expediente, inventario y producción. No '
                'sustituye el juicio del médico veterinario ni emite recetas '
                'automáticamente.',
              ),
              const SizedBox(height: 8),
              const AppVersionLabel(),
            ],
          ),
        ),
        card(
          icon: VetIcons.folder,
          title: 'Datos que maneja',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bullet('Cuenta, clínica, rol y miembros del equipo.'),
              bullet(
                'Pacientes y expediente: lo que registra el médico '
                'veterinario en la clínica.',
              ),
              bullet(
                'Dosis, vademécum y referencias: consulta y cálculo; no '
                'prescriben.',
              ),
              bullet('Inventario, caja, producción y agenda de la clínica.'),
              bullet(
                'Soporte: mensajes de ayuda; no se piden datos clínicos en '
                'los reportes.',
              ),
            ],
          ),
        ),
        card(
          icon: VetIcons.lock,
          title: 'Privacidad y seguridad',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bullet(
                'Los datos viven en Supabase con permisos por clínica y rol; '
                'el servidor decide qué puede leer cada cuenta.',
              ),
              bullet(
                'La app no comparte datos clínicos con terceros ni los usa '
                'para publicidad.',
              ),
              bullet('Las copias de seguridad se guardan cifradas.'),
              bullet(
                'Puedes pedir la eliminación de tu cuenta o de tu clínica '
                'escribiendo al correo de soporte.',
              ),
            ],
          ),
        ),
        card(
          icon: VetIcons.book,
          title: 'Fuentes',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bullet(
                'Pautas del fabricante: 1197 pautas del catálogo comercial, '
                'con su texto literal y su enlace; pendientes de revisión MVZ.',
              ),
              bullet(
                'Referencias fisiológicas y de laboratorio con fuente, '
                'intervalo y estado de revisión.',
              ),
              bullet(
                'Catálogo comercial de la app y fichas personales o de la '
                'clínica con fuente verificable.',
              ),
              bullet(
                'Antes de decidir, revisa la fuente y el estado de cada ficha: '
                'la app no clasifica pacientes.',
              ),
            ],
          ),
        ),
        card(
          icon: VetIcons.document,
          title: 'Licencias',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bullet('Flutter y Dart: licencia BSD de Google.'),
              bullet(
                'Tipografía Plus Jakarta Sans: SIL Open Font License 1.1.',
              ),
              bullet('Iconos VetIcons: conjunto propio de la app.'),
              bullet(
                'Los paquetes de terceros conservan su licencia; el detalle '
                'está en pubspec.lock.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const VetSectionHeader(
          title: 'Colaboradores',
          subtitle:
              'Personas y modelos que aportaron, con su área y su evidencia. '
              'El registro completo está en docs/colaboradores-y-aportes.md.',
          icon: VetIcons.usersGroup,
        ),
        if (loading) const LinearProgressIndicator(),
        if (!loading && collaborators.isEmpty)
          const Text('No se pudo cargar el registro de colaboradores.'),
        for (final person in collaborators)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: VetCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(child: Icon(VetIcons.userCircle)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(person.name, style: theme.textTheme.titleSmall),
                        if (person.platform.isNotEmpty)
                          Text(
                            person.bot.isEmpty
                                ? person.platform
                                : '${person.platform} · ${person.bot}',
                            style: theme.textTheme.bodySmall,
                          ),
                        const SizedBox(height: 4),
                        VetStatusBadge(
                          label: person.status,
                          kind: kind(person.status),
                        ),
                        const SizedBox(height: 4),
                        Text(person.areas),
                        if (person.evidence.isNotEmpty)
                          Text(
                            'Evidencia: ${person.evidence}',
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        card(
          icon: VetIcons.headset,
          title: 'Contacto y soporte',
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Correo de soporte: provetdosis@gmail.com'),
              Text(
                'Para reportar un error, di la pantalla, lo que esperabas y lo '
                'que viste. No incluyas datos de pacientes.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Esta pantalla es informativa. No envía datos ni cambia permisos.',
        ),
      ],
    );
  }
}

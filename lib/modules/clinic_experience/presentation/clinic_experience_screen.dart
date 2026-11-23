import 'package:flutter/material.dart';
import '../../auth/domain/clinic_membership.dart';
import '../domain/clinic_experience.dart';
import '../domain/clinic_experience_repository.dart';
import '../../../core/widgets/accent_glow.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_icons.dart';
import '../../../vet_ui/vet_theme.dart';

class ClinicExperienceScreen extends StatefulWidget {
  const ClinicExperienceScreen({
    super.key,
    required this.member,
    required this.initial,
    required this.repository,
    required this.ready,
    this.onSaved,
  });
  final ClinicMembership member;
  final ClinicExperience initial;
  final ClinicExperienceRepository repository;
  final bool ready;
  final Future<void> Function()? onSaved;

  @override
  State<ClinicExperienceScreen> createState() => _ClinicExperienceScreenState();
}

class _ClinicExperienceScreenState extends State<ClinicExperienceScreen> {
  late ClinicExperience draft = widget.initial;
  bool saving = false;
  String? message;

  Future<bool> refreshBoundary() async {
    try {
      await widget.onSaved?.call();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> save() async {
    if (saving || widget.member.role != ClinicRole.admin || !widget.ready) {
      return;
    }
    setState(() {
      saving = true;
      message = null;
    });
    try {
      final next = await widget.repository.save(widget.member.clinicId, draft);
      if (!mounted) return;
      setState(() {
        draft = next;
      });
      final refreshed = await refreshBoundary();
      if (mounted) {
        setState(
          () => message = refreshed
              ? 'Preferencias guardadas para esta clínica.'
              : 'Se guardaron los cambios, pero no fue posible actualizar la vista. Comprueba la conexión antes de continuar.',
        );
      }
    } catch (_) {
      // A rejected write may be a conflict with another admin: read the
      // current server revision before letting this modal reopen.
      await refreshBoundary();
      if (mounted) {
        setState(
          () => message =
              'No se pudo guardar. Es posible que otro administrador haya actualizado las opciones: cierra y vuelve a abrir esta pantalla para revisar la última versión.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canEdit =
        widget.ready && widget.member.role == ClinicRole.admin && !saving;

    return Scaffold(
      appBar: AppBar(title: const Text('Personalización de clínica')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AccentIcon(VetIcons.hospital, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.member.clinicName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Solo ajusta la experiencia y la navegación. Los permisos profesionales, las comprobaciones clínicas y los registros de auditoría continúan vigentes. Ocultar no elimina datos.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!widget.ready) ...[
            const VetCallout(
              text:
                  'La configuración de esta clínica aún no está disponible en el servidor. No se guardarán preferencias locales que puedan confundirse con las compartidas.',
              kind: VetBadgeKind.warning,
              icon: VetIcons.cloudOff,
            ),
            const SizedBox(height: 16),
          ],
          VetCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      VetIcons.sliders,
                      size: 20,
                      color: VetColors.brandSky,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Perfil de clínica',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ClinicPreset>(
                  key: ValueKey(draft.preset),
                  initialValue: draft.preset,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Perfil predeterminado',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: ClinicPreset.general,
                      child: Text('General: todas las secciones'),
                    ),
                    DropdownMenuItem(
                      value: ClinicPreset.smallAnimals,
                      child: Text('Pequeñas especies'),
                    ),
                    DropdownMenuItem(
                      value: ClinicPreset.hospital,
                      child: Text('Hospital veterinario'),
                    ),
                    DropdownMenuItem(
                      value: ClinicPreset.production,
                      child: Text('Producción animal'),
                    ),
                    DropdownMenuItem(
                      value: ClinicPreset.custom,
                      child: Text('Personalizado'),
                    ),
                  ],
                  onChanged: canEdit
                      ? (value) {
                          if (value != null) {
                            setState(
                              () => draft = ClinicExperience.forPreset(
                                value,
                                previous: draft,
                              ),
                            );
                          }
                        }
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          VetCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(VetIcons.paw, size: 20, color: VetColors.mint),
                    const SizedBox(width: 8),
                    Text(
                      'Áreas de trabajo',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Elige las áreas que atiende la clínica. Las secciones de las demás se ocultan. La administración clínica va incluida con pequeñas y exóticos; en producción es opcional.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                for (final (id, label, description) in [
                  (
                    'small',
                    'Pequeñas especies',
                    'Perro, gato y clínica general.',
                  ),
                  (
                    'production',
                    'Producción',
                    'Aves, peces, bovinos, porcinos y equinos.',
                  ),
                  ('exotic', 'Exóticos', 'Mamíferos pequeños de compañía.'),
                ])
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: draft.workAreas.contains(id),
                    title: Text(label),
                    subtitle: Text(description),
                    onChanged: canEdit
                        ? (value) {
                            final next = {...draft.workAreas};
                            if (value == true) {
                              next.add(id);
                            } else {
                              next.remove(id);
                            }
                            setState(() => draft = draft.copy(workAreas: next));
                          }
                        : null,
                  ),
                if (draft.workAreas.contains('production'))
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: draft.includeAdmin,
                    title: const Text('Incluir administración clínica'),
                    subtitle: const Text(
                      'Caja, finanzas y productividad. Con pequeñas o exóticos ya va incluida.',
                    ),
                    onChanged: canEdit
                        ? (value) => setState(
                            () =>
                                draft = draft.copy(includeAdmin: value == true),
                          )
                        : null,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          VetCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      VetIcons.grid,
                      size: 20,
                      color: VetColors.purple,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Módulos y submódulos',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Activa solo las opciones que deseas mostrar. Los accesos protegidos, como Ajustes y revisión autorizada, nunca se ocultan.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                for (final group in experienceVisibilityGroups)
                  if (group.pages.any(configurableExperiencePages.contains))
                    ExpansionTile(
                      title: Text(
                        group.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${group.pages.where(configurableExperiencePages.contains).where(draft.visible).length} activos',
                      ),
                      trailing: Switch(
                        value: group.pages
                            .where(configurableExperiencePages.contains)
                            .every(draft.visible),
                        onChanged: canEdit
                            ? (visible) {
                                setState(() {
                                  for (final page in group.pages) {
                                    draft = draft.withPage(page, visible);
                                  }
                                });
                              }
                            : null,
                      ),
                      children: [
                        for (final page in group.pages)
                          if (configurableExperiencePages.contains(page))
                            SwitchListTile(
                              title: Text(page),
                              value: draft.visible(page),
                              onChanged: canEdit
                                  ? (value) => setState(
                                      () => draft = draft.withPage(page, value),
                                    )
                                  : null,
                            ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: canEdit
                                ? () {
                                    setState(() {
                                      draft = draft.restoreModuleVisibility(
                                        group.title,
                                      );
                                      message =
                                          'Visibilidad predeterminada de ${group.title} recuperada. Guarda para aplicar el cambio a la clínica.';
                                    });
                                  }
                                : null,
                            icon: const Icon(VetIcons.refresh, size: 16),
                            label: const Text('Restablecer este módulo'),
                          ),
                        ),
                      ],
                    ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          VetCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      VetIcons.arrowForward,
                      size: 20,
                      color: VetColors.turquoise,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Flujos de trabajo',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Libre: entrada directa. Asistido: recomendaciones de secuencia. Obligatorio: preferencia reservada para cadenas que se validarán en el servidor antes de exigirlas. Ninguna opción omite comprobaciones clínicas existentes.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                for (final task in configurableFlows.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: DropdownButtonFormField<ClinicalFlowMode>(
                      key: ValueKey(
                        'flow-${task.key}-${draft.flow(task.key).name}',
                      ),
                      initialValue: draft.flow(task.key),
                      decoration: InputDecoration(
                        labelText: task.value,
                        border: const OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: ClinicalFlowMode.free,
                          child: Text('Libre'),
                        ),
                        DropdownMenuItem(
                          value: ClinicalFlowMode.guided,
                          child: Text('Asistido'),
                        ),
                        DropdownMenuItem(
                          value: ClinicalFlowMode.mandatory,
                          child: Text('Obligatorio (en preparación)'),
                        ),
                      ],
                      onChanged: canEdit
                          ? (mode) {
                              if (mode != null) {
                                setState(
                                  () => draft = draft.withFlow(task.key, mode),
                                );
                              }
                            }
                          : null,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          VetCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(VetIcons.bell, size: 20, color: VetColors.mint),
                    const SizedBox(width: 8),
                    Text(
                      'Notificaciones de hospitalización',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Elige por qué canales quieres que se envíen los avisos. Teléfono significa notificación o alarma del dispositivo, no una llamada ni un SMS. WhatsApp requiere una conexión habilitada por la clínica y autorización del destinatario.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<HospitalNoticeDelivery>(
                  key: ValueKey(
                    'hospital-notice-${draft.hospitalNoticeDelivery.name}',
                  ),
                  initialValue: draft.hospitalNoticeDelivery,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Canales preferidos',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: HospitalNoticeDelivery.phone,
                      child: Text('Teléfono (alarma del dispositivo)'),
                    ),
                    DropdownMenuItem(
                      value: HospitalNoticeDelivery.whatsapp,
                      child: Text('WhatsApp (en preparación)'),
                    ),
                    DropdownMenuItem(
                      value: HospitalNoticeDelivery.both,
                      child: Text('Ambos (en preparación)'),
                    ),
                  ],
                  onChanged: canEdit
                      ? (channel) {
                          if (channel != null) {
                            setState(
                              () => draft = draft.copy(
                                hospitalNoticeDelivery: channel,
                              ),
                            );
                          }
                        }
                      : null,
                ),
                const SizedBox(height: 8),
                const VetNote(
                  text:
                      'Esta preferencia no activa WhatsApp ni desactiva las alarmas existentes. El envío externo quedará sujeto a disponibilidad, consentimiento, permisos de turno y pruebas con el proveedor. Los avisos deben omitir datos clínicos sensibles.',
                  icon: VetIcons.info,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          VetCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      VetIcons.sparkles,
                      size: 20,
                      color: VetColors.violet,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Proveedor IA predeterminado',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey(
                    'provider-${draft.defaultAiProvider ?? 'none'}',
                  ),
                  initialValue: draft.defaultAiProvider ?? '',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Elegir en cada solicitud'),
                    ),
                    for (final provider in aiExperienceProviders.entries)
                      DropdownMenuItem(
                        value: provider.key,
                        child: Text(provider.value),
                      ),
                  ],
                  onChanged: canEdit
                      ? (provider) => setState(
                          () => draft = draft.copy(
                            defaultAiProvider: provider,
                            clearProvider: provider == '',
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 8),
                const VetNote(
                  text:
                      'Esto no guarda API keys. Solo preselecciona una conexión que ya esté autorizada; cada usuario puede cambiar de proveedor y modelo antes de enviar. Las claves se gestionan por separado.',
                  icon: VetIcons.shield,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (message != null) ...[
            VetCallout(
              text: message!,
              kind: message!.contains('No se pudo')
                  ? VetBadgeKind.danger
                  : VetBadgeKind.success,
              icon: message!.contains('No se pudo')
                  ? VetIcons.alertTriangle
                  : VetIcons.checkCircle,
            ),
            const SizedBox(height: 12),
          ],
          AccentGlow(
            color: theme.colorScheme.primary,
            radius: 20,
            emphasis: 0.4,
            child: VetActionButton(
              onPressed: canEdit ? save : null,
              icon: VetIcons.save,
              label: saving
                  ? 'Guardando...'
                  : 'Guardar configuración de la clínica',
            ),
          ),
        ],
      ),
    );
  }
}

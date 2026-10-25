import 'package:flutter/material.dart';
import '../../auth/domain/clinic_membership.dart';
import '../../core/domain/section_catalog.dart';
import '../domain/clinic_experience.dart';
import '../domain/clinic_experience_repository.dart';

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

  Future<void> save() async {
    if (saving || widget.member.role != ClinicRole.admin || !widget.ready) return;
    setState(() { saving = true; message = null; });
    try {
      final next = await widget.repository.save(widget.member.clinicId, draft);
      if (!mounted) return;
      setState(() {
        draft = next;
        message = 'Preferencias guardadas para esta clínica.';
      });
      await widget.onSaved?.call();
    } catch (_) {
      if (mounted) setState(() =>
        message = 'No se pudo guardar. Es posible que otro administrador haya actualizado las opciones: cierra y vuelve a abrir esta pantalla para revisar la última versión.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = widget.ready && widget.member.role == ClinicRole.admin && !saving;
    return Scaffold(
      appBar: AppBar(title: const Text('Personalización de clínica')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.member.clinicName, style: Theme.of(context).textTheme.titleLarge),
          const Text('Solo ajusta la experiencia y la navegación. Los permisos profesionales, las comprobaciones clínicas y los registros de auditoría continúan vigentes. Ocultar no elimina datos.'),
          if (!widget.ready)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('La configuración de esta clínica aún no está disponible en el servidor. No se guardarán preferencias locales que puedan confundirse con las compartidas.'),
            ),
          const SizedBox(height: 16),
          DropdownButtonFormField<ClinicPreset>(
            key: ValueKey(draft.preset),
            initialValue: draft.preset,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Perfil de clínica', border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: ClinicPreset.general, child: Text('General: todas las secciones')),
              DropdownMenuItem(value: ClinicPreset.smallAnimals, child: Text('Pequeñas especies')),
              DropdownMenuItem(value: ClinicPreset.hospital, child: Text('Hospital veterinario')),
              DropdownMenuItem(value: ClinicPreset.production, child: Text('Producción animal')),
              DropdownMenuItem(value: ClinicPreset.custom, child: Text('Personalizado')),
            ],
            onChanged: canEdit ? (value) {
              if (value != null) setState(() =>
                draft = ClinicExperience.forPreset(value, previous: draft));
            } : null,
          ),
          const SizedBox(height: 20),
          Text('Módulos y submódulos', style: Theme.of(context).textTheme.titleLarge),
          const Text('Activa solo las opciones que deseas mostrar. Los accesos protegidos, como Ajustes y revisión autorizada, nunca se ocultan.'),
          for (final group in sectionGroups)
            if (group.pages.any(configurableExperiencePages.contains))
              ExpansionTile(
                title: Text(group.title),
                subtitle: Text(
                  group.pages.where(configurableExperiencePages.contains)
                    .where(draft.visible).length.toString() + ' activos',
                ),
                trailing: Switch(
                  value: group.pages.where(configurableExperiencePages.contains)
                      .every(draft.visible),
                  onChanged: canEdit ? (visible) {
                    setState(() {
                      for (final page in group.pages) {
                        draft = draft.withPage(page, visible);
                      }
                    });
                  } : null,
                ),
                children: [
                  for (final page in group.pages)
                    if (configurableExperiencePages.contains(page))
                      SwitchListTile(
                        title: Text(page),
                        value: draft.visible(page),
                        onChanged: canEdit ? (value) =>
                            setState(() => draft = draft.withPage(page, value)) : null,
                      ),
                ],
              ),
          const SizedBox(height: 20),
          Text('Flujos de trabajo', style: Theme.of(context).textTheme.titleLarge),
          const Text('Libre: entrada directa. Asistido: recomendaciones de secuencia. Obligatorio: preferencia reservada para cadenas que se validarán en el servidor antes de exigirlas. Ninguna opción omite comprobaciones clínicas existentes.'),
          for (final task in configurableFlows.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: DropdownButtonFormField<ClinicalFlowMode>(
                key: ValueKey('flow-' + task.key + '-' + draft.flow(task.key).name),
                initialValue: draft.flow(task.key),
                decoration: InputDecoration(
                  labelText: task.value,
                  border: const OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: ClinicalFlowMode.free, child: Text('Libre')),
                  DropdownMenuItem(value: ClinicalFlowMode.guided, child: Text('Asistido')),
                  DropdownMenuItem(value: ClinicalFlowMode.mandatory, child: Text('Obligatorio (en preparación)')),
                ],
                onChanged: canEdit ? (mode) {
                  if (mode != null) setState(() => draft = draft.withFlow(task.key, mode));
                } : null,
              ),
            ),
          const SizedBox(height: 20),
          Text('Proveedor IA predeterminado', style: Theme.of(context).textTheme.titleLarge),
          DropdownButtonFormField<String>(
            key: ValueKey('provider-' + (draft.defaultAiProvider ?? 'none')),
            initialValue: draft.defaultAiProvider ?? '',
            isExpanded: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: '', child: Text('Elegir en cada solicitud')),
              for (final provider in aiExperienceProviders.entries)
                DropdownMenuItem(value: provider.key, child: Text(provider.value)),
            ],
            onChanged: canEdit ? (provider) => setState(() =>
              draft = draft.copy(defaultAiProvider: provider, clearProvider: provider == '')) : null,
          ),
          const Text('Esto no guarda API keys. Solo preselecciona una conexión que ya esté autorizada; cada usuario puede cambiar de proveedor y modelo antes de enviar. Las claves se gestionan por separado.'),
          const SizedBox(height: 20),
          if (message != null) Text(message!),
          FilledButton.icon(
            onPressed: canEdit ? save : null,
            icon: const Icon(Icons.save_outlined),
            label: Text(saving ? 'Guardando...' : 'Guardar configuración de la clínica'),
          ),
        ],
      ),
    );
  }
}

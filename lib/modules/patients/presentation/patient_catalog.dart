import 'package:flutter/material.dart';
import '../domain/patient_models.dart';
import '../../../vet_ui/vet_theme.dart';
import '../../../vet_ui/vet_components.dart';

String patientSearchText(String text) {
  var value = text.toLowerCase().trim();
  const accents = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u'};
  for (final entry in accents.entries) {
    value = value.replaceAll(entry.key, entry.value);
  }
  return value.replaceAll(RegExp(r'\s+'), ' ');
}

String patientEventTimestamp(BuildContext context, DateTime timestamp) {
  final date = timestamp.toLocal();
  final local = MaterialLocalizations.of(context);
  return '${local.formatShortDate(date)} · ${local.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
}

class PatientCatalogTile extends StatelessWidget {
  const PatientCatalogTile({
    super.key,
    required this.patient,
    required this.selected,
    this.onTap,
  });
  final VetPatient patient;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => VetSectionCard(
    title: patient.name,
    icon: Icons.pets_outlined,
    accentColor: VetColors.turquoise,
    onTap: onTap,
    padding: const EdgeInsets.all(VetSpacing.md),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [
                  patient.species,
                  if (patient.breed.isNotEmpty) patient.breed,
                ].join(' · '),
                style: VetTypography.bodyMedium,
              ),
              if (patient.birthDate != null) ...[
                const SizedBox(height: VetSpacing.xs),
                Text(
                  'Nacimiento: ${patient.birthDate} · ${patient.sex}',
                  style: VetTypography.bodySmall,
                ),
              ],
            ],
          ),
        ),
        Icon(
          selected ? Icons.check_circle_outline : Icons.chevron_right,
          color: selected
              ? Theme.of(context).colorScheme.primary
              : VetColors.muted,
        ),
      ],
    ),
  );
}

class PatientIdentity extends StatelessWidget {
  const PatientIdentity({super.key, required this.patient});
  final VetPatient patient;

  @override
  Widget build(BuildContext context) => VetCard(
    padding: const EdgeInsets.all(VetSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Expediente abierto', style: VetTypography.labelMedium),
        const SizedBox(height: VetSpacing.sm),
        Text(
          '${patient.name} · ${patient.species}',
          style: VetTypography.headlineSmall,
        ),
        if (patient.breed.isNotEmpty) ...[
          const SizedBox(height: VetSpacing.xs),
          Text(patient.breed, style: VetTypography.bodyMedium),
        ],
        const SizedBox(height: VetSpacing.xs),
        Text(
          '${patient.sex} · Nacimiento: ${patient.birthDate ?? 'Pendiente'}',
          style: VetTypography.bodyMedium.copyWith(color: VetColors.muted),
        ),
      ],
    ),
  );
}

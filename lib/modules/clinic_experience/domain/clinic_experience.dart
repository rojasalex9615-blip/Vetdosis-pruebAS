import '../../core/domain/section_catalog.dart';

/// Pages that can be configured per clinic. This intentionally includes routes
/// that are not standalone navigation groups, so old saved visibility choices
/// remain valid while the main menu stays concise.
const experienceVisibilityGroups = [
  ...sectionGroups,
  SectionGroup('Producción animal', ['Producción y grandes especies']),
];

/// Only presentation preferences. Never grants permission, skips validation or
/// changes the server-side clinical/audit contracts.
enum ClinicPreset { general, smallAnimals, hospital, production, custom }

enum ClinicalFlowMode { free, guided, mandatory }

/// Where the clinic wants hospital notices delivered. This is a routing
/// preference, never evidence that WhatsApp delivery or opt-in is configured.
/// Existing local alarms must not be disabled solely by changing this field.
enum HospitalNoticeDelivery { phone, whatsapp, both }

extension HospitalNoticeDeliveryChannels on HospitalNoticeDelivery {
  bool get phoneSelected => this != HospitalNoticeDelivery.whatsapp;
  bool get whatsappSelected => this != HospitalNoticeDelivery.phone;
}

const protectedExperiencePages = <String>{
  'Inicio', 'Ajustes', 'Mi cuenta y clínicas', 'Ayuda y soporte',
  'Modo revisión', 'Más', 'Cálculos', 'Planes',
};

const configurableFlows = <String, String>{
  'dose': 'Cálculo de dosis',
  'prescription': 'Recetas',
  'hospital': 'Hospitalización',
  'inventory': 'Inventario y movimientos',
  'clinical': 'Procedimientos clínicos',
};

const aiExperienceProviders = <String, String>{
  'google': 'Google Gemini',
  'openai': 'OpenAI',
  'anthropic': 'Anthropic Claude',
  'zai': 'Z.ai',
};

Set<String> get configurableExperiencePages => {
  for (final group in experienceVisibilityGroups)
    for (final page in group.pages)
      if (!protectedExperiencePages.contains(page)) page,
};

class ClinicExperience {
  ClinicExperience({
    required this.preset,
    required Set<String> hiddenPages,
    required Map<String, ClinicalFlowMode> flowModes,
    required this.defaultAiProvider,
    required this.hospitalNoticeDelivery,
    required this.revision,
  }) : hiddenPages = Set.unmodifiable(hiddenPages),
       flowModes = Map.unmodifiable(flowModes);

  final ClinicPreset preset;
  final Set<String> hiddenPages;
  final Map<String, ClinicalFlowMode> flowModes;
  /// Provider identifier, not a credential or key.
  final String? defaultAiProvider;
  final HospitalNoticeDelivery hospitalNoticeDelivery;
  final int revision;

  static ClinicExperience defaults() => ClinicExperience(
    preset: ClinicPreset.general,
    hiddenPages: {},
    flowModes: {},
    defaultAiProvider: null,
    hospitalNoticeDelivery: HospitalNoticeDelivery.phone,
    revision: 0,
  );

  static ClinicExperience forPreset(
    ClinicPreset preset, {
    ClinicExperience? previous,
  }) {
    // Switching to Personalizado must preserve each manual module choice.
    if (preset == ClinicPreset.custom) {
      return (previous ?? ClinicExperience.defaults()).copy(
        preset: ClinicPreset.custom,
      );
    }
    final enabledGroups = switch (preset) {
      ClinicPreset.smallAnimals => <String>{
        'Atención y expedientes', 'Medicamentos y herramientas',
        'Administración y finanzas', 'Equipo y comunicación',
        'Cuenta y ajustes', 'Asistente IA', 'Revisión de catálogos',
      },
      ClinicPreset.hospital => <String>{
        'Atención y expedientes', 'Medicamentos y herramientas',
        'Administración y finanzas', 'Equipo y comunicación',
        'Estadísticas y reportes', 'Cuenta y ajustes', 'Asistente IA',
        'Revisión de catálogos',
      },
      ClinicPreset.production => <String>{
        'Atención y expedientes', 'Medicamentos y herramientas',
        'Producción animal', 'Administración y finanzas',
        'Equipo y comunicación', 'Estadísticas y reportes',
        'Cuenta y ajustes', 'Asistente IA', 'Revisión de catálogos',
      },
      ClinicPreset.general || ClinicPreset.custom => <String>{
        for (final group in experienceVisibilityGroups) group.title,
      },
    };
    final hide = <String>{
      for (final group in experienceVisibilityGroups)
        if (!enabledGroups.contains(group.title))
          for (final page in group.pages)
            if (!protectedExperiencePages.contains(page)) page,
    };
    if (preset == ClinicPreset.smallAnimals) {
      hide.addAll({'Planeación financiera', 'Productividad y semana'});
    }
    if (preset == ClinicPreset.production) {
      hide.add('Hospitalización');
    }
    return ClinicExperience(
      preset: preset,
      hiddenPages: hide,
      flowModes: previous?.flowModes ?? {},
      defaultAiProvider: previous?.defaultAiProvider,
      hospitalNoticeDelivery: previous?.hospitalNoticeDelivery ?? HospitalNoticeDelivery.phone,
      revision: previous?.revision ?? 0,
    );
  }

  bool visible(String page) =>
      protectedExperiencePages.contains(page) || !hiddenPages.contains(page);

  ClinicalFlowMode flow(String key) =>
      flowModes[key] ?? ClinicalFlowMode.guided;

  ClinicExperience withPage(String page, bool visible) {
    if (!configurableExperiencePages.contains(page)) return this;
    final hidden = Set<String>.from(hiddenPages);
    if (visible) {
      hidden.remove(page);
    } else {
      hidden.add(page);
    }
    return copy(preset: ClinicPreset.custom, hiddenPages: hidden);
  }

  /// Restores *only* module visibility to the factory default (all entries
  /// displayed). It does not touch clinical data, permissions, alarms, workflow
  /// preferences, provider connections, or other module groups.
  ClinicExperience restoreModuleVisibility(String groupTitle) {
    final groups = experienceVisibilityGroups.where(
      (group) => group.title == groupTitle,
    );
    if (groups.isEmpty) return this;

    final targetPages = groups.first.pages.where(
      configurableExperiencePages.contains,
    ).toSet();
    if (targetPages.isEmpty) return this;

    final updated = Set<String>.from(hiddenPages)..removeAll(targetPages);
    if (updated.length == hiddenPages.length) return this;
    return copy(preset: ClinicPreset.custom, hiddenPages: updated);
  }

  /// Only clears the selected workflow preference; current safe default is
  /// guided. Clinical validations remain enforced regardless of mode.
  ClinicExperience restoreFlowDefault(String key) {
    if (!configurableFlows.containsKey(key) || !flowModes.containsKey(key)) {
      return this;
    }
    final updated = Map<String, ClinicalFlowMode>.from(flowModes)..remove(key);
    return copy(flowModes: updated);
  }

  ClinicExperience withFlow(String key, ClinicalFlowMode mode) {
    if (!configurableFlows.containsKey(key)) return this;
    return copy(flowModes: {...flowModes, key: mode});
  }

  ClinicExperience copy({
    ClinicPreset? preset,
    Set<String>? hiddenPages,
    Map<String, ClinicalFlowMode>? flowModes,
    String? defaultAiProvider,
    bool clearProvider = false,
    HospitalNoticeDelivery? hospitalNoticeDelivery,
    int? revision,
  }) => ClinicExperience(
    preset: preset ?? this.preset,
    hiddenPages: hiddenPages ?? this.hiddenPages,
    flowModes: flowModes ?? this.flowModes,
    defaultAiProvider: clearProvider ? null : defaultAiProvider ?? this.defaultAiProvider,
    hospitalNoticeDelivery: hospitalNoticeDelivery ?? this.hospitalNoticeDelivery,
    revision: revision ?? this.revision,
  );

  Map<String, dynamic> toJson() => {
    'schema_version': 1,
    'preset': preset.name,
    'hidden_pages': hiddenPages.toList()..sort(),
    'workflow_modes': flowModes.map((key, mode) => MapEntry(key, mode.name)),
    'default_ai_provider': defaultAiProvider,
    'hospital_notice_delivery': hospitalNoticeDelivery.name,
  };

  factory ClinicExperience.fromServer(Map<String, dynamic> data) {
    if (data['schema_version'] != 1 || data['revision'] is! int ||
        (data['revision'] as int) < 0 || data['settings'] is! Map) {
      throw const FormatException('Contrato de personalización desconocido.');
    }
    final settings = Map<String, dynamic>.from(data['settings'] as Map);
    if (settings['schema_version'] != 1 ||
        settings['preset'] is! String ||
        settings['hidden_pages'] is! List ||
        settings['workflow_modes'] is! Map) {
      throw const FormatException('Preferencias de clínica inválidas.');
    }
    final preset = ClinicPreset.values.where((p) => p.name == settings['preset']).firstOrNull;
    if (preset == null) throw const FormatException('Perfil desconocido.');
    final rawPages = settings['hidden_pages'] as List;
    if (rawPages.any((value) => value is! String ||
        !configurableExperiencePages.contains(value)) ||
        rawPages.toSet().length != rawPages.length) {
      throw const FormatException('Submódulos desconocidos.');
    }
    final modes = Map<String, dynamic>.from(settings['workflow_modes'] as Map);
    final parsedModes = <String, ClinicalFlowMode>{};
    for (final entry in modes.entries) {
      if (!configurableFlows.containsKey(entry.key) || entry.value is! String) {
        throw const FormatException('Flujo desconocido.');
      }
      final parsed = ClinicalFlowMode.values.where((m) => m.name == entry.value).firstOrNull;
      if (parsed == null) throw const FormatException('Modo de trabajo inválido.');
      parsedModes[entry.key] = parsed;
    }
    final ai = settings['default_ai_provider'];
    if (ai != null && (ai is! String || !aiExperienceProviders.containsKey(ai))) {
      throw const FormatException('Proveedor predeterminado desconocido.');
    }
    final rawDelivery = settings['hospital_notice_delivery'] ?? 'phone';
    if (rawDelivery is! String) {
      throw const FormatException('Canal de hospitalización inválido.');
    }
    final delivery = HospitalNoticeDelivery.values.where(
      (channel) => channel.name == rawDelivery,
    ).firstOrNull;
    if (delivery == null) {
      throw const FormatException('Canal de hospitalización desconocido.');
    }
    return ClinicExperience(
      preset: preset,
      hiddenPages: rawPages.cast<String>().toSet(),
      flowModes: parsedModes,
      defaultAiProvider: ai as String?,
      hospitalNoticeDelivery: delivery,
      revision: data['revision'] as int,
    );
  }
}

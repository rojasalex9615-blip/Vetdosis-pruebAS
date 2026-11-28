import 'package:flutter/material.dart';
import '../data/settings_repository.dart';
import '../../offline/application/sync_engine.dart';
import '../../../vet_ui/vet_icons.dart';

enum ClinicalBranch {
  small('Pequeñas especies', VetIcons.paw),
  exotic('Exóticos / Silvestres', VetIcons.rabbit),
  production('Producción y grandes especies', VetIcons.tractor),
  management('Gestión clínica', VetIcons.clinic);

  const ClinicalBranch(this.label, this.icon);
  final String label;
  final IconData icon;
}

class CoreViewModel extends ChangeNotifier {
  CoreViewModel(this.repository, this.settings, {this.syncEngine});
  final SyncEngine? syncEngine;
  final SettingsRepository repository;
  AppSettings settings;
  ClinicalBranch branch = ClinicalBranch.small;
  String screen = 'Inicio';
  String? activityPatientId;
  String? activityInstructions;
  String? saveError;
  ThemeMode get themeMode => switch (settings.brightness) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
  /// Cambiar de rama lleva al tablero de esa rama, no a su catálogo.
  ///
  /// Quien elige «Pequeñas especies» cae en Inicio, que ya es su tablero. Por
  /// simetría, quien elige Producción o Exóticos debe caer en el suyo y no en
  /// la lista de especies: el catálogo se consulta, el tablero es lo que se
  /// mira al empezar el día. Cada pantalla conserva su pestaña de catálogo a
  /// un toque, así que no se pierde nada.
  void selectBranch(ClinicalBranch value) {
    activityPatientId = null;
    activityInstructions = null;
    branch = value;
    screen = switch (value) {
      ClinicalBranch.production => 'Dashboard Pecuario',
      ClinicalBranch.exotic => 'Dashboard Exóticos',
      ClinicalBranch.management => 'Más',
      _ => 'Inicio',
    };
    notifyListeners();
  }

  void navigate(String value, {String? patientId, String? instructions}) {
    activityPatientId = patientId;
    activityInstructions = instructions;
    screen = value;
    notifyListeners();
  }

  Future<void> updateSettings({
    int? palette,
    String? brightness,
    String? visualStyle,
    Set<String>? workAreas,
    bool? includeAdmin,
  }) async {
    settings = AppSettings(
      palette: palette ?? settings.palette,
      visualStyle: visualStyle ?? settings.visualStyle,
      brightness: brightness ?? settings.brightness,
      workAreas: workAreas ?? settings.workAreas,
      includeAdmin: includeAdmin ?? settings.includeAdmin,
    );
    saveError = null;
    notifyListeners();
    try {
      await repository.save(settings);
    } catch (_) {
      saveError = 'No se pudo guardar la apariencia en este dispositivo.';
      notifyListeners();
    }
  }
}

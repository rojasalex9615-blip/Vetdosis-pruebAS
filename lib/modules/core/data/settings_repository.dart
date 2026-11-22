import 'package:shared_preferences/shared_preferences.dart';

const allWorkAreas = <String>{'small', 'production', 'exotic'};
const defaultWorkAreas = allWorkAreas;

class AppSettings {
  final int palette;
  final String brightness;
  final String visualStyle;
  final Set<String> workAreas;

  /// Administracion clinica va incluida con pequenas y exoticos; en
  /// produccion es opcional y se controla con esta marca.
  final bool includeAdmin;
  const AppSettings({
    this.palette = 0,
    this.brightness = 'system',
    this.visualStyle = 'neu',
    this.workAreas = defaultWorkAreas,
    this.includeAdmin = true,
  });
}

class SettingsRepository {
  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final palette = prefs.getInt('palette') ?? 0;
    final mode = prefs.getString('brightness') ?? 'system';
    final visualStyle = prefs.getString('visualStyle') ?? 'neu';
    final storedAreas = prefs.getStringList('workAreas');
    return AppSettings(
      visualStyle: ['standard', 'neu'].contains(visualStyle)
          ? visualStyle
          : 'standard',
      palette: palette >= 0 && palette < 5 ? palette : 0,
      brightness: ['system', 'light', 'dark'].contains(mode) ? mode : 'system',
      workAreas: storedAreas == null
          ? defaultWorkAreas
          : storedAreas.where(allWorkAreas.contains).toSet(),
      includeAdmin: prefs.getBool('includeAdmin') ?? true,
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setInt('palette', settings.palette) ||
        !await prefs.setString('brightness', settings.brightness) ||
        !await prefs.setString('visualStyle', settings.visualStyle) ||
        !await prefs.setStringList('workAreas', settings.workAreas.toList()) ||
        !await prefs.setBool('includeAdmin', settings.includeAdmin)) {
      throw StateError('settings_not_saved');
    }
  }
}

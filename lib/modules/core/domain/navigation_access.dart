import '../../auth/domain/clinic_membership.dart';
import 'module_access.dart';

/// Presentation filter only. Clinical and data authorization stays on the server.
bool navigationAllowed(
  String page,
  ClinicMembership? member, [
  ModuleAccess? access,
]) {
  if (member == null) return true;
  if (access != null && !moduleNavigationAllowed(page, member, access)) {
    return false;
  }
  final role = member.role;
  if (role == ClinicRole.revisor) {
    // El revisor abre el Vademécum para comprobar que la pauta da el resultado
    // correcto. Sin la calculadora no puede revisar la calidad del dato. No se
    // le abre la receta ni la dosis clínica por paciente: eso sigue siendo del
    // MVZ.
    return const {
      'Inicio',
      'Modo revisión',
      'Vademécum',
      'Ajustes',
      'Ayuda y soporte',
    }.contains(page);
  }
  return switch (page) {
    'Modo revisión' => role == ClinicRole.admin,
    'Planeación financiera' => role == ClinicRole.admin,
    'Cálculos' ||
    'Cálculo rápido' ||
    'Operaciones de dosis' ||
    'Cálculos clínicos' => [ClinicRole.admin, ClinicRole.mvz].contains(role),
    'Hospitalización' || 'Receta' when access == null => [
      ClinicRole.admin,
      ClinicRole.mvz,
      ClinicRole.auxiliar,
    ].contains(role),
    'Hospitalización' || 'Receta' => true,
    'Inventario' || 'Caja' || 'Escanear producto' || 'Formatos' => true,
    'Estadísticas' ||
    'Respaldo' ||
    'Estadísticas y respaldo' when access == null => role == ClinicRole.admin,
    'Estadísticas' || 'Respaldo' || 'Estadísticas y respaldo' => true,
    'Equipo y avisos' || 'Anuncios y avisos' || 'Pendientes del equipo' || 'Productividad y semana' => !member.isPersonal,
    'Checado' => !member.isPersonal,
    _ => true,
  };
}

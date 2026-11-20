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
    // Decisión 2026-11-19 (Alejandra): el revisor ve todo y usa las
    // herramientas — Vademécum y cálculo de dosis del empaque para comprobar
    // que la pauta da el resultado correcto — sin editar datos de la clínica.
    // La edición sigue cerrada por los permisos de cada módulo
    // (PatientAccess, canManage, canCalculate) y por la autorización del
    // servidor; este filtro solo abre la navegación.
    return true;
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

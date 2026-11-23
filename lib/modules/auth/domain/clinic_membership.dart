enum ClinicRole {
  admin('Administrador'),
  mvz('MVZ'),
  auxiliar('Auxiliar'),
  recepcion('Recepción'),
  estilista('Estilista'),
  revisor('Revisor de catálogos');

  const ClinicRole(this.label);
  final String label;
  static ClinicRole parse(String value) => ClinicRole.values.firstWhere(
    (role) => role.name == value,
    orElse: () => throw const FormatException('Rol desconocido'),
  );
}

class ClinicMembership {
  const ClinicMembership({
    required this.clinicId,
    required this.clinicName,
    required this.userId,
    required this.role,
    this.workspaceKind = 'clinic',
  });
  final String clinicId;
  final String clinicName;
  final String userId;
  final ClinicRole role;
  final String workspaceKind;
  bool get isPersonal => workspaceKind == 'personal';

  /// El servidor llama «Mi espacio personal» al area de trabajo personal.
  /// En pantalla se nombra como area de trabajo para no confundirla con
  /// «Mi espacio personal» (notas, horarios y ficha de la persona).
  String get displayName =>
      isPersonal ? 'Área de trabajo personal' : clinicName;
}

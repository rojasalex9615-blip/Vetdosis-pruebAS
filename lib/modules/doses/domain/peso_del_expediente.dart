/// Peso anotado en el expediente del paciente.
///
/// No es una medición clínica verificada como [RecordedPatientWeight]: viene de
/// la entrada de peso que ya está en la historia. Se muestra con su fecha para
/// que el MVZ decida si le sirve; la app no lo presenta como medición del día.
class PesoDelExpediente {
  const PesoDelExpediente({
    required this.clinicId,
    required this.patientId,
    required this.patientName,
    required this.kg,
    this.fecha,
  });

  final String clinicId, patientId, patientName, kg;
  final String? fecha;

  String get detalle => fecha == null || fecha!.isEmpty
      ? 'Peso anotado en el expediente: $kg kg'
      : 'Peso anotado en el expediente: $kg kg · $fecha';
}

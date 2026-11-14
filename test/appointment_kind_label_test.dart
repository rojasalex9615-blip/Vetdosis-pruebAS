import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/operations/presentation/appointment_summary.dart';

void main() {
  test('Visita a campo tiene su etiqueta y un tipo desconocido cae en Cita', () {
    expect(appointmentKindLabel('visita_campo'), 'Visita a campo o granja');
    expect(appointmentKindLabel('cirugia'), 'Cirugía');
    expect(appointmentKindLabel('algo_nuevo'), 'Cita');
    expect(appointmentKindLabel(null), 'Cita');
  });
}

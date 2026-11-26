import 'quantity.dart';

/// Un cálculo de dosis tal como quedó, con su cita.
///
/// Guarda el texto exacto que se multiplicó y el que se mostró: si mañana
/// cambia el catálogo, el registro sigue diciendo qué se calculó y con qué
/// fuente. No guarda diagnósticos ni datos que no se hayan usado.
class DoseRecord {
  const DoseRecord({
    required this.id,
    required this.createdAt,
    required this.principio,
    required this.dosisLiteral,
    required this.cita,
    required this.pesoKg,
    required this.resultadoMg,
    this.pautaId = '',
    this.indicacion = '',
    this.especie = '',
    this.via = '',
    this.intervalo = '',
    this.concentracionMgMl,
    this.resultadoMl,
    this.clinicId,
    this.patientId,
    this.patientName,
    this.actorId,
  });

  final String id;
  final DateTime createdAt;
  final String principio, dosisLiteral, cita, pesoKg, resultadoMg;
  final String pautaId, indicacion, especie, via, intervalo;
  final String? concentracionMgMl, resultadoMl;
  final String? clinicId, patientId, patientName, actorId;

  String get resumen => resultadoMl == null
      ? resultadoMg
      : '$resultadoMg ($resultadoMl a $concentracionMgMl mg/mL)';

  Map<String, dynamic> toJson() => {
    'id': id,
    'created_at': createdAt.toUtc().toIso8601String(),
    'principio': principio,
    'pauta_id': pautaId,
    'indicacion': indicacion,
    'especie': especie,
    'via': via,
    'intervalo': intervalo,
    'dosis_literal': dosisLiteral,
    'cita': cita,
    'peso_kg': pesoKg,
    'resultado_mg': resultadoMg,
    if (concentracionMgMl != null) 'concentracion_mg_ml': concentracionMgMl,
    if (resultadoMl != null) 'resultado_ml': resultadoMl,
    if (clinicId != null) 'clinic_id': clinicId,
    if (patientId != null) 'patient_id': patientId,
    if (patientName != null) 'patient_name': patientName,
    if (actorId != null) 'actor_id': actorId,
  };

  static DoseRecord fromJson(Map<String, dynamic> json) => DoseRecord(
    id: json['id'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    principio: json['principio'] as String,
    pautaId: json['pauta_id'] as String? ?? '',
    indicacion: json['indicacion'] as String? ?? '',
    especie: json['especie'] as String? ?? '',
    via: json['via'] as String? ?? '',
    intervalo: json['intervalo'] as String? ?? '',
    dosisLiteral: json['dosis_literal'] as String,
    cita: json['cita'] as String,
    pesoKg: json['peso_kg'] as String,
    resultadoMg: json['resultado_mg'] as String,
    concentracionMgMl: json['concentracion_mg_ml'] as String?,
    resultadoMl: json['resultado_ml'] as String?,
    clinicId: json['clinic_id'] as String?,
    patientId: json['patient_id'] as String?,
    patientName: json['patient_name'] as String?,
    actorId: json['actor_id'] as String?,
  );
}

/// Volumen para una dosis en masa y una concentración del empaque.
///
/// La concentración la dicta el envase que el médico tiene en la mano, no el
/// catálogo: por eso es un dato de entrada y se guarda con el cálculo.
class VolumenDeEmpaque {
  const VolumenDeEmpaque({
    required this.minimo,
    required this.maximo,
    required this.concentracion,
  });

  final Quantity minimo, maximo, concentracion;

  bool get esRango => minimo.compareTo(maximo) != 0;

  String get texto => esRango
      ? '${minimo.display()}–${maximo.display()} mL'
      : '${minimo.display()} mL';

  /// Lectura para la jeringa: el volumen redondeado a la graduación elegida.
  /// El número exacto sigue a la vista; esto solo ayuda a medir.
  String? redondeado(Quantity? graduacion) {
    if (graduacion == null || !graduacion.positive) return null;
    final desde = minimo.nearestStep(graduacion).display();
    if (!esRango) return 'Jeringa de ${graduacion.display()} mL: $desde mL';
    final hasta = maximo.nearestStep(graduacion).display();
    return 'Jeringa de ${graduacion.display()} mL: $desde–$hasta mL';
  }
}

/// Convierte miligramos a mililitros con la concentración del empaque.
///
/// Devuelve null si la concentración no es mayor que cero: no se inventa un
/// volumen sin saber cuánto fármaco hay por mililitro.
VolumenDeEmpaque? volumenDeEmpaque({
  required Quantity dosisMg,
  Quantity? dosisMaximaMg,
  required Quantity concentracionMgMl,
}) {
  if (!concentracionMgMl.positive) return null;
  final minimo = dosisMg / concentracionMgMl;
  final maximo = (dosisMaximaMg ?? dosisMg) / concentracionMgMl;
  return VolumenDeEmpaque(
    minimo: minimo,
    maximo: maximo.compareTo(minimo) < 0 ? minimo : maximo,
    concentracion: concentracionMgMl,
  );
}

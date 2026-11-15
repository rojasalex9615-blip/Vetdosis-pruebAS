/// Valores de referencia de mamíferos pequeños no convencionales.
///
/// Transcripción del lote 2 de exóticos (Drive de Ale, `VetDosis_lote2_exoticos`)
/// de «Clínica de Mascotas No Convencionales: Mamíferos», de Miguel Ángel de la
/// Torre Suire. Es SOLO referencia: ningún dato está validado clínicamente, no
/// hay cálculos ni dosis, y la propia fuente marca dos valores bioquímicos del
/// cuyo para corroborar. Nada de aquí se guarda ni se aplica a un paciente.
library;

enum ExoticGroup {
  reproduccion('Reproducción'),
  hematologia('Hematología'),
  bioquimica('Bioquímica sérica');

  const ExoticGroup(this.label);
  final String label;
}

/// De dónde sale un grupo de datos y en qué estado de revisión está.
class ExoticSource {
  const ExoticSource({
    required this.work,
    required this.page,
    required this.table,
    required this.status,
  });
  final String work;
  final int page;
  final String table;
  final String status;
}

const _work =
    'Clínica de Mascotas No Convencionales: Mamíferos (M. Á. de la Torre Suire)';

const exoticSources = <ExoticGroup, ExoticSource>{
  ExoticGroup.reproduccion: ExoticSource(
    work: _work,
    page: 171,
    table: '4.2',
    status: 'Pendiente de revisión clínica',
  ),
  ExoticGroup.hematologia: ExoticSource(
    work: _work,
    page: 175,
    table: '4.4',
    status: 'Transcripción pendiente de revisión clínica',
  ),
  ExoticGroup.bioquimica: ExoticSource(
    work: _work,
    page: 176,
    table: '4.4 (continuación)',
    status: 'Pendiente de revisión clínica',
  ),
};

/// Nombre científico solo donde la fuente lo da.
const exoticTaxon = <String, String>{
  'Ratón': 'Mus musculus',
  'Rata': 'Rattus norvegicus',
  'Cuyo': 'Cavia porcellus',
  'Chinchilla': 'Chinchilla lanigera',
};

/// Avisos de precisión taxonómica que la fuente deja abiertos.
const exoticTaxonNotes = <String, String>{
  'Hámster':
      'La tabla agrupa varias especies de hámster; sirio, ruso y chino aparecen sin nombre científico confirmado.',
  'Jerbo':
      'La tabla no explicita género ni especie del jerbo; verifícalo antes de usar estos datos.',
};

const exoticSpecies = <String>[
  'Ratón',
  'Rata',
  'Hámster',
  'Jerbo',
  'Cuyo',
  'Chinchilla',
];

class ExoticReferenceRow {
  const ExoticReferenceRow(
    this.species,
    this.group,
    this.parameter,
    this.min,
    this.max,
    this.unit, {
    this.qualifier,
    this.note,
    this.flagged = false,
  });

  final String species;
  final ExoticGroup group;
  final String parameter;
  final double min, max;
  final String unit;

  /// Sexo o variante a la que aplica (macho, hembra, sirio…).
  final String? qualifier;
  final String? note;

  /// La transcripción marca este valor para corroborarlo (valor o unidad).
  final bool flagged;

  String get title => qualifier == null ? parameter : '$parameter · $qualifier';

  String get range => min == max
      ? '${_fmt(min)} $unit'
      : '${_fmt(min)}–${_fmt(max)} $unit';
}

String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : '$v';

List<ExoticGroup> exoticGroupsFor(String species) => [
  for (final g in ExoticGroup.values)
    if (exoticReferences.any((r) => r.species == species && r.group == g)) g,
];

List<ExoticReferenceRow> exoticRowsFor(String species, ExoticGroup group) => [
  for (final r in exoticReferences)
    if (r.species == species && r.group == group) r,
];

const _r = ExoticGroup.reproduccion;
const _h = ExoticGroup.hematologia;
const _b = ExoticGroup.bioquimica;

const exoticReferences = <ExoticReferenceRow>[
  // Reproducción · tabla 4.2, p. 171
  ExoticReferenceRow('Ratón', _r, 'Pubertad', 30, 50, 'días'),
  ExoticReferenceRow('Ratón', _r, 'Ciclo estral', 4, 5, 'días'),
  ExoticReferenceRow('Ratón', _r, 'Duración del estro', 10, 20, 'horas'),
  ExoticReferenceRow('Ratón', _r, 'Crías por camada', 5, 12, 'crías'),
  ExoticReferenceRow('Ratón', _r, 'Destete', 21, 28, 'días'),
  ExoticReferenceRow('Rata', _r, 'Pubertad', 65, 100, 'días'),
  ExoticReferenceRow('Rata', _r, 'Ciclo estral', 4, 5, 'días'),
  ExoticReferenceRow('Rata', _r, 'Duración del estro', 10, 20, 'horas'),
  ExoticReferenceRow('Rata', _r, 'Crías por camada', 8, 18, 'crías'),
  ExoticReferenceRow('Rata', _r, 'Destete', 21, 28, 'días'),
  ExoticReferenceRow('Hámster', _r, 'Pubertad', 9, 13, 'semanas',
      qualifier: 'macho'),
  ExoticReferenceRow('Hámster', _r, 'Pubertad', 6, 10, 'semanas',
      qualifier: 'hembra'),
  ExoticReferenceRow('Hámster', _r, 'Ciclo estral', 4, 4, 'días'),
  ExoticReferenceRow('Hámster', _r, 'Duración del estro', 8, 26, 'horas'),
  ExoticReferenceRow('Hámster', _r, 'Gestación', 15, 18, 'días',
      qualifier: 'sirio'),
  ExoticReferenceRow('Hámster', _r, 'Gestación', 18, 21, 'días',
      qualifier: 'ruso'),
  ExoticReferenceRow('Hámster', _r, 'Gestación', 20, 22, 'días',
      qualifier: 'chino'),
  ExoticReferenceRow('Hámster', _r, 'Crías por camada', 5, 10, 'crías'),
  ExoticReferenceRow('Hámster', _r, 'Destete', 20, 28, 'días'),
  ExoticReferenceRow('Jerbo', _r, 'Pubertad', 70, 85, 'días',
      qualifier: 'macho'),
  ExoticReferenceRow('Jerbo', _r, 'Pubertad', 65, 85, 'días',
      qualifier: 'hembra'),
  ExoticReferenceRow('Jerbo', _r, 'Ciclo estral', 4, 7, 'días'),
  ExoticReferenceRow('Jerbo', _r, 'Duración del estro', 12, 18, 'horas'),
  ExoticReferenceRow('Jerbo', _r, 'Crías por camada', 3, 8, 'crías'),
  ExoticReferenceRow('Jerbo', _r, 'Destete', 20, 30, 'días'),
  ExoticReferenceRow('Cuyo', _r, 'Pubertad', 2, 2, 'meses',
      qualifier: 'macho'),
  ExoticReferenceRow('Cuyo', _r, 'Pubertad', 3, 3, 'meses',
      qualifier: 'hembra'),
  ExoticReferenceRow('Cuyo', _r, 'Ciclo estral', 15, 17, 'días'),
  ExoticReferenceRow('Cuyo', _r, 'Duración del estro', 6, 11, 'horas'),
  ExoticReferenceRow('Cuyo', _r, 'Crías por camada', 1, 6, 'crías'),
  ExoticReferenceRow('Cuyo', _r, 'Destete', 14, 28, 'días'),
  ExoticReferenceRow('Chinchilla', _r, 'Pubertad', 7, 10, 'meses'),
  ExoticReferenceRow('Chinchilla', _r, 'Ciclo estral', 30, 50, 'días'),
  ExoticReferenceRow('Chinchilla', _r, 'Duración del estro', 40, 40, 'horas'),
  ExoticReferenceRow('Chinchilla', _r, 'Camadas por año', 2, 2, 'camadas/año'),
  ExoticReferenceRow('Chinchilla', _r, 'Crías por camada', 2, 2, 'crías'),
  ExoticReferenceRow('Chinchilla', _r, 'Destete', 36, 48, 'días'),

  // Hematología del cuyo por sexo · tabla 4.4, p. 175
  ExoticReferenceRow('Cuyo', _h, 'Hemoglobina', 11.6, 17.2, 'g/dL',
      qualifier: 'macho'),
  ExoticReferenceRow('Cuyo', _h, 'Hemoglobina', 11.4, 17.0, 'g/dL',
      qualifier: 'hembra'),
  ExoticReferenceRow('Cuyo', _h, 'Volumen corpuscular medio (VCM)', 71, 83, 'fL',
      qualifier: 'macho'),
  ExoticReferenceRow(
      'Cuyo', _h, 'Volumen corpuscular medio (VCM)', 86.1, 95.9, 'fL',
      qualifier: 'hembra'),
  ExoticReferenceRow(
      'Cuyo', _h, 'Hemoglobina corpuscular media (HCM)', 24.2, 27.2, 'pg',
      qualifier: 'macho'),
  ExoticReferenceRow(
      'Cuyo', _h, 'Hemoglobina corpuscular media (HCM)', 23.1, 26.3, 'pg',
      qualifier: 'hembra'),
  ExoticReferenceRow('Cuyo', _h,
      'Concentración de hemoglobina corpuscular media (CHCM)', 29.7, 38.9, 'g/dL',
      qualifier: 'macho'),
  ExoticReferenceRow('Cuyo', _h,
      'Concentración de hemoglobina corpuscular media (CHCM)', 28.2, 34.4, 'g/dL',
      qualifier: 'hembra'),
  ExoticReferenceRow('Cuyo', _h, 'Plaquetas', 260, 740, '10^3/µL',
      qualifier: 'macho'),
  ExoticReferenceRow('Cuyo', _h, 'Plaquetas', 266, 634, '10^3/µL',
      qualifier: 'hembra'),
  ExoticReferenceRow('Cuyo', _h, 'Neutrófilos', 28, 56, '%',
      qualifier: 'macho', note: 'Porcentaje diferencial, no recuento absoluto.'),
  ExoticReferenceRow('Cuyo', _h, 'Neutrófilos', 20.3, 41.9, '%',
      qualifier: 'hembra', note: 'Porcentaje diferencial, no recuento absoluto.'),
  ExoticReferenceRow('Cuyo', _h, 'Linfocitos', 40, 62.5, '%',
      qualifier: 'macho', note: 'Porcentaje diferencial, no recuento absoluto.'),
  ExoticReferenceRow('Cuyo', _h, 'Linfocitos', 46.4, 80.4, '%',
      qualifier: 'hembra', note: 'Porcentaje diferencial, no recuento absoluto.'),
  ExoticReferenceRow('Cuyo', _h, 'Monocitos', 3.3, 5.3, '%',
      qualifier: 'macho', note: 'Porcentaje diferencial, no recuento absoluto.'),
  ExoticReferenceRow('Cuyo', _h, 'Monocitos', 1, 2.6, '%',
      qualifier: 'hembra', note: 'Porcentaje diferencial, no recuento absoluto.'),
  ExoticReferenceRow('Cuyo', _h, 'Eosinófilos', 1, 7, '%',
      qualifier: 'macho', note: 'Porcentaje diferencial, no recuento absoluto.'),
  ExoticReferenceRow('Cuyo', _h, 'Eosinófilos', 0, 7, '%',
      qualifier: 'hembra', note: 'Porcentaje diferencial, no recuento absoluto.'),
  ExoticReferenceRow('Cuyo', _h, 'Basófilos', 0, 1.7, '%',
      qualifier: 'macho', note: 'Porcentaje diferencial, no recuento absoluto.'),
  ExoticReferenceRow('Cuyo', _h, 'Basófilos', 0, 0.8, '%',
      qualifier: 'hembra', note: 'Porcentaje diferencial, no recuento absoluto.'),

  // Bioquímica sérica del cuyo · tabla 4.4 (continuación), p. 176
  ExoticReferenceRow('Cuyo', _b, 'ALT', 10, 25, 'UI/L'),
  ExoticReferenceRow('Cuyo', _b, 'Bilirrubina total', 0.3, 0.9, 'mg/dL'),
  ExoticReferenceRow('Cuyo', _b, 'Colesterol', 20, 43, 'mg/dL'),
  ExoticReferenceRow('Cuyo', _b, 'Triglicéridos', 0, 145, 'mg/dL'),
  ExoticReferenceRow('Cuyo', _b, 'Proteínas totales', 4.6, 6.2, 'g/dL'),
  ExoticReferenceRow('Cuyo', _b, 'Albúmina', 2.1, 3.9, 'g/dL'),
  ExoticReferenceRow('Cuyo', _b, 'Globulinas', 1.7, 2.6, 'g/dL'),
  ExoticReferenceRow('Cuyo', _b, 'Glucosa', 60, 125, 'mg/dL'),
  ExoticReferenceRow('Cuyo', _b, 'Fósforo', 5.3, 5.3, 'mg/dL',
      note: 'Valor aislado publicado.', flagged: true),
  ExoticReferenceRow('Cuyo', _b, 'Potasio', 6.8, 8.9, 'mEq/L',
      note: 'Intervalo elevado: confirmar con laboratorio o fuente primaria.',
      flagged: true),
  ExoticReferenceRow('Cuyo', _b, 'Calcio', 7.8, 10.5, 'mg/dL'),
  ExoticReferenceRow('Cuyo', _b, 'Nitrógeno ureico (BUN)', 9, 32, 'mg/dL',
      note: 'BUN: no convertir a urea sin una relación explícita.'),
  ExoticReferenceRow('Cuyo', _b, 'Creatinina', 0.6, 2.2, 'mg/dL'),
];

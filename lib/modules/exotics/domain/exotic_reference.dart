/// Valores de referencia de mamíferos pequeños no convencionales.
///
/// Cada valor sale de una obra publicada y lleva su cita (obra, página, tabla)
/// y el nombre exacto con que esa obra llama a la especie. Cuando dos obras dan
/// rangos distintos se muestran los dos: son criterios de profesionales
/// distintos y aquí no se elige, promedia ni descarta ninguno.
///
/// Origen: filas de la hoja «Exóticos complementos» (lote 8) de
/// `vetdosis_reference_staging.raw_intake_rows` en Supabase, copiadas tal cual.
/// Es solo consulta: no hay cálculos ni dosis, y nada se guarda ni se aplica a
/// un paciente.
library;

enum ExoticGroup {
  fisiologia('Fisiología'),
  reproduccion('Reproducción y manejo'),
  hematologia('Hematología'),
  bioquimica('Bioquímica sérica');

  const ExoticGroup(this.label);
  final String label;
}

/// Obra, página y tabla de donde se tomó un valor.
class ExoticCitation {
  const ExoticCitation(this.work, this.page, this.table);
  final String work;
  final String page;
  final String table;

  String get text => '$work, $page, tabla $table';
}

const _torre =
    'De la Torre Suire, Clínica de Mascotas No Convencionales: Mamíferos';
const _manejo =
    'Manejo y tratamiento de los animales exóticos (fragmento escaneado)';

const exoticCitations = <String, ExoticCitation>{
  'T171': ExoticCitation(_torre, 'p. 171', '4.2'),
  'T175': ExoticCitation(_torre, 'p. 175', '4.4'),
  'T176': ExoticCitation(_torre, 'p. 176', '4.4 (continuación)'),
  'T190': ExoticCitation(_torre, 'p. 190', '4.5'),
  'T194': ExoticCitation(_torre, 'p. 194', '4.7'),
  'T205': ExoticCitation(_torre, 'p. 205', '4.10'),
  'T206': ExoticCitation(_torre, 'p. 206', '4.10 (continuación)'),
  'M1': ExoticCitation(_manejo, 'p. 1 del PDF', '2.1'),
  'M2c': ExoticCitation(_manejo, 'p. 2 del PDF', '2.1 (continuación)'),
  'M2': ExoticCitation(_manejo, 'p. 2 del PDF', '2.2'),
  'M4': ExoticCitation(_manejo, 'p. 4 del PDF', '2.3'),
};

/// Avisos de nomenclatura que las propias obras dejan abiertos.
const exoticTaxonNotes = <String, String>{
  'Hámster':
      'Los nombres son los que usa cada obra y pueden ser nombres comunes de la región del autor, no una especie exacta (hámster dorado, sirio, ruso, chino, grupo o sin especie). Se muestran tal cual, sin homologarlos.',
  'Jerbo':
      'Los nombres son los que usa cada obra y pueden ser nombres comunes de la región del autor, no una especie exacta (jerbo mongol, jerbo del libro A, jerbo sin especie). Se muestran tal cual, sin homologarlos; el nombre científico que aparece junto a algunos valores es el que registra la transcripción de esa obra.',
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
  const ExoticReferenceRow({
    required this.species,
    required this.group,
    required this.parameter,
    required this.min,
    required this.max,
    required this.unit,
    required this.citation,
    required this.sourceName,
    this.publishedAs,
    this.qualifier,
    this.taxon,
    this.note,
    this.flagged = false,
  });

  /// Especie de la lista de la app (donde se agrupa).
  final String species;
  final ExoticGroup group;
  final String parameter;
  final double min, max;
  final String unit;
  final ExoticCitation citation;

  /// Nombre de la especie tal como lo da la obra.
  final String sourceName;

  /// Nombre del parámetro en la obra, solo si se unificó con otro sinónimo.
  final String? publishedAs;

  /// Sexo al que aplica (macho, hembra).
  final String? qualifier;
  final String? taxon;
  final String? note;

  /// La transcripción marca este valor para corroborar valor y unidad.
  final bool flagged;

  String get title => qualifier == null ? parameter : '$parameter · $qualifier';

  String get range => min == max
      ? '${_fmt(min)} $unit'
      : '${_fmt(min)}–${_fmt(max)} $unit';

  /// «Nombre en la obra (taxon) · obra, página, tabla».
  String get caption {
    final who = taxon == null ? sourceName : '$sourceName ($taxon)';
    final alias = publishedAs == null ? '' : ' · en la obra: $publishedAs';
    return '$who$alias · ${citation.text}';
  }
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

/// Obras distintas que citan a una especie.
int exoticWorksFor(String species) => {
  for (final r in exoticReferences)
    if (r.species == species) r.citation.work,
}.length;

const _groupCodes = <String, ExoticGroup>{
  'F': ExoticGroup.fisiologia,
  'R': ExoticGroup.reproduccion,
  'H': ExoticGroup.hematologia,
  'B': ExoticGroup.bioquimica,
};

/// Sinónimos de parámetro entre obras; el nombre original se conserva.
const _aliases = <String, String>{
  'Tamaño de camada': 'Crías por camada',
  'Glóbulos rojos': 'Eritrocitos',
  'Glóbulos blancos': 'Leucocitos totales',
};

const _differentials = <String>{
  'Neutrófilos',
  'Linfocitos',
  'Monocitos',
  'Eosinófilos',
  'Basófilos',
};

final exoticReferences = _parse();

List<ExoticReferenceRow> _parse() {
  final rows = <ExoticReferenceRow>[];
  for (final line in _data.split('\n')) {
    if (line.trim().isEmpty) continue;
    final f = line.split('|');
    assert(f.length == 11, 'Fila mal formada: $line');
    final published = f[2];
    final parameter = _aliases[published] ?? published;
    final group = _groupCodes[f[1]]!;
    var note = f[10].isEmpty ? null : f[10];
    final flagged = note != null && note.startsWith('!');
    if (flagged) note = note.substring(1);
    if (note == null &&
        group == ExoticGroup.hematologia &&
        _differentials.contains(parameter)) {
      note = 'Porcentaje diferencial, no recuento absoluto.';
    }
    rows.add(
      ExoticReferenceRow(
        species: f[0],
        group: group,
        parameter: parameter,
        publishedAs: parameter == published ? null : published,
        qualifier: f[3].isEmpty ? null : f[3],
        min: double.parse(f[4]),
        max: double.parse(f[5]),
        unit: f[6],
        citation: exoticCitations[f[7]]!,
        sourceName: f[8],
        taxon: f[9].isEmpty ? null : f[9],
        note: note,
        flagged: flagged,
      ),
    );
  }
  return List.unmodifiable(rows);
}

// especie|grupo|parámetro|sexo|mín|máx|unidad|cita|nombre en la obra|taxon|nota
// Grupo: F fisiología, R reproducción y manejo, H hematología, B bioquímica.
// Nota que empieza con ! = la transcripción pide corroborar valor y unidad.
const _data = '''
Ratón|R|Pubertad||30|50|días|T171|Ratón|Mus musculus|
Ratón|R|Ciclo estral||4|5|días|T171|Ratón|Mus musculus|
Ratón|R|Duración del estro||10|20|horas|T171|Ratón|Mus musculus|
Ratón|R|Crías por camada||5|12|crías|T171|Ratón|Mus musculus|
Ratón|R|Destete||21|28|días|T171|Ratón|Mus musculus|
Rata|R|Pubertad||65|100|días|T171|Rata|Rattus norvegicus|
Rata|R|Ciclo estral||4|5|días|T171|Rata|Rattus norvegicus|
Rata|R|Duración del estro||10|20|horas|T171|Rata|Rattus norvegicus|
Rata|R|Crías por camada||8|18|crías|T171|Rata|Rattus norvegicus|
Rata|R|Destete||21|28|días|T171|Rata|Rattus norvegicus|
Hámster|R|Pubertad|macho|9|13|semanas|T171|Hámster (grupo)||
Hámster|R|Pubertad|hembra|6|10|semanas|T171|Hámster (grupo)||
Hámster|R|Ciclo estral||4|4|días|T171|Hámster (grupo)||
Hámster|R|Duración del estro||8|26|horas|T171|Hámster (grupo)||
Hámster|R|Gestación||15|18|días|T171|Hámster sirio||
Hámster|R|Gestación||18|21|días|T171|Hámster ruso||
Hámster|R|Gestación||20|22|días|T171|Hámster chino||
Hámster|R|Crías por camada||5|10|crías|T171|Hámster (grupo)||
Hámster|R|Destete||20|28|días|T171|Hámster (grupo)||
Jerbo|R|Pubertad|macho|70|85|días|T171|Jerbo (de la obra)||
Jerbo|R|Pubertad|hembra|65|85|días|T171|Jerbo (de la obra)||
Jerbo|R|Ciclo estral||4|7|días|T171|Jerbo (de la obra)||
Jerbo|R|Duración del estro||12|18|horas|T171|Jerbo (de la obra)||
Jerbo|R|Crías por camada||3|8|crías|T171|Jerbo (de la obra)||
Jerbo|R|Destete||20|30|días|T171|Jerbo (de la obra)||
Cuyo|R|Pubertad|macho|2|2|meses|T171|Cuyo|Cavia porcellus|
Cuyo|R|Pubertad|hembra|3|3|meses|T171|Cuyo|Cavia porcellus|
Cuyo|R|Ciclo estral||15|17|días|T171|Cuyo|Cavia porcellus|
Cuyo|R|Duración del estro||6|11|horas|T171|Cuyo|Cavia porcellus|
Cuyo|R|Crías por camada||1|6|crías|T171|Cuyo|Cavia porcellus|
Cuyo|R|Destete||14|28|días|T171|Cuyo|Cavia porcellus|
Chinchilla|R|Pubertad||7|10|meses|T171|Chinchilla|Chinchilla lanigera|
Chinchilla|R|Ciclo estral||30|50|días|T171|Chinchilla|Chinchilla lanigera|
Chinchilla|R|Duración del estro||40|40|horas|T171|Chinchilla|Chinchilla lanigera|
Chinchilla|R|Camadas por año||2|2|camadas/año|T171|Chinchilla|Chinchilla lanigera|
Chinchilla|R|Crías por camada||2|2|crías|T171|Chinchilla|Chinchilla lanigera|
Chinchilla|R|Destete||36|48|días|T171|Chinchilla|Chinchilla lanigera|
Cuyo|H|Hemoglobina|macho|11.6|17.2|g/dL|T175|Cuyo|Cavia porcellus|
Cuyo|H|Hemoglobina|hembra|11.4|17.0|g/dL|T175|Cuyo|Cavia porcellus|
Cuyo|H|Volumen corpuscular medio (VCM)|macho|71|83|fL|T175|Cuyo|Cavia porcellus|
Cuyo|H|Volumen corpuscular medio (VCM)|hembra|86.1|95.9|fL|T175|Cuyo|Cavia porcellus|
Cuyo|H|Hemoglobina corpuscular media (HCM)|macho|24.2|27.2|pg|T175|Cuyo|Cavia porcellus|
Cuyo|H|Hemoglobina corpuscular media (HCM)|hembra|23.1|26.3|pg|T175|Cuyo|Cavia porcellus|
Cuyo|H|Concentración de hemoglobina corpuscular media (CHCM)|macho|29.7|38.9|g/dL|T175|Cuyo|Cavia porcellus|
Cuyo|H|Concentración de hemoglobina corpuscular media (CHCM)|hembra|28.2|34.4|g/dL|T175|Cuyo|Cavia porcellus|
Cuyo|H|Plaquetas|macho|260|740|10^3/µL|T175|Cuyo|Cavia porcellus|
Cuyo|H|Plaquetas|hembra|266|634|10^3/µL|T175|Cuyo|Cavia porcellus|
Cuyo|H|Neutrófilos|macho|28|56|%|T175|Cuyo|Cavia porcellus|
Cuyo|H|Neutrófilos|hembra|20.3|41.9|%|T175|Cuyo|Cavia porcellus|
Cuyo|H|Linfocitos|macho|40|62.5|%|T175|Cuyo|Cavia porcellus|
Cuyo|H|Linfocitos|hembra|46.4|80.4|%|T175|Cuyo|Cavia porcellus|
Cuyo|H|Monocitos|macho|3.3|5.3|%|T175|Cuyo|Cavia porcellus|
Cuyo|H|Monocitos|hembra|1|2.6|%|T175|Cuyo|Cavia porcellus|
Cuyo|H|Eosinófilos|macho|1|7|%|T175|Cuyo|Cavia porcellus|
Cuyo|H|Eosinófilos|hembra|0|7|%|T175|Cuyo|Cavia porcellus|
Cuyo|H|Basófilos|macho|0|1.7|%|T175|Cuyo|Cavia porcellus|
Cuyo|H|Basófilos|hembra|0|0.8|%|T175|Cuyo|Cavia porcellus|
Cuyo|H|Hematocrito|macho|37|47|%|T175|Cuyo|Cavia porcellus|
Cuyo|H|Hematocrito|hembra|40.9|49.9|%|T175|Cuyo|Cavia porcellus|
Cuyo|H|Eritrocitos|macho|4.36|6.84|10^6/µL|T175|Cuyo|Cavia porcellus|
Cuyo|H|Eritrocitos|hembra|3.35|6.15|10^6/µL|T175|Cuyo|Cavia porcellus|
Cuyo|H|Leucocitos totales|macho|5.5|17.5|10^3/µL|T175|Cuyo|Cavia porcellus|
Cuyo|H|Leucocitos totales|hembra|5.2|16.4|10^3/µL|T175|Cuyo|Cavia porcellus|
Cuyo|B|ALT||10|25|UI/L|T176|Cuyo|Cavia porcellus|
Cuyo|B|Bilirrubina total||0.3|0.9|mg/dL|T176|Cuyo|Cavia porcellus|
Cuyo|B|Colesterol||20|43|mg/dL|T176|Cuyo|Cavia porcellus|
Cuyo|B|Triglicéridos||0|145|mg/dL|T176|Cuyo|Cavia porcellus|
Cuyo|B|Proteínas totales||4.6|6.2|g/dL|T176|Cuyo|Cavia porcellus|
Cuyo|B|Albúmina||2.1|3.9|g/dL|T176|Cuyo|Cavia porcellus|
Cuyo|B|Globulinas||1.7|2.6|g/dL|T176|Cuyo|Cavia porcellus|
Cuyo|B|Glucosa||60|125|mg/dL|T176|Cuyo|Cavia porcellus|
Cuyo|B|Fósforo||5.3|5.3|mg/dL|T176|Cuyo|Cavia porcellus|!Valor aislado publicado.
Cuyo|B|Potasio||6.8|8.9|mEq/L|T176|Cuyo|Cavia porcellus|!Intervalo elevado: confirmar con laboratorio o fuente primaria.
Cuyo|B|Calcio||7.8|10.5|mg/dL|T176|Cuyo|Cavia porcellus|
Cuyo|B|Nitrógeno ureico (BUN)||9|32|mg/dL|T176|Cuyo|Cavia porcellus|BUN: no convertir a urea sin una relación explícita.
Cuyo|B|Creatinina||0.6|2.2|mg/dL|T176|Cuyo|Cavia porcellus|
Hámster|F|Temperatura rectal||37|38|°C|T190|Hámster dorado|Mesocricetus auratus|
Hámster|F|Frecuencia cardíaca||250|500|lpm|T190|Hámster dorado|Mesocricetus auratus|
Hámster|F|Frecuencia respiratoria||30|35|resp/min|T190|Hámster dorado|Mesocricetus auratus|
Hámster|F|Peso adulto macho||85|130|g|T190|Hámster dorado|Mesocricetus auratus|
Hámster|F|Peso adulto hembra||95|140|g|T190|Hámster dorado|Mesocricetus auratus|
Hámster|H|Hematocrito||45|50|%|T205|Hámster dorado|Mesocricetus auratus|
Hámster|H|Hemoglobina||16.6|18.6|g/dL|T205|Hámster dorado|Mesocricetus auratus|
Hámster|H|Eritrocitos||7|8|10^6/µL|T205|Hámster dorado|Mesocricetus auratus|
Hámster|H|Leucocitos totales||7|10|10^3/µL|T205|Hámster dorado|Mesocricetus auratus|
Hámster|H|Neutrófilos||18|40|%|T205|Hámster dorado|Mesocricetus auratus|
Hámster|H|Linfocitos||56|80|%|T205|Hámster dorado|Mesocricetus auratus|
Hámster|B|Glucosa||37|196|mg/dL|T206|Hámster dorado|Mesocricetus auratus|
Hámster|B|Colesterol||55|181|mg/dL|T206|Hámster dorado|Mesocricetus auratus|
Hámster|B|Creatinina||0.4|1|mg/dL|T206|Hámster dorado|Mesocricetus auratus|
Hámster|B|Proteínas totales||5.2|7|g/dL|T206|Hámster dorado|Mesocricetus auratus|
Hámster|B|ALT||22|128|UI/L|T206|Hámster dorado|Mesocricetus auratus|
Jerbo|F|Temperatura rectal||37|38.5|°C|T194|Jerbo mongol|Meriones unguiculatus|
Jerbo|F|Frecuencia cardíaca||360|360|lpm|T194|Jerbo mongol|Meriones unguiculatus|
Jerbo|F|Frecuencia respiratoria||90|90|resp/min|T194|Jerbo mongol|Meriones unguiculatus|
Jerbo|F|Peso adulto macho||65|100|g|T194|Jerbo mongol|Meriones unguiculatus|
Jerbo|F|Peso adulto hembra||55|85|g|T194|Jerbo mongol|Meriones unguiculatus|
Jerbo|H|Hematocrito||35|45|%|T205|Jerbo mongol|Meriones unguiculatus|
Jerbo|H|Hemoglobina||14|16|g/dL|T205|Jerbo mongol|Meriones unguiculatus|
Jerbo|H|Eritrocitos||7|8|10^6/µL|T205|Jerbo mongol|Meriones unguiculatus|
Jerbo|H|Leucocitos totales||7.5|10.9|10^3/µL|T205|Jerbo mongol|Meriones unguiculatus|
Jerbo|H|Linfocitos||75|75|%|T205|Jerbo mongol|Meriones unguiculatus|
Jerbo|B|Glucosa||50|135|mg/dL|T206|Jerbo mongol|Meriones unguiculatus|
Jerbo|B|Colesterol||90|150|mg/dL|T206|Jerbo mongol|Meriones unguiculatus|
Jerbo|B|Proteínas totales||4.3|12.5|g/dL|T206|Jerbo mongol|Meriones unguiculatus|
Jerbo|B|Albúmina||1.8|5.5|g/dL|T206|Jerbo mongol|Meriones unguiculatus|
Jerbo|B|Calcio||3.7|6.2|mg/dL|T206|Jerbo mongol|Meriones unguiculatus|
Jerbo|B|Fósforo||3.7|7|mg/dL|T206|Jerbo mongol|Meriones unguiculatus|
Hámster|F|Temperatura rectal||37.6|37.6|°C|M1|Hámster (especie no precisada)||
Hámster|F|Frecuencia cardíaca||310|471|lpm|M1|Hámster (especie no precisada)||
Hámster|F|Frecuencia respiratoria||38|110|resp/min|M1|Hámster (especie no precisada)||
Hámster|F|Vida media||18|36|meses|M1|Hámster (especie no precisada)||
Hámster|F|Peso adulto macho||87|130|g|M1|Hámster (especie no precisada)||
Hámster|F|Peso adulto hembra||95|130|g|M1|Hámster (especie no precisada)||
Hámster|R|Gestación||15|18|días|M2c|Hámster (especie no precisada)||
Hámster|R|Tamaño de camada||5|10|crías|M2c|Hámster (especie no precisada)||
Hámster|R|Peso al nacimiento||1.5|3|g|M2c|Hámster (especie no precisada)||
Hámster|R|Apertura de ojos||12|14|días|M2c|Hámster (especie no precisada)||
Hámster|R|Destete||19|28|días|M2c|Hámster (especie no precisada)||
Hámster|R|Consumo diario de agua||9|12|mL/día|M2c|Hámster (especie no precisada)||
Hámster|R|Temperatura ambiente recomendada||21|24|°C|M2c|Hámster (especie no precisada)||
Hámster|H|Hematocrito||41|52|%|M2|Hámster (especie no precisada)||
Hámster|H|Glóbulos rojos||5|9.2|10^6/µL|M2|Hámster (especie no precisada)||
Hámster|H|Hemoglobina||14.6|20|g/dL|M2|Hámster (especie no precisada)||
Hámster|H|Glóbulos blancos||3|11|10^3/µL|M2|Hámster (especie no precisada)||
Hámster|H|Neutrófilos||10|42|%|M2|Hámster (especie no precisada)||
Hámster|H|Linfocitos||50|95|%|M2|Hámster (especie no precisada)||
Hámster|H|Plaquetas||200|570|10^3/µL|M2|Hámster (especie no precisada)||
Hámster|B|Glucosa||65|73|mg/dL|M4|Hámster (especie no precisada)||
Hámster|B|Urea||42|60|mg/dL|M4|Hámster (especie no precisada)||
Hámster|B|Colesterol||182|237|mg/dL|M4|Hámster (especie no precisada)||
Hámster|B|Proteínas totales||6.4|7.3|g/dL|M4|Hámster (especie no precisada)||
Hámster|B|Albúmina||3.2|3.7|g/dL|M4|Hámster (especie no precisada)||
Hámster|B|Sodio||128|145|mEq/L|M4|Hámster (especie no precisada)||
Hámster|B|Potasio||4.9|5.1|mEq/L|M4|Hámster (especie no precisada)||
Hámster|B|Fósforo||5.3|6.6|mg/dL|M4|Hámster (especie no precisada)||
Hámster|B|Calcio||10.4|12.3|mg/dL|M4|Hámster (especie no precisada)||
Jerbo|F|Temperatura rectal||38.2|38.2|°C|M1|Jerbo del libro A|Jaculus jaculus (identificación de la p. 18)|
Jerbo|F|Frecuencia cardíaca||260|300|lpm|M1|Jerbo del libro A|Jaculus jaculus (identificación de la p. 18)|
Jerbo|F|Frecuencia respiratoria||85|160|resp/min|M1|Jerbo del libro A|Jaculus jaculus (identificación de la p. 18)|
Jerbo|F|Vida media||24|39|meses|M1|Jerbo del libro A|Jaculus jaculus (identificación de la p. 18)|
Jerbo|F|Peso adulto macho||46|131|g|M1|Jerbo del libro A|Jaculus jaculus (identificación de la p. 18)|
Jerbo|F|Peso adulto hembra||50|55|g|M1|Jerbo del libro A|Jaculus jaculus (identificación de la p. 18)|
Jerbo|R|Gestación||23|26|días|M2c|Jerbo del libro A|Jaculus jaculus (identificación de la p. 18)|
Jerbo|R|Tamaño de camada||3|8|crías|M2c|Jerbo del libro A|Jaculus jaculus (identificación de la p. 18)|
Jerbo|R|Peso al nacimiento||2.5|3.5|g|M2c|Jerbo del libro A|Jaculus jaculus (identificación de la p. 18)|
Jerbo|R|Apertura de ojos||16|21|días|M2c|Jerbo del libro A|Jaculus jaculus (identificación de la p. 18)|
Jerbo|R|Destete||21|28|días|M2c|Jerbo del libro A|Jaculus jaculus (identificación de la p. 18)|
Jerbo|R|Consumo diario de agua||4|4|mL/día|M2c|Jerbo del libro A|Jaculus jaculus (identificación de la p. 18)|
Jerbo|R|Temperatura ambiente recomendada||18|22|°C|M2c|Jerbo del libro A|Jaculus jaculus (identificación de la p. 18)|
Jerbo|H|Hematocrito||41|52|%|M2|Jerbo del libro A|Jaculus jaculus (identificación de la p. 18)|
Jerbo|H|Glóbulos rojos||7|10|10^6/µL|M2|Jerbo del libro A|Jaculus jaculus (identificación de la p. 18)|
Jerbo|H|Hemoglobina||12.1|16.9|g/dL|M2|Jerbo del libro A|Jaculus jaculus (identificación de la p. 18)|
Jerbo|H|Glóbulos blancos||4.3|21.6|10^3/µL|M2|Jerbo del libro A|Jaculus jaculus (identificación de la p. 18)|
Jerbo|H|Neutrófilos||5|34|%|M2|Jerbo del libro A|Jaculus jaculus (identificación de la p. 18)|
Jerbo|H|Linfocitos||60|95|%|M2|Jerbo del libro A|Jaculus jaculus (identificación de la p. 18)|
Jerbo|H|Plaquetas||400|600|10^3/µL|M2|Jerbo del libro A|Jaculus jaculus (identificación de la p. 18)|
Jerbo|B|Glucosa||47|137|mg/dL|M4|Jerbo del libro A|Jaculus jaculus (identificación de la p. 18)|
Jerbo|B|Urea||17|30|mg/dL|M4|Jerbo del libro A|Jaculus jaculus (identificación de la p. 18)|
Jerbo|B|Colesterol||90|141|mg/dL|M4|Jerbo del libro A|Jaculus jaculus (identificación de la p. 18)|
Jerbo|B|Proteínas totales||4.6|14.7|g/dL|M4|Jerbo del libro A|Jaculus jaculus (identificación de la p. 18)|
Jerbo|B|Albúmina||1.8|5.8|g/dL|M4|Jerbo del libro A|Jaculus jaculus (identificación de la p. 18)|
Jerbo|B|Sodio||143|147|mEq/L|M4|Jerbo del libro A|Jaculus jaculus (identificación de la p. 18)|
Jerbo|B|Potasio||3.6|5.9|mEq/L|M4|Jerbo del libro A|Jaculus jaculus (identificación de la p. 18)|
Jerbo|B|Fósforo||3.7|11.2|mg/dL|M4|Jerbo del libro A|Jaculus jaculus (identificación de la p. 18)|
Jerbo|B|Calcio||3.7|6.1|mg/dL|M4|Jerbo del libro A|Jaculus jaculus (identificación de la p. 18)|
''';

/// Modelos del módulo avícola de postura (M15).
///
/// Todo llega del RPC `avi_workspace`; el cliente no consulta tablas ni
/// escribe directamente. Los números son solo presentación: el servidor
/// conserva la decisión exacta y las referencias sin verificar.
library;

String aviDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String aviShortDate(DateTime? value) => value == null
    ? '—'
    : '${value.day.toString().padLeft(2, '0')}/'
          '${value.month.toString().padLeft(2, '0')}/${value.year}';

/// Número sin ceros sobrantes; los nulos se muestran como raya.
String aviNumber(num? value) {
  if (value == null) return '—';
  final d = value.toDouble();
  if (d == d.roundToDouble()) return d.toStringAsFixed(0);
  return d.toString();
}

String _text(dynamic value) => value == null ? '' : value.toString();
int _int(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(_text(value)) ?? 0;
int? _intOrNull(dynamic value) => value == null
    ? null
    : value is num
    ? value.toInt()
    : int.tryParse(_text(value));
double? _doubleOrNull(dynamic value) => value == null
    ? null
    : value is num
    ? value.toDouble()
    : double.tryParse(_text(value));
DateTime? _date(dynamic value) {
  final text = _text(value);
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

class AviReference {
  const AviReference({
    required this.id,
    required this.stage,
    required this.weekFrom,
    required this.weekTo,
    required this.system,
    required this.parameter,
    required this.min,
    required this.max,
    required this.unit,
    required this.source,
    required this.status,
  });

  final String id;
  final String stage;
  final int? weekFrom;
  final int? weekTo;
  final String system;
  final String parameter;
  final double? min;
  final double? max;
  final String unit;
  final String source;
  final String status;

  bool get pending => status == 'pendiente';
  bool get verified => status == 'verificada';

  String get weeks {
    if (weekFrom == null) return 'sin semana';
    return weekTo == null
        ? 'desde semana $weekFrom'
        : 'semanas $weekFrom–$weekTo';
  }

  String get range {
    if (min == null || max == null) return 'sin valor publicado';
    final suffix = unit.isEmpty ? '' : ' $unit';
    if (min == max) return '${aviNumber(min)}$suffix';
    return '${aviNumber(min)}–${aviNumber(max)}$suffix';
  }

  static AviReference read(Map<String, dynamic> value) => AviReference(
    id: _text(value['id']),
    stage: _text(value['stage']),
    weekFrom: _intOrNull(value['week_from']),
    weekTo: _intOrNull(value['week_to']),
    system: _text(value['system']),
    parameter: _text(value['parameter']),
    min: _doubleOrNull(value['min']),
    max: _doubleOrNull(value['max']),
    unit: _text(value['unit']),
    source: _text(value['source']),
    status: _text(value['status']),
  );
}

class AviEquipmentReference {
  const AviEquipmentReference({
    required this.id,
    required this.stage,
    required this.equipment,
    required this.birdsPerUnitMin,
    required this.birdsPerUnitMax,
    required this.note,
    required this.source,
    required this.status,
  });

  final String id;
  final String stage;
  final String equipment;
  final double? birdsPerUnitMin;
  final double? birdsPerUnitMax;
  final String note;
  final String source;
  final String status;

  String get range {
    if (birdsPerUnitMin == null || birdsPerUnitMax == null) {
      return 'sin valor publicado';
    }
    if (birdsPerUnitMin == birdsPerUnitMax) {
      return '${aviNumber(birdsPerUnitMin)} aves/unidad';
    }
    return '${aviNumber(birdsPerUnitMin)}–'
        '${aviNumber(birdsPerUnitMax)} aves/unidad';
  }

  static AviEquipmentReference read(Map<String, dynamic> value) =>
      AviEquipmentReference(
        id: _text(value['id']),
        stage: _text(value['stage']),
        equipment: _text(value['equipment']),
        birdsPerUnitMin: _doubleOrNull(value['birds_per_unit_min']),
        birdsPerUnitMax: _doubleOrNull(value['birds_per_unit_max']),
        note: _text(value['note']),
        source: _text(value['source']),
        status: _text(value['status']),
      );
}

class AviHouse {
  const AviHouse({
    required this.id,
    required this.name,
    required this.system,
    required this.capacity,
    required this.notes,
    required this.archived,
    required this.version,
  });

  final String id;
  final String name;
  final String system;
  final int capacity;
  final String notes;
  final bool archived;
  final int version;

  String get systemLabel =>
      system == 'jaula_bateria' ? 'Jaula / batería' : 'Piso';

  static AviHouse read(Map<String, dynamic> value) => AviHouse(
    id: _text(value['id']),
    name: _text(value['name']),
    system: _text(value['system']),
    capacity: _int(value['capacity']),
    notes: _text(value['notes']),
    archived: value['archived'] == true,
    version: _int(value['version']),
  );
}

class AviFlock {
  const AviFlock({
    required this.id,
    required this.code,
    required this.houseId,
    required this.house,
    required this.system,
    required this.geneticLine,
    required this.startDate,
    required this.status,
    required this.closedOn,
    required this.initialBirds,
    required this.version,
    required this.week,
    required this.birds,
    required this.mortalityTotal,
    required this.mortalityPct,
    required this.eggsTotal,
    required this.feedKgTotal,
    required this.records,
    required this.lastRecord,
    required this.lastEggs,
    required this.layingPct,
    required this.feedGBirdDay,
  });

  final String id;
  final String code;
  final String? houseId;
  final String house;
  final String system;
  final String geneticLine;
  final DateTime startDate;
  final String status;
  final DateTime? closedOn;
  final int initialBirds;
  final int version;
  final int week;
  final int birds;
  final int mortalityTotal;
  final double mortalityPct;
  final int eggsTotal;
  final double feedKgTotal;
  final int records;
  final DateTime? lastRecord;
  final int? lastEggs;
  final double? layingPct;
  final double? feedGBirdDay;

  bool get active => status == 'activa';

  static AviFlock read(Map<String, dynamic> value) => AviFlock(
    id: _text(value['id']),
    code: _text(value['code']),
    houseId: value['house_id'] == null ? null : _text(value['house_id']),
    house: _text(value['house']),
    system: _text(value['system']),
    geneticLine: _text(value['genetic_line']),
    startDate: _date(value['start_date']) ?? DateTime(2000),
    status: _text(value['status']),
    closedOn: _date(value['closed_on']),
    initialBirds: _int(value['initial_birds']),
    version: _int(value['version']),
    week: _int(value['week']),
    birds: _int(value['birds']),
    mortalityTotal: _int(value['mortality_total']),
    mortalityPct: _doubleOrNull(value['mortality_pct']) ?? 0,
    eggsTotal: _int(value['eggs_total']),
    feedKgTotal: _doubleOrNull(value['feed_kg_total']) ?? 0,
    records: _int(value['records']),
    lastRecord: _date(value['last_record']),
    lastEggs: _intOrNull(value['last_eggs']),
    layingPct: _doubleOrNull(value['laying_pct']),
    feedGBirdDay: _doubleOrNull(value['feed_g_bird_day']),
  );
}

class AviRecord {
  const AviRecord({
    required this.id,
    required this.flockId,
    required this.flock,
    required this.date,
    required this.eggs,
    required this.eggsDiscarded,
    required this.mortality,
    required this.feedKg,
    required this.avgWeightG,
    required this.waterL,
    required this.notes,
    required this.version,
  });

  final String id;
  final String flockId;
  final String flock;
  final DateTime date;
  final int eggs;
  final int eggsDiscarded;
  final int mortality;
  final double feedKg;
  final double? avgWeightG;
  final double? waterL;
  final String notes;
  final int version;

  static AviRecord read(Map<String, dynamic> value) => AviRecord(
    id: _text(value['id']),
    flockId: _text(value['flock_id']),
    flock: _text(value['flock']),
    date: _date(value['date']) ?? DateTime(2000),
    eggs: _int(value['eggs']),
    eggsDiscarded: _int(value['eggs_discarded']),
    mortality: _int(value['mortality']),
    feedKg: _doubleOrNull(value['feed_kg']) ?? 0,
    avgWeightG: _doubleOrNull(value['avg_weight_g']),
    waterL: _doubleOrNull(value['water_l']),
    notes: _text(value['notes']),
    version: _int(value['version']),
  );
}

class AviEvent {
  const AviEvent({
    required this.id,
    required this.flockId,
    required this.flock,
    required this.date,
    required this.kind,
    required this.title,
    required this.details,
    required this.withdrawalUntil,
    required this.version,
  });

  final String id;
  final String flockId;
  final String flock;
  final DateTime date;
  final String kind;
  final String title;
  final String details;
  final DateTime? withdrawalUntil;
  final int version;

  static const kinds = <String, String>{
    'vacunacion': 'Vacunación',
    'tratamiento': 'Tratamiento',
    'desparasitacion': 'Desparasitación',
    'pesaje': 'Pesaje',
    'alimentacion': 'Alimentación',
    'inspeccion': 'Inspección',
    'otro': 'Otro',
  };

  String get kindLabel => kinds[kind] ?? kind;

  static AviEvent read(Map<String, dynamic> value) => AviEvent(
    id: _text(value['id']),
    flockId: _text(value['flock_id']),
    flock: _text(value['flock']),
    date: _date(value['date']) ?? DateTime(2000),
    kind: _text(value['kind']),
    title: _text(value['title']),
    details: _text(value['details']),
    withdrawalUntil: _date(value['withdrawal_until']),
    version: _int(value['version']),
  );
}

class AviWorkspace {
  const AviWorkspace({
    required this.day,
    required this.timezone,
    required this.canWrite,
    required this.references,
    required this.equipment,
    required this.houses,
    required this.flocks,
    required this.records,
    required this.events,
  });

  final DateTime day;
  final String timezone;
  final bool canWrite;
  final List<AviReference> references;
  final List<AviEquipmentReference> equipment;
  final List<AviHouse> houses;
  final List<AviFlock> flocks;
  final List<AviRecord> records;
  final List<AviEvent> events;

  List<AviFlock> get activeFlocks =>
      flocks.where((flock) => flock.active).toList();

  static AviWorkspace read(Map<String, dynamic> value) {
    if (value['schema_version'] != 1) {
      throw const FormatException('Contrato avícola desconocido.');
    }
    List<T> list<T>(dynamic raw, T Function(Map<String, dynamic>) parse) {
      if (raw is! List) return <T>[];
      return raw
          .whereType<Map>()
          .map((row) => parse(Map<String, dynamic>.from(row)))
          .toList();
    }

    return AviWorkspace(
      day: _date(value['day']) ?? DateTime(2000),
      timezone: _text(value['timezone']),
      canWrite: value['can_write'] == true,
      references: list(value['references'], AviReference.read),
      equipment: list(value['equipment'], AviEquipmentReference.read),
      houses: list(value['houses'], AviHouse.read),
      flocks: list(value['flocks'], AviFlock.read),
      records: list(value['records'], AviRecord.read),
      events: list(value['events'], AviEvent.read),
    );
  }
}

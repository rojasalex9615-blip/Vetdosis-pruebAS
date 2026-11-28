import 'aviculture_records.dart';

class PoultryFarm {
  const PoultryFarm({
    required this.id,
    required this.name,
    this.identifier = '',
    this.location = '',
    this.notes = '',
    this.archived = false,
    this.version = 1,
  });
  final String id, name, identifier, location, notes;
  final bool archived;
  final int version;
  factory PoultryFarm.read(Map<String, dynamic> r) => PoultryFarm(
    id: r['id'] as String,
    name: r['name'] as String,
    identifier: r['identifier'] as String? ?? '',
    location: r['location'] as String? ?? '',
    notes: r['notes'] as String? ?? '',
    archived: r['archived'] == true,
    version: r['version'] as int,
  );
}

class PoultryHealthEvent {
  PoultryHealthEvent(this.data);
  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  String get houseId => data['house_id'] as String;
  String? get flockId => data['flock_id'] as String?;
  String get kind => data['kind'] as String;
  DateTime get date => DateTime.parse(data['occurred_on'] as String);
  String get title =>
      kind == 'enfermedad' ? '${data['diagnosis']}' : '${data['product']}';
  String get label =>
      {
        'vacunacion': 'Vacunación',
        'medicacion': 'Medicación',
        'enfermedad': 'Enfermedad',
      }[kind] ??
      kind;
}

class PoultryFarmWorkspace {
  const PoultryFarmWorkspace({
    required this.records,
    required this.farms,
    required this.houseFarmIds,
    required this.health,
    required this.canManage,
  });
  final AviWorkspace records;
  final List<PoultryFarm> farms;
  final Map<String, String?> houseFarmIds;
  final List<PoultryHealthEvent> health;
  final bool canManage;
  factory PoultryFarmWorkspace.read(Map<String, dynamic> r, String clinicId) {
    if (r['schema_version'] != 1 || r['clinic_id'] != clinicId) {
      throw const FormatException(
        'Respuesta de otra clínica o contrato desconocido.',
      );
    }
    final farms = (r['farms'] as List).map((e) {
      final row = Map<String, dynamic>.from(e as Map);
      if (row['clinic_id'] != clinicId) {
        throw const FormatException('Granja de otra clínica.');
      }
      return PoultryFarm.read(row);
    }).toList();
    if ((r['records'] as Map)['clinic_id'] != clinicId ||
        (r['records'] as Map)['day'] is! String ||
        DateTime.tryParse((r['records'] as Map)['day'] as String) == null) {
      throw const FormatException('Registros de otra clínica.');
    }
    final records = AviWorkspace.read(
      Map<String, dynamic>.from(r['records'] as Map),
    );
    final houses = records.houses.map((h) => h.id).toSet(),
        ids = farms.map((f) => f.id).toSet();
    if (ids.length != farms.length ||
        ids.contains('') ||
        houses.length != records.houses.length ||
        houses.contains('')) {
      throw const FormatException(
        'Identificadores avícolas repetidos o incompletos.',
      );
    }
    final mappings = <String, String?>{};
    for (final e in r['house_farms'] as List) {
      final id = e['house_id'] as String, farm = e['farm_id'] as String?;
      if (!houses.contains(id) ||
          (farm != null && !ids.contains(farm)) ||
          mappings.containsKey(id)) {
        throw const FormatException('Caseta fuera de granja.');
      }
      mappings[id] = farm;
    }
    if (mappings.length != houses.length) {
      throw const FormatException('Falta la relación de una caseta.');
    }
    final eventIds = <String>{};
    final health = (r['health'] as List).map((e) {
      final row = Map<String, dynamic>.from(e as Map);
      if (row['clinic_id'] != clinicId ||
          !houses.contains(row['house_id']) ||
          row['farm_id'] == null ||
          !ids.contains(row['farm_id']) ||
          mappings[row['house_id']] != row['farm_id']) {
        throw const FormatException('Registro sanitario fuera de su granja.');
      }
      final flock = row['flock_id'];
      if (flock != null &&
          !records.flocks.any(
            (f) => f.id == flock && f.houseId == row['house_id'],
          )) {
        throw const FormatException('Parvada de otra caseta.');
      }
      final id = row['id'] as String;
      if (id.isEmpty ||
          !eventIds.add(id) ||
          !['vacunacion', 'medicacion', 'enfermedad'].contains(row['kind'])) {
        throw const FormatException(
          'Registro sanitario incompleto o repetido.',
        );
      }
      final date = row['occurred_on'] as String;
      if (DateTime.tryParse(date) == null ||
          aviDate(DateTime.parse(date)) != date) {
        throw const FormatException('Fecha sanitaria inválida.');
      }
      return PoultryHealthEvent(row);
    }).toList();
    return PoultryFarmWorkspace(
      records: records,
      farms: farms,
      houseFarmIds: mappings,
      health: health,
      canManage: r['can_manage'] == true,
    );
  }
}

abstract class PoultryFarmRepository {
  Future<PoultryFarmWorkspace> load(String clinicId);
  Future<String> saveFarm(
    String clinicId,
    Map<String, dynamic> data, {
    String? id,
    int? version,
    required String operation,
  });
  Future<String> saveHouse(
    String clinicId,
    String farmId,
    Map<String, dynamic> data, {
    String? id,
    int? version,
    required String operation,
  });
  Future<String> saveFlock(
    String clinicId,
    Map<String, dynamic> data, {
    required String operation,
  });
  Future<String> saveHealth(
    String clinicId,
    Map<String, dynamic> data, {
    required String operation,
  });
}

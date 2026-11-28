import 'poultry_farm.dart';
import 'aviculture_records.dart';

class PoultrySchedule {
  PoultrySchedule(this.data);
  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  String get houseId => data['house_id'] as String;
  String? get flockId => data['flock_id'] as String?;
  String get title => data['title'] as String;
  String get status => data['status'] as String;
  DateTime get date => DateTime.parse(data['due_on'] as String);
  int get daysBefore => data['days_before'] as int;
  int get version => data['version'] as int;
  // Calendar dates are compared as day components, independent of DST/timezone.
  DateTime _day(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);
  bool warnsOn(DateTime today) =>
      status == 'pendiente' &&
      !_day(
        today,
      ).isBefore(DateTime.utc(date.year, date.month, date.day - daysBefore));
  bool overdueOn(DateTime today) =>
      status == 'pendiente' && _day(today).isAfter(_day(date));
  static List<PoultrySchedule> read(
    Map<String, dynamic> r,
    String clinic,
    PoultryFarmWorkspace workspace,
  ) {
    if (r['schema_version'] != 1 || r['clinic_id'] != clinic) {
      throw const FormatException(
        'Calendario de otra área o versión desconocida.',
      );
    }
    final ids = <String>{};
    return (r['items'] as List).map((e) {
      final row = Map<String, dynamic>.from(e as Map);
      final item = PoultrySchedule(row);
      if (row['clinic_id'] != clinic ||
          item.id.isEmpty ||
          !ids.add(item.id) ||
          workspace.houseFarmIds[item.houseId] != row['farm_id'] ||
          row['farm_id'] == null ||
          !workspace.records.houses.any((h) => h.id == item.houseId)) {
        throw const FormatException('Calendario fuera de su caseta.');
      }
      if (item.flockId != null &&
          !workspace.records.flocks.any(
            (f) => f.id == item.flockId && f.houseId == item.houseId,
          )) {
        throw const FormatException('Parvada fuera de caseta.');
      }
      if (aviDate(item.date) != row['due_on'] ||
          item.daysBefore < 0 ||
          item.daysBefore > 90 ||
          !['pendiente', 'completada', 'cancelada'].contains(item.status) ||
          !['vacunacion', 'medicacion', 'seguimiento'].contains(row['kind']) ||
          item.title.trim().isEmpty ||
          item.version < 1) {
        throw const FormatException('Calendario incompleto.');
      }
      return item;
    }).toList();
  }
}

abstract class PoultryScheduleRepository {
  Future<Map<String, dynamic>> calendar(String clinic);
  Future<String> saveScheduled(
    String clinic,
    Map<String, dynamic> data, {
    String? id,
    int? version,
    required String operation,
  });
}

/// Mi espacio personal: datos de la persona, no de una clinica.
///
/// Las notas, recordatorios y horarios solo los ve su dueño (RLS por
/// auth.uid() en 16A_espacio_personal.sql). La ficha de emergencia vive por
/// clinica en staff_medical y se abre desde aqui.
class PersonalNote {
  const PersonalNote({
    this.id,
    required this.title,
    this.body = '',
    this.reminder = false,
    this.remindAt,
    this.done = false,
  });
  final String? id;
  final String title;
  final String body;
  final bool reminder;
  final DateTime? remindAt;
  final bool done;

  factory PersonalNote.fromRow(Map<String, dynamic> row) => PersonalNote(
    id: row['id'] as String,
    title: row['title'] as String,
    body: row['body'] as String? ?? '',
    reminder: row['kind'] == 'reminder',
    remindAt: row['remind_at'] == null
        ? null
        : DateTime.parse(row['remind_at'] as String).toLocal(),
    done: row['done'] as bool? ?? false,
  );

  Map<String, dynamic> toRow() => {
    'kind': reminder ? 'reminder' : 'note',
    'title': title.trim(),
    'body': body.trim(),
    'remind_at': reminder ? remindAt?.toUtc().toIso8601String() : null,
    'done': done,
  };

  PersonalNote copyWith({bool? done}) => PersonalNote(
    id: id,
    title: title,
    body: body,
    reminder: reminder,
    remindAt: remindAt,
    done: done ?? this.done,
  );
}

const weekdayLabels = {
  1: 'Lunes',
  2: 'Martes',
  3: 'Miércoles',
  4: 'Jueves',
  5: 'Viernes',
  6: 'Sábado',
  7: 'Domingo',
};

/// Un bloque de horario semanal en un lugar de trabajo.
class WorkSchedule {
  const WorkSchedule({
    this.id,
    required this.place,
    this.clinicId,
    required this.weekday,
    required this.startMinutes,
    required this.endMinutes,
    this.note = '',
  });
  final String? id;
  final String place;
  final String? clinicId;
  final int weekday;
  final int startMinutes;
  final int endMinutes;
  final String note;

  /// Una guardia que termina antes de empezar cruza la medianoche.
  bool get overnight => endMinutes < startMinutes;

  static int _minutes(String value) {
    final parts = value.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  static String clock(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  factory WorkSchedule.fromRow(Map<String, dynamic> row) => WorkSchedule(
    id: row['id'] as String,
    place: row['place'] as String,
    clinicId: row['linked_clinic_id'] as String?,
    weekday: (row['weekday'] as num).toInt(),
    startMinutes: _minutes(row['starts_at'] as String),
    endMinutes: _minutes(row['ends_at'] as String),
    note: row['note'] as String? ?? '',
  );

  Map<String, dynamic> toRow() => {
    'place': place.trim(),
    'linked_clinic_id': clinicId,
    'weekday': weekday,
    'starts_at': clock(startMinutes),
    'ends_at': clock(endMinutes),
    'note': note.trim(),
  };

  String get range =>
      '${clock(startMinutes)}–${clock(endMinutes)}${overnight ? ' (día siguiente)' : ''}';
}

abstract interface class PersonalSpaceRepository {
  Future<List<PersonalNote>> notes();
  Future<void> saveNote(PersonalNote note);
  Future<void> deleteNote(String id);
  Future<List<WorkSchedule>> schedules();
  Future<void> saveSchedule(WorkSchedule schedule);
  Future<void> deleteSchedule(String id);
}

/// Una persona puede tener la misma clinica en varios bloques; se ordena por
/// dia y hora para leer la semana de corrido.
List<WorkSchedule> sortedWeek(Iterable<WorkSchedule> items) =>
    items.toList()..sort(
      (a, b) => a.weekday != b.weekday
          ? a.weekday.compareTo(b.weekday)
          : a.startMinutes.compareTo(b.startMinutes),
    );

/// Recordatorios pendientes primero, por fecha; los hechos al final.
List<PersonalNote> sortedReminders(Iterable<PersonalNote> items) =>
    items.where((n) => n.reminder).toList()..sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      final at = a.remindAt, bt = b.remindAt;
      if (at == null || bt == null) return at == null ? 1 : -1;
      return at.compareTo(bt);
    });

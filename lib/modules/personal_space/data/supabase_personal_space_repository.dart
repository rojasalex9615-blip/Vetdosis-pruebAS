import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/personal_space.dart';

/// Tablas de 16A_espacio_personal.sql. La RLS limita cada fila a su dueño;
/// el cliente no envia user_id: lo pone el servidor con auth.uid().
class SupabasePersonalSpaceRepository implements PersonalSpaceRepository {
  SupabasePersonalSpaceRepository(this.client);
  final SupabaseClient client;

  @override
  Future<List<PersonalNote>> notes() async {
    final rows = await client
        .from('personal_notes')
        .select('id,kind,title,body,remind_at,done')
        .order('updated_at', ascending: false)
        .limit(500);
    return rows.map(PersonalNote.fromRow).toList();
  }

  @override
  Future<void> saveNote(PersonalNote note) async {
    final row = note.toRow();
    if (note.id == null) {
      await client.from('personal_notes').insert(row);
    } else {
      await client
          .from('personal_notes')
          .update({
            ...row,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', note.id!);
    }
  }

  @override
  Future<void> deleteNote(String id) =>
      client.from('personal_notes').delete().eq('id', id);

  @override
  Future<List<WorkSchedule>> schedules() async {
    final rows = await client
        .from('personal_work_schedules')
        .select('id,place,linked_clinic_id,weekday,starts_at,ends_at,note')
        .limit(200);
    return sortedWeek(rows.map(WorkSchedule.fromRow));
  }

  @override
  Future<void> saveSchedule(WorkSchedule schedule) async {
    if (schedule.id == null) {
      await client.from('personal_work_schedules').insert(schedule.toRow());
    } else {
      await client
          .from('personal_work_schedules')
          .update(schedule.toRow())
          .eq('id', schedule.id!);
    }
  }

  @override
  Future<void> deleteSchedule(String id) =>
      client.from('personal_work_schedules').delete().eq('id', id);
}

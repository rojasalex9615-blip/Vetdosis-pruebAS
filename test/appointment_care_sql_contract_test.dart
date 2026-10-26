import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Guards the reviewed, undeployed SQL candidate against a regression where
/// non-consultation appointments without an expediente cannot complete care.
void main() {
  test('care snapshot allows non-consultation without patient and guards consults', () {
    final sql = File('supabase/adaptations/appointment_care_v1.sql')
        .readAsStringSync();
    expect(
      sql,
      contains(
        "'can_close',can_manage and (a.patient_id is null or can_patient) "
        "and (a.kind<>'consulta' or (can_clinical and a.patient_id is not null))",
      ),
    );
    expect(
      sql,
      contains("if p_action='ready' and a.kind='consulta' then"),
    );
    expect(
      sql,
      contains("if a.patient_id is null then raise exception 'care_patient_required'"),
    );
  });
}

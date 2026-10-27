import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vetdosis_pro/modules/hospital/application/hospital_push_service.dart';

void main() {
  test(
    'a revoked clinic does not block another clinic and only its enrollment is removed',
    () async {
      final calls = <String>[];
      final discarded = <String>[];
      final result = await refreshHospitalClinics(
        clinics: ['revoked', 'active'],
        isCurrent: () => true,
        register: (clinic) async {
          calls.add(clinic);
          if (clinic == 'revoked') {
            throw const PostgrestException(
              message: 'current_hospital_recipient_required',
            );
          }
        },
        discard: (clinic) async {
          discarded.add(clinic);
        },
      );
      expect(calls, ['revoked', 'active']);
      expect(discarded, ['revoked']);
      expect(result, false);
    },
  );

  test(
    'transient failure keeps enrollment for retry while other clinics refresh',
    () async {
      final calls = <String>[];
      final result = await refreshHospitalClinics(
        clinics: ['offline', 'active'],
        isCurrent: () => true,
        register: (clinic) async {
          calls.add(clinic);
          if (clinic == 'offline') throw StateError('network');
        },
        discard: (_) async {
          fail('Transient failures must keep consent');
        },
      );
      expect(calls, ['offline', 'active']);
      expect(result, false);
    },
  );

  test(
    'session change during a request prevents subsequent clinic operations',
    () async {
      var current = true;
      final calls = <String>[];
      expect(
        await refreshHospitalClinics(
          clinics: ['first', 'second'],
          isCurrent: () => current,
          register: (clinic) async {
            calls.add(clinic);
            current = false;
          },
          discard: (_) async {
            fail('Must not discard after session change');
          },
        ),
        false,
      );
      expect(calls, ['first']);
    },
  );

  test('cleanup failure still allows renewal in remaining clinics', () async {
    final calls = <String>[];
    expect(
      await refreshHospitalClinics(
        clinics: ['revoked', 'active'],
        isCurrent: () => true,
        register: (clinic) async {
          calls.add(clinic);
          if (clinic == 'revoked') {
            throw const PostgrestException(
              message: 'current_hospital_recipient_required',
            );
          }
        },
        discard: (_) async {
          throw StateError('storage unavailable');
        },
      ),
      false,
    );
    expect(calls, ['revoked', 'active']);
  });

  test('all clinics refreshed permits marking the token current', () async {
    expect(
      await refreshHospitalClinics(
        clinics: ['a', 'b'],
        isCurrent: () => true,
        register: (_) async {},
        discard: (_) async {
          fail('No revocation');
        },
      ),
      true,
    );
  });
}

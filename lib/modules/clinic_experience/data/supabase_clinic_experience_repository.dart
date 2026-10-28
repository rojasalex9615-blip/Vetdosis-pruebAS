import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/clinic_experience.dart';
import '../domain/clinic_experience_repository.dart';

class SupabaseClinicExperienceRepository implements ClinicExperienceRepository {
  const SupabaseClinicExperienceRepository(this.client);
  final SupabaseClient client;

  @override
  Future<ClinicExperience> read(String clinicId) async {
    final data = await client.rpc(
      'clinic_experience_read', params: {'p_clinic': clinicId},
    );
    if (data is! Map) {
      throw const FormatException('Respuesta de configuración inválida.');
    }
    return ClinicExperience.fromServer(Map<String, dynamic>.from(data));
  }

  @override
  Future<ClinicExperience> save(String clinicId, ClinicExperience value) async {
    final data = await client.rpc('clinic_experience_save', params: {
      'p_clinic': clinicId,
      'p_expected_revision': value.revision,
      'p_settings': value.toJson(),
    });
    if (data is! Map) {
      throw const FormatException('Respuesta de guardado inválida.');
    }
    return ClinicExperience.fromServer(Map<String, dynamic>.from(data));
  }
}

import 'clinic_experience.dart';

abstract interface class ClinicExperienceRepository {
  Future<ClinicExperience> read(String clinicId);
  /// Optimistic revision protects concurrent changes by two administrators.
  Future<ClinicExperience> save(String clinicId, ClinicExperience value);
}

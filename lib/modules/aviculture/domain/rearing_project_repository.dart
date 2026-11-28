import 'pullet_rearing.dart';

class RearingProject {
  const RearingProject({
    required this.id,
    required this.updatedAt,
    required this.plan,
  });
  final String id;
  final DateTime updatedAt;
  final PulletRearingPlan plan;
}

/// Proyectos locales privados por cuenta y clínica; incluye la versión de guía.
abstract class RearingProjectRepository {
  Future<List<RearingProject>> list(String userId, String clinicId);
  Future<void> save(String userId, String clinicId, RearingProject project);
  Future<void> restoreCopies(
    String userId,
    String clinicId,
    List<RearingProject> projects,
  );
  Future<void> remove(String userId, String clinicId, String id);
}

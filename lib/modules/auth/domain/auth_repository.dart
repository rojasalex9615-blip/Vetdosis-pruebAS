import 'clinic_membership.dart';

abstract interface class AuthRepository {
  String? get userId;
  Stream<void> get changes;
  Future<void> signIn(String email, String password);
  Future<void> register(String email, String password, {String? referral});
  Future<void> googleSignIn();
  Future<void> signOut();
  Future<List<ClinicMembership>> memberships();
  Future<void> createClinic(String name);
  Future<void> joinClinic(String token);
  Future<String> invite(String clinicId, String email, ClinicRole role);
}

abstract interface class PersonalWorkspaceRepository {
  Future<void> createPersonalWorkspace();
}

abstract interface class PasswordRecoveryRepository {
  bool get recoveringPassword;
  Future<void> requestPasswordRecovery(String email);
  Future<void> completePasswordRecovery(String password);
}

abstract interface class TeamRepository {
  bool get teamManagementAvailable;

  /// null means the explicit capability endpoint is not installed yet.
  Future<bool?> canManageWorkspace(String clinicId);
  Future<Map<String, dynamic>> team(String clinicId);
  Future<void> setMemberRole(String clinicId, String userId, ClinicRole role);
  Future<void> removeMember(String clinicId, String userId);
  Future<void> revokeInvitation(String invitationId);
}

abstract interface class TeamDutyRepository {
  /// Loads visible shifts, absences, coverage, and editing permissions.
  Future<Map<String, dynamic>> dutyWorkspace(String clinic);

  /// Saves a shift or absence, optionally replacing the entry in `replaces_id`.
  ///
  /// [data] uses calendar dates, minutes since midnight, and an IANA time zone.
  /// Reuse [operation] for an identical retry. Server errors propagate.
  Future<void> saveDuty(
    String clinic,
    String user,
    Map<String, dynamic> data,
    String operation,
  );

  /// Records cancellation with a reason while preserving the original entry.
  ///
  /// Reuse [operation] for an identical retry. Server errors propagate.
  Future<void> cancelDuty(
    String clinic,
    String entry,
    String reason,
    String operation,
  );
}

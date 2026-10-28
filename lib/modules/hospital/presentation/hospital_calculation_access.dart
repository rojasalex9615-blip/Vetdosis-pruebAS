import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../auth/domain/clinic_membership.dart';
import '../../auth/presentation/auth_view_model.dart';
import '../../core/domain/module_access.dart';
import '../../core/domain/navigation_access.dart';

/// Access for one patient/weight flow. A refresh counter is not an identity.
/// Module grants are re-read while this route is alive and before calculation.
class HospitalCalculationAccess extends ChangeNotifier {
  HospitalCalculationAccess({
    required this.auth,
    required this.member,
    required ModuleAccess? initialAccess,
    this.repository,
  }) : _access =
           initialAccess ?? (repository == null ? null : ModuleAccess.denied),
       _revision = auth.accessRevision {
    auth.addListener(_authChanged);
    unawaited(revalidate());
  }
  final AuthViewModel auth;
  final ClinicMembership member;
  final ModuleAccessRepository? repository;
  ModuleAccess? _access;
  int _revision, _generation = 0;
  bool _disposed = false;

  bool get _sameSession =>
      !_disposed &&
      auth.signedIn &&
      !auth.offline &&
      auth.repository.userId == member.userId &&
      auth.active?.userId == member.userId &&
      auth.active?.clinicId == member.clinicId &&
      auth.active?.role == member.role;

  bool get current =>
      _sameSession &&
      navigationAllowed('Hospitalización', member, _access) &&
      navigationAllowed('Cálculo rápido', member, _access);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _authChanged() {
    if (_revision != auth.accessRevision) {
      _revision = auth.accessRevision;
      unawaited(revalidate());
    }
    // Identity, offline and role changes invalidate immediately, without waiting
    // for an RPC. Successful same-context refreshes preserve the selection.
    _notify();
  }

  Future<bool> revalidate() async {
    final request = ++_generation;
    if (!_sameSession) {
      _notify();
      return false;
    }
    final source = repository;
    if (source == null) return current; // Existing nonconfigured/legacy mode.
    try {
      final next = ModuleAccess.read(await source.workspace(member.clinicId));
      if (!_sameSession || request != _generation) return false;
      _access = next;
      _notify();
      return current;
    } catch (_) {
      if (!_disposed && request == _generation) {
        _access = ModuleAccess.denied;
        _notify();
      }
      return false;
    }
  }

  @override
  void dispose() {
    auth.removeListener(_authChanged);
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

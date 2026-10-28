import 'dart:async';

import 'package:flutter/widgets.dart';

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
  Completer<bool>? _pending;

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

  Future<bool> revalidate() {
    if (_disposed) return Future.value(false);
    // Callers waiting for a refresh share the newest result. A superseded RPC
    // may finish later (or never); it cannot deny or restore the current flow.
    final pending = _pending ??= Completer<bool>();
    unawaited(_revalidate(++_generation, pending));
    return pending.future;
  }

  void _complete(Completer<bool> pending, bool result) {
    if (identical(_pending, pending)) _pending = null;
    if (!pending.isCompleted) pending.complete(result);
  }

  Future<void> _revalidate(int request, Completer<bool> pending) async {
    if (!_sameSession) {
      _complete(pending, false);
      _notify();
      return;
    }
    final source = repository;
    if (source == null) {
      _complete(pending, current);
      return;
    }
    try {
      final next = ModuleAccess.read(await source.workspace(member.clinicId));
      if (request != _generation || _disposed) return;
      if (!_sameSession) {
        _complete(pending, false);
        return;
      }
      _access = next;
      _complete(pending, current);
      _notify();
    } catch (_) {
      if (!_disposed && request == _generation) {
        _access = ModuleAccess.denied;
        _complete(pending, false);
        _notify();
      }
    }
  }

  @override
  void dispose() {
    auth.removeListener(_authChanged);
    _disposed = true;
    _generation++;
    final pending = _pending;
    if (pending != null) _complete(pending, false);
    super.dispose();
  }
}

/// Owns access for the actual route lifetime, including exit animations and
/// replacement of the Navigator after an authentication-context change.
class HospitalCalculationAccessScope extends StatefulWidget {
  const HospitalCalculationAccessScope({
    super.key,
    required this.auth,
    required this.member,
    required this.initialAccess,
    required this.repository,
    required this.builder,
  });
  final AuthViewModel auth;
  final ClinicMembership member;
  final ModuleAccess? initialAccess;
  final ModuleAccessRepository? repository;
  final Widget Function(BuildContext, HospitalCalculationAccess) builder;

  @override
  State<HospitalCalculationAccessScope> createState() =>
      _HospitalCalculationAccessScopeState();
}

class _HospitalCalculationAccessScopeState
    extends State<HospitalCalculationAccessScope> {
  late final HospitalCalculationAccess access;

  @override
  void initState() {
    super.initState();
    access = HospitalCalculationAccess(
      auth: widget.auth,
      member: widget.member,
      initialAccess: widget.initialAccess,
      repository: widget.repository,
    );
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, access);

  @override
  void dispose() {
    access.dispose();
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import '../../auth/domain/clinic_membership.dart';
import '../domain/clinic_experience.dart';
import '../domain/clinic_experience_repository.dart';

/// Loads clinic-scoped presentation preferences without caching across users.
/// Missing backend keeps the legacy menu visible, never granting permissions.
class ClinicExperienceBoundary extends StatefulWidget {
  const ClinicExperienceBoundary({
    super.key,
    required this.member,
    required this.repository,
    required this.revision,
    required this.builder,
  });
  final ClinicMembership? member;
  final ClinicExperienceRepository? repository;
  final int revision;
  final Widget Function(
    ClinicExperience preferences,
    bool ready,
    Future<void> Function() reload,
  ) builder;

  @override
  State<ClinicExperienceBoundary> createState() => _ClinicExperienceBoundaryState();
}

class _ClinicExperienceBoundaryState extends State<ClinicExperienceBoundary> {
  ClinicExperience settings = ClinicExperience.defaults();
  bool ready = false;
  int generation = 0;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void didUpdateWidget(covariant ClinicExperienceBoundary oldWidget) {
    super.didUpdateWidget(oldWidget);
    final identityChanged =
        oldWidget.member?.userId != widget.member?.userId ||
        oldWidget.member?.clinicId != widget.member?.clinicId ||
        oldWidget.repository != widget.repository;
    if (identityChanged) {
      // Never share preferences across sessions or clinic switches.
      settings = ClinicExperience.defaults();
      ready = false;
      reload();
    } else if (oldWidget.revision != widget.revision) {
      // A periodic permissions refresh does not invalidate an already loaded
      // display preference. Authorization is checked separately.
      reload(preserveOnFailure: true);
    }
  }

  Future<void> reload({bool preserveOnFailure = false, bool reportFailure = false}) async {
    final ticket = ++generation;
    final member = widget.member;
    final repo = widget.repository;
    if (member == null || repo == null) {
      if (mounted) {
        setState(() {
          settings = ClinicExperience.defaults();
          ready = false;
        });
      }
      return;
    }
    try {
      final next = await repo.read(member.clinicId);
      if (mounted && ticket == generation &&
          widget.member?.userId == member.userId &&
          widget.member?.clinicId == member.clinicId) {
        setState(() { settings = next; ready = true; });
      }
    } catch (_) {
      if (mounted && ticket == generation && !preserveOnFailure) {
        setState(() {
          settings = ClinicExperience.defaults();
          ready = false;
        });
      }
      if (reportFailure) rethrow;
    }
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(settings, ready, () => reload(preserveOnFailure: true, reportFailure: true));
}

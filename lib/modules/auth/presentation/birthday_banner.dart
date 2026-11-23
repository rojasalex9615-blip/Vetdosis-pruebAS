import 'package:flutter/material.dart';
import '../domain/personal_profile.dart';
import '../domain/personal_profile_repository.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_icons.dart';

/// Saludo de cumpleaños en el Inicio: felicita al homenajeado y avisa de los
/// cumpleaños del equipo de hoy. No muestra nada si no hay nada que contar.
class BirthdayBanner extends StatefulWidget {
  const BirthdayBanner({
    super.key,
    required this.repository,
    required this.userId,
    this.clinicId,
  });

  final PersonalProfileRepository repository;
  final String userId;

  /// null en el área personal: no hay equipo que consultar.
  final String? clinicId;

  @override
  State<BirthdayBanner> createState() => _BirthdayBannerState();
}

class _BirthdayBannerState extends State<BirthdayBanner> {
  PersonalProfile? me;
  List<PersonalProfile> team = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    PersonalProfile? mine;
    List<PersonalProfile> others = const [];
    try {
      mine = await widget.repository.read(widget.userId);
      final clinic = widget.clinicId;
      if (clinic != null) {
        others = await widget.repository.teamProfiles(clinic);
      }
    } catch (_) {
      return;
    }
    if (!mounted) return;
    setState(() {
      me = mine;
      team = others;
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final mine = me;
    final name = mine?.displayName ?? '';
    if (mine != null && mine.celebratesOn(today)) {
      return _banner(
        context,
        icon: VetIcons.calendarCheck,
        title: name.isEmpty
            ? '¡Feliz cumpleaños!'
            : '¡Feliz cumpleaños, $name!',
        subtitle: 'Hoy es tu día. Que lo disfrutes.',
      );
    }
    final others = [
      for (final profile in birthdaysOn(team, today))
        if (profile.userId != widget.userId)
          profile.displayName.isEmpty ? 'un compañero' : profile.displayName,
    ];
    if (others.isNotEmpty) {
      return _banner(
        context,
        icon: VetIcons.calendar,
        title: others.length == 1
            ? 'Hoy cumple ${others.first}'
            : 'Hoy cumplen ${others.join(', ')}',
        subtitle: 'Felicítalo desde Perfiles del equipo.',
      );
    }
    final next = upcomingBirthdays(
      [
        ?mine,
        for (final profile in team)
          if (profile.userId != widget.userId) profile,
      ],
      today: today,
      days: 7,
    );
    if (next.isEmpty) return const SizedBox.shrink();
    final upcoming = next.first;
    final born = upcoming.birthday!;
    final when =
        '${born.day.toString().padLeft(2, '0')}/'
        '${born.month.toString().padLeft(2, '0')}';
    return _banner(
      context,
      icon: VetIcons.calendar,
      title:
          'Próximo cumpleaños: '
          '${upcoming.displayName.isEmpty ? 'un compañero' : upcoming.displayName}',
      subtitle: 'El $when.',
    );
  }

  Widget _banner(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) => VetCard(
    child: Row(
      children: [
        Icon(icon, size: 26),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    ),
  );
}

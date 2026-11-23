/// Datos personales del miembro y qué campos puede ver el resto del equipo.
///
/// Alergias y tipo de sangre se ocultan por defecto porque son datos de salud;
/// la foto se muestra por defecto. El nombre y el cumpleaños se usan para el
/// saludo y el calendario del equipo, así que siempre se comparten.
class PersonalProfile {
  const PersonalProfile({
    required this.userId,
    this.displayName = '',
    this.birthday,
    this.phone = '',
    this.email = '',
    this.allergies = '',
    this.bloodType = '',
    this.photoUrl,
    this.showPhone = false,
    this.showEmail = false,
    this.showAllergies = false,
    this.showBloodType = false,
    this.showPhoto = true,
    this.revision = 0,
  });

  final String userId;
  final String displayName;
  final DateTime? birthday;
  final String phone;
  final String email;
  final String allergies;
  final String bloodType;
  final String? photoUrl;
  final bool showPhone;
  final bool showEmail;
  final bool showAllergies;
  final bool showBloodType;
  final bool showPhoto;
  final int revision;

  static const empty = PersonalProfile(userId: '');

  /// Copia que se entrega al resto del equipo: solo los campos autorizados.
  PersonalProfile visibleToTeam() => PersonalProfile(
    userId: userId,
    displayName: displayName,
    birthday: birthday,
    phone: showPhone ? phone : '',
    email: showEmail ? email : '',
    allergies: showAllergies ? allergies : '',
    bloodType: showBloodType ? bloodType : '',
    photoUrl: showPhoto ? photoUrl : null,
    showPhone: showPhone,
    showEmail: showEmail,
    showAllergies: showAllergies,
    showBloodType: showBloodType,
    showPhoto: showPhoto,
    revision: revision,
  );

  PersonalProfile copy({
    String? displayName,
    DateTime? birthday,
    bool clearBirthday = false,
    String? phone,
    String? email,
    String? allergies,
    String? bloodType,
    String? photoUrl,
    bool clearPhoto = false,
    bool? showPhone,
    bool? showEmail,
    bool? showAllergies,
    bool? showBloodType,
    bool? showPhoto,
    int? revision,
  }) => PersonalProfile(
    userId: userId,
    displayName: displayName ?? this.displayName,
    birthday: clearBirthday ? null : birthday ?? this.birthday,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    allergies: allergies ?? this.allergies,
    bloodType: bloodType ?? this.bloodType,
    photoUrl: clearPhoto ? null : photoUrl ?? this.photoUrl,
    showPhone: showPhone ?? this.showPhone,
    showEmail: showEmail ?? this.showEmail,
    showAllergies: showAllergies ?? this.showAllergies,
    showBloodType: showBloodType ?? this.showBloodType,
    showPhoto: showPhoto ?? this.showPhoto,
    revision: revision ?? this.revision,
  );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'display_name': displayName,
    'birthday': birthday == null
        ? null
        : '${birthday!.year.toString().padLeft(4, '0')}-'
              '${birthday!.month.toString().padLeft(2, '0')}-'
              '${birthday!.day.toString().padLeft(2, '0')}',
    'phone': phone,
    'email': email,
    'allergies': allergies,
    'blood_type': bloodType,
    'photo_url': photoUrl,
    'show_phone': showPhone,
    'show_email': showEmail,
    'show_allergies': showAllergies,
    'show_blood_type': showBloodType,
    'show_photo': showPhoto,
  };

  factory PersonalProfile.fromJson(Map<String, dynamic> data) {
    final rawBirthday = data['birthday'];
    DateTime? birthday;
    if (rawBirthday is String && rawBirthday.isNotEmpty) {
      birthday = DateTime.tryParse(rawBirthday);
    }
    String text(String key) {
      final value = data[key];
      return value is String ? value : '';
    }

    bool flag(String key, {required bool fallback}) {
      final value = data[key];
      return value is bool ? value : fallback;
    }

    return PersonalProfile(
      userId: text('user_id'),
      displayName: text('display_name'),
      birthday: birthday,
      phone: text('phone'),
      email: text('email'),
      allergies: text('allergies'),
      bloodType: text('blood_type'),
      photoUrl: data['photo_url'] is String
          ? data['photo_url'] as String
          : null,
      showPhone: flag('show_phone', fallback: false),
      showEmail: flag('show_email', fallback: false),
      showAllergies: flag('show_allergies', fallback: false),
      showBloodType: flag('show_blood_type', fallback: false),
      showPhoto: flag('show_photo', fallback: true),
      revision: data['revision'] is int ? data['revision'] as int : 0,
    );
  }

  /// Edad cumplida a la fecha indicada, o null sin cumpleaños válido.
  int? ageOn(DateTime date) {
    final born = birthday;
    if (born == null) return null;
    var age = date.year - born.year;
    if (date.month < born.month ||
        (date.month == born.month && date.day < born.day)) {
      age--;
    }
    return age < 0 ? null : age;
  }

  bool celebratesOn(DateTime date) {
    final born = birthday;
    return born != null && born.month == date.month && born.day == date.day;
  }
}

/// Próximos cumpleaños dentro de [days] días, incluido hoy y ordenados por
/// cercanía. Ignora perfiles sin fecha.
List<PersonalProfile> upcomingBirthdays(
  Iterable<PersonalProfile> profiles, {
  required DateTime today,
  int days = 30,
}) {
  final base = DateTime(today.year, today.month, today.day);
  final result = <(int, PersonalProfile)>[];
  for (final profile in profiles) {
    final born = profile.birthday;
    if (born == null) continue;
    var next = DateTime(base.year, born.month, born.day);
    if (next.isBefore(base))
      next = DateTime(base.year + 1, born.month, born.day);
    final diff = next.difference(base).inDays;
    if (diff >= 0 && diff <= days) result.add((diff, profile));
  }
  result.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final entry in result) entry.$2];
}

/// Perfiles que cumplen años en la fecha indicada.
List<PersonalProfile> birthdaysOn(
  Iterable<PersonalProfile> profiles,
  DateTime date,
) => [
  for (final profile in profiles)
    if (profile.celebratesOn(date)) profile,
];

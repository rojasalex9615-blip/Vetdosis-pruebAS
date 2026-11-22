import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/auth/domain/personal_profile.dart';

void main() {
  const profile = PersonalProfile(
    userId: 'u1',
    displayName: 'Ale Rojas',
    birthday: null,
    phone: '555',
    email: 'ale@example.com',
    allergies: 'penicilina',
    bloodType: 'O+',
    photoUrl: 'https://example.com/a.png',
  );

  test('salud y contacto ocultos por defecto; foto visible', () {
    final team = profile.visibleToTeam();
    expect(team.displayName, 'Ale Rojas');
    expect(team.phone, isEmpty);
    expect(team.email, isEmpty);
    expect(team.allergies, isEmpty);
    expect(team.bloodType, isEmpty);
    expect(team.photoUrl, 'https://example.com/a.png');
  });

  test('los campos marcados sí llegan al equipo', () {
    final team = profile
        .copy(showPhone: true, showEmail: true, showAllergies: true)
        .visibleToTeam();
    expect(team.phone, '555');
    expect(team.email, 'ale@example.com');
    expect(team.allergies, 'penicilina');
    expect(team.bloodType, isEmpty);
  });

  test('la foto oculta no se comparte', () {
    expect(profile.copy(showPhoto: false).visibleToTeam().photoUrl, isNull);
  });

  test('cumpleaños y edad', () {
    final born = PersonalProfile(
      userId: 'u2',
      birthday: DateTime(1990, 5, 10),
    );
    expect(born.celebratesOn(DateTime(2026, 5, 10)), isTrue);
    expect(born.celebratesOn(DateTime(2026, 5, 11)), isFalse);
    expect(born.ageOn(DateTime(2026, 5, 9)), 35);
    expect(born.ageOn(DateTime(2026, 5, 10)), 36);
  });

  test('ida y vuelta JSON conserva visibilidad', () {
    final restored = PersonalProfile.fromJson(profile.toJson());
    expect(restored.userId, 'u1');
    expect(restored.allergies, 'penicilina');
    expect(restored.showAllergies, isFalse);
    expect(restored.showPhoto, isTrue);
  });
}

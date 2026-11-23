import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/auth/domain/personal_profile.dart';

void main() {
  final today = DateTime(2026, 11, 21);
  final profiles = [
    const PersonalProfile(userId: 'a', displayName: 'Ana', birthday: null),
    PersonalProfile(
      userId: 'b',
      displayName: 'Beto',
      birthday: DateTime(1990, 11, 21),
    ),
    PersonalProfile(
      userId: 'c',
      displayName: 'Caro',
      birthday: DateTime(1992, 11, 25),
    ),
    PersonalProfile(
      userId: 'd',
      displayName: 'Dani',
      birthday: DateTime(1991, 12, 15),
    ),
    PersonalProfile(
      userId: 'e',
      displayName: 'Eva',
      birthday: DateTime(1993, 11, 1),
    ),
  ];

  test('incluye hoy y ordena por cercanía dentro de la ventana', () {
    final next = upcomingBirthdays(profiles, today: today, days: 30);
    expect(next.map((p) => p.displayName), ['Beto', 'Caro', 'Dani']);
  });

  test('ventana corta excluye los lejanos', () {
    final next = upcomingBirthdays(profiles, today: today, days: 5);
    expect(next.map((p) => p.displayName), ['Beto', 'Caro']);
  });

  test('un cumpleaños ya pasado pasa al año siguiente', () {
    final next = upcomingBirthdays(
      [
        PersonalProfile(
          userId: 'e',
          displayName: 'Eva',
          birthday: DateTime(1993, 11, 1),
        ),
      ],
      today: today,
      days: 400,
    );
    expect(next.single.displayName, 'Eva');
  });

  test('birthdaysOn devuelve solo los de hoy', () {
    expect(birthdaysOn(profiles, today).map((p) => p.displayName), ['Beto']);
  });
}

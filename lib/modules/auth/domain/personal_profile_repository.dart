import 'personal_profile.dart';

abstract interface class PersonalProfileRepository {
  /// Perfil propio, incluidos los campos ocultos al equipo.
  Future<PersonalProfile?> read(String userId);

  /// Guarda con revisión optimista; el servidor devuelve la versión guardada.
  Future<PersonalProfile> save(PersonalProfile profile);

  /// Perfiles del equipo con solo los campos que cada persona autorizó.
  Future<List<PersonalProfile>> teamProfiles(String clinicId);
}

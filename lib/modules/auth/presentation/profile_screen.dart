import 'package:flutter/material.dart';
import '../domain/personal_profile.dart';
import '../domain/personal_profile_repository.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_icons.dart';

/// Edición del perfil personal. Cada campo de salud o contacto tiene su
/// casilla para decidir si el resto del equipo puede verlo.
class PersonalProfileScreen extends StatefulWidget {
  const PersonalProfileScreen({
    super.key,
    required this.repository,
    required this.userId,
    this.initial,
  });

  final PersonalProfileRepository repository;
  final String userId;
  final PersonalProfile? initial;

  @override
  State<PersonalProfileScreen> createState() => _PersonalProfileScreenState();
}

class _PersonalProfileScreenState extends State<PersonalProfileScreen> {
  late PersonalProfile profile =
      widget.initial ?? PersonalProfile(userId: widget.userId);
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _allergies = TextEditingController();
  final _bloodType = TextEditingController();
  final _photo = TextEditingController();
  bool busy = false;
  String? message;

  @override
  void initState() {
    super.initState();
    _fill();
    if (widget.initial == null) _load();
  }

  void _fill() {
    _name.text = profile.displayName;
    _phone.text = profile.phone;
    _email.text = profile.email;
    _allergies.text = profile.allergies;
    _bloodType.text = profile.bloodType;
    _photo.text = profile.photoUrl ?? '';
  }

  Future<void> _load() async {
    try {
      final loaded = await widget.repository.read(widget.userId);
      if (!mounted || loaded == null) return;
      setState(() {
        profile = loaded;
        _fill();
      });
    } catch (_) {
      if (mounted) setState(() => message = 'No se pudo cargar el perfil.');
    }
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          profile.birthday ?? DateTime(now.year - 30, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Fecha de cumpleaños',
    );
    if (picked != null && mounted) {
      setState(() => profile = profile.copy(birthday: picked));
    }
  }

  Future<void> _save() async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    final next = profile.copy(
      displayName: _name.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      allergies: _allergies.text.trim(),
      bloodType: _bloodType.text.trim(),
      photoUrl: _photo.text.trim().isEmpty ? null : _photo.text.trim(),
    );
    try {
      final saved = await widget.repository.save(next);
      if (!mounted) return;
      setState(() {
        profile = saved;
        _fill();
        message = 'Perfil guardado.';
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => message =
              'No se pudo guardar. Revisa la conexión o vuelve a abrir el perfil.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType? keyboard,
  }) => TextFormField(
    controller: controller,
    enabled: !busy,
    maxLines: maxLines,
    keyboardType: keyboard,
    decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
  );

  Widget _visibility(String label, bool value, ValueChanged<bool> onChanged) =>
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: value,
        title: Text('Mostrar $label al equipo'),
        onChanged: busy ? null : (next) => onChanged(next == true),
      );

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _allergies, _bloodType, _photo]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final birthday = profile.birthday;
    final birthdayText = birthday == null
        ? 'Sin fecha'
        : '${birthday.day.toString().padLeft(2, '0')}/'
              '${birthday.month.toString().padLeft(2, '0')}/'
              '${birthday.year}';
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        children: [
          VetCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Datos personales', style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Alergias y tipo de sangre están ocultos salvo que los marques. La foto se muestra al equipo por defecto.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                _field(_name, 'Nombre y apellidos', VetIcons.userCircle),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(VetIcons.calendar),
                  title: const Text('Cumpleaños'),
                  subtitle: Text(birthdayText),
                  trailing: const Icon(VetIcons.chevronRight, size: 18),
                  onTap: busy ? null : _pickBirthday,
                ),
                const SizedBox(height: 8),
                _field(
                  _phone,
                  'Teléfono',
                  VetIcons.phone,
                  keyboard: TextInputType.phone,
                ),
                _visibility(
                  'el teléfono',
                  profile.showPhone,
                  (v) => setState(() => profile = profile.copy(showPhone: v)),
                ),
                const SizedBox(height: 8),
                _field(
                  _email,
                  'Correo',
                  VetIcons.mail,
                  keyboard: TextInputType.emailAddress,
                ),
                _visibility(
                  'el correo',
                  profile.showEmail,
                  (v) => setState(() => profile = profile.copy(showEmail: v)),
                ),
                const SizedBox(height: 8),
                _field(
                  _allergies,
                  'Alergias',
                  VetIcons.alertTriangle,
                  maxLines: 2,
                ),
                _visibility(
                  'las alergias',
                  profile.showAllergies,
                  (v) =>
                      setState(() => profile = profile.copy(showAllergies: v)),
                ),
                const SizedBox(height: 8),
                _field(_bloodType, 'Tipo de sangre', VetIcons.heart),
                _visibility(
                  'el tipo de sangre',
                  profile.showBloodType,
                  (v) =>
                      setState(() => profile = profile.copy(showBloodType: v)),
                ),
                const SizedBox(height: 8),
                _field(_photo, 'Foto (enlace)', VetIcons.camera),
                _visibility(
                  'la foto',
                  profile.showPhoto,
                  (v) => setState(() => profile = profile.copy(showPhoto: v)),
                ),
                if (message != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    message!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 16),
                VetActionButton(
                  label: busy ? 'Guardando...' : 'Guardar perfil',
                  icon: VetIcons.save,
                  onPressed: busy ? null : _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Vista de solo lectura con los campos que la persona autorizó.
class PersonalProfileViewScreen extends StatelessWidget {
  const PersonalProfileViewScreen({super.key, required this.profile});

  final PersonalProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final birthday = profile.birthday;
    final rows = <(IconData, String, String)>[
      if (profile.phone.isNotEmpty) (VetIcons.phone, 'Teléfono', profile.phone),
      if (profile.email.isNotEmpty) (VetIcons.mail, 'Correo', profile.email),
      if (profile.allergies.isNotEmpty)
        (VetIcons.alertTriangle, 'Alergias', profile.allergies),
      if (profile.bloodType.isNotEmpty)
        (VetIcons.heart, 'Tipo de sangre', profile.bloodType),
      if (birthday != null)
        (
          VetIcons.calendar,
          'Cumpleaños',
          '${birthday.day.toString().padLeft(2, '0')}/'
              '${birthday.month.toString().padLeft(2, '0')}/'
              '${birthday.year}',
        ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          profile.displayName.isEmpty ? 'Perfil' : profile.displayName,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        children: [
          VetCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      backgroundImage: profile.photoUrl == null
                          ? null
                          : NetworkImage(profile.photoUrl!),
                      child: profile.photoUrl == null
                          ? const Icon(VetIcons.userCircle, size: 28)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        profile.displayName.isEmpty
                            ? 'Sin nombre'
                            : profile.displayName,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (rows.isEmpty)
                  Text(
                    'Este miembro no comparte datos adicionales con el equipo.',
                    style: theme.textTheme.bodyMedium,
                  ),
                for (final row in rows)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(row.$1),
                    title: Text(row.$2),
                    subtitle: Text(row.$3),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

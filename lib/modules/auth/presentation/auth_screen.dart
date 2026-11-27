import 'team_duty_screen.dart';
import '../domain/personal_profile_repository.dart';
import 'profile_screen.dart';
import 'messages_screen.dart';
import '../domain/team_message.dart';
import '../../../core/widgets/brand_gradient.dart';
import '../../../core/widgets/neu_identity.dart';
import '../../../core/widgets/google_mark.dart';
import '../../legal/presentation/legal_links.dart';
import '../../permissions/domain/permission_repository.dart';
import '../../permissions/presentation/permission_screen.dart';
import '../domain/auth_repository.dart';
import 'team_screen.dart';
import 'package:flutter/material.dart';
import '../domain/clinic_membership.dart';
import 'auth_view_model.dart';
import '../../../core/widgets/accent_glow.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_icons.dart';
import '../../../vet_ui/vet_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.model,
    this.configured = true,
    this.initialRegister = false,
  });
  final AuthViewModel? model;
  final bool configured;
  final bool initialRegister;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _clinic = TextEditingController();
  final _code = TextEditingController();
  final _referral = TextEditingController();
  final _form = GlobalKey<FormState>();
  late bool _register = widget.initialRegister;
  bool _reset = false;
  bool _showPassword = false;
  @override
  void dispose() {
    for (final field in [_email, _password, _clinic, _code, _referral]) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final veiled = AccessBackdrop.appliesTo(context);
    final entering = model?.signedIn != true;
    return AccessBackdrop(
      child: Scaffold(
        backgroundColor: veiled ? Colors.transparent : null,
        appBar: AppBar(
          title: veiled ? null : const Text('VetDosis Pro'),
          backgroundColor: veiled ? Colors.transparent : null,
          scrolledUnderElevation: veiled ? 0 : null,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                children: [
                  const VetDosisBrand(large: true),
                  const SizedBox(height: 10),
                  Text(
                    _reset || model?.recoveringPassword == true
                        ? 'Recuperar acceso'
                        : model?.signedIn == true
                        ? 'Tu clínica'
                        : _register
                        ? 'Registro de usuario'
                        : 'Inicio de sesión',
                    textAlign: veiled && entering ? TextAlign.center : null,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _reset || model?.recoveringPassword == true
                        ? 'Escribe tu correo y te enviaremos un enlace.'
                        : model?.signedIn == true
                        ? 'Consulta y cambia la clínica con la que trabajas.'
                        : _register
                        ? 'Crea tu cuenta para empezar a usar VetDosis Pro.'
                        : 'Entra con tu correo y contraseña para consultar tu clínica.',
                    textAlign: veiled && entering ? TextAlign.center : null,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (!widget.configured) ...[
                    const Text(
                      'El acceso estará disponible cuando conectemos tu clínica.',
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Conexión pendiente. Tus datos aún no se envían a ningún servidor.',
                    ),
                  ] else if (model!.recoveringPassword) ...[
                    const Text('Elige una nueva contraseña.'),
                    Form(
                      key: _form,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _password,
                            obscureText: true,
                            enabled: !model.busy,
                            autofillHints: const [AutofillHints.newPassword],
                            decoration: const InputDecoration(
                              labelText: 'Nueva contraseña',
                            ),
                            validator: (value) => (value?.length ?? 0) >= 8
                                ? null
                                : 'Usa al menos 8 caracteres',
                          ),
                          TextFormField(
                            obscureText: true,
                            enabled: !model.busy,
                            decoration: const InputDecoration(
                              labelText: 'Confirma la contraseña',
                            ),
                            validator: (value) => value == _password.text
                                ? null
                                : 'Las contraseñas no coinciden',
                          ),
                          if (_register) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _referral,
                              enabled: !model.busy,
                              decoration: const InputDecoration(
                                labelText: '¿Cómo encontró la app? (opcional)',
                                prefixIcon: Icon(VetIcons.search),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    NeuPrimaryButton(
                      onPressed: model.busy
                          ? null
                          : () {
                              if (_form.currentState!.validate()) {
                                model.completePasswordRecovery(_password.text);
                              }
                            },
                      child: const Text('Actualizar contraseña'),
                    ),
                    TextButton(
                      onPressed: model.busy ? null : model.signOut,
                      child: const Text('Cancelar y cerrar sesión'),
                    ),
                  ] else if (model.loadingMemberships) ...[
                    const Center(child: CircularProgressIndicator()),
                  ] else if (!model.signedIn) ...[
                    if (!veiled) ...[
                      Text(
                        'Ingresa con tu cuenta para acceder a las clínicas de tu equipo.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Form(
                      key: _form,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'Correo electrónico',
                              prefixIcon: Icon(VetIcons.mail),
                            ),
                            validator: (value) =>
                                value != null &&
                                    RegExp(
                                      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                    ).hasMatch(value.trim())
                                ? null
                                : 'Ingresa un correo válido',
                          ),
                          const SizedBox(height: 12),
                          if (!_reset)
                            TextFormField(
                              controller: _password,
                              obscureText: !_showPassword,
                              autofillHints: const [AutofillHints.password],
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
                                prefixIcon: const Icon(VetIcons.lock),
                                suffixIcon: IconButton(
                                  tooltip: _showPassword
                                      ? 'Ocultar contraseña'
                                      : 'Mostrar contraseña',
                                  onPressed: () => setState(
                                    () => _showPassword = !_showPassword,
                                  ),
                                  icon: Icon(
                                    _showPassword
                                        ? VetIcons.eye
                                        : VetIcons.eyeOff,
                                  ),
                                ),
                              ),
                              validator: (value) =>
                                  (value?.length ?? 0) >= (_register ? 8 : 1)
                                  ? null
                                  : 'Revisa la contraseña (mínimo 8 caracteres al registrarte)',
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: model.busy
                          ? null
                          : () {
                              if (!_form.currentState!.validate()) return;
                              if (_reset) {
                                model.requestPasswordRecovery(_email.text);
                              } else if (_register) {
                                model.register(
                                  _email.text,
                                  _password.text,
                                  referral: _referral.text,
                                );
                              } else {
                                model.signIn(_email.text, _password.text);
                              }
                            },
                      // Sin alto forzado: el de Material 3 son 40, y a 48 el
                      // boton se veia hinchado frente a los campos. El area
                      // tactil sigue siendo de 48 porque los botones usan
                      // MaterialTapTargetSize.padded, asi que no se pierde
                      // accesibilidad al dejar la altura visual en 40.
                      child: Text(
                        _reset
                            ? 'Enviar enlace de recuperación'
                            : _register
                            ? 'Crear cuenta'
                            : 'Ingresar',
                      ),
                    ),
                    if (!_reset && model.googleEnabled) ...[
                      const SizedBox(height: 14),
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text('O ingresa con'),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton(
                        onPressed: model.busy ? null : model.googleSignIn,
                        style: veiled
                            ? OutlinedButton.styleFrom(
                                backgroundBuilder: plainButtonLayer,
                                backgroundColor: const Color(0xFF2B2B31),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: const Color(
                                  0x662B2B31,
                                ),
                                side: BorderSide.none,
                              )
                            : null,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GoogleMark(size: 18),
                            SizedBox(width: 10),
                            Text('Continuar con Google'),
                          ],
                        ),
                      ),
                    ],
                    TextButton(
                      onPressed: model.busy
                          ? null
                          : () => setState(() {
                              if (_reset) {
                                _reset = false;
                              } else {
                                _register = !_register;
                              }
                              _password.clear();
                            }),
                      child: Text(
                        _reset
                            ? 'Volver al ingreso'
                            : _register
                            ? 'Ya tengo cuenta'
                            : 'Crear una cuenta',
                      ),
                    ),
                    if (!_reset && model.recoveryAvailable)
                      TextButton(
                        onPressed: model.busy
                            ? null
                            : () => setState(() {
                                _reset = true;
                                _register = false;
                                _password.clear();
                              }),
                        child: const Text('Olvidé mi contraseña'),
                      ),
                  const LegalSmallPrint(preLogin: true),
                  ] else ...[
                    if (model.error == null) ...[
                      if (model.personalAvailable)
                        FilledButton.icon(
                          onPressed: model.busy
                              ? null
                              : model.createPersonalWorkspace,
                          icon: const Icon(VetIcons.user),
                          label: const Text('Usar mi área de trabajo personal'),
                        ),
                      const Text(
                        'Crea una clínica o ingresa el código que te compartió su administrador.',
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _clinic,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de la nueva clínica',
                        ),
                      ),
                      FilledButton(
                        onPressed: model.busy
                            ? null
                            : () {
                                if (_clinic.text.trim().length >= 2 &&
                                    _clinic.text.trim().length <= 120) {
                                  model.createClinic(_clinic.text);
                                }
                              },
                        child: const Text('Crear clínica'),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _code,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Código de invitación',
                        ),
                      ),
                      OutlinedButton(
                        onPressed: model.busy
                            ? null
                            : () {
                                if (_code.text.trim().isNotEmpty) {
                                  model.joinClinic(_code.text);
                                }
                              },
                        child: const Text('Unirme a una clínica'),
                      ),
                    ],
                    TextButton(
                      onPressed: model.busy ? null : model.refresh,
                      child: const Text('Volver a verificar acceso'),
                    ),
                    TextButton(
                      onPressed: model.busy ? null : model.signOut,
                      child: const Text('Cerrar sesión'),
                    ),
                  ],
                  if (model?.busy == true)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (model?.error != null)
                    Text(
                      model!.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (model?.message != null) Text(model!.message!),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ClinicAccountScreen extends StatefulWidget {
  const ClinicAccountScreen({
    super.key,
    required this.model,
    this.identityBuilder,
    this.personalSpaceBuilder,
  });
  final Widget Function(BuildContext context)? identityBuilder;
  final Widget Function(BuildContext context)? personalSpaceBuilder;
  final AuthViewModel model;
  @override
  State<ClinicAccountScreen> createState() => _ClinicAccountScreenState();
}

class _ClinicAccountScreenState extends State<ClinicAccountScreen> {
  final _email = TextEditingController();
  final _clinicName = TextEditingController();
  final _inviteCode = TextEditingController();
  ClinicRole _role = ClinicRole.mvz;
  @override
  void dispose() {
    _email.dispose();
    _clinicName.dispose();
    _inviteCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.model,
    builder: (context, _) {
      final model = widget.model;
      final theme = Theme.of(context);

      return Scaffold(
        appBar: AppBar(
          title: const Text('Mi cuenta y clínicas'),
          actions: [
            IconButton(
              icon: const Icon(VetIcons.refresh),
              tooltip: 'Actualizar permisos',
              onPressed: model.busy ? null : model.refresh,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.identityBuilder != null) ...[
                  widget.identityBuilder!(context),
                  const SizedBox(height: 16),
                ],
                if (model.repository is PersonalProfileRepository &&
                    model.repository.userId != null) ...[
                  AccentGlow(
                    color: theme.colorScheme.primary,
                    radius: 24,
                    emphasis: 0.45,
                    child: VetCard(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const AccentIcon(
                          VetIcons.userCircle,
                          size: 28,
                        ),
                        title: const Text(
                          'Mi perfil personal',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: const Text(
                          'Nombre, cumpleaños, contacto, alergias y qué ve el equipo',
                        ),
                        trailing: const Icon(VetIcons.chevronRight),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => PersonalProfileScreen(
                              repository:
                                  model.repository as PersonalProfileRepository,
                              userId: model.repository.userId!,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (model.repository is TeamMessageRepository &&
                    model.repository is PersonalProfileRepository &&
                    model.active != null &&
                    !model.active!.isPersonal) ...[
                  VetCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const AccentIcon(VetIcons.mail, size: 28),
                      title: const Text(
                        'Mensajes del equipo',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text(
                        'Avisos a una persona o a todo el equipo',
                      ),
                      trailing: const Icon(VetIcons.chevronRight),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => MessagesLoader(
                            messages: model.repository as TeamMessageRepository,
                            profiles:
                                model.repository as PersonalProfileRepository,
                            clinicId: model.active!.clinicId,
                            userId: model.active!.userId,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (widget.personalSpaceBuilder != null) ...[
                  AccentGlow(
                    color: theme.colorScheme.primary,
                    radius: 24,
                    emphasis: 0.45,
                    child: VetCard(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const AccentIcon(
                          VetIcons.userCircle,
                          size: 28,
                        ),
                        title: const Text(
                          'Mi espacio personal',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: const Text(
                          'Notas, recordatorios, horarios y ficha de emergencia',
                        ),
                        trailing: const Icon(VetIcons.chevronRight),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: widget.personalSpaceBuilder!,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (model.memberships.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(VetIcons.hospital, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Áreas de trabajo',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (model.personalAvailable &&
                      !model.memberships.any((m) => m.isPersonal)) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: model.busy
                            ? null
                            : model.createPersonalWorkspace,
                        icon: const Icon(VetIcons.user),
                        label: const Text('Crear mi área de trabajo personal'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  for (final member in model.memberships) ...[
                    VetCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: InkWell(
                        onTap: model.busy
                            ? null
                            : () => model.selectClinic(member),
                        borderRadius: BorderRadius.circular(16),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color:
                                    (model.active == member
                                            ? VetColors.success
                                            : theme.colorScheme.primary)
                                        .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                member.isPersonal
                                    ? VetIcons.userCircle
                                    : VetIcons.hospital,
                                color: model.active == member
                                    ? VetColors.success
                                    : theme.colorScheme.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    member.displayName,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    member.isPersonal
                                        ? 'Pacientes y dosis propios, sin equipo'
                                        : member.role.label,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (model.active == member) ...[
                              const VetStatusBadge(
                                label: 'Activa',
                                kind: VetBadgeKind.success,
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                VetIcons.checkCircle,
                                color: VetColors.success,
                                size: 20,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 8),
                ],
                if (!model.offline &&
                    model.active != null &&
                    model.repository is PermissionRepository) ...[
                  OutlinedButton.icon(
                    onPressed: model.busy
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => PermissionScreen(
                                model: model,
                                clinic: model.active!,
                              ),
                            ),
                          ),
                    icon: const Icon(VetIcons.shieldCheck),
                    label: const Text('Permisos y habilitación'),
                  ),
                  const SizedBox(height: 8),
                ],
                if (!model.offline &&
                    model.active != null &&
                    model.active?.isPersonal != true &&
                    model.repository is TeamDutyRepository) ...[
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            TeamDutyScreen(model: model, clinic: model.active!),
                      ),
                    ),
                    icon: const Icon(VetIcons.clock),
                    label: const Text('Equipo: horarios y faltas'),
                  ),
                  const SizedBox(height: 8),
                ],
                if (!model.offline &&
                    model.active?.role == ClinicRole.admin &&
                    model.active?.isPersonal != true) ...[
                  const SizedBox(height: 12),
                  if (model.repository is TeamRepository &&
                      (model.repository as TeamRepository)
                          .teamManagementAvailable) ...[
                    OutlinedButton.icon(
                      onPressed: model.busy
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => TeamScreen(
                                  model: model,
                                  clinic: model.active!,
                                ),
                              ),
                            ),
                      icon: const Icon(VetIcons.usersGroup),
                      label: const Text('Administrar equipo e invitaciones'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  VetCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              VetIcons.userPlus,
                              size: 20,
                              color: VetColors.brandSky,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Invitar a una persona a esta clínica',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Correo de la persona invitada',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(VetIcons.mail, size: 20),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<ClinicRole>(
                          initialValue: _role,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Rol que le asignarás',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(VetIcons.idBadge, size: 20),
                          ),
                          items: ClinicRole.values
                              .map(
                                (role) => DropdownMenuItem(
                                  value: role,
                                  child: Text(role.label),
                                ),
                              )
                              .toList(),
                          onChanged: (role) {
                            if (role != null) setState(() => _role = role);
                          },
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: model.busy
                              ? null
                              : () {
                                  if (RegExp(
                                    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                  ).hasMatch(_email.text.trim())) {
                                    model.invite(_email.text, _role);
                                  }
                                },
                          icon: const Icon(VetIcons.paperPlane, size: 18),
                          label: const Text('Generar código de invitación'),
                        ),
                        if (model.invitation != null) ...[
                          const SizedBox(height: 14),
                          const VetCallout(
                            text:
                                'Comparte este código con la persona invitada. Vence en 7 días y solo puede usarse una vez con su correo confirmado.',
                            kind: VetBadgeKind.information,
                            icon: VetIcons.shieldCheck,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: SelectableText(
                              model.invitation!,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (!model.offline) ...[
                  VetCard(
                    child: ExpansionTile(
                      leading: const Icon(VetIcons.plusCircle),
                      title: const Text(
                        'Agregar otra clínica',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      childrenPadding: const EdgeInsets.only(top: 8, bottom: 8),
                      children: [
                        TextField(
                          controller: _clinicName,
                          decoration: const InputDecoration(
                            labelText: 'Nombre de la nueva clínica',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: model.busy
                              ? null
                              : () {
                                  final name = _clinicName.text.trim();
                                  if (name.length >= 2 && name.length <= 120) {
                                    model.createClinic(name);
                                  }
                                },
                          child: const Text('Crear clínica'),
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _inviteCode,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'Código de invitación',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: model.busy
                              ? null
                              : () {
                                  if (_inviteCode.text.trim().isNotEmpty) {
                                    model.joinClinic(_inviteCode.text);
                                  }
                                },
                          child: const Text('Unirme a una clínica'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: model.busy ? null : model.refresh,
                    icon: const Icon(VetIcons.refresh, size: 16),
                    label: const Text('Actualizar mis permisos'),
                  ),
                ),
                if (model.error != null) ...[
                  const SizedBox(height: 10),
                  VetCallout(
                    text: model.error!,
                    kind: VetBadgeKind.danger,
                    icon: VetIcons.alertTriangle,
                  ),
                ],
                if (model.busy) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: model.busy
                      ? null
                      : () async {
                          await model.signOut();
                          if (context.mounted) Navigator.pop(context);
                        },
                  icon: const Icon(VetIcons.logout),
                  label: const Text('Cerrar sesión'),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

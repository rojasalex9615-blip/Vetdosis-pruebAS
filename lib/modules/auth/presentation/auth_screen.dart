import 'team_duty_screen.dart';
import '../../../core/widgets/auth_glass.dart';
import '../../permissions/domain/permission_repository.dart';
import '../../permissions/presentation/permission_screen.dart';
import '../domain/auth_repository.dart';
import 'team_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../domain/clinic_membership.dart';
import 'auth_view_model.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.model, this.configured = true, this.initialRegister = false});
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
  final _form = GlobalKey<FormState>();
  late bool _register = widget.initialRegister;
  bool _reset = false;
  bool _showPassword = false;

  @override
  void dispose() {
    for (final field in [_email, _password, _clinic, _code]) {
      field.dispose();
    }
    super.dispose();
  }

  Widget _passwordToggle(VoidCallback onPressed) => IconButton(
    tooltip: _showPassword ? 'Ocultar contraseña' : 'Mostrar contraseña',
    onPressed: onPressed,
    icon: Icon(
      _showPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      size: 20,
      color: authMuted,
    ),
  );

  void _switchMode() {
    setState(() {
      if (_reset) {
        _reset = false;
      } else {
        _register = !_register;
      }
      _password.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final heading = _reset || model?.recoveringPassword == true
        ? 'Recuperar acceso'
        : model?.signedIn == true
        ? 'Tu clínica'
        : _register
        ? 'Crea tu cuenta'
        : 'Iniciar Sesión';
    final intro = _reset || model?.recoveringPassword == true
        ? 'Restablece tu contraseña y vuelve a entrar.'
        : model?.signedIn == true
        ? 'Elige la clínica donde quieres trabajar.'
        : _register
        ? 'Crea tu cuenta para trabajar con tu equipo veterinario.'
        : 'Ingresa con tu cuenta para acceder a las clínicas de tu equipo.';
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: authSkyTop,
        body: AuthBackdrop(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 36),
                  children: [
                    const AuthBackButton(),
                    const SizedBox(height: 8),
                    const AuthBrandHeader(),
                    const SizedBox(height: 26),
                    Text(
                      heading,
                      textAlign: TextAlign.center,
                      style: authHeadingStyle,
                    ),
                    const SizedBox(height: 10),
                    Text(intro, textAlign: TextAlign.center, style: authBodyStyle),
                    const SizedBox(height: 24),
                    if (!widget.configured) ...[
                      const GlassCard(
                        child: Column(
                          children: [
                            Text(
                              'El acceso estará disponible cuando conectemos tu clínica.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15.5,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                                color: authInk,
                              ),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Conexión pendiente. Tus datos aún no se envían a ningún servidor.',
                              textAlign: TextAlign.center,
                              style: authBodyStyle,
                            ),
                          ],
                        ),
                      ),
                    ] else if (model!.recoveringPassword) ...[
                      GlassCard(
                        child: Form(
                          key: _form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Elige una nueva contraseña.',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: authInk,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _password,
                                obscureText: true,
                                enabled: !model.busy,
                                autofillHints: const [AutofillHints.newPassword],
                                decoration: authFieldDecoration(
                                  hint: 'Nueva contraseña',
                                  icon: Icons.lock_outline,
                                ),
                                validator: (value) => (value?.length ?? 0) >= 8
                                    ? null
                                    : 'Usa al menos 8 caracteres',
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                obscureText: true,
                                enabled: !model.busy,
                                decoration: authFieldDecoration(
                                  hint: 'Confirma la contraseña',
                                  icon: Icons.lock_reset_outlined,
                                ),
                                validator: (value) => value == _password.text
                                    ? null
                                    : 'Las contraseñas no coinciden',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      AuthGradientButton(
                        label: 'Actualizar contraseña',
                        busy: model.busy,
                        onPressed: () {
                          if (_form.currentState!.validate()) {
                            model.completePasswordRecovery(_password.text);
                          }
                        },
                      ),
                      AuthTextLink(
                        label: 'Cancelar y cerrar sesión',
                        onPressed: model.busy ? null : model.signOut,
                      ),
                    ] else if (model.loadingMemberships) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 36),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ] else if (!model.signedIn) ...[
                      GlassCard(
                        padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                        child: Form(
                          key: _form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                decoration: authFieldDecoration(
                                  hint: 'Correo electrónico',
                                  icon: Icons.mail_outline,
                                ),
                                validator: (value) =>
                                    value != null &&
                                        RegExp(
                                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                        ).hasMatch(value.trim())
                                    ? null
                                    : 'Ingresa un correo válido',
                              ),
                              if (!_reset) ...[
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _password,
                                  obscureText: !_showPassword,
                                  autofillHints: const [AutofillHints.password],
                                  decoration: authFieldDecoration(
                                    hint: 'Contraseña',
                                    icon: Icons.lock_outline,
                                    suffix: _passwordToggle(
                                      () => setState(
                                        () => _showPassword = !_showPassword,
                                      ),
                                    ),
                                  ),
                                  validator: (value) =>
                                      (value?.length ?? 0) >=
                                          (_register ? 8 : 1)
                                      ? null
                                      : 'Revisa la contraseña (mínimo 8 caracteres al registrarte)',
                                ),
                                if (!_register && model.recoveryAvailable)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: AuthTextLink(
                                      label: 'Olvidé mi contraseña',
                                      onPressed: model.busy
                                          ? null
                                          : () => setState(() {
                                              _reset = true;
                                              _register = false;
                                              _password.clear();
                                            }),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      AuthGradientButton(
                        label: _reset
                            ? 'Enviar enlace de recuperación'
                            : _register
                            ? 'Crear cuenta'
                            : 'Ingresar',
                        busy: model.busy,
                        onPressed: () {
                          if (!_form.currentState!.validate()) return;
                          if (_reset) {
                            model.requestPasswordRecovery(_email.text);
                          } else if (_register) {
                            model.register(_email.text, _password.text);
                          } else {
                            model.signIn(_email.text, _password.text);
                          }
                        },
                      ),
                      if (!_reset && model.googleEnabled) ...[
                        const SizedBox(height: 14),
                        AuthGoogleButton(
                          onPressed: model.busy ? null : model.googleSignIn,
                        ),
                      ],
                      const SizedBox(height: 8),
                      AuthTextLink(
                        label: _reset
                            ? 'Volver al ingreso'
                            : _register
                            ? 'Ya tengo cuenta'
                            : 'Crear una cuenta',
                        onPressed: model.busy ? null : _switchMode,
                      ),
                    ] else ...[
                      if (model.error == null) ...[
                        if (model.personalAvailable) ...[
                          OutlinedButton.icon(
                            onPressed: model.busy
                                ? null
                                : model.createPersonalWorkspace,
                            style: authSecondaryButtonStyle(),
                            icon: const Icon(Icons.person_outline, size: 20),
                            label: const Text('Usar mi espacio personal'),
                          ),
                          const SizedBox(height: 14),
                        ],
                        GlassCard(
                          padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Crea una clínica o ingresa el código que te compartió su administrador.',
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.4,
                                  color: authInkSoft,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _clinic,
                                decoration: authFieldDecoration(
                                  hint: 'Nombre de la nueva clínica',
                                  icon: Icons.local_hospital_outlined,
                                ),
                              ),
                              const SizedBox(height: 14),
                              AuthGradientButton(
                                label: 'Crear clínica',
                                busy: model.busy,
                                onPressed: () {
                                  if (_clinic.text.trim().length >= 2 &&
                                      _clinic.text.trim().length <= 120) {
                                    model.createClinic(_clinic.text);
                                  }
                                },
                              ),
                              const SizedBox(height: 18),
                              TextField(
                                controller: _code,
                                autocorrect: false,
                                decoration: authFieldDecoration(
                                  hint: 'Código de invitación',
                                  icon: Icons.vpn_key_outlined,
                                ),
                              ),
                              const SizedBox(height: 14),
                              OutlinedButton(
                                onPressed: model.busy
                                    ? null
                                    : () {
                                        if (_code.text.trim().isNotEmpty) {
                                          model.joinClinic(_code.text);
                                        }
                                      },
                                style: authSecondaryButtonStyle(),
                                child: const Text('Unirme a una clínica'),
                              ),
                            ],
                          ),
                        ),
                      ],
                      AuthTextLink(
                        label: 'Volver a verificar acceso',
                        onPressed: model.busy ? null : model.refresh,
                      ),
                      AuthTextLink(
                        label: 'Cerrar sesión',
                        onPressed: model.busy ? null : model.signOut,
                      ),
                    ],
                    if (model?.busy == true)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (model?.error != null)
                      AuthMessage(model!.error!, isError: true),
                    if (model?.message != null) AuthMessage(model!.message!),
                  ],
                ),
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
  });
  final Widget Function(BuildContext context)? identityBuilder;
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
      return Scaffold(
        appBar: AppBar(title: const Text('Mi cuenta y clínicas')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (widget.identityBuilder != null)
              widget.identityBuilder!(context),
            if (model.personalAvailable)
              TextButton.icon(
                onPressed: model.busy ? null : model.createPersonalWorkspace,
                icon: const Icon(Icons.person_outline),
                label: const Text('Abrir mi espacio personal'),
              ),
            for (final member in model.memberships)
              ListTile(
                title: Text(member.clinicName),
                subtitle: Text(
                  member.isPersonal ? 'Espacio personal' : member.role.label,
                ),
                trailing: model.active == member
                    ? const Icon(Icons.check_circle_outline)
                    : null,
                onTap: model.busy ? null : () => model.selectClinic(member),
              ),
            if (!model.offline &&
                model.active != null &&
                model.repository is PermissionRepository)
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
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('Permisos y habilitación'),
              ),
            if (!model.offline &&
                model.active != null &&
                model.active?.isPersonal != true &&
                model.repository is TeamDutyRepository)
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        TeamDutyScreen(model: model, clinic: model.active!),
                  ),
                ),
                icon: const Icon(Icons.schedule),
                label: const Text('Equipo: horarios y faltas'),
              ),
            if (!model.offline &&
                model.active?.role == ClinicRole.admin &&
                model.active?.isPersonal != true) ...[
              const Divider(),
              if (model.repository is TeamRepository &&
                  (model.repository as TeamRepository).teamManagementAvailable)
                OutlinedButton.icon(
                  onPressed: model.busy
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                TeamScreen(model: model, clinic: model.active!),
                          ),
                        ),
                  icon: const Icon(Icons.groups_outlined),
                  label: const Text('Administrar equipo e invitaciones'),
                ),
              const Text('Invitar a una persona a esta clínica'),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo de la persona invitada',
                ),
              ),
              DropdownButtonFormField<ClinicRole>(
                initialValue: _role,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Rol que le asignarás',
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
              FilledButton(
                onPressed: model.busy
                    ? null
                    : () {
                        if (RegExp(
                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                        ).hasMatch(_email.text.trim())) {
                          model.invite(_email.text, _role);
                        }
                      },
                child: const Text('Generar código de invitación'),
              ),
              if (model.invitation != null) ...[
                const Text(
                  'Comparte este código con la persona invitada. Vence en 7 días y solo puede usarse una vez con su correo confirmado.',
                ),
                SelectableText(model.invitation!),
              ],
            ],
            const Divider(),
            if (!model.offline)
              ExpansionTile(
                title: const Text('Agregar otra clínica'),
                children: [
                  TextField(
                    controller: _clinicName,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la nueva clínica',
                    ),
                  ),
                  FilledButton(
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
                  TextField(
                    controller: _inviteCode,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Código de invitación',
                    ),
                  ),
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
            TextButton(
              onPressed: model.busy ? null : model.refresh,
              child: const Text('Actualizar mis permisos'),
            ),
            if (model.error != null) Text(model.error!),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: model.busy
                  ? null
                  : () async {
                      await model.signOut();
                      if (context.mounted) Navigator.pop(context);
                    },
              child: const Text('Cerrar sesión'),
            ),
          ],
        ),
      );
    },
  );
}

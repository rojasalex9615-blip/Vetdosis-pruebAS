import 'package:flutter/material.dart';

import '../../../core/widgets/neu_identity.dart';
import '../../auth/presentation/auth_screen.dart';
import '../../auth/presentation/auth_view_model.dart';

/// Public product entry shown before authentication.
///
/// Three horizontal slides: welcome with the brand and access buttons, a
/// product description, and the plans for the closed beta.
class PublicWelcomeScreen extends StatefulWidget {
  const PublicWelcomeScreen({super.key, required this.auth});

  final AuthViewModel? auth;

  @override
  State<PublicWelcomeScreen> createState() => _PublicWelcomeScreenState();
}

class _PublicWelcomeScreenState extends State<PublicWelcomeScreen> {
  static const int _pageCount = 3;
  static const _footer =
      'Las referencias y respuestas asistidas requieren revisión veterinaria.';

  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openAccess(BuildContext context, {bool register = false}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AuthScreen(
          model: widget.auth,
          configured: widget.auth != null,
          initialRegister: register,
        ),
      ),
    );
  }

  void _turn(int delta) {
    _controller.animateToPage(
      (_page + delta).clamp(0, _pageCount - 1).toInt(),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget slide(List<Widget> children) => ListView(
      padding: const EdgeInsets.all(24),
      children: children,
    );
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _controller,
                    onPageChanged: (page) => setState(() => _page = page),
                    children: [
                      slide(_welcomeChildren(theme)),
                      slide(_descriptionChildren(theme)),
                      slide(_plansChildren(theme)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      Flexible(
                        child: _page > 0
                            ? FittedBox(
                                fit: BoxFit.scaleDown,
                                child: TextButton(
                                  onPressed: () => _turn(-1),
                                  child: const Text('Anterior'),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < _pageCount; i++)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                child: Icon(
                                  Icons.circle,
                                  size: i == _page ? 10 : 8,
                                  color: i == _page
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outlineVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: _page < _pageCount - 1
                            ? FittedBox(
                                fit: BoxFit.scaleDown,
                                child: FilledButton.tonal(
                                  onPressed: () => _turn(1),
                                  child: const Text('Siguiente'),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: Text(
                    _footer,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _welcomeChildren(ThemeData theme) => [
    const SizedBox(height: 8),
    const VetDosisBrand(large: true),
    const SizedBox(height: 14),
    Text(
      'Bienvenido a VetDosis',
      textAlign: TextAlign.center,
      style: theme.textTheme.headlineLarge,
    ),
    const SizedBox(height: 12),
    Text(
      'Dosis, expedientes y equipo de tu clínica, en un solo lugar.',
      textAlign: TextAlign.center,
      style: theme.textTheme.titleMedium,
    ),
    const SizedBox(height: 20),
    FilledButton.icon(
      onPressed: () => _openAccess(context),
      icon: const Icon(Icons.login),
      label: const Text('Iniciar sesión'),
    ),
    const SizedBox(height: 8),
    OutlinedButton(
      onPressed: widget.auth == null
          ? null
          : () => _openAccess(context, register: true),
      child: const Text('Crear cuenta'),
    ),
    const SizedBox(height: 16),
  ];

  List<Widget> _descriptionChildren(ThemeData theme) => [
    Text('Qué incluye VetDosis Pro', style: theme.textTheme.headlineSmall),
    const SizedBox(height: 16),
    Text('Especies', style: theme.textTheme.titleLarge),
    const SizedBox(height: 4),
    const _Numbered(1, 'Pequeñas especies', ''),
    const _Numbered(
      2,
      'Producción animal',
      'Avicultura e incubación. Bovinos, ovinos y cerdos próximamente.',
    ),
    const _Numbered(3, 'Exóticos', 'Próximamente.'),
    const SizedBox(height: 16),
    Text('Administración clínica', style: theme.textTheme.titleLarge),
    const SizedBox(height: 4),
    const _Numbered(
      1,
      'Cálculos con criterio',
      'Dosis por especie y por kg, fluidoterapia y productos comerciales. '
          'Vademécum con fuentes. Tú validas, la app te ahorra el error.',
    ),
    const _Numbered(
      2,
      'Pacientes y hospitalización',
      'Expedientes, agenda, recetas y consentimientos en PDF. '
          'Seguimiento de hospitalizados con recordatorios.',
    ),
    const _Numbered(
      3,
      'Inventario y caja',
      'Escáner de códigos y lectura de etiquetas. Ventas, crédito, abonos y '
          'promociones.',
    ),
    const _Numbered(
      4,
      'Tu clínica como negocio',
      'Dashboard, planeación financiera en pesos, punto de equilibrio. Equipo '
          'con permisos, asistencia, horarios, mensajes, avisos, tablón de '
          'notas y comisiones.',
    ),
    const _Numbered(
      5,
      'IA que asiste, no decide',
      'Borradores, dictado por voz y lectura de etiquetas. Siempre con tu '
          'revisión profesional.',
    ),
    const SizedBox(height: 16),
    Text('Próximamente', style: theme.textTheme.titleLarge),
    const SizedBox(height: 4),
    const _Soon('Trabajo sin conexión'),
    const _Soon('Alarmas con la app cerrada'),
    const _Soon('WhatsApp Business y pagos en línea'),
    const _Soon('Libro de control de medicamentos controlados'),
    const SizedBox(height: 16),
  ];

  List<Widget> _plansChildren(ThemeData theme) => [
    Text('Planes', style: theme.textTheme.headlineSmall),
    const SizedBox(height: 8),
    const _Plan('Gratis', 'Para empezar.'),
    const _Plan('Individual', 'Para el MVZ independiente.'),
    const _Plan('Clínica', 'Para todo tu equipo.'),
    const SizedBox(height: 12),
    const Text('Beta cerrada. Planes y precios por anunciar.'),
    const SizedBox(height: 16),
  ];
}

class _Numbered extends StatelessWidget {
  const _Numbered(this.number, this.title, this.description);

  final int number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    minLeadingWidth: 24,
    leading: Text('$number', style: Theme.of(context).textTheme.titleMedium),
    title: Text(title),
    subtitle: description.isEmpty ? null : Text(description),
  );
}

class _Soon extends StatelessWidget {
  const _Soon(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    minLeadingWidth: 24,
    leading: const Icon(Icons.schedule_rounded, size: 20),
    title: Text(text),
  );
}

class _Plan extends StatelessWidget {
  const _Plan(this.name, this.description);

  final String name;
  final String description;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(title: Text(name), subtitle: Text(description)),
  );
}

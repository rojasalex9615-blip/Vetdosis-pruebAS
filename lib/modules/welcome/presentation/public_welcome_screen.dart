import 'package:flutter/material.dart';

import '../../../core/widgets/brand_gradient.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_theme.dart';
import '../../auth/presentation/auth_screen.dart';
import '../../auth/presentation/auth_view_model.dart';
import 'clinic_highlights.dart';
import 'welcome_intro_video.dart';
import '../../../vet_ui/vet_icons.dart';

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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      children: children,
    );
    return AccessBackdrop(
      child: Scaffold(
      backgroundColor: AccessBackdrop.appliesTo(context)
          ? Colors.transparent
          : null,
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
                                  VetIcons.dot,
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
      ),
    );
  }

  // La animación ya trae el logotipo y el lema, así que aquí no se repite la
  // marca estática: debajo va el titular, que es lo que lee el lector de
  // pantalla, y enseguida los dos accesos.
  List<Widget> _welcomeChildren(ThemeData theme) => [
    const WelcomeIntroVideo(),
    const SizedBox(height: 18),
    Text(
      'Bienvenido a VetDosis',
      textAlign: TextAlign.center,
      style: theme.textTheme.headlineMedium,
    ),
    const SizedBox(height: 10),
    Text(
      'Dosis, expedientes y equipo de tu clínica, en un solo lugar.',
      textAlign: TextAlign.center,
      style: theme.textTheme.titleMedium?.copyWith(color: VetColors.muted),
    ),
    const SizedBox(height: 22),
    FilledButton.icon(
      onPressed: () => _openAccess(context),
      icon: const Icon(VetIcons.login),
      label: const Text('Iniciar sesión'),
    ),
    const SizedBox(height: 10),
    OutlinedButton(
      onPressed: widget.auth == null
          ? null
          : () => _openAccess(context, register: true),
      child: const Text('Crear cuenta'),
    ),
    const SizedBox(height: 16),
  ];

  List<Widget> _descriptionChildren(ThemeData theme) => [
    const VetSectionHeader(
      title: 'Qué incluye VetDosis Pro',
      subtitle: 'Lo que ya puedes usar en la beta cerrada.',
      large: true,
    ),
    const _GroupLabel('Especies'),
    const _FeatureCard(
      icon: VetIcons.paw,
      accent: VetColors.turquoise,
      title: 'Pequeñas especies',
      description: 'Perro y gato, con dosis por peso y por especie.',
    ),
    const _FeatureCard(
      icon: VetIcons.tractor,
      accent: VetColors.mint,
      title: 'Producción animal',
      description: 'Avicultura e incubación. Bovinos, ovinos y cerdos '
          'próximamente.',
    ),
    const _FeatureCard(
      icon: VetIcons.leaf,
      accent: VetColors.cyan,
      title: 'Exóticos',
      description: 'Próximamente.',
    ),
    const SizedBox(height: 18),
    const _GroupLabel('Administración clínica'),
    const ClinicHighlights(),
    const SizedBox(height: 4),
    const _GroupLabel('Próximamente'),
    const _SoonList([
      'Trabajo sin conexión',
      'Alarmas con la app cerrada',
      'WhatsApp Business y pagos en línea',
      'Libro de control de medicamentos controlados',
    ]),
    const SizedBox(height: 16),
  ];

  List<Widget> _plansChildren(ThemeData theme) => [
    const VetSectionHeader(
      title: 'Planes',
      subtitle: 'Elige el alcance cuando abramos las altas.',
      large: true,
    ),
    const _Plan(
      icon: VetIcons.playCircle,
      accent: VetColors.turquoise,
      name: 'Gratis',
      description: 'Para empezar.',
    ),
    const _Plan(
      icon: VetIcons.user,
      accent: VetColors.violet,
      name: 'Individual',
      description: 'Para el MVZ independiente.',
    ),
    const _Plan(
      icon: VetIcons.usersGroup,
      accent: VetColors.purple,
      name: 'Clínica',
      description: 'Para todo tu equipo.',
    ),
    const SizedBox(height: 10),
    const VetNotice(
      text: 'Beta cerrada. Planes y precios por anunciar.',
      icon: VetIcons.lock,
    ),
    const SizedBox(height: 22),
    const _GroupLabel('Administración clínica'),
    const ClinicHighlights(),
    const SizedBox(height: 16),
  ];
}

/// Rótulo que abre un grupo de tarjetas dentro de una lámina.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: VetColors.muted,
        letterSpacing: 1.1,
      ),
    ),
  );
}

/// Tarjeta de una capacidad: cuadro de ícono tintado, título y apoyo.
class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: VetCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VetIconBox(icon: icon, accent: accent),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: VetColors.muted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lista de lo que aún no está, en una sola tarjeta para no competir en peso
/// visual con las capacidades que ya se pueden usar.
class _SoonList extends StatelessWidget {
  const _SoonList(this.items);

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return VetCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    VetIcons.clock,
                    size: 20,
                    color: VetColors.muted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(item, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Plan extends StatelessWidget {
  const _Plan({
    required this.icon,
    required this.accent,
    required this.name,
    required this.description,
  });

  final IconData icon;
  final Color accent;
  final String name;
  final String description;

  static const double _radius = 24;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      // Cada plan lleva el contorno y un halo leve de su propio color, segun
      // la referencia de Ale: asi los tres se distinguen de un vistazo y la
      // lamina de precios no es una pila de tarjetas iguales. El contorno va
      // en primer plano para no mover el contenido de la tarjeta.
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(color: accent.withValues(alpha: .7), width: 1.4),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: .34),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: VetCard(
        radius: _radius,
        child: Row(
          children: [
            VetIconBox(icon: icon, accent: accent),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: VetColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/widgets/neu_identity.dart';
import '../../auth/presentation/auth_screen.dart';
import '../../auth/presentation/auth_view_model.dart';
import '../../../vet_ui/vet_theme.dart';
import '../../../vet_ui/vet_components.dart';

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
      padding: const EdgeInsets.all(VetSpacing.xxl),
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
                  padding: const EdgeInsets.fromLTRB(
                    VetSpacing.lg,
                    VetSpacing.sm,
                    VetSpacing.lg,
                    VetSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Flexible(
                        child: _page > 0
                            ? TextButton(
                                onPressed: () => _turn(-1),
                                child: const Text('Anterior'),
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
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: i == _page ? 24 : 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: i == _page
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.outlineVariant,
                                    borderRadius:
                                        BorderRadius.circular(VetSpacing.radiusFull),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: _page < _pageCount - 1
                            ? FilledButton.tonal(
                                onPressed: () => _turn(1),
                                child: const Text('Siguiente'),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    VetSpacing.xxl,
                    0,
                    VetSpacing.xxl,
                    VetSpacing.md,
                  ),
                  child: Text(
                    _footer,
                    textAlign: TextAlign.center,
                    style: VetTypography.bodySmall,
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
    const SizedBox(height: VetSpacing.xs),
    const VetDosisBrand(large: true),
    const SizedBox(height: VetSpacing.lg),
    Text(
      'Bienvenido a VetDosis',
      textAlign: TextAlign.center,
      style: VetTypography.displaySmall,
    ),
    const SizedBox(height: VetSpacing.md),
    Text(
      'Dosis, expedientes y equipo de tu clínica, en un solo lugar.',
      textAlign: TextAlign.center,
      style: VetTypography.bodyLarge.copyWith(color: VetColors.muted),
    ),
    const SizedBox(height: VetSpacing.xl),
    VetActionButton(
      label: 'Iniciar sesión',
      icon: Icons.login,
      onPressed: () => _openAccess(context),
      fullWidth: true,
    ),
    const SizedBox(height: VetSpacing.sm),
    VetSecondaryButton(
      label: 'Crear cuenta',
      onPressed: widget.auth == null
          ? null
          : () => _openAccess(context, register: true),
      fullWidth: true,
    ),
    const SizedBox(height: VetSpacing.lg),
  ];

  List<Widget> _descriptionChildren(ThemeData theme) => [
    Text('Qué incluye VetDosis Pro', style: VetTypography.headlineMedium),
    const SizedBox(height: VetSpacing.lg),
    _FeatureSection(
      title: 'Especies',
      items: const [
        _FeatureItem(1, 'Pequeñas especies', ''),
        _FeatureItem(
          2,
          'Producción animal',
          'Avicultura e incubación. Bovinos, ovinos y cerdos próximamente.',
        ),
        _FeatureItem(3, 'Exóticos', 'Próximamente.'),
      ],
    ),
    const SizedBox(height: VetSpacing.lg),
    _FeatureSection(
      title: 'Administración clínica',
      items: const [
        _FeatureItem(
          1,
          'Cálculos con criterio',
          'Dosis por especie y por kg, fluidoterapia y productos comerciales. '
              'Vademécum con fuentes. Tú validas, la app te ahorra el error.',
        ),
        _FeatureItem(
          2,
          'Pacientes y hospitalización',
          'Expedientes, agenda, recetas y consentimientos en PDF. '
              'Seguimiento de hospitalizados con recordatorios.',
        ),
        _FeatureItem(
          3,
          'Inventario y caja',
          'Escáner de códigos y lectura de etiquetas. Ventas, crédito, abonos y '
              'promociones.',
        ),
        _FeatureItem(
          4,
          'Tu clínica como negocio',
          'Dashboard, planeación financiera en pesos, punto de equilibrio. Equipo '
              'con permisos, asistencia, horarios, mensajes, avisos, tablón de '
              'notas y comisiones.',
        ),
        _FeatureItem(
          5,
          'IA que asiste, no decide',
          'Borradores, dictado por voz y lectura de etiquetas. Siempre con tu '
              'revisión profesional.',
        ),
      ],
    ),
    const SizedBox(height: VetSpacing.lg),
    _FeatureSection(
      title: 'Próximamente',
      items: const [
        _FeatureItem(0, 'Trabajo sin conexión', ''),
        _FeatureItem(0, 'Alarmas con la app cerrada', ''),
        _FeatureItem(0, 'WhatsApp Business y pagos en línea', ''),
        _FeatureItem(0, 'Libro de control de medicamentos controlados', ''),
      ],
      showNumbers: false,
      icon: Icons.schedule_rounded,
    ),
    const SizedBox(height: VetSpacing.lg),
  ];

  List<Widget> _plansChildren(ThemeData theme) => [
    Text('Planes', style: VetTypography.headlineMedium),
    const SizedBox(height: VetSpacing.md),
    _PlanCard(name: 'Gratis', description: 'Para empezar.', accent: VetColors.mint),
    const SizedBox(height: VetSpacing.md),
    _PlanCard(
      name: 'Individual',
      description: 'Para el MVZ independiente.',
      accent: VetColors.turquoise,
    ),
    const SizedBox(height: VetSpacing.md),
    _PlanCard(
      name: 'Clínica',
      description: 'Para todo tu equipo.',
      accent: VetColors.purple,
    ),
    const SizedBox(height: VetSpacing.lg),
    Text(
      'Beta cerrada. Planes y precios por anunciar.',
      style: VetTypography.bodyMedium.copyWith(color: VetColors.muted),
      textAlign: TextAlign.center,
    ),
    const SizedBox(height: VetSpacing.lg),
  ];
}

class _FeatureSection extends StatelessWidget {
  const _FeatureSection({
    required this.title,
    required this.items,
    this.showNumbers = true,
    this.icon,
  });
  final String title;
  final List<_FeatureItem> items;
  final bool showNumbers;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: VetColors.muted),
            const SizedBox(width: VetSpacing.sm),
          ],
          Text(title, style: VetTypography.headlineSmall),
        ],
      ),
      const SizedBox(height: VetSpacing.md),
      for (final item in items) ...[
        _FeatureTile(item: item, showNumber: showNumbers),
        const SizedBox(height: VetSpacing.sm),
      ],
    ],
  );
}

class _FeatureItem {
  const _FeatureItem(this.number, this.title, this.description);
  final int number;
  final String title;
  final String description;
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.item, required this.showNumber});
  final _FeatureItem item;
  final bool showNumber;

  @override
  Widget build(BuildContext context) => VetCard(
    padding: const EdgeInsets.all(VetSpacing.md),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showNumber) ...[
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: VetColors.purple.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(VetSpacing.radiusMd),
            ),
            alignment: Alignment.center,
            child: Text(
              '${item.number}',
              style: VetTypography.labelMedium.copyWith(
                color: VetColors.purple,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: VetSpacing.md),
        ] else ...[
          Icon(Icons.schedule_rounded, size: 20, color: VetColors.muted),
          const SizedBox(width: VetSpacing.md),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: VetTypography.titleMedium),
              if (item.description.isNotEmpty) ...[
                const SizedBox(height: VetSpacing.xs),
                Text(item.description, style: VetTypography.bodySmall),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.name,
    required this.description,
    required this.accent,
  });
  final String name;
  final String description;
  final Color accent;

  @override
  Widget build(BuildContext context) => VetCard(
    padding: const EdgeInsets.all(VetSpacing.lg),
    elevated: true,
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(VetSpacing.radiusMd),
          ),
          child: Icon(Icons.workspace_premium_outlined, color: accent, size: 24),
        ),
        const SizedBox(width: VetSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: VetTypography.headlineSmall.copyWith(color: accent)),
              const SizedBox(height: VetSpacing.xs),
              Text(description, style: VetTypography.bodyMedium),
            ],
          ),
        ),
        Icon(Icons.chevron_right, color: VetColors.muted),
      ],
    ),
  );
}

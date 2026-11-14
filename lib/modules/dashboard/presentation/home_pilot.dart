import '../../../core/widgets/accent_glow.dart';
import '../../../core/widgets/contrast.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/workspace_panel.dart';
import '../../../core/widgets/neu_identity.dart';
import '../../../vet_ui/vet_theme.dart';
import '../../core/presentation/core_view_model.dart';
import '../../../vet_ui/vet_icons.dart';

/// Shared shell presentation. It never changes membership or access.
ThemeData homePilotTheme(ThemeData base) {
  // The functional home shell must preserve the selected Neu palette.
  if (base.extension<WorkspaceStyle>()?.neumorphic == true) {
    return base.copyWith(
      drawerTheme: base.drawerTheme.copyWith(
        backgroundColor: base.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        backgroundColor: base.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: base.scaffoldBackgroundColor,
        foregroundColor: base.colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
  // Clásico already has the exact palette and non-neumorphic style selected
  // in VetDosisApp; never silently replace them with Neu overrides.
  return base;
}

/// Tarjeta de fondo de los bloques del Inicio, con su relieve y su borde.
class HomeSurface extends StatelessWidget {
  const HomeSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.selected = false,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool selected;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return AccentGlow(
      color: theme.colorScheme.primary,
      enabled: selected,
      emphasis: .65,
      radius: 24,
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: .08)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          // En Neu solo la tarjeta elegida lleva trazo; las demas se
          // distinguen por el relieve, como en las referencias.
          border: selected
              ? Border.all(color: theme.colorScheme.primary)
              : theme.extension<WorkspaceStyle>()?.neumorphic == true
              ? null
              : Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: .5),
                ),
          boxShadow: theme.extension<WorkspaceStyle>()?.neumorphic == true
              ? neuShadows(dark)
              : [
                  BoxShadow(
                    color: dark ? Colors.black26 : const Color(0xFFDDE4EE),
                    offset: const Offset(5, 6),
                    blurRadius: 14,
                  ),
                  BoxShadow(
                    color: dark ? VetColors.darkHighlight : Colors.white,
                    offset: const Offset(-4, -4),
                    blurRadius: 12,
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Selector del area clinica en la que se esta trabajando.
class HomePracticeSelector extends StatelessWidget {
  const HomePracticeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  final ClinicalBranch selected;
  final ValueChanged<ClinicalBranch> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Selecciona tu tipo de práctica',
        style: Theme.of(context).textTheme.labelLarge,
      ),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.4;
          final columns = largeText || constraints.maxWidth < 280 ? 1 : 3;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final branch in ClinicalBranch.values.where(
                (b) => b != ClinicalBranch.management,
              ))
                SizedBox(
                  width: (constraints.maxWidth - 12 * (columns - 1)) / columns,
                  child: Semantics(
                    selected: branch == selected,
                    button: true,
                    child: HomeSurface(
                      padding: EdgeInsets.zero,
                      selected: branch == selected,
                      child: InkWell(
                        onTap: () => onChanged(branch),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 18,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 80),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  branch.icon,
                                  color: branch == selected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  switch (branch) {
                                    ClinicalBranch.small => 'Pequeñas especies',
                                    ClinicalBranch.exotic => 'Exóticos',
                                    _ => 'Producción y grandes especies',
                                  },
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () => onChanged(ClinicalBranch.management),
          icon: Icon(
            selected == ClinicalBranch.management
                ? VetIcons.checkCircle
                : VetIcons.clinic,
          ),
          label: const Text('Gestión clínica'),
        ),
      ),
    ],
  );
}

/// Rejilla de accesos a los modulos disponibles en el Inicio.
class HomeModuleGrid extends StatelessWidget {
  const HomeModuleGrid({
    super.key,
    required this.actions,
    required this.onNavigate,
    this.details = const {},
  });
  final List<(String, String)> actions;

  /// Linea de apoyo bajo el nombre de cada modulo, por pagina de destino.
  ///
  /// Solo se pinta la de los modulos que traen una: un dato consultado
  /// («12 activos») o una pista de para que sirve. Nunca una cifra inventada.
  final Map<String, String> details;
  final ValueChanged<String> onNavigate;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final columns = constraints.maxWidth >= 320 && scale < 1.4
          ? 3
          : constraints.maxWidth >= 260 && scale < 1.8
          ? 2
          : 1;
      return Wrap(
        spacing: 12,
        runSpacing: 16,
        children: [
          for (var i = 0; i < actions.length; i++)
            SizedBox(
              width: (constraints.maxWidth - 12 * (columns - 1)) / columns,
              child: HomeSurface(
                padding: EdgeInsets.zero,
                child: InkWell(
                  onTap: () => onNavigate(actions[i].$2),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 132),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 16,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Cada modulo con su tono, no todos con el mismo
                          // lavanda y el mismo primary: asi se distinguen de
                          // un vistazo, que es para lo que esta la cuadricula.
                          Builder(
                            builder: (context) {
                              final tono = sectionAccent(actions[i].$2);
                              final placa = _placa(context, tono);
                              return AccentGlow(
                                color: tono,
                                radius: 16,
                                emphasis: .35,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: placa,
                                    borderRadius: BorderRadius.circular(16),
                                    // La placa se levanta un punto sobre la
                                    // tarjeta, como en las referencias.
                                    boxShadow:
                                        Theme.of(context)
                                                .extension<WorkspaceStyle>()
                                                ?.neumorphic ==
                                            true
                                        ? neuShadows(
                                            Theme.of(context).brightness ==
                                                Brightness.dark,
                                            depth: .45,
                                          )
                                        : null,
                                  ),
                                  // Los tonos de marca son claros: sobre su
                                  // propia placa el glifo se oscurece lo justo
                                  // para ser legible, como en las cifras.
                                  child: Icon(
                                    sectionIcon(actions[i].$2),
                                    color: readableOn(tono, placa),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(
                            actions[i].$1,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  fontSize: 13,
                                  letterSpacing: 0,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          if (details[actions[i].$2] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                details[actions[i].$2]!,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      fontSize: 11,
                                      letterSpacing: 0,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

/// Fondo real de la tarjeta de un modulo: su color de marca, translucido,
/// compuesto sobre la superficie. El contraste del icono se mide contra esto.
Color _placa(BuildContext context, Color color) => composite(
  color,
  Theme.of(context).brightness == Brightness.dark ? .14 : .10,
  Theme.of(context).colorScheme.surface,
);

/// Resumen del Inicio: las cifras del espacio y el grafico de la semana.
///
/// Cada cifra lleva el color de su modulo, retocado si hiciera falta para
/// que el icono se distinga sobre su propia tarjeta tenida.
class HomeSummary extends StatelessWidget {
  const HomeSummary({super.key, required this.metrics, this.activity});

  /// Cada tarjeta del resumen: etiqueta, valor, icono y color de identidad.
  ///
  /// El color tine la tarjeta y pinta el glifo; el tono que acaba en pantalla
  /// se mide contra esa tarjeta ya tenida, no contra el lienzo.
  final List<(String, String, IconData, Color)> metrics;
  final List<(String, int)>? activity;
  @override
  Widget build(BuildContext context) => HomeSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Tu espacio en cifras',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        const Text('Datos consultados · según tus permisos'),
        const SizedBox(height: 16),
        if (metrics.isEmpty)
          const Text('Elige un espacio con acceso para consultar su resumen.'),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns =
                constraints.maxWidth >= 380 &&
                    MediaQuery.textScalerOf(context).scale(1) < 1.25
                ? 4
                : constraints.maxWidth >= 240 &&
                      MediaQuery.textScalerOf(context).scale(1) < 1.6
                ? 2
                : 1;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final metric in metrics)
                  SizedBox(
                    width:
                        (constraints.maxWidth - 12 * (columns - 1)) / columns,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        // Cada modulo lleva su color de la paleta de marca en
                        // lugar de un unico primary, para distinguirlos de un
                        // vistazo igual que en el prototipo.
                        color: _placa(context, metric.$4),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      // Centrada y con el icono dentro de su cuadrado
                      // redondeado, igual que los modulos de abajo: antes el
                      // glifo iba suelto y todo alineado a la izquierda, y las
                      // dos rejillas de Inicio no se parecian entre si.
                      child: Column(
                        children: [
                          Builder(
                            builder: (context) {
                              // El glifo ya no se apoya en la placa de la
                              // tarjeta sino en su propio cuadrado, que lleva
                              // un paso mas de tinte. El fondo se compone
                              // opaco sobre la placa, y la tinta se mide
                              // contra ese fondo real: medir contra la placa
                              // dejaba el icono por debajo de 3:1 encima del
                              // cuadrado que de verdad tiene detras.
                              final placa = _placa(context, metric.$4);
                              final caja = composite(metric.$4, .18, placa);
                              return Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: caja,
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: Icon(
                                  metric.$3,
                                  color: readableOn(metric.$4, caja),
                                  size: 22,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            metric.$2,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            metric.$1,
                            textAlign: TextAlign.center,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(letterSpacing: 0),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        if (activity != null) ...[
          const SizedBox(height: 20),
          const Text('Citas consultadas · últimos 7 días'),
          const SizedBox(height: 12),
          if (activity!.every((day) => day.$2 == 0))
            const Text('Sin citas en los datos consultados de este periodo.')
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (MediaQuery.textScalerOf(context).scale(1) > 1.5) {
                  return Wrap(
                    spacing: 12,
                    children: [
                      for (final day in activity!) Text('${day.$1}: ${day.$2}'),
                    ],
                  );
                }
                final max = activity!
                    .map((e) => e.$2)
                    .reduce((a, b) => a > b ? a : b);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final day in activity!)
                      Expanded(
                        child: Semantics(
                          label: '${day.$1}: ${day.$2} citas',
                          child: ExcludeSemantics(
                            child: Column(
                              children: [
                                Text(
                                  '${day.$2}',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                                const SizedBox(height: 4),
                                // Barra ancha y redondeada con el
                                // recorrido de marca; el dia de mas citas va
                                // a pleno y el resto algo mas tenue. Los dias
                                // sin citas dejan solo una marca palida.
                                Container(
                                  width: 18,
                                  height: day.$2 == 0
                                      ? 8
                                      : 18 + 78 * day.$2 / max,
                                  decoration: BoxDecoration(
                                    color: day.$2 == 0
                                        ? Theme.of(context)
                                              .colorScheme
                                              .outlineVariant
                                              .withValues(alpha: .55)
                                        : null,
                                    gradient: day.$2 == 0
                                        ? null
                                        : LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              for (final tono in const [
                                                VetColors.violet,
                                                VetColors.brandSky,
                                                VetColors.turquoise,
                                              ])
                                                tono.withValues(
                                                  alpha: day.$2 == max
                                                      ? 1
                                                      : .72,
                                                ),
                                            ],
                                          ),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  day.$1,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        fontWeight: day.$2 == max && max > 0
                                            ? FontWeight.w800
                                            : null,
                                        color: day.$2 == max && max > 0
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : null,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ],
    ),
  );
}

/// Renglon de una cita dentro de un apartado del Inicio.
///
/// Sigue la referencia de «Proximas citas»: una tarjeta baja con una barra
/// de color a la izquierda, el paciente y su detalle, y a la derecha una
/// etiqueta corta (la hora o el estado). Los textos los decide quien llama;
/// aqui solo se les da forma.
class HomeAppointmentRow extends StatelessWidget {
  const HomeAppointmentRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.color,
    this.tag,
    this.onTap,
  });
  final String title, subtitle;
  final String? tag;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final neu = theme.extension<WorkspaceStyle>()?.neumorphic == true;
    final surface = theme.colorScheme.surface;
    final chip = composite(color, dark ? .22 : .16, surface);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: neu ? neuShadows(dark, depth: .6) : null,
        ),
        child: Material(
          color: surface,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: readableOn(color, surface),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (tag != null) ...[
                      const SizedBox(width: 8),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: chip,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            tag!,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: inkOn(chip),
                            ),
                          ),
                        ),
                      ),
                    ],
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

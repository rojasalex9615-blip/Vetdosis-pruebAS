import '../core/widgets/accent_glow.dart';
import '../core/widgets/neu_identity.dart';
import '../core/widgets/workspace_panel.dart';
import 'package:flutter/material.dart';

import 'vet_theme.dart';
import 'vet_icons.dart';

enum VetActionStyle { primary, secondary, neutral, destructive }

enum VetBadgeKind { information, success, warning, danger, unverified }

class VetCard extends StatelessWidget {
  const VetCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    // El orden importa, y antes estaba mal: el Material recortaba DENTRO del
    // padding con el radio exterior, asi que la curva de la esquina mordia la
    // caja de contenido. El primer hijo perdia su esquina superior izquierda y
    // «Tu agenda» se pintaba como «Íu agenda». Medido: de 26 filas de la
    // primera linea, 24 quedaban fuera del recorte.
    //
    // Ahora, de fuera adentro: la sombra, que debe quedar FUERA del recorte o
    // se corta; el recorte, sobre el borde real de la tarjeta; y dentro la
    // superficie con su borde y el padding, que es lo que separa el contenido
    // de las curvas. El recorte sigue existiendo para que las ondas del
    // InkWell no se salgan, que es para lo que estaba.
    final forma = BorderRadius.circular(radius);
    // VetCard no era neu, y es la tarjeta que mas se usa (16 sitios: las
    // tarjetas de Secciones, Produccion, Porcinos, Agenda y Operaciones).
    // Llevaba UNA sombra abajo a la derecha, que es la elevacion de Material,
    // y encima un borde visible. Resultado: se dibujaba con un trazo y una
    // sombra plana en medio de una pantalla que se levanta con relieve, y por
    // eso se veia como de otro sistema.
    //
    // En neu pasa al par de sombras del sistema y pierde el trazo. El borde no
    // se quita, se vuelve transparente: ocupa 1 px y de el salia el padding
    // efectivo de 17 en vez de 16, asi que borrarlo moveria el contenido de
    // las 16 tarjetas y las pruebas de ancho que ya existen.
    //
    // El clasico se queda exactamente como estaba: es otro estilo, no una
    // version a medias de este.
    final neu = theme.extension<WorkspaceStyle>()?.neumorphic == true;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: forma,
        boxShadow: neu
            ? neuShadows(dark)
            : [
                BoxShadow(
                  color: dark ? Colors.black26 : VetColors.softShadow,
                  offset: const Offset(3, 4),
                  blurRadius: 10,
                ),
              ],
      ),
      // La superficie va en el propio Material, no en un Container de dentro.
      // ListTile pinta su fondo y sus ondas sobre el Material mas cercano, asi
      // que un color intermedio se los tapa, y el framework lo detecta
      // (_debugCheckBackgroundIsHidden salta con cualquier DecoratedBox
      // intermedio de color opaco). El de aqui dentro lleva solo el borde, que
      // no cuenta como fondo.
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: forma,
        clipBehavior: Clip.antiAlias,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: forma,
            border: Border.all(
              color: neu ? Colors.transparent : theme.colorScheme.outlineVariant,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class VetActionButton extends StatelessWidget {
  const VetActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = VetActionStyle.primary,
    this.loading = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final VetActionStyle style;
  final bool loading;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (background, foreground) = switch (style) {
      VetActionStyle.primary => (colors.primary, colors.onPrimary),
      VetActionStyle.secondary => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
      VetActionStyle.neutral => (colors.surfaceContainerLow, colors.onSurface),
      VetActionStyle.destructive => (colors.error, colors.onError),
    };
    return AccentGlow(
      color: background,
      enabled: !loading && onPressed != null && style != VetActionStyle.neutral,
      emphasis: .8,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          backgroundBuilder: plainButtonLayer,
          elevation: 0,
          shadowColor: Colors.transparent,
          foregroundColor: foreground,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (icon != null)
              Icon(icon, size: 20),
            if (icon != null || loading) const SizedBox(width: 8),
            Flexible(child: Text(label, textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
  }
}

class VetStatusBadge extends StatelessWidget {
  const VetStatusBadge({
    super.key,
    required this.label,
    this.kind = VetBadgeKind.information,
  });
  final String label;
  final VetBadgeKind kind;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = switch (kind) {
      VetBadgeKind.information => Theme.of(context).colorScheme.primary,
      VetBadgeKind.success =>
        dark ? const Color(0xFF7DE1B8) : VetColors.success,
      VetBadgeKind.warning =>
        dark ? const Color(0xFFFFD580) : VetColors.warning,
      VetBadgeKind.danger => Theme.of(context).colorScheme.error,
      VetBadgeKind.unverified => Theme.of(context).colorScheme.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class VetModuleTile extends StatelessWidget {
  const VetModuleTile({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.accent = VetColors.turquoise,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => VetCard(
    padding: EdgeInsets.zero,
    radius: 20,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 112),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AccentGlow(
                  color: accent,
                  radius: 14,
                  emphasis: 1,
                  enabled: onTap != null,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: accent),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class VetPracticeSelector extends StatelessWidget {
  const VetPracticeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  final int selected;
  final ValueChanged<int> onChanged;
  static const labels = ['Pequeñas especies', 'Exóticos', 'Producción'];
  static const icons = [
    VetIcons.paw,
    VetIcons.rabbit,
    VetIcons.tractor,
  ];
  @override
  Widget build(BuildContext context) => Row(
    children: List.generate(3, (i) {
      final active = i == selected;
      return Expanded(
        child: Padding(
          padding: EdgeInsets.only(right: i == 2 ? 0 : 8),
          child: Semantics(
            selected: active,
            button: true,
            label: labels[i],
            child: Material(
              color: active
                  ? VetColors.lavender.withValues(alpha: .22)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => onChanged(i),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 84),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: active ? VetColors.purple : VetColors.softShadow,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AccentIcon(
                        icons[i],
                        enabled: active,
                        emphasis: .75,
                        color: active ? VetColors.purple : VetColors.turquoise,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        labels[i],
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: active
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }),
  );
}

class VetKpiCard extends StatelessWidget {
  const VetKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accent = VetColors.purple,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  @override
  Widget build(BuildContext context) => VetCard(
    radius: 16,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    child: Column(
      children: [
        AccentIcon(icon, color: accent, size: 24),
        const SizedBox(height: 7),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

/// Cuadro tintado con ícono para el icono de un módulo, sección o especie.
class VetIconBox extends StatelessWidget {
  const VetIconBox({
    super.key,
    required this.icon,
    this.accent = VetColors.turquoise,
    this.size = 44,
  });
  final IconData icon;
  final Color accent;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: accent.withValues(alpha: .15),
      borderRadius: BorderRadius.circular(size * .32),
    ),
    child: Icon(icon, color: accent, size: size * .52),
  );
}

/// Título de pantalla o de bloque con una línea de apoyo opcional.
/// Con [icon] el encabezado lleva delante un cuadro tintado, que es lo que
/// permite encontrar donde empieza cada bloque sin leerlo. En una pantalla
/// larga —Caja, Formatos— el ojo salta de cuadro en cuadro; sin el hay que
/// recorrer el texto para saber si una linea es titulo o parrafo.
///
/// [step] pinta el numero dentro del cuadro en lugar del icono, para las
/// pantallas que van por pasos numerados.
class VetSectionHeader extends StatelessWidget {
  const VetSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.large = false,
    this.icon,
    this.step,
    this.accent,
  }) : assert(
         icon == null || step == null,
         'El cuadro pinta el numero o el icono, no los dos.',
       );
  final String title;
  final String? subtitle;
  final bool large;

  /// Icono del cuadro tintado que abre el bloque.
  final IconData? icon;

  /// Numero del paso, si el bloque es un paso de un recorrido.
  final int? step;

  /// Tono del cuadro. Por omision el primario del tema.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    // El apoyo no lleva el gris fijo de antes: sobre el fondo oscuro
    // #201F25 ese gris queda en 3.6:1, por debajo del minimo de texto. El del
    // esquema se adapta a los dos modos.
    final supportColor = theme.colorScheme.onSurfaceVariant;
    final boxAccent = accent ?? theme.colorScheme.primary;
    final titleStyle = large ? textTheme.headlineSmall : textTheme.titleMedium;
    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: titleStyle),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          // La indicacion va chica y en otro tono, no solo en otra linea.
          // Con el mismo cuerpo y el mismo gris que el resto, el titulo y su
          // explicacion se leian como un bloque y no como dos cosas.
          Text(
            subtitle!,
            style: textTheme.bodySmall?.copyWith(color: supportColor),
          ),
        ],
      ],
    );
    final boxSize = large ? 44.0 : 36.0;
    final Widget? box = switch ((icon, step)) {
      (final IconData i, _) => VetIconBox(
        icon: i,
        accent: boxAccent,
        size: boxSize,
      ),
      (_, final int n) => Container(
        width: boxSize,
        height: boxSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: boxAccent.withValues(alpha: .15),
          borderRadius: BorderRadius.circular(boxSize * .32),
        ),
        child: Text(
          '$n',
          style: textTheme.titleMedium?.copyWith(color: boxAccent),
        ),
      ),
      _ => null,
    };
    // Un paso numerado en Neu es una tarjeta, como en las referencias de
    // Ale: el cuadro y el titulo arriba, y la explicacion debajo a todo el
    // ancho en vez de apretada junto al cuadro. Los bloques sin numero
    // siguen siendo un titulo suelto.
    if (step != null &&
        box != null &&
        theme.extension<WorkspaceStyle>()?.neumorphic == true) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: VetCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  box,
                  const SizedBox(width: 14),
                  Expanded(child: Text(title, style: textTheme.titleLarge)),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 12),
                Text(
                  subtitle!,
                  style: textTheme.bodyMedium?.copyWith(color: supportColor),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: box == null
          ? texts
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                box,
                const SizedBox(width: 12),
                Expanded(child: texts),
              ],
            ),
    );
  }
}

/// Aviso con ícono para notas de contexto, límites o accesos no habilitados.
class VetNotice extends StatelessWidget {
  const VetNotice({
    super.key,
    required this.text,
    this.icon = VetIcons.info,
    this.kind = VetBadgeKind.information,
  });
  final String text;
  final IconData icon;
  final VetBadgeKind kind;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (kind) {
      VetBadgeKind.information => scheme.primary,
      VetBadgeKind.success => VetColors.success,
      VetBadgeKind.warning => VetColors.warning,
      VetBadgeKind.danger => scheme.error,
      VetBadgeKind.unverified => scheme.onSurfaceVariant,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// Un valor de referencia con su procedencia.
///
/// Un mismo dato clinico suele tener mas de una referencia legitima segun la
/// fuente, la edad o el manejo: la frecuencia cardiaca del perro adulto no es
/// la del cachorro, y la lactancia porcina son 21 dias en NRC 2012 y 28 en el
/// ciclo de clase. Mezclarlas en una sola cifra pierde informacion; elegir una
/// por el usuario decide por el. Se muestran todas, cada una con su cita.
class VetReferenceValue {
  const VetReferenceValue(this.value, {this.qualifier, this.source});

  /// El rango o la cifra, ya formateado: «60 – 140 lpm», «21 d».
  final String value;

  /// A que caso aplica, si no es el general: «Cachorros», «Razas gigantes».
  final String? qualifier;

  /// De donde sale este valor en concreto, no el bloque entero.
  final String? source;
}

/// Un dato con sus referencias.
class VetReferenceRow {
  const VetReferenceRow({
    required this.label,
    required this.values,
    this.icon,
    this.note,
  });
  final String label;
  final List<VetReferenceValue> values;
  final IconData? icon;
  final String? note;
}

/// Tarjeta de valores de referencia, para mostrar bajo un resultado.
///
/// La cita va en letra pequena y pegada a su valor, no al pie de la tarjeta:
/// con una sola nota al final no se sabe que dato viene de donde, que es justo
/// lo que hay que poder distinguir cuando las fuentes no concuerdan.
class VetReferenceCard extends StatelessWidget {
  const VetReferenceCard({
    super.key,
    required this.title,
    required this.rows,
    this.subtitle,
    this.badge = 'Valores de referencia',
    this.badgeKind = VetBadgeKind.unverified,
  });
  final String title;
  final String? subtitle;
  final List<VetReferenceRow> rows;
  final String? badge;
  final VetBadgeKind badgeKind;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tenue = Theme.of(context).colorScheme.onSurfaceVariant;
    return VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: textTheme.titleMedium),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: textTheme.bodySmall?.copyWith(color: tenue),
                      ),
                    ],
                  ],
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                VetStatusBadge(label: badge!, kind: badgeKind),
              ],
            ],
          ),
          const SizedBox(height: 12),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (row.icon != null) ...[
                        Icon(row.icon, size: 18, color: tenue),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(row.label, style: textTheme.titleSmall),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (final ref in row.values)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, left: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                if (ref.qualifier != null)
                                  TextSpan(
                                    text: '${ref.qualifier}: ',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: tenue,
                                    ),
                                  ),
                                TextSpan(
                                  text: ref.value,
                                  style: textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          if (ref.source != null)
                            Text(
                              ref.source!,
                              style: textTheme.labelSmall?.copyWith(
                                color: tenue,
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (row.note != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      row.note!,
                      style: textTheme.bodySmall?.copyWith(color: tenue),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

import '../../vet_ui/vet_theme.dart';
import 'neu_identity.dart';
import 'package:flutter/material.dart';
import '../../vet_ui/vet_icons.dart';

class WorkspaceStyle extends ThemeExtension<WorkspaceStyle> {
  const WorkspaceStyle({required this.neumorphic});
  final bool neumorphic;
  @override
  WorkspaceStyle copyWith({bool? neumorphic}) =>
      WorkspaceStyle(neumorphic: neumorphic ?? this.neumorphic);
  @override
  WorkspaceStyle lerp(covariant WorkspaceStyle? other, double t) =>
      t < .5 ? this : other ?? this;
}

class WorkspacePanel extends StatelessWidget {
  const WorkspacePanel({
    super.key,
    required this.child,
    this.radius = 24,
    this.depth = 1,
    this.softLighting = false,
  });
  final double radius, depth;
  final bool softLighting;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.extension<WorkspaceStyle>()?.neumorphic != true) {
      return Card(child: child);
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: neuShadows(
          theme.brightness == Brightness.dark,
          depth: depth,
        ),
        gradient: softLighting
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(
                    theme.scaffoldBackgroundColor,
                    Colors.white,
                    theme.brightness == Brightness.dark ? .025 : .28,
                  )!,
                  theme.scaffoldBackgroundColor,
                ],
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

/// Color de marca de cada seccion, para distinguirlas de un vistazo.
///
/// Vive junto a [sectionIcon] y no dentro de una pantalla porque lo usan el
/// panel, la cuadricula de modulos de Inicio y las cifras del espacio. Antes
/// la cuadricula pintaba todos los modulos con el mismo lavanda y el mismo
/// primary, asi que se veian identicos, mientras el panel tenia su propia
/// tabla aparte: dos tablas en paralelo para lo mismo.
///
/// Las familias se agrupan por cercania clinica, no por capricho: lo que se
/// consulta sobre el animal en turquesa y menta, lo que mueve existencias en
/// cian, lo administrativo en violetas.
Color sectionAccent(String page) => switch (page) {
  'Pacientes' => VetColors.turquoise,
  'Hospitalización' => VetColors.mint,
  'Agenda' || 'Checado' => VetColors.violet,
  'Inventario' => VetColors.cyan,
  'Receta' || 'Recetas' => VetColors.lilac,
  'Cálculo rápido' ||
  'Cálculos' ||
  'Operaciones de dosis' ||
  'Vademécum' => VetColors.brandSky,
  'Cálculos clínicos' => VetColors.purple,
  'Escanear producto' => VetColors.purpleDeep,
  'Estadísticas' || 'Respaldo' || 'Estadísticas y respaldo' => VetColors.violet,
  'Caja' || 'Planeación financiera' => VetColors.brandAqua,
  'Formatos' => VetColors.lavender,
  _ => VetColors.lilac,
};

IconData sectionIcon(String page) => switch (page) {
  'Inicio' => VetIcons.dashboard,
  'Cálculos' ||
  'Cálculo rápido' ||
  'Vademécum' ||
  'Operaciones de dosis' => VetIcons.calculator,
  'Cálculos clínicos' => VetIcons.flask,
  'Escanear producto' => VetIcons.qrScan,
  'Hospitalización' => VetIcons.hospital,
  'Pacientes' => VetIcons.paw,
  'Formatos' => VetIcons.folder,
  'Receta' || 'Recetas' => VetIcons.document,
  'Agenda' => VetIcons.calendar,
  'Checado' => VetIcons.idBadge,
  'Asistente IA' => VetIcons.sparkles,
  'Planes' => VetIcons.certificate,
  'Producto y costos' => VetIcons.info,
  'Inicio guiado' => VetIcons.compass,
  'Ayuda y soporte' => VetIcons.help,
  'Estadísticas' => VetIcons.barChart,
  'Respaldo' || 'Estadísticas y respaldo' => VetIcons.cloudUpload,
  'Planeación financiera' => VetIcons.trendingUp,
  'Caja' => VetIcons.cashRegister,
  'Equipo y avisos' || 'Pendientes del equipo' => VetIcons.chats,
  'Inventario' => VetIcons.box,
  'Ajustes' => VetIcons.sliders,
  _ => VetIcons.grid,
};

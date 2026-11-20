import 'package:flutter/material.dart';

import '../../../vet_ui/vet_theme.dart';
import '../../../vet_ui/vet_components.dart';

const productTools = <_ProductTool>[
  _ProductTool(
    'Cálculos y dosis',
    'Peso, especie y presentación; cálculos separados de la interfaz.',
    'Cálculo rápido',
    Icons.calculate_outlined,
    VetColors.purple,
  ),
  _ProductTool(
    'Pacientes y expedientes',
    'Historia clínica, peso y seguimiento del paciente.',
    'Pacientes',
    Icons.pets_outlined,
    VetColors.turquoise,
  ),
  _ProductTool(
    'Hospitalización',
    'Tratamientos, responsables y avisos programados.',
    'Hospitalización',
    Icons.local_hospital_outlined,
    VetColors.mint,
  ),
  _ProductTool(
    'Formatos y recetas',
    'Plantillas por clínica, firma y PDF para revisión.',
    'Formatos',
    Icons.description_outlined,
    VetColors.lavender,
  ),
  _ProductTool(
    'Inventario y caja',
    'Lotes, caducidades, ventas y pagos manuales.',
    'Inventario',
    Icons.inventory_2_outlined,
    VetColors.cyan,
  ),
  _ProductTool(
    'Agenda y equipo',
    'Citas, estética, servicios y organización por permisos.',
    'Agenda',
    Icons.calendar_month_outlined,
    VetColors.lilac,
  ),
  _ProductTool(
    'Asistente IA',
    'Ayuda de uso incluida por temas; chat con proveedor propio, historial y contexto optativos.',
    'Asistente IA',
    Icons.auto_awesome,
    VetColors.violet,
  ),
  _ProductTool(
    'Respaldo y reportes',
    'Exportación operacional y estadísticas por permisos.',
    'Estadísticas y respaldo',
    Icons.backup_outlined,
    VetColors.pink,
  ),
];

class _ProductTool {
  const _ProductTool(this.title, this.description, this.route, this.icon, this.accent);
  final String title;
  final String description;
  final String route;
  final IconData icon;
  final Color accent;
}

class ProductScreen extends StatelessWidget {
  const ProductScreen({super.key, this.onNavigate});
  final void Function(String)? onNavigate;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('VetDosis Pro', style: VetTypography.displaySmall),
      const SizedBox(height: VetSpacing.xs),
      Text(
        'Tu trabajo veterinario, organizado en un mismo espacio.',
        style: VetTypography.bodyLarge.copyWith(color: VetColors.muted),
      ),
      const SizedBox(height: VetSpacing.md),
      Text(
        'Para México, en Android, iPhone y navegador. Trabaja de forma individual o con tu clínica, con acceso según el rol de cada integrante.',
        style: VetTypography.bodyMedium,
      ),
      const SizedBox(height: VetSpacing.xl),
      Text('Herramientas incluidas', style: VetTypography.headlineMedium),
      const SizedBox(height: VetSpacing.lg),
      for (final tool in productTools)
        _ToolCard(
          tool: tool,
          onTap: onNavigate == null ? null : () => onNavigate!(tool.route),
        ),
      const SizedBox(height: VetSpacing.xxl),
      Text('Planes y costos', style: VetTypography.headlineMedium),
      const SizedBox(height: VetSpacing.xs),
      Text(
        'Propuesta de lanzamiento · MXN · cobros aún desactivados',
        style: VetTypography.bodyMedium.copyWith(color: VetColors.muted),
      ),
      const SizedBox(height: VetSpacing.lg),
      _PlanCard(
        name: 'Gratis · \$0',
        description: 'Espacio personal · 50 pacientes · 250 MiB · 5 intentos IA/día',
        accent: VetColors.mint,
      ),
      const SizedBox(height: VetSpacing.md),
      _PlanCard(
        name: 'Individual · \$199/mes o \$1,990/año',
        description:
            'Espacio propio · 5,000 pacientes · 2 GiB · 200 intentos IA/día. Ventas y cierre de caja manual sin conectar una pasarela.',
        accent: VetColors.turquoise,
      ),
      const SizedBox(height: VetSpacing.md),
      _PlanCard(
        name: 'Clínica · \$799/mes o \$7,990/año',
        description:
            'Todos sus integrantes · 50,000 pacientes · 10 GiB · 1,000 intentos IA/día compartidos.',
        accent: VetColors.purple,
      ),
      const SizedBox(height: VetSpacing.lg),
      Text(
        'Beta y regalos: beneficios temporales. El consumo de IA con clave propia depende del proveedor. La ayuda incluida tiene cupo separado y necesita activación. El anual equivale a diez mensualidades. Límites y precios sujetos a revisión antes de publicar.',
        style: VetTypography.bodySmall,
      ),
      const SizedBox(height: VetSpacing.lg),
      Text(
        'Estado de lanzamiento: implementación local en pruebas. Conexión y pruebas reales de Supabase, dispositivos y servicios externos pendientes. El catálogo clínico necesita referencias verificadas; las respuestas de IA requieren revisión profesional. OCR, dictado y automatización de WhatsApp/Drive siguen pendientes.',
        style: VetTypography.bodySmall,
      ),
      if (onNavigate != null) ...[
        const SizedBox(height: VetSpacing.xl),
        VetActionButton(
          label: 'Ver mi plan y pagos',
          icon: Icons.workspace_premium_outlined,
          onPressed: () => onNavigate!('Planes'),
          fullWidth: true,
        ),
      ],
    ],
  );
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.tool, this.onTap});
  final _ProductTool tool;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => VetCard(
    padding: const EdgeInsets.all(VetSpacing.md),
    elevated: onTap != null,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(VetSpacing.radiusLg),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tool.accent.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(VetSpacing.radiusMd),
            ),
            child: Icon(tool.icon, color: tool.accent, size: 24),
          ),
          const SizedBox(width: VetSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tool.title, style: VetTypography.titleMedium),
                const SizedBox(height: VetSpacing.xs),
                Text(tool.description, style: VetTypography.bodySmall),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right, color: VetColors.muted),
        ],
      ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
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

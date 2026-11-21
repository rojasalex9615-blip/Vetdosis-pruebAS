import 'package:flutter/material.dart';
import '../../../core/widgets/accent_glow.dart';
import '../../../core/widgets/workspace_panel.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_icons.dart';
import '../../../vet_ui/vet_theme.dart';

const productTools = <(String, String, String)>[
  (
    'Cálculos y dosis',
    'Peso, especie y presentación; cálculos separados de la interfaz.',
    'Cálculo rápido',
  ),
  (
    'Pacientes y expedientes',
    'Historia clínica, peso y seguimiento del paciente.',
    'Pacientes',
  ),
  (
    'Hospitalización',
    'Tratamientos, responsables y avisos programados.',
    'Hospitalización',
  ),
  (
    'Formatos y recetas',
    'Plantillas por clínica, firma y PDF para revisión.',
    'Formatos',
  ),
  (
    'Inventario y caja',
    'Lotes, caducidades, ventas y pagos manuales.',
    'Inventario',
  ),
  (
    'Agenda y equipo',
    'Citas, estética, servicios y organización por permisos.',
    'Agenda',
  ),
  (
    'Asistente IA',
    'Ayuda de uso incluida por temas; chat con proveedor propio, historial y contexto optativos.',
    'Asistente IA',
  ),
  (
    'Respaldo y reportes',
    'Exportación operacional y estadísticas por permisos.',
    'Estadísticas y respaldo',
  ),
];

class ProductScreen extends StatelessWidget {
  const ProductScreen({super.key, this.onNavigate});
  final void Function(String)? onNavigate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AccentIcon(VetIcons.paw, size: 32),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('VetDosis Pro', style: theme.textTheme.headlineLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Tu trabajo veterinario, organizado en un mismo espacio.',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Para México, en Android, iPhone y navegador. Trabaja de forma individual o con tu clínica, con acceso según el rol de cada integrante.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Herramientas integradas',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Diseñadas específicamente para la práctica médica diaria.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        for (final tool in productTools) ...[
          VetCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: InkWell(
              onTap: onNavigate == null ? null : () => onNavigate!(tool.$3),
              borderRadius: BorderRadius.circular(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: sectionAccent(tool.$3).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: sectionAccent(tool.$3).withValues(alpha: 0.28),
                      ),
                    ),
                    child: Icon(
                      sectionIcon(tool.$3),
                      color: sectionAccent(tool.$3),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tool.$1,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tool.$2,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onNavigate != null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      VetIcons.chevronRight,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            const AccentIcon(VetIcons.certificate, size: 24),
            const SizedBox(width: 10),
            Text(
              'Planes y costos',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Propuesta de lanzamiento · MXN · cobros aún desactivados',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        VetCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(VetIcons.playCircle, size: 22, color: VetColors.turquoise),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Gratis · \$0',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const VetStatusBadge(
                    label: 'Inicial',
                    kind: VetBadgeKind.information,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Espacio personal · 50 pacientes · 250 MiB · 5 intentos IA/día',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              const VetDataRow(
                label: 'Pacientes incluidos',
                value: '50 pacientes',
                icon: VetIcons.paw,
              ),
              const VetDataRow(
                label: 'Almacenamiento',
                value: '250 MiB',
                icon: VetIcons.folder,
              ),
              const VetDataRow(
                label: 'Consultas IA',
                value: '5 intentos/día',
                icon: VetIcons.robot,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AccentGlow(
          color: theme.colorScheme.primary,
          radius: 26,
          emphasis: 0.6,
          child: VetCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(VetIcons.user, size: 22, color: VetColors.violet),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Individual · \$199/mes o \$1,990/año',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const VetStatusBadge(
                      label: 'Recomendado',
                      kind: VetBadgeKind.success,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Espacio propio · 5,000 pacientes · 2 GiB · 200 intentos IA/día. Ventas y cierre de caja manual sin conectar una pasarela.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                const VetDataRow(
                  label: 'Pacientes incluidos',
                  value: '5,000 pacientes',
                  icon: VetIcons.paw,
                ),
                const VetDataRow(
                  label: 'Almacenamiento',
                  value: '2 GiB',
                  icon: VetIcons.folder,
                ),
                const VetDataRow(
                  label: 'Consultas IA',
                  value: '200 intentos/día',
                  icon: VetIcons.robot,
                ),
                const VetDataRow(
                  label: 'Caja e inventario',
                  value: 'Ventas y corte manual',
                  icon: VetIcons.cashRegister,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        VetCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(VetIcons.usersGroup, size: 22, color: VetColors.purple),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Clínica · \$799/mes o \$7,990/año',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const VetStatusBadge(
                    label: 'Multiusuario',
                    kind: VetBadgeKind.information,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Todos sus integrantes · 50,000 pacientes · 10 GiB · 1,000 intentos IA/día compartidos.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              const VetDataRow(
                label: 'Pacientes incluidos',
                value: '50,000 pacientes',
                icon: VetIcons.paw,
              ),
              const VetDataRow(
                label: 'Almacenamiento',
                value: '10 GiB compartidos',
                icon: VetIcons.folder,
              ),
              const VetDataRow(
                label: 'Consultas IA',
                value: '1,000 intentos/día',
                icon: VetIcons.robot,
              ),
              const VetDataRow(
                label: 'Equipo y roles',
                value: 'Sin cobro por usuario',
                icon: VetIcons.idBadge,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const VetNote(
          text:
              'Beta y regalos: beneficios temporales. El consumo de IA con clave propia depende del proveedor. La ayuda incluida tiene cupo separado y necesita activación. El anual equivale a diez mensualidades. Límites y precios sujetos a revisión antes de publicar.',
          icon: VetIcons.gift,
        ),
        const SizedBox(height: 8),
        const VetCallout(
          text:
              'Estado de lanzamiento: implementación local en pruebas. Conexión y pruebas reales de Supabase, dispositivos y servicios externos pendientes. El catálogo clínico necesita referencias verificadas; las respuestas de IA requieren revisión profesional. OCR, dictado y automatización de WhatsApp/Drive siguen pendientes.',
          icon: VetIcons.info,
          kind: VetBadgeKind.information,
        ),
        if (onNavigate != null) ...[
          const SizedBox(height: 16),
          AccentGlow(
            color: theme.colorScheme.primary,
            child: VetActionButton(
              label: 'Ver mi plan y pagos',
              icon: VetIcons.certificate,
              onPressed: () => onNavigate!('Planes'),
            ),
          ),
        ],
      ],
    );
  }
}

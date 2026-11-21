import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/widgets/accent_glow.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_icons.dart';
import '../../../vet_ui/vet_theme.dart';

const guideSteps = <(String, String, String)>[
  (
    '1. Elige tu espacio',
    'Usa tu espacio personal o la clínica de tu equipo. Los roles vienen de tu cuenta.',
    'Mi cuenta',
  ),
  (
    '2. Personaliza tu experiencia',
    'Elige una de las cinco paletas y apariencia clara u oscura.',
    'Ajustes',
  ),
  (
    '3. Conoce tus herramientas',
    'Explora las funciones y sus límites antes de cargar datos reales.',
    'Producto y costos',
  ),
  (
    '4. Revisa tu perfil y formatos',
    'Captura tus datos profesionales y revisa membrete, permisos y plantillas antes de emitir documentos.',
    'Receta',
  ),
  (
    '5. Registra tu primer paciente',
    'Captura datos con consentimiento y revisa el expediente. No agregamos pacientes de prueba automáticamente.',
    'Pacientes',
  ),
  (
    '6. Configura IA y revisa el plan',
    'La clave y el modelo son opcionales. Decide qué contexto compartir y consulta tu plan.',
    'Planes',
  ),
  (
    '7. Encuentra ayuda',
    'Reporta problemas, adjunta archivos y consulta el seguimiento de soporte.',
    'Ayuda y soporte',
  ),
];

IconData _stepIcon(int index) => switch (index) {
  0 => VetIcons.userCircle,
  1 => VetIcons.brush,
  2 => VetIcons.info,
  3 => VetIcons.document,
  4 => VetIcons.paw,
  5 => VetIcons.robot,
  6 => VetIcons.help,
  _ => VetIcons.compass,
};

class GuidedStartScreen extends StatefulWidget {
  const GuidedStartScreen({
    super.key,
    required this.scope,
    required this.onNavigate,
  });
  final String scope;
  final void Function(String) onNavigate;
  @override
  State<GuidedStartScreen> createState() => _GuidedStartScreenState();
}

class _GuidedStartScreenState extends State<GuidedStartScreen> {
  Set<int> done = {};
  bool loaded = false;
  String? error;
  String get storageKey => 'guided_start_v1_${widget.scope}';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final values = p.getStringList(storageKey) ?? [];
      if (mounted) {
        setState(() {
          done = values.map(int.tryParse).whereType<int>().toSet();
          loaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loaded = true;
          error = 'No se pudo recuperar tu progreso.';
        });
      }
    }
  }

  Future<void> mark(int i, bool value) async {
    final next = {...done};
    value ? next.add(i) : next.remove(i);
    try {
      final p = await SharedPreferences.getInstance();
      if (!await p.setStringList(storageKey, next.map((v) => '$v').toList())) {
        throw StateError('save');
      }
      if (mounted) {
        setState(() {
          done = next;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'No se pudo guardar el progreso en este dispositivo.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = guideSteps.length;
    final completedCount = done.length;
    final progress = total > 0 ? (completedCount / total).clamp(0.0, 1.0) : 0.0;
    final isAllDone = completedCount >= total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AccentIcon(VetIcons.compass, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Inicio guiado',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Avanza a tu ritmo. Marcar un paso indica que lo revisaste; no verifica una configuración ni cambia tus permisos. Puedes volver a esta guía cuando quieras.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AccentGlow(
          color: theme.colorScheme.primary,
          radius: 24,
          emphasis: 0.45,
          child: VetCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tu avance de configuración',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    VetStatusBadge(
                      label: isAllDone
                          ? 'Completado'
                          : '${(progress * 100).round()}% listo',
                      kind: isAllDone
                          ? VetBadgeKind.success
                          : VetBadgeKind.information,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isAllDone ? VetColors.success : theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${done.length} de ${guideSteps.length} pasos revisados · Progreso guardado solo en este dispositivo.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!loaded) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
        if (error != null) ...[
          const SizedBox(height: 12),
          VetCallout(
            text: error!,
            kind: VetBadgeKind.danger,
            icon: VetIcons.warningTriangle,
          ),
        ],
        const SizedBox(height: 16),
        for (var i = 0; i < guideSteps.length; i++) ...[
          VetCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: done.contains(i),
                  onChanged: !loaded ? null : (v) => mark(i, v ?? false),
                  secondary: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: done.contains(i)
                          ? VetColors.success.withValues(alpha: 0.15)
                          : theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: done.contains(i)
                            ? VetColors.success.withValues(alpha: 0.3)
                            : theme.colorScheme.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Icon(
                      done.contains(i) ? VetIcons.checkCircle : _stepIcon(i),
                      color: done.contains(i)
                          ? VetColors.success
                          : theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    guideSteps[i].$1,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      decoration: done.contains(i)
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      guideSteps[i].$2,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: () => widget.onNavigate(guideSteps[i].$3),
                    icon: const Icon(VetIcons.arrowForward, size: 16),
                    label: const Text('Abrir'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class FirstStepsBanner extends StatefulWidget {
  const FirstStepsBanner({
    super.key,
    required this.scope,
    required this.onOpen,
  });
  final String scope;
  final VoidCallback onOpen;
  @override
  State<FirstStepsBanner> createState() => _FirstStepsBannerState();
}

class _FirstStepsBannerState extends State<FirstStepsBanner> {
  bool visible = false;
  String get storageKey => 'guided_start_invitation_v1_${widget.scope}';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (mounted) setState(() => visible = !(p.getBool(storageKey) ?? false));
    } catch (_) {
      if (mounted) setState(() => visible = true);
    }
  }

  Future<void> dismiss() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(storageKey, true);
    } catch (_) {}
    if (mounted) setState(() => visible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AccentGlow(
        color: theme.colorScheme.primary,
        radius: 24,
        emphasis: 0.5,
        child: VetCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(VetIcons.compass, size: 22, color: VetColors.brandSky),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bienvenido: configura tu espacio paso a paso',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Revisa la guía antes de comenzar. Puedes retomarla desde el menú.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: widget.onOpen,
                    icon: const Icon(VetIcons.compass, size: 16),
                    label: const Text('Comenzar guía'),
                  ),
                  TextButton(
                    onPressed: dismiss,
                    child: const Text('Más tarde'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

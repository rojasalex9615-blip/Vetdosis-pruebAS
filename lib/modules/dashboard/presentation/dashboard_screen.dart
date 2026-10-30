import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/widgets/workspace_panel.dart';
import '../../core/domain/navigation_access.dart';
import '../../inventory/domain/inventory_models.dart';
import '../../hospital/application/hospital_alerts.dart';
import '../../prescribing/presentation/rx_entry_screen.dart';
import 'dashboard_view_model.dart';
import 'alert_preferences_panel.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.model,
    required this.onNavigate,
    this.offline = false,
    this.statisticsOnly = false,
    this.alerts,
  });
  final DashboardViewModel model;
  final ValueChanged<String> onNavigate;
  final bool offline, statisticsOnly;
  final HospitalAlerts? alerts;
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DashboardViewModel model = widget.model;
  final search = TextEditingController();
  Timer? timer;
  bool openingCash = false;
  @override
  void initState() {
    super.initState();
    model.load(offline: widget.offline);
    timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    search.dispose();
    model.dispose();
    super.dispose();
  }

  String time(DateTime date) {
    final d = model.localTime(date);
    return '${d.day}/${d.month}/${d.year} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Widget panel(String title, String page, List<Widget> children) =>
      WorkspacePanel(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    sectionIcon(page),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Abrir $title',
                    onPressed: () => widget.onNavigate(page),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              ...children,
            ],
          ),
        ),
      );
  Widget unavailable(String name, bool loaded, Widget content) =>
      model.errors[name] != null
      ? Text(model.errors[name]!)
      : loaded
      ? content
      : const Text('Resumen no disponible.');
  Widget metrics(List<(String, String)> values) => LayoutBuilder(
    builder: (context, c) {
      final cols =
          c.maxWidth >= 330 && MediaQuery.textScalerOf(context).scale(1) < 1.4
          ? 2
          : 1;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final v in values)
            SizedBox(
              width: (c.maxWidth - 12 * (cols - 1)) / cols,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.$2, style: Theme.of(context).textTheme.titleLarge),
                    Text(v.$1),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
  String money(dynamic value) {
    try {
      return Money.parse('$value', signed: true).display;
    } catch (_) {
      return 'No disponible';
    }
  }

  Future<void> openCash() async {
    if (widget.offline ||
        model.member == null ||
        model.inventory == null ||
        model.stock == null ||
        model.busy ||
        openingCash) {
      return;
    }
    setState(() => openingCash = true);
    try {
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => RxEntryScreen(
            title: 'Abrir turno de caja',
            fields: const [
              RxField(
                'opening',
                'Fondo inicial de efectivo MXN',
                required: true,
              ),
            ],
            submit: (data, op) async {
              try {
                await model.inventory!.write('inv_shift_open', {
                  'p_clinic': model.member!.clinicId,
                  'p_opening': Money.parse(data['opening']).decimal,
                  'p_operation': op,
                });
              } on FormatException {
                rethrow;
              } catch (_) {
                throw const FormatException(
                  'No se pudo abrir el turno. Actualiza y revisa conexión y permisos.',
                );
              }
            },
          ),
        ),
      );
      if (saved == true && mounted) await model.load(offline: widget.offline);
    } finally {
      if (mounted) setState(() => openingCash = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([model, ?widget.alerts]),
    builder: (context, _) {
      final m = model;
      final stats = m.statistics;
      final statisticsPanel = panel('Estadísticas', 'Estadísticas', [
        unavailable(
          'Estadísticas',
          stats != null,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Ventas mensuales netas de devoluciones · MXN. No representan utilidad neta.',
              ),
              for (final s
                  in m
                      .rows(stats, 'sales')
                      .reversed
                      .take(widget.statisticsOnly ? 12 : 3))
                ListTile(
                  title: Text('${s['month']}'),
                  trailing: Text(money(s['amount'])),
                ),
              if (widget.statisticsOnly) ...[
                const Text('Citas no canceladas del mes por especie'),
                for (final s in m.rows(stats, 'species'))
                  ListTile(
                    title: Text('${s['species']}'),
                    trailing: Text('${s['count']}'),
                  ),
              ],
            ],
          ),
        ),
      ]);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.statisticsOnly
                      ? 'Estadísticas de la clínica'
                      : 'Resumen de tu espacio',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                tooltip: 'Actualizar resumen',
                onPressed: m.busy
                    ? null
                    : () => m.load(offline: widget.offline),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (widget.offline)
            const Text('Sin conexión: reconecta para consultar los resúmenes.'),
          if (m.member == null)
            const Text(
              'Conecta tu cuenta y elige una clínica para consultar sus datos.',
            ),
          if (m.member != null &&
              m.moduleAccess != null &&
              m.moduleAccess!.modules.values.every((enabled) => !enabled))
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No tienes accesos habilitados a las áreas de este espacio. '
                'Revisa los permisos de tu cuenta con quien lo administra.',
              ),
            ),
          if (m.updated != null) Text('Última consulta: ${time(m.updated!)}'),
          if (m.busy) const LinearProgressIndicator(),
          if (navigationAllowed('Estadísticas', m.member, m.moduleAccess))
            statisticsPanel,
          if (!widget.statisticsOnly) ...[
            const SizedBox(height: 20),
            Text(
              'Módulos principales',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final modules = <(String, String, IconData, Color)>[
                  (
                    'Inventario',
                    'Inventario',
                    Icons.inventory_2_outlined,
                    const Color(0xFF5B8DEF),
                  ),
                  (
                    'Pacientes',
                    'Pacientes',
                    Icons.pets_outlined,
                    const Color(0xFF2BBBAD),
                  ),
                  (
                    'Recetas',
                    'Receta',
                    Icons.assignment_outlined,
                    const Color(0xFF9B6DFF),
                  ),
                  (
                    'Agenda',
                    'Agenda',
                    Icons.calendar_month_outlined,
                    const Color(0xFF6C7CFF),
                  ),
                  (
                    'Cálculo rápido',
                    'Cálculo rápido',
                    Icons.calculate_outlined,
                    const Color(0xFF3ECFC0),
                  ),
                  (
                    'Hospital',
                    'Hospitalización',
                    Icons.add_box_outlined,
                    const Color(0xFF7B68EE),
                  ),
                ];
                final visible = modules
                    .where(
                      (mod) => navigationAllowed(
                        mod.$2,
                        m.member,
                        m.moduleAccess,
                      ),
                    )
                    .toList();
                if (visible.isEmpty) {
                  return const SizedBox.shrink();
                }
                final crossAxisCount = constraints.maxWidth >= 520 ? 3 : 2;
                const spacing = 12.0;
                final itemWidth =
                    (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
                    crossAxisCount;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final mod in visible)
                      SizedBox(
                        width: itemWidth,
                        child: _ModuleCard(
                          title: mod.$1,
                          icon: mod.$3,
                          accent: mod.$4,
                          onTap: () => widget.onNavigate(mod.$2),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final action in <(String, String)>[
                  ('Estadísticas', 'Estadísticas'),
                  ('Formatos', 'Formatos'),
                  ('Cálculos clínicos', 'Cálculos clínicos'),
                  ('Escáner', 'Escanear producto'),
                ])
                  if (navigationAllowed(action.$2, m.member, m.moduleAccess))
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width - 48,
                      ),
                      child: WorkspacePanel(
                        child: InkWell(
                          onTap: () => widget.onNavigate(action.$2),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(sectionIcon(action.$2), size: 20),
                                const SizedBox(width: 8),
                                Flexible(child: Text(action.$1)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
            panel(
              'Alertas y recordatorios',
              navigationAllowed('Hospitalización', m.member, m.moduleAccess)
                  ? 'Hospitalización'
                  : 'Agenda',
              [
                if (m.canSummarize('hospital'))
                  unavailable(
                    'Hospitalización',
                    m.ward != null,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${m.overdue.length} dosis pendientes cuyo horario ya llegó.',
                        ),
                        for (final t in m.overdue.take(3))
                          ListTile(
                            title: Text('${m.patient(t)} · ${t.label}'),
                            subtitle: Text(
                              'Horario: ${time(m.effectiveTime(t))}',
                            ),
                            onTap: () => widget.onNavigate('Hospitalización'),
                          ),
                      ],
                    ),
                  ),
                if (m.canSummarize('inventory') &&
                    widget.alerts?.stockWarnings != false)
                  unavailable(
                    'Inventario',
                    m.stock != null,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${m.lowStock.length} productos con stock disponible bajo o igual al mínimo.',
                        ),
                        for (final p in m.lowStock.take(3))
                          ListTile(
                            title: Text('${p['nombre']}'),
                            subtitle: Text(
                              'Disponible: ${p['available_stock']} · mínimo ${p['stock_minimo']}',
                            ),
                            onTap: () => widget.onNavigate('Inventario'),
                          ),
                      ],
                    ),
                  ),
                if (m.canSummarize('hospital') &&
                    (widget.alerts?.leadMinutes ?? 0) > 0)
                  for (final t
                      in m.nextDoses
                          .where(
                            (t) =>
                                m.effectiveTime(t).difference(m.now()) <=
                                Duration(minutes: widget.alerts!.leadMinutes),
                          )
                          .take(3))
                    ListTile(
                      title: Text(
                        'Próxima dosis · ${m.patient(t)} · ${t.label}',
                      ),
                      subtitle: Text(time(m.effectiveTime(t))),
                      onTap: () => widget.onNavigate('Hospitalización'),
                    ),
                if (navigationAllowed(
                  'Hospitalización',
                  m.member,
                  m.moduleAccess,
                ))
                  ExpansionTile(
                    title: const Text('Configurar avisos en este dispositivo'),
                    children: [
                      AlertPreferencesPanel(
                        alerts: widget.alerts,
                        onUpdated: () async {
                          final a = widget.alerts;
                          if (a?.scope != null && m.ward != null) {
                            await a!.reconcile(
                              '${m.member!.userId}:${m.member!.clinicId}:${m.member!.role.name}',
                              m.ward!.tasks,
                            );
                          }
                        },
                      ),
                    ],
                  ),
              ],
            ),
            if (m.canSummarize('agenda')) ...[
              panel('Próximas citas de hoy', 'Agenda', [
                Text(
                  m.clinicTimezone == null
                      ? 'Día y horas del teléfono'
                      : 'Zona de la clínica: ${m.clinicTimezone}',
                ),
                unavailable(
                  'Agenda',
                  m.agenda != null,
                  Column(
                    children: [
                      if (m.todayAppointments.isEmpty)
                        const Text('No hay citas futuras agendadas para hoy.'),
                      for (final a in m.todayAppointments)
                        ListTile(
                          title: Text('${a['patient_name']}'),
                          subtitle: Text(
                            '${time(m.starts(a)!)} · ${a['kind']}',
                          ),
                          onTap: () => widget.onNavigate('Agenda'),
                        ),
                    ],
                  ),
                ),
              ]),
              panel('Citas recientes', 'Agenda', [
                unavailable(
                  'Agenda',
                  m.agenda != null,
                  Column(
                    children: [
                      if (m.recent.isEmpty)
                        const Text(
                          'No hay citas recientes en los datos consultados.',
                        ),
                      for (final a in m.recent.take(3))
                        ListTile(
                          title: Text('${a['patient_name']}'),
                          subtitle: Text(
                            '${time(m.starts(a)!)} · ${a['state']}',
                          ),
                          onTap: () => widget.onNavigate('Agenda'),
                        ),
                    ],
                  ),
                ),
              ]),
            ],
            if (m.canSummarize('inventory')) ...[
              panel('Inventario', 'Inventario', [
                unavailable(
                  'Inventario',
                  m.stock != null,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${m.lowStock.length} productos bajos · ${m.products.length} activos',
                      ),
                      FilledButton.tonal(
                        onPressed: openingCash || m.busy ? null : openCash,
                        child: const Text('Abrir turno de caja'),
                      ),
                    ],
                  ),
                ),
              ]),
            ],
          ],
        ],
      );
    },
  );
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.title,
    required this.icon,
    required this.accent,
    required this.onTap,
  });
  final String title;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 0,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import '../../../core/widgets/accent_glow.dart';
import '../../../core/widgets/neu_identity.dart';
import '../../../core/widgets/neu_header_card.dart';
import 'home_pilot.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_format.dart';
import '../../../vet_ui/vet_theme.dart';
import '../../doses/domain/quantity.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/widgets/workspace_panel.dart';
import '../../clinic_experience/domain/clinic_experience.dart';
import '../../core/domain/navigation_access.dart';
import '../../auth/domain/staff_labels.dart';
import '../../identity/domain/identity_repository.dart';
import '../../inventory/domain/inventory_models.dart';
import '../../hospital/application/hospital_alerts.dart';
import '../../prescribing/presentation/rx_entry_screen.dart';
import 'dashboard_view_model.dart';
import 'alert_preferences_panel.dart';
import 'statistics_screen.dart';
import '../../../vet_ui/vet_icons.dart';

/// Inicio: resumen del espacio, accesos a los modulos y proximas citas.
///
/// Lo que muestra depende de los permisos de quien entra: cada bloque se
/// omite si su area no esta visible para esa persona.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.model,
    required this.onNavigate,
    this.offline = false,
    this.statisticsOnly = false,
    this.homePilot = false,
    this.alerts,
    this.isVisible,
    this.identity,
    this.experience,
    this.header,
  });
  final DashboardViewModel model;
  final ValueChanged<String> onNavigate;
  final bool offline, statisticsOnly, homePilot;
  final HospitalAlerts? alerts;
  final bool Function(String)? isVisible;
  final IdentityRepository? identity;
  final ClinicExperience? experience;

  /// Contenido opcional sobre el resumen (por ejemplo, el saludo de cumpleaños).
  final Widget? header;
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DashboardViewModel model = widget.model;
  final search = TextEditingController();
  Timer? timer;
  bool openingCash = false;

  /// Combines server-provided navigation access with clinic preferences.
  bool routeAuthorized(String page) =>
      navigationAllowed(page, model.member, model.moduleAccess);

  bool routeVisible(String page) =>
      routeAuthorized(page) && (widget.isVisible?.call(page) ?? true);

  void openPage(String page) {
    if (routeVisible(page)) widget.onNavigate(page);
  }

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

  /// Solo la hora, para la etiqueta de las citas de hoy.
  String hour(DateTime date) {
    final d = model.localTime(date);
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  // Una sola tabla de color por seccion, la de workspace_panel.dart, en vez
  // de esta copia local: la cuadricula de Inicio y el panel pintaban el mismo
  // modulo de colores distintos.
  Color sectionColor(String page) => sectionAccent(page);

  Widget panel(String title, String page, List<Widget> children) =>
      NeuHeaderCard(
        title: title,
        icon: sectionIcon(page),
        color: sectionColor(page),
        trailing: IconButton(
          tooltip: 'Abrir $title',
          onPressed: () => openPage(page),
          icon: const Icon(VetIcons.chevronRight),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      );
  Widget unavailable(String name, bool loaded, Widget content) =>
      model.errors[name] != null
      ? Text(model.errors[name]!)
      : loaded
      ? content
      : const VetEmptyState(
          text: 'Resumen no disponible.',
          icon: VetIcons.info,
        );
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

  List<(String, int)>? get activity {
    if (model.member == null ||
        !model.canSummarize('agenda') ||
        !routeVisible('Agenda') ||
        model.agenda == null) {
      return null;
    }
    final local = model.localTime(model.now());
    final today = DateTime.utc(local.year, local.month, local.day);
    const labels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return List.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      final count = model.rows(model.agenda, 'appointments').where((row) {
        final date = model.starts(row);
        if (date == null || row['state'] == 'cancelado') return false;
        return DateUtils.isSameDay(model.localTime(date), day);
      }).length;
      return (labels[day.weekday - 1], count);
    });
  }

  List<(String, String, IconData, Color)> get summaryMetrics => [
    if (model.member != null &&
        model.canSeePatients &&
        routeVisible('Pacientes'))
      (
        'Pacientes',
        model.patientCount?.toString() ?? '—',
        VetIcons.paw,
        VetColors.turquoise,
      ),
    if (model.member != null &&
        model.canSummarize('agenda') &&
        routeVisible('Agenda'))
      (
        'Citas por venir',
        model.agenda == null ? '—' : '${model.upcoming.length}',
        VetIcons.calendar,
        VetColors.violet,
      ),
    if (model.member != null &&
        model.canSummarize('hospital') &&
        routeVisible('Hospitalización'))
      (
        'En hospital',
        model.ward == null ? '—' : '${model.ward!.stays.length}',
        VetIcons.hospital,
        VetColors.cyan,
      ),
    if (model.member != null &&
        !model.member!.isPersonal &&
        model.canSummarize('agenda') &&
        routeVisible('Pendientes del equipo'))
      (
        'Tareas visibles',
        model.agenda == null ? '—' : '${model.pendingTasks.length}',
        VetIcons.checkCircle,
        VetColors.lilac,
      ),
  ];

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
      final theme = Theme.of(context);
      final totals = m.dayTotals;
      final statisticsPanel = panel('Estadísticas', 'Estadísticas', [
        StatisticsPanel(
          model: model,
          statisticsOnly: widget.statisticsOnly,
          identity: widget.identity,
          experience: widget.experience,
        ),
      ]);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.header != null) ...[
            widget.header!,
            const SizedBox(height: 12),
          ],
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
                icon: const Icon(VetIcons.refresh),
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
          if (widget.statisticsOnly && routeVisible('Estadísticas'))
            statisticsPanel,
          if (widget.homePilot && !widget.statisticsOnly) ...[
            const SizedBox(height: 16),
            HomeSummary(metrics: summaryMetrics, activity: activity),
          ],
          if (!widget.homePilot &&
              !widget.statisticsOnly &&
              routeVisible('Estadísticas'))
            statisticsPanel,
          if (!widget.statisticsOnly) ...[
            const SizedBox(height: 16),
            if (widget.homePilot) ...[
              Text(
                'Módulos principales',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              HomeModuleGrid(
                actions: [
                  for (final action in <(String, String)>[
                    ('Inventario', 'Inventario'),
                    ('Pacientes', 'Pacientes'),
                    ('Recetas', 'Receta'),
                    ('Agenda', 'Agenda'),
                    ('Cálculo rápido', 'Cálculo rápido'),
                    ('Hospital', 'Hospitalización'),
                    ('Caja', 'Caja'),
                  ])
                    if (routeVisible(action.$2)) action,
                ],
                // Solo datos ya consultados; si aun no llegaron, el modulo
                // se queda con su pista en vez de mostrar un cero falso.
                details: {
                  'Inventario': m.stock == null
                      ? 'Productos y lotes'
                      : '${m.products.length} artículos',
                  'Pacientes': m.patientCount == null || !m.canSeePatients
                      ? 'Expedientes'
                      : '${m.patientCount} registrados',
                  'Receta': 'Emitir y consultar',
                  'Agenda': m.agenda == null || !m.canSummarize('agenda')
                      ? 'Citas y recordatorios'
                      : '${m.upcoming.length} por venir',
                  'Cálculo rápido': 'Dosis por peso',
                  'Hospitalización':
                      m.ward == null || !m.canSummarize('hospital')
                      ? 'Pacientes internados'
                      : '${m.ward!.stays.length} internados',
                  'Caja': 'Ventas y cierre del día',
                },
                onNavigate: openPage,
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final actions = <(String, String)>[
                    ('Formatos', 'Formatos'),
                    ('Estadísticas', 'Estadísticas'),
                    ('Cálculos clínicos', 'Cálculos clínicos'),
                    ('Escáner', 'Escanear producto'),
                  ].where((a) => routeVisible(a.$2)).toList();

                  if (actions.isEmpty) return const SizedBox.shrink();

                  const spacing = 10.0;
                  final colWidth = (constraints.maxWidth - spacing) / 2;

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      for (final action in actions)
                        SizedBox(
                          width: colWidth,
                          child: _DashboardActionCapsule(
                            label: action.$1,
                            page: action.$2,
                            onTap: () => openPage(action.$2),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
            ] else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final action in <(String, String)>[
                    ('Inventario', 'Inventario'),
                    ('Estadísticas', 'Estadísticas'),
                    ('Recetas', 'Receta'),
                    ('Formatos', 'Formatos'),
                    ('Pacientes', 'Pacientes'),
                    ('Agenda', 'Agenda'),
                    ('Hospitalización', 'Hospitalización'),
                    ('Cálculo rápido', 'Cálculo rápido'),
                    ('Cálculos clínicos', 'Cálculos clínicos'),
                    ('Escáner', 'Escanear producto'),
                    ('Caja', 'Caja'),
                  ])
                    if (routeVisible(action.$2))
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width - 48,
                        ),
                        child: VetActionButton(
                          label: action.$1,
                          icon: sectionIcon(action.$2),
                          style: VetActionStyle.neutral,
                          onPressed: () => openPage(action.$2),
                        ),
                      ),
                ],
              ),
            if (widget.homePilot && routeVisible('Estadísticas'))
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: VetCard(
                  padding: EdgeInsets.zero,
                  child: Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      shape: const Border(),
                      collapsedShape: const Border(),
                      leading: const Icon(VetIcons.barChart, size: 20),
                      title: const Text(
                        'Ver estadísticas',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: statisticsPanel,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (routeAuthorized('Hospitalización') ||
                routeVisible('Agenda') ||
                routeVisible('Inventario'))
              panel(
                'Alertas y recordatorios',
                routeAuthorized('Hospitalización')
                    ? 'Hospitalización'
                    : routeVisible('Agenda')
                    ? 'Agenda'
                    : 'Inventario',
                [
                  if (m.canSummarize('hospital') &&
                      routeAuthorized('Hospitalización'))
                    unavailable(
                      'Hospitalización',
                      m.ward != null,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          VetDataRow(
                            label: 'Dosis con horario cumplido',
                            value: '${m.overdue.length}',
                            icon: VetIcons.clock,
                            valueColor: m.overdue.isEmpty
                                ? VetColors.success
                                : VetColors.danger,
                            emphasized: true,
                          ),
                          if (m.overdue.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                'Al día · no hay dosis retrasadas',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: VetColors.success,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          for (final t in m.overdue.take(3))
                            ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              leading: const Icon(
                                VetIcons.clock,
                                size: 18,
                                color: VetColors.danger,
                              ),
                              title: Text(
                                '${m.patient(t)} · ${t.label}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                'Horario: ${time(m.effectiveTime(t))}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: const Icon(
                                VetIcons.chevronRight,
                                size: 16,
                              ),
                              onTap: () => openPage('Hospitalización'),
                            ),
                        ],
                      ),
                    ),
                  if (m.canSummarize('inventory') &&
                      routeVisible('Inventario') &&
                      widget.alerts?.stockWarnings != false)
                    unavailable(
                      'Inventario',
                      m.stock != null,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          VetDataRow(
                            label: 'Productos con stock en el mínimo',
                            value: '${m.lowStock.length}',
                            icon: VetIcons.box,
                            valueColor: m.lowStock.isEmpty
                                ? VetColors.success
                                : VetColors.warning,
                            emphasized: true,
                          ),
                          if (m.lowStock.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                'Stock en niveles óptimos',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: VetColors.success,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          for (final p in m.lowStock.take(3))
                            ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              leading: const Icon(
                                VetIcons.alertOctagon,
                                size: 18,
                                color: VetColors.warning,
                              ),
                              title: Text(
                                '${p['nombre']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                'Disponible: ${p['available_stock']} · mínimo ${p['stock_minimo']}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: const Icon(
                                VetIcons.chevronRight,
                                size: 16,
                              ),
                              onTap: () => openPage('Inventario'),
                            ),
                        ],
                      ),
                    ),
                  if (m.canSummarize('hospital') &&
                      routeAuthorized('Hospitalización') &&
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
                        onTap: () => openPage('Hospitalización'),
                      ),
                ],
              ),
            // Settings for alarms already on this device remain reachable even
            // when a clinic hides the hospital navigation shortcut.
            if (widget.alerts != null && routeAuthorized('Hospitalización'))
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
            if (m.canSummarize('agenda') && routeVisible('Agenda')) ...[
              panel('Próximas citas de hoy', 'Agenda', [
                Text(
                  m.clinicTimezone == null
                      ? 'Día y horas del teléfono'
                      : VetFormat.timezone(m.clinicTimezone),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                unavailable(
                  'Agenda',
                  m.agenda != null,
                  Column(
                    children: [
                      if (m.todayAppointments.isEmpty)
                        const VetEmptyState(
                          text: 'No hay citas futuras agendadas para hoy.',
                          icon: VetIcons.calendar,
                        ),
                      for (final a in m.todayAppointments)
                        HomeAppointmentRow(
                          title: '${a['patient_name']}',
                          subtitle: '${time(m.starts(a)!)} · ${a['kind']}',
                          tag: hour(m.starts(a)!),
                          color: sectionColor('Agenda'),
                          onTap: () => openPage('Agenda'),
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
                        const VetEmptyState(
                          text:
                              'No hay citas recientes en los datos consultados.',
                          icon: VetIcons.calendarClock,
                        ),
                      for (final a in m.recent.take(3))
                        HomeAppointmentRow(
                          title: '${a['patient_name']}',
                          subtitle: '${time(m.starts(a)!)} · ${a['state']}',
                          color: sectionColor('Agenda'),
                          onTap: () => openPage('Agenda'),
                        ),
                    ],
                  ),
                ),
              ]),
            ],
            if (m.canSummarize('inventory') &&
                (routeVisible('Inventario') || routeVisible('Caja'))) ...[
              if (routeVisible('Inventario'))
                panel('Inventario', 'Inventario', [
                  unavailable(
                    'Inventario',
                    m.stock != null,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${m.products.length} artículos activos · ${m.lowStock.length} por revisar',
                        ),
                        if (m.canSeeClinicSales && routeVisible('Caja'))
                          metrics([
                            (
                              'Valor a costo',
                              m.valueAtCost?.display ?? 'No disponible',
                            ),
                            (
                              'Valor a venta',
                              m.valueAtSale?.display ?? 'No disponible',
                            ),
                            (
                              'Margen potencial',
                              m.potentialMargin?.display ?? 'No disponible',
                            ),
                          ]),
                        const Text(
                          'Existencias disponibles por unidad; no incluye lotes caducados.',
                        ),
                        if (m.stockByUnit == null)
                          const Text('Existencias por unidad no disponibles.'),
                        for (final e
                            in (m.stockByUnit ?? <String, Quantity>{}).entries)
                          Text('${e.value.display()} ${e.key}'),
                        const Text(
                          'Margen potencial antes de comisiones y gastos; no es utilidad neta.',
                        ),
                        TextField(
                          controller: search,
                          decoration: const InputDecoration(
                            labelText: 'Buscar producto por nombre o código',
                            prefixIcon: Icon(VetIcons.search),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        if (search.text.trim().isNotEmpty)
                          for (final p
                              in m.products
                                  .where(
                                    (p) =>
                                        '${p['nombre']} ${p['codigo_barras'] ?? ''}'
                                            .toLowerCase()
                                            .contains(
                                              search.text.trim().toLowerCase(),
                                            ),
                                  )
                                  .take(5))
                            ListTile(
                              title: Text('${p['nombre']}'),
                              subtitle: Text(
                                'Disponible: ${p['available_stock']} ${p['stock_unit']}',
                              ),
                              onTap: () => openPage('Inventario'),
                            ),
                      ],
                    ),
                  ),
                ]),
              if (routeVisible('Caja'))
                panel('Caja del turno', 'Caja', [
                  unavailable(
                    'Inventario',
                    m.stock != null,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (m.ownShift == null) ...[
                          Row(
                            children: [
                              Icon(
                                VetIcons.lockOpen,
                                size: 18,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Caja cerrada',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Captura el fondo inicial al abrir el turno.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: widget.offline || m.busy || openingCash
                                ? null
                                : openCash,
                            icon: const Icon(VetIcons.lockOpen),
                            label: const Text('Abrir caja'),
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 18,
                                color: VetColors.successOn(context),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Caja abierta',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Fondo inicial',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              letterSpacing: .8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            money(m.ownShift!['opening_cash']),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              // onSurface y no la tinta clara: en el tema
                              // oscuro el importe quedaría invisible.
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => openPage('Caja'),
                            child: const Text('Venta o revisión del turno'),
                          ),
                        ],
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(height: 1),
                        ),
                        Text(
                          'ÚLTIMOS CORTES',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        if (m.recentCuts.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'No hay cortes cerrados en los datos consultados.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        for (final sh in m.recentCuts)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Cierre: ${time(DateTime.parse(sh['closed_at']))}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Contado: ${money(sh['counted_cash'])}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            onTap: () => openPage('Caja'),
                          ),
                      ],
                    ),
                  ),
                ]),
              if (m.canSeeClinicSales && routeVisible('Caja'))
                panel('Ventas de hoy', 'Caja', [
                  unavailable(
                    'Inventario',
                    totals != null,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Día de la clínica: ${m.stock?['today'] ?? 'no disponible'}',
                        ),
                        metrics([
                          ('Ventas menos reversos', money(totals?['gross'])),
                          (
                            'Margen tras costos y comisiones',
                            money(totals?['margin']),
                          ),
                          (
                            'Resultado con gastos capturados',
                            money(totals?['recorded_net']),
                          ),
                        ]),
                        metrics([
                          (
                            'Ventas vigentes del día',
                            totals?['sale_count'] is int
                                ? '${totals!['sale_count']}'
                                : 'No disponible',
                          ),
                          (
                            'Ticket promedio de ventas vigentes',
                            totals?['average_ticket'] == null
                                ? 'No disponible'
                                : money(totals!['average_ticket']),
                          ),
                        ]),
                        for (final entry in [
                          ('Efectivo', 'cash'),
                          ('Tarjeta', 'card'),
                          ('Transferencia', 'transfer'),
                        ])
                          ListTile(
                            title: Text(entry.$1),
                            trailing: Text(money(totals?[entry.$2])),
                          ),
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Importes netos de reversos. No acreditan que estén incluidos todos los gastos ni costos pendientes.',
                            style: TextStyle(
                              fontSize: 12,
                              color: VetColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
            ],
            if (m.canSummarize('hospital') &&
                routeAuthorized('Hospitalización'))
              panel('Próximas dosis', 'Hospitalización', [
                unavailable(
                  'Hospitalización',
                  m.ward != null,
                  Column(
                    children: [
                      if (m.nextDoses.isEmpty)
                        const VetEmptyState(
                          text:
                              'No hay dosis futuras pendientes en los datos consultados.',
                          icon: VetIcons.pills,
                        ),
                      for (final t in m.nextDoses.take(5))
                        ListTile(
                          title: Text('${m.patient(t)} · ${t.label}'),
                          subtitle: Text(time(m.effectiveTime(t))),
                          onTap: () => openPage('Hospitalización'),
                        ),
                    ],
                  ),
                ),
              ]),
            if (m.member != null &&
                m.commissions != null &&
                routeVisible('Servicios'))
              panel('Mis comisiones', 'Servicios', [
                VetDataRow(
                  label: 'Saldo pendiente de liquidar',
                  value: money(m.ownCommission?['amount'] ?? '0'),
                  icon: VetIcons.coins,
                  emphasized: true,
                ),
                if (m.commissions?['schedule'] is Map)
                  VetDataRow(
                    label: 'Próximo pago',
                    value: VetFormat.dateFromIso(
                      (m.commissions!['schedule'] as Map)['next_pay_on'],
                    ),
                    icon: VetIcons.calendar,
                  ),
                const VetNote(
                  text:
                      'El porcentaje se configura por servicio. Solo cuentan ventas vigentes.',
                  divider: true,
                ),
              ]),
            if (m.member?.isPersonal == false &&
                m.attendanceWeek != null &&
                routeVisible('Control de asistencia'))
              panel('Puntualidad y asistencia', 'Control de asistencia', [
                if (m.attendanceWeek!['week_summary'] is Map) ...[
                  () {
                    final s = m.attendanceWeek!['week_summary'] as Map;
                    final configured = s['configured'] == true;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        VetDataRow(
                          label: 'Semana desde',
                          value: VetFormat.dateFromIso(s['week_start']),
                          icon: VetIcons.calendar,
                        ),
                        VetDataRow(
                          label: 'Asistencias registradas',
                          value: '${s['attended'] ?? 0}',
                          icon: VetIcons.checkCircle,
                          emphasized: true,
                        ),
                        if (configured) ...[
                          VetDataRow(
                            label: 'A tiempo',
                            value: '${s['on_time'] ?? 0}',
                            valueColor: VetColors.success,
                          ),
                          VetDataRow(
                            label: 'Retrasos',
                            value: '${s['late'] ?? 0}',
                            valueColor: VetColors.warning,
                          ),
                        ] else
                          const VetNote(
                            text:
                                'La clínica aún no configuró un horario para medir retrasos.',
                          ),
                        const VetNote(
                          text:
                              'Administración ve el total del equipo; cada integrante ve sus propios registros.',
                          icon: VetIcons.info,
                          divider: true,
                        ),
                      ],
                    );
                  }(),
                ],
              ]),
            if (m.canShowTeamPanel('tasks') &&
                routeVisible('Pendientes del equipo'))
              panel('Tareas de hoy', 'Pendientes del equipo', [
                unavailable(
                  'Agenda',
                  m.agenda != null,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (m.todayTasks.isEmpty)
                        const VetEmptyState(
                          text: 'No hay tareas programadas para hoy.',
                          icon: VetIcons.clipboardList,
                        ),
                      for (final t in m.todayTasks.take(4))
                        ListTile(
                          title: Text('${t['title']} · ${t['priority']}'),
                          subtitle: Text(
                            t['assigned_to'] == null
                                ? 'Para el equipo'
                                : staffLabel(
                                    '${t['assigned_to']}',
                                    m.rows(m.agenda, 'people'),
                                  ),
                          ),
                          onTap: () => openPage('Pendientes del equipo'),
                        ),
                      TextButton(
                        onPressed: () => openPage('Pendientes del equipo'),
                        child: const Text('Crear o revisar pendientes'),
                      ),
                    ],
                  ),
                ),
              ]),
            if (m.canShowTeamPanel('messages') &&
                routeVisible('Anuncios y avisos'))
              panel('Anuncios y avisos', 'Anuncios y avisos', [
                unavailable(
                  'Agenda',
                  m.agenda != null,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (m.notices.isEmpty)
                        const VetEmptyState(
                          text: 'No hay avisos recientes.',
                          icon: VetIcons.bell,
                        ),
                      for (final msg in m.notices)
                        ListTile(
                          title: Text('${msg['category']} · ${msg['body']}'),
                          subtitle: Text(
                            '${staffLabel('${msg['author_id']}', m.rows(m.agenda, 'people'))} · ${time(DateTime.parse(msg['created_at']))}',
                          ),
                        ),
                      TextButton(
                        onPressed: () => openPage('Anuncios y avisos'),
                        child: const Text('Ver avisos'),
                      ),
                    ],
                  ),
                ),
              ]),
          ],
          const SizedBox(height: 16),
        ],
      );
    },
  );
}

/// Botón en cápsula simétrica de 2x2 para las acciones rápidas del Inicio
/// (Formatos, Estadísticas, Cálculos clínicos, Escáner), con relieve neu
/// suave y tonalidad lavanda armónica.
class _DashboardActionCapsule extends StatelessWidget {
  const _DashboardActionCapsule({
    required this.label,
    required this.page,
    required this.onTap,
  });

  final String label;
  final String page;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final neu = theme.extension<WorkspaceStyle>()?.neumorphic == true;
    final accent = sectionAccent(page);

    final vivid = vividAccent(accent);
    // Color de panel claro u oscuro con relieve neu y sin el morado anterior
    final surface = dark
        ? VetColors.darkSurface
        : (neu ? neuBackground : VetColors.surface);

    final textColor = dark ? const Color(0xFFE2E5EE) : const Color(0xFF1E2638);

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.85),
          width: 1.2,
        ),
        boxShadow: neu ? neuShadows(dark, depth: 0.65) : null,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(surface, Colors.white, dark ? 0.04 : 0.45)!,
            surface,
          ],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AccentGlow(
                  color: vivid,
                  radius: 10,
                  emphasis: 0.75,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(sectionIcon(page), size: 18, color: vivid),
                  ),
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      letterSpacing: 0.1,
                    ),
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

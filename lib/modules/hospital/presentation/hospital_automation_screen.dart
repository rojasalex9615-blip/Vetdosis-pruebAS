import 'package:flutter/material.dart';
import '../../auth/domain/clinic_membership.dart';
import '../../prescribing/presentation/rx_entry_screen.dart';
import '../domain/hospital_automation.dart';
import '../domain/hospital_repository.dart';
import '../application/hospital_push_service.dart';

class HospitalAutomationScreen extends StatefulWidget {
  const HospitalAutomationScreen({
    super.key,
    required this.repository,
    required this.member,
    this.stayId,
    this.pushService,
  });
  final HospitalAutomationRepository repository;
  final ClinicMembership member;
  final String? stayId;
  final HospitalPushService? pushService;
  @override
  State<HospitalAutomationScreen> createState() =>
      _HospitalAutomationScreenState();
}

class _HospitalAutomationScreenState extends State<HospitalAutomationScreen> {
  HospitalAutomationWorkspace? workspace;
  String? error;
  bool busy = false, opening = false;
  bool pushBusy = false;
  String? pushError;
  List<Map<String, dynamic>> pushTargets = [];
  int generation = 0;
  @override
  void initState() {
    super.initState();
    load();
    loadPushTargets();
  }

  @override
  void dispose() {
    generation++;
    workspace = null;
    super.dispose();
  }

  Future<void> load() async {
    if (!mounted) return;
    final current = ++generation;
    setState(() {
      busy = true;
      workspace = null;
      error = null;
    });
    try {
      final raw = await widget.repository.automationWorkspace(
        widget.member.clinicId,
        widget.stayId,
      );
      if (!mounted || current != generation) return;
      final w = HospitalAutomationWorkspace.read(
        raw,
        widget.member.clinicId,
        widget.member.userId,
        widget.stayId,
      );
      setState(() => workspace = w);
    } catch (_) {
      if (mounted && current == generation) {
        setState(
          () => error =
              'No se pudieron consultar las órdenes y avisos. Revisa permisos, conexión y versión del servidor.',
        );
      }
    } finally {
      if (mounted && current == generation) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> loadPushTargets() async {
    final service = widget.pushService;
    if (service == null) return;
    try {
      final targets = await service.targets(widget.member);
      if (mounted) setState(() { pushTargets = targets; pushError = null; });
    } catch (_) {
      if (mounted) {
        setState(() => pushError =
            'No se pudieron consultar los destinos de aviso. Revisa la conexión y la versión del servidor.');
      }
    }
  }

  Future<bool> confirmPush(String title, String details) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(details),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirmar')),
          ],
        ),
      ) ?? false;

  Future<void> enablePush() async {
    final service = widget.pushService;
    if (service == null || pushBusy) return;
    final confirmed = await confirmPush(
      'Avisos en este teléfono',
      'Acepto recibir avisos hospitalarios genéricos de esta clínica en este teléfono. '
      'No incluyen datos del paciente ni confirman que se haya realizado el cuidado. '
      'Puedo revocar este permiso aquí.',
    );
    if (!mounted || !confirmed) return;
    setState(() { pushBusy = true; pushError = null; });
    try {
      await service.enable(widget.member);
      await loadPushTargets();
    } catch (_) {
      if (mounted) {
        setState(() => pushError =
            'No se pudo activar este teléfono. Revisa permisos de notificación, conexión y acceso hospitalario.');
      }
    } finally {
      if (mounted) setState(() => pushBusy = false);
    }
  }

  Future<void> revokePush(String targetId, {bool thisDevice = false}) async {
    final service = widget.pushService;
    if (service == null || pushBusy) return;
    final confirmed = await confirmPush(
      'Revocar avisos',
      'Este destino dejará de recibir nuevos avisos hospitalarios de la clínica.',
    );
    if (!mounted || !confirmed) return;
    setState(() { pushBusy = true; pushError = null; });
    try {
      if (thisDevice) {
        await service.disableThisDevice(widget.member);
      } else {
        await service.revoke(widget.member, targetId);
      }
      await loadPushTargets();
    } catch (_) {
      if (mounted) {
        setState(() => pushError =
            'No se pudo revocar el destino. Revisa conexión y sesión antes de salir.');
      }
    } finally {
      if (mounted) setState(() => pushBusy = false);
    }
  }

  Future<void> form(
    String title,
    List<RxField> fields,
    Future<void> Function(Map<String, dynamic>, String) submit, {
    String? review,
  }) async {
    if (opening || busy) return;
    setState(() => opening = true);
    try {
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => RxEntryScreen(
            title: title,
            fields: fields,
            submit: submit,
            reviewText: review,
          ),
        ),
      );
      if (mounted) await load();
    } finally {
      if (mounted) {
        setState(() => opening = false);
      }
    }
  }

  Future<void> order({Map<String, dynamic>? replaces}) async {
    if (opening || busy) return;
    await load();
    final w = workspace;
    if (!mounted || w == null || !w.canCreate || widget.stayId == null) return;
    if (replaces != null &&
        !w
            .rows('orders')
            .any((r) => r['id'] == replaces['id'] && r['can_stop'] == true)) {
      return;
    }
    final procedures = {
      for (final r in w.rows('procedures'))
        r['id'] as String: r['name'] as String,
    };
    await form(
      replaces == null ? 'Orden diaria en servidor' : 'Nueva versión de orden',
      [
        RxField(
          'procedure_id',
          'Tipo de procedimiento',
          type: 'select',
          options: procedures,
          required: true,
        ),
        const RxField('label', 'Nombre del cuidado indicado', required: true),
        const RxField(
          'instructions',
          'Indicación profesional completa (porción o dispositivo si corresponde)',
          required: true,
        ),
        const RxField(
          'first_day',
          'Primera fecha (AAAA-MM-DD)',
          required: true,
        ),
        const RxField('last_day', 'Última fecha (AAAA-MM-DD)', required: true),
        const RxField(
          'zone',
          'Zona IANA confirmada (ej. America/Mexico_City)',
          required: true,
        ),
        const RxField(
          'times',
          'Horarios diarios HH:mm separados por comas',
          required: true,
        ),
        const RxField(
          'escalation_minutes',
          'Escalar si nadie responde tras (minutos)',
          required: true,
        ),
        if (replaces != null)
          const RxField(
            'change_reason',
            'Motivo de nueva versión',
            required: true,
          ),
        const RxField(
          'confirmed',
          'Revisé paciente, indicación, vigencia, zona y horarios; autorizo la generación diaria',
          type: 'checkbox',
          required: true,
        ),
      ],
      (data, operation) => widget.repository.createDailyOrder(
        widget.member.clinicId,
        widget.stayId!,
        validateDailyOrder({
          ...data,
          if (replaces != null) 'replaces_id': replaces['id'],
        }),
        operation,
      ),
      review:
          'El servidor genera hoy y mañana, y recupera horarios omitidos tras una interrupción. Máximo 31 días y 200 tareas por orden; no se renueva al terminar. Todos los horarios de la vigencia deben ser futuros al autorizar. Las horas inexistentes o ambiguas por cambio estacional se rechazan. '
          'No se infieren dosis ni se confirma ningún cuidado. ${replaces == null ? '' : 'La nueva versión detiene los horarios futuros pendientes de la anterior; conserva los vencidos y realizados para su resolución explícita.'}',
    );
  }

  Future<void> route() async {
    if (opening || busy) return;
    await load();
    final w = workspace;
    if (!mounted || w == null || !w.canManage) return;
    final members = w.rows('members');
    await form(
      'Responsables de avisos',
      [
        RxField(
          'primary',
          'Encargado que recibe el primer aviso',
          type: 'select',
          options: {
            for (final r in members.where((r) => r['primary_eligible'] == true))
              r['id'] as String: r['name'] as String,
          },
          required: true,
        ),
        RxField(
          'mvz',
          'MVZ responsable que recibe la escalación',
          type: 'select',
          options: {
            for (final r in members.where((r) => r['mvz_eligible'] == true))
              r['id'] as String: r['name'] as String,
          },
          required: true,
        ),
        const RxField(
          'confirmed',
          'Revisé ambos destinatarios',
          type: 'checkbox',
          required: true,
        ),
      ],
      (data, operation) async {
        if (data['primary'] == data['mvz']) {
          throw const FormatException('Elige dos integrantes distintos.');
        }
        await widget.repository.setNoticeRoute(
          widget.member.clinicId,
          data['primary'],
          data['mvz'],
          operation,
        );
      },
      review:
          'Requieren permisos de lectura y observaciones hospitalarias. La escalación requiere un MVZ responsable designado, aceptado y vigente. La entrega externa con la app cerrada requiere configurar su canal durante la integración final.',
    );
  }

  String timeLabel(int minute) =>
      "${'${minute ~/ 60}'.padLeft(2, '0')}:${'${minute % 60}'.padLeft(2, '0')}";
  @override
  Widget build(BuildContext context) {
    final w = workspace;
    return Scaffold(
      appBar: AppBar(title: const Text('Órdenes diarias y avisos')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Generación en servidor desde indicaciones autorizadas. Recibir un aviso no significa haber realizado el cuidado.',
          ),
          OutlinedButton(
            onPressed: busy || opening ? null : load,
            child: const Text('Actualizar órdenes y avisos'),
          ),
          if (busy) const LinearProgressIndicator(),
          if (error != null) Text(error!),
          if (w != null) ...[
            Text(
              w.enabled
                  ? 'Generador habilitado. Última ejecución: ${w.raw['runtime']['last_run_at'] ?? 'sin ejecución registrada'}.'
                  : 'Generador todavía desactivado en servidor. Las órdenes automáticas no pueden crearse hasta su activación revisada.',
            ),
            const Text(
              'Los avisos de esta bandeja no acreditan una notificación externa entregada. El canal con la app cerrada se verifica en la integración final.',
            ),
            if (w.raw['route'] == null)
              const Text('Sin responsables de avisos configurados.')
            else
              Text(
                'Primer aviso: ${w.raw['route']['primary_user']} · Escalación MVZ: ${w.raw['route']['mvz_user']}',
              ),
            if (w.raw['route'] != null &&
                (w.raw['route']['primary_current'] == false ||
                    w.raw['route']['mvz_current'] == false))
              const Text(
                'Hay un destinatario sin autorización vigente. Revisa los responsables de avisos.',
              ),
            if (w.canManage)
              OutlinedButton(
                onPressed: opening ? null : route,
                child: const Text('Configurar responsables de avisos'),
              ),
            if (widget.pushService != null) ...[
              const SizedBox(height: 12),
              const Text('Avisos al teléfono'),
              Text(w.raw['runtime']?['external_delivery_enabled'] == true
                  ? 'La entrega externa está habilitada en servidor.'
                  : 'La entrega externa aún está apagada; registrar este teléfono prepara su destino.'),
              if (pushError != null) Text(pushError!),
              if (pushBusy) const LinearProgressIndicator(),
              if (!widget.pushService!.enrolled(widget.member))
                OutlinedButton(
                  onPressed: pushBusy ? null : enablePush,
                  child: const Text('Aceptar avisos en este teléfono'),
                ),
              for (final target in pushTargets)
                ListTile(
                  title: Text(target['label']?.toString() ?? 'Destino de aviso'),
                  subtitle: Text(target['channel'] == 'whatsapp'
                      ? 'WhatsApp · consentimiento ${target['consent_at']}'
                      : 'Notificación al teléfono · consentimiento ${target['consent_at']}'),
                  trailing: TextButton(
                    onPressed: pushBusy ? null : () => revokePush(
                      target['id'] as String,
                      thisDevice: widget.pushService!.enrolled(widget.member) &&
                          target['id'] == widget.pushService!.currentTargetId(widget.member),
                    ),
                    child: const Text('Revocar'),
                  ),
                ),
            ],
            if (w.canCreate)
              FilledButton(
                onPressed: opening ? null : order,
                child: const Text('Crear orden diaria en servidor'),
              ),
            const SizedBox(height: 16),
            const Text('Órdenes e historial'),
            if (w.rows('orders').isEmpty)
              const Text('Sin órdenes diarias registradas.'),
            for (final r in w.rows('orders'))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${r['patient_name']} · ${r['label']} · versión ${r['version']}',
                      ),
                      Text(r['instructions']),
                      Text(
                        '${r['first_day']} a ${r['last_day']} · ${r['zone']}\n${(r['minutes'] as List).map((m) => timeLabel(m as int)).join(', ')}',
                      ),
                      Text('Autorizó: ${r['author_id']} · ${r['created_at']}'),
                      if (r['replaces_id'] != null)
                        Text('Sustituye: ${r['replaces_id']}'),
                      if (r['stop'] != null)
                        Text(
                          'Detenida: ${r['stop']['reason']} · ${r['stop']['created_at']}',
                        ),
                      if (r['can_stop'] == true) ...[
                        if (w.canCreate)
                          TextButton(
                            onPressed: opening
                                ? null
                                : () => order(replaces: r),
                            child: const Text('Crear nueva versión'),
                          ),
                        TextButton(
                          onPressed: opening
                              ? null
                              : () => form(
                                  'Detener orden diaria',
                                  const [
                                    RxField('reason', 'Motivo', required: true),
                                  ],
                                  (d, op) => widget.repository.stopDailyOrder(
                                    widget.member.clinicId,
                                    r['id'],
                                    d['reason'],
                                    op,
                                  ),
                                  review:
                                      'Cancela únicamente horarios futuros pendientes de esta orden. Los vencidos y realizados conservan su historia y requieren resolución explícita.',
                                ),
                          child: const Text('Detener horarios futuros'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            const Text('Avisos y respuestas'),
            if (w.rows('notices').isEmpty)
              const Text('Sin avisos registrados.'),
            for (final n in w.rows('notices'))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${n['patient_name']} · ${n['task_label']}'),
                      Text(
                        '${n['stage'] == 'mvz' ? 'Escalación al MVZ' : 'Primer aviso'} · ${n['created_at']}\nDestinatario: ${n['recipient_id']} · Tarea: ${n['task_state']}',
                      ),
                      if (n['response'] != null)
                        Text(
                          'Respondió: ${n['response']['actor_id']} · ${n['response']['created_at']}\n${n['response']['note']}',
                        ),
                      if (n['can_ack'] == true)
                        TextButton(
                          onPressed: opening
                              ? null
                              : () => form(
                                  'Confirmar recepción del aviso',
                                  const [
                                    RxField(
                                      'note',
                                      'Respuesta / acción de seguimiento',
                                      required: true,
                                    ),
                                    RxField(
                                      'confirmed',
                                      'Confirmo que recibí este aviso; el cuidado sigue pendiente hasta registrarlo',
                                      type: 'checkbox',
                                      required: true,
                                    ),
                                  ],
                                  (d, op) =>
                                      widget.repository.acknowledgeNotice(
                                        widget.member.clinicId,
                                        n['id'],
                                        d['note'],
                                        op,
                                      ),
                                  review:
                                      'La respuesta conserva quién y cuándo. Si se registra antes de la escalación, evita ese siguiente aviso; no marca realizado ni cancela la tarea o su alarma local.',
                                ),
                          child: const Text('Confirmar que recibí el aviso'),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

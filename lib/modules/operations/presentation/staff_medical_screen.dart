import 'dart:convert';

import 'package:flutter/material.dart';

import '../../auth/domain/clinic_membership.dart';
import '../../patients/presentation/patient_view_model.dart'
    show newOperationId;
import '../domain/operations_repository.dart';

const medicalFields = {
  'emergency': 'Contacto de emergencia (nombre, parentesco y teléfono)',
  'blood': 'Tipo de sangre',
  'allergies': 'Alergias',
  'drug_allergies': 'Fármacos a los que soy alérgico/a',
  'conditions': 'Enfermedades o padecimientos (opcional)',
  'vaccines': 'Vacunación',
};
String medicalFailure(Object error) {
  final text = error.toString();
  if (text.contains('staff_medical_revision_changed') ||
      text.contains('staff_medical_refresh_required')) {
    return 'La ficha cambió en otra sesión. Actualiza y revisa antes de guardar.';
  }
  if (text.contains('staff_medical_read_required')) {
    return 'La consulta del equipo requiere administración y permiso vigente específico.';
  }
  if (text.contains('staff_medical_profile_unavailable')) {
    return 'La ficha se retiró o no tiene consentimiento vigente. Actualiza la lista.';
  }
  if (text.contains('staff_medical_fields_invalid')) {
    return 'El servidor de esta clínica aún no admite todos los campos (fármacos). Deja ese campo vacío o espera la actualización.';
  }
  if (text.contains('staff_medical_delegate_required')) {
    return 'Esta persona ya no te comparte su ficha.';
  }
  if (text.contains('PGRST202')) {
    return 'Esta función requiere la actualización del servidor.';
  }
  if (text.contains('staff_medical_consent_required')) {
    return 'Revisa el aviso vigente y confirma tu consentimiento para guardar.';
  }
  return 'No se confirmó la operación. Revisa el historial antes de reintentar; los mismos datos conservan el intento.';
}

bool medicalScope(Map<String, dynamic> data, ClinicMembership member) =>
    data['schema_version'] == 1 &&
    data['clinic_id'] == member.clinicId &&
    data['actor_id'] == member.userId;

class StaffMedicalScreen extends StatefulWidget {
  const StaffMedicalScreen({
    super.key,
    required this.repository,
    required this.member,
  });
  final StaffMedicalRepository repository;
  final ClinicMembership member;
  @override
  State<StaffMedicalScreen> createState() => _StaffMedicalScreenState();
}

class _StaffMedicalScreenState extends State<StaffMedicalScreen>
    with WidgetsBindingObserver {
  final fields = {
    for (final key in medicalFields.keys) key: TextEditingController(),
  };
  Map<String, dynamic>? data;
  bool busy = false, consent = false, hidden = false;
  String? error, retryKey, operation;
  int generation = 0;
  bool current(int revision) => mounted && generation == revision;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  void clear() {
    data = null;
    consent = false;
    for (final c in fields.values) {
      c.clear();
    }
  }

  @override
  void dispose() {
    generation++;
    clear();
    WidgetsBinding.instance.removeObserver(this);
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant StaffMedicalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.member.userId != widget.member.userId ||
        oldWidget.member.clinicId != widget.member.clinicId ||
        oldWidget.member.role != widget.member.role) {
      generation++;
      clear();
      retryKey = null;
      operation = null;
      busy = false;
      load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      generation++;
      setState(() {
        hidden = true;
        busy = false;
        clear();
      });
    }
    if (state == AppLifecycleState.resumed && hidden) {
      hidden = false;
      load();
    }
  }

  Future<void> load() async {
    final revision = generation;
    setState(() {
      busy = true;
      error = null;
      clear();
    });
    try {
      final next = await widget.repository.staffMedicalWorkspace(
        widget.member.clinicId,
        widget.member.userId,
      );
      if (!current(revision)) return;
      if (!medicalScope(next, widget.member) ||
          next['notice'] is! Map ||
          next['notice']['text'] is! String ||
          next['notice']['hash'] is! String ||
          next['notice']['version'] is! int ||
          next['revision'] is! int ||
          next['member_since'] is! String) {
        throw StateError('unknown_medical_contract');
      }
      setState(() {
        data = next;
        final details = next['profile']?['details'] as Map? ?? {};
        for (final key in fields.keys) {
          fields[key]!.text = '${details[key] ?? ''}';
        }
      });
    } catch (e) {
      if (current(revision)) {
        setState(() {
          clear();
          error =
              'No se pudo consultar tu ficha. Comprueba conexión, sesión y la actualización de la clínica.';
        });
      }
    } finally {
      if (current(revision)) setState(() => busy = false);
    }
  }

  Future<void> withdraw() async {
    if (busy || data?['profile'] == null) return;
    final revision = generation;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirar mi ficha'),
        content: const Text(
          'Se eliminará la ficha activa. Se conserva el historial mínimo de consentimientos y accesos, sin el contenido médico. No necesitas aceptar el aviso para retirarla.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar retirada'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    if (!current(revision)) {
      setState(
        () => error =
            'La pantalla se ocultó antes de confirmar. Revisa tu ficha y repite la retirada.',
      );
      return;
    }
    await mutate('withdraw');
  }

  Future<void> mutate(String action) async {
    if (busy || data == null || (action == 'save' && !consent)) return;
    final revision = generation;
    try {
      final details = {
        for (final key in fields.keys)
          if (fields[key]!.text.trim().isNotEmpty)
            key: fields[key]!.text.trim(),
      };
      if (action == 'save' && details.isEmpty) {
        throw const FormatException(
          'Completa al menos un dato o usa la retirada de la ficha.',
        );
      }
      final args = <String, dynamic>{
        'p_clinic': widget.member.clinicId,
        'p_actor': widget.member.userId,
        'p_action': action,
        'p_details': action == 'save' ? details : null,
        'p_consent': action == 'save',
        'p_notice_version': action == 'save'
            ? data!['notice']['version']
            : null,
        'p_notice_hash': action == 'save' ? data!['notice']['hash'] : null,
        'p_expected_revision': data!['revision'],
        'p_member_since': data!['member_since'],
      };
      final key = jsonEncode(args);
      if (retryKey != key) {
        retryKey = key;
        operation = newOperationId();
      }
      args['p_operation'] = operation;
      setState(() {
        busy = true;
        error = null;
      });
      await widget.repository.staffMedicalWrite(args);
      if (!current(revision)) return;
      retryKey = null;
      operation = null;
      await load();
    } on FormatException catch (e) {
      if (current(revision)) setState(() => error = e.message);
    } catch (e) {
      if (current(revision)) setState(() => error = medicalFailure(e));
    } finally {
      if (current(revision)) setState(() => busy = false);
    }
  }

  Future<void> team() async {
    if (busy || data?['can_team_read'] != true) return;
    final revision = generation;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StaffMedicalTeamScreen(
          repository: widget.repository,
          member: widget.member,
        ),
      ),
    );
    if (current(revision)) await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mi ficha de emergencia')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (busy) const LinearProgressIndicator(),
        TextButton(
          onPressed: busy ? null : load,
          child: const Text('Actualizar mi ficha'),
        ),
        if (data != null) ...[
          Text(data!['notice']['text'] as String),
          if (data!['profile'] != null &&
              data!['profile']['consent_current'] != true)
            const Text(
              'Tu ficha conserva un consentimiento anterior. Puedes retirarla o revisar el aviso actual antes de guardarla de nuevo.',
            ),
          for (final key in fields.keys)
            TextField(
              controller: fields[key],
              enabled: !busy,
              maxLength: 2000,
              decoration: InputDecoration(labelText: medicalFields[key]),
              onChanged: (_) => setState(() => consent = false),
            ),
          CheckboxListTile(
            value: consent,
            title: const Text(
              'He leído el aviso y consiento guardar estos datos',
            ),
            onChanged: busy
                ? null
                : (v) => setState(() => consent = v ?? false),
          ),
          FilledButton(
            onPressed: busy || !consent ? null : () => mutate('save'),
            child: const Text('Guardar con mi consentimiento'),
          ),
          if (data!['profile'] != null)
            TextButton(
              onPressed: busy ? null : withdraw,
              child: const Text('Retirar mi ficha y consentimiento'),
            ),
          if (data!['can_team_read'] == true)
            TextButton(
              onPressed: busy ? null : team,
              child: const Text('Consulta autorizada de fichas del equipo'),
            ),
          if (widget.repository is StaffMedicalSharingRepository &&
              !widget.member.isPersonal)
            StaffMedicalSharingPanel(
              repository: widget.repository as StaffMedicalSharingRepository,
              member: widget.member,
              profileShared: data!['profile']?['consent_current'] == true,
            ),
          if ((data!['events'] as List? ?? []).isNotEmpty)
            const Text('Historial de consentimiento de mi ficha'),
          for (final event in (data!['events'] as List? ?? []).cast<Map>())
            Text(
              '${event['created_at']} · ${event['action'] == 'accepted' ? 'Aceptación' : 'Retirada'}',
            ),
          // Con el servidor actualizado el panel de arriba muestra los
          // accesos con nombre; sin el, queda la lista anterior.
          if (widget.repository is! StaffMedicalSharingRepository ||
              widget.member.isPersonal) ...[
            if ((data!['accesses'] as List? ?? []).isNotEmpty)
              const Text('Últimos accesos administrativos a mi ficha'),
            for (final access in (data!['accesses'] as List? ?? []).cast<Map>())
              Text(
                '${access['created_at']} · ${access['actor_id']} · ${medicalPurposeLabel(access['purpose'])}',
              ),
          ],
        ],
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
  );
}

class StaffMedicalTeamScreen extends StatefulWidget {
  const StaffMedicalTeamScreen({
    super.key,
    required this.repository,
    required this.member,
  });
  final StaffMedicalRepository repository;
  final ClinicMembership member;
  @override
  State<StaffMedicalTeamScreen> createState() => _StaffMedicalTeamScreenState();
}

class _StaffMedicalTeamScreenState extends State<StaffMedicalTeamScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> people = [];
  Map<String, dynamic>? viewed;
  bool busy = false, more = false;
  String? error;
  int generation = 0;
  bool current(int revision) => mounted && generation == revision;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void dispose() {
    generation++;
    viewed = null;
    people = [];
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant StaffMedicalTeamScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.member.userId != widget.member.userId ||
        oldWidget.member.clinicId != widget.member.clinicId ||
        oldWidget.member.role != widget.member.role) {
      generation++;
      viewed = null;
      people = [];
      busy = false;
      load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      generation++;
      setState(() {
        viewed = null;
        people = [];
        busy = false;
        more = false;
        error =
            'La consulta se ocultó al salir de la aplicación. Actualiza y confirma de nuevo la finalidad para consultar otra ficha.';
      });
    }
  }

  Future<void> load({bool append = false}) async {
    final revision = generation;
    setState(() {
      busy = true;
      error = null;
      viewed = null;
      if (!append) {
        people = [];
        more = false;
      }
    });
    try {
      final data = await widget.repository.staffMedicalDirectory(
        widget.member.clinicId,
        widget.member.userId,
        offset: append ? people.length : 0,
      );
      if (!current(revision)) return;
      if (!medicalScope(data, widget.member)) {
        throw StateError('session_changed');
      }
      final rows = (data['items'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() {
        people.addAll(rows);
        more = rows.length == 100;
      });
    } catch (e) {
      if (current(revision)) {
        setState(() {
          people = [];
          more = false;
          error = medicalFailure(e);
        });
      }
    } finally {
      if (current(revision)) setState(() => busy = false);
    }
  }

  Future<void> open(Map<String, dynamic> person) async {
    if (busy) return;
    final revision = generation;
    setState(() => viewed = null);
    final purpose = await askMedicalPurpose(
      context,
      '${person['display_name']}',
    );
    if (purpose == null || !mounted) return;
    if (!current(revision)) {
      setState(
        () => error =
            'La pantalla se ocultó antes de confirmar. Confirma de nuevo la finalidad de consulta.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = await widget.repository.staffMedicalView(
        widget.member.clinicId,
        widget.member.userId,
        '${person['user_id']}',
        purpose,
      );
      if (!current(revision)) return;
      if (!medicalScope(data, widget.member) ||
          data['subject_id'] != person['user_id'] ||
          data['access_id'] is! String ||
          data['details'] is! Map) {
        throw StateError('session_changed');
      }
      setState(() => viewed = data);
    } catch (e) {
      if (current(revision)) {
        setState(() {
          viewed = null;
          error = medicalFailure(e);
        });
      }
    } finally {
      if (current(revision)) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Fichas del equipo')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Solo fichas con consentimiento vigente. Cada consulta requiere finalidad explícita y queda registrada.',
        ),
        if (busy) const LinearProgressIndicator(),
        TextButton(
          onPressed: busy ? null : () => load(),
          child: const Text('Actualizar lista'),
        ),
        for (final person in people)
          ListTile(
            title: Text('${person['display_name']}'),
            trailing: TextButton(
              onPressed: busy ? null : () => open(person),
              child: const Text('Consultar ficha'),
            ),
          ),
        if (more)
          TextButton(
            onPressed: busy ? null : () => load(append: true),
            child: const Text('Cargar más personas'),
          ),
        if (viewed != null) ...[
          const Text('Ficha privada · acceso registrado'),
          for (final field in medicalFields.entries)
            if (viewed!['details'][field.key] != null)
              Text('${field.value}: ${viewed!['details'][field.key]}'),
          TextButton(
            onPressed: () => setState(() => viewed = null),
            child: const Text('Ocultar ficha'),
          ),
        ],
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
  );
}

String medicalPurposeLabel(Object? purpose) =>
    purpose == 'emergency' ? 'Emergencia' : 'Preparación para emergencias';

/// Pide la finalidad y la confirmacion de que el acceso queda registrado.
/// Devuelve null si la persona cancela.
Future<String?> askMedicalPurpose(BuildContext context, String name) async {
  String? purpose;
  bool confirmed = false;
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        title: const Text('Finalidad de la consulta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name),
            DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Finalidad'),
              items: const [
                DropdownMenuItem(value: 'emergency', child: Text('Emergencia')),
                DropdownMenuItem(
                  value: 'emergency_preparation',
                  child: Text('Preparación para emergencias'),
                ),
              ],
              onChanged: (v) => update(() {
                purpose = v;
                confirmed = false;
              }),
            ),
            CheckboxListTile(
              value: confirmed,
              title: const Text(
                'Confirmo esta finalidad y el registro de mi acceso',
              ),
              onChanged: (v) => update(() => confirmed = v ?? false),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: purpose == null || !confirmed
                ? null
                : () => Navigator.pop(context, true),
            child: const Text('Consultar y registrar acceso'),
          ),
        ],
      ),
    ),
  );
  return accepted == true ? purpose : null;
}

/// Compañeros elegidos, fichas que me compartieron y registro de accesos.
///
/// La ficha solo la consultan la administración con permiso específico y los
/// compañeros que su dueño elige aqui. Cada consulta pide finalidad y queda
/// registrada; ese registro lo ven el dueño y la administración.
class StaffMedicalSharingPanel extends StatefulWidget {
  const StaffMedicalSharingPanel({
    super.key,
    required this.repository,
    required this.member,
    required this.profileShared,
  });
  final StaffMedicalSharingRepository repository;
  final ClinicMembership member;

  /// Si la ficha propia tiene consentimiento vigente. Sin el, elegir
  /// compañeros no les da nada que consultar y se avisa.
  final bool profileShared;
  @override
  State<StaffMedicalSharingPanel> createState() =>
      _StaffMedicalSharingPanelState();
}

class _StaffMedicalSharingPanelState extends State<StaffMedicalSharingPanel>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> colleagues = [], shared = [], log = [];
  Map<String, dynamic>? viewed;
  String? viewedName, error, scope;
  bool busy = false;
  int generation = 0;
  bool current(int revision) => mounted && generation == revision;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void dispose() {
    generation++;
    viewed = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant StaffMedicalSharingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.member.userId != widget.member.userId ||
        oldWidget.member.clinicId != widget.member.clinicId) {
      generation++;
      viewed = null;
      load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Una ficha ajena no se queda en pantalla al salir de la aplicacion.
    if ((state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused) &&
        viewed != null) {
      setState(() {
        viewed = null;
        viewedName = null;
      });
    }
  }

  List<Map<String, dynamic>> rows(Object? value) => (value as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  Future<void> load() async {
    final revision = generation;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final c = widget.member.clinicId, a = widget.member.userId;
      final delegates = await widget.repository.staffMedicalDelegates(c, a);
      final access = await widget.repository.staffMedicalAccessLog(c, a);
      if (!current(revision)) return;
      if (!medicalScope(delegates, widget.member) ||
          !medicalScope(access, widget.member)) {
        throw StateError('session_changed');
      }
      setState(() {
        colleagues = rows(delegates['colleagues']);
        shared = rows(delegates['shared_with_me']);
        log = rows(access['items']);
        scope = access['scope'] as String?;
      });
    } catch (e) {
      if (current(revision)) {
        setState(() {
          colleagues = [];
          shared = [];
          log = [];
          error = medicalFailure(e);
        });
      }
    } finally {
      if (current(revision)) setState(() => busy = false);
    }
  }

  Future<void> toggle(Map<String, dynamic> person, bool enabled) async {
    if (busy) return;
    final revision = generation;
    setState(() => busy = true);
    try {
      await widget.repository.staffMedicalDelegateSet(
        widget.member.clinicId,
        widget.member.userId,
        '${person['user_id']}',
        enabled,
      );
      if (!current(revision)) return;
      busy = false;
      await load();
    } catch (e) {
      if (current(revision)) {
        setState(() {
          busy = false;
          error = medicalFailure(e);
        });
      }
    }
  }

  Future<void> open(Map<String, dynamic> person) async {
    if (busy) return;
    final revision = generation;
    final name = '${person['display_name']}';
    final purpose = await askMedicalPurpose(context, name);
    if (purpose == null || !current(revision)) return;
    setState(() {
      busy = true;
      viewed = null;
      error = null;
    });
    try {
      final data = await widget.repository.staffMedicalDelegateView(
        widget.member.clinicId,
        widget.member.userId,
        '${person['user_id']}',
        purpose,
      );
      if (!current(revision)) return;
      if (!medicalScope(data, widget.member) ||
          data['subject_id'] != person['user_id'] ||
          data['details'] is! Map) {
        throw StateError('session_changed');
      }
      setState(() {
        viewed = data;
        viewedName = name;
      });
    } catch (e) {
      if (current(revision)) setState(() => error = medicalFailure(e));
    } finally {
      if (current(revision)) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Text('Compañeros con acceso en emergencia', style: text.titleMedium),
          Text(
            widget.profileShared
                ? 'Elige quién de esta clínica puede consultar tu ficha si te pasa algo. Puedes quitarlo cuando quieras.'
                : 'Guarda tu ficha con el aviso vigente para que los compañeros que elijas puedan consultarla.',
          ),
          if (busy) const LinearProgressIndicator(),
          if (colleagues.isEmpty && !busy && error == null)
            const Text('No hay más integrantes en esta clínica.'),
          for (final person in colleagues)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${person['display_name']}'),
              value: person['delegated'] == true,
              onChanged: busy ? null : (v) => toggle(person, v),
            ),
          if (shared.isNotEmpty) ...[
            const Divider(),
            Text('Fichas que me compartieron', style: text.titleMedium),
            for (final person in shared)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${person['display_name']}'),
                subtitle: person['available'] == true
                    ? null
                    : const Text('Sin ficha vigente por ahora'),
                trailing: TextButton(
                  onPressed: busy || person['available'] != true
                      ? null
                      : () => open(person),
                  child: const Text('Consultar'),
                ),
              ),
          ],
          if (viewed != null) ...[
            Text(
              'Ficha de $viewedName · acceso registrado',
              style: text.titleSmall,
            ),
            for (final field in medicalFields.entries)
              if (viewed!['details'][field.key] != null)
                Text('${field.value}: ${viewed!['details'][field.key]}'),
            TextButton(
              onPressed: () => setState(() {
                viewed = null;
                viewedName = null;
              }),
              child: const Text('Ocultar ficha'),
            ),
          ],
          const Divider(),
          Text(
            scope == 'clinic'
                ? 'Registro de accesos a fichas de la clínica'
                : 'Quién consultó mi ficha',
            style: text.titleMedium,
          ),
          if (log.isEmpty && !busy && error == null)
            const Text('Nadie ha consultado todavía.'),
          for (final item in log)
            Text(
              '${_when(item['created_at'])} · ${item['actor_name']}'
              '${scope == 'clinic' ? ' → ${item['subject_name']}' : ''}'
              ' · ${item['via'] == 'delegate' ? 'Compañero elegido' : 'Administración'}'
              ' · ${medicalPurposeLabel(item['purpose'])}',
            ),
          TextButton(
            onPressed: busy ? null : load,
            child: const Text('Actualizar compañeros y accesos'),
          ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }
}

String _when(Object? value) {
  final at = DateTime.tryParse('$value')?.toLocal();
  if (at == null) return '$value';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(at.day)}/${two(at.month)}/${at.year} ${two(at.hour)}:${two(at.minute)}';
}

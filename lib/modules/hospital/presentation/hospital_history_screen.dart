import 'dart:async';
import 'package:flutter/material.dart';
import '../domain/hospital_history.dart';
import 'hospital_history_view_model.dart';
import '../../../vet_ui/vet_icons.dart';

class HospitalHistoryScreen extends StatefulWidget {
  const HospitalHistoryScreen({
    super.key,
    required this.repository,
    required this.clinic,
    required this.isCurrent,
    required this.identityChanges,
  });
  final HospitalHistoryRepository repository;
  final String clinic;
  final bool Function() isCurrent;
  final Listenable identityChanges;
  @override
  State<HospitalHistoryScreen> createState() => _HospitalHistoryScreenState();
}

class _HospitalHistoryScreenState extends State<HospitalHistoryScreen> {
  late final HospitalHistoryViewModel model;
  final search = TextEditingController();
  Timer? timer;
  @override
  void initState() {
    super.initState();
    model = HospitalHistoryViewModel(
      widget.repository,
      widget.clinic,
      widget.isCurrent,
    );
    widget.identityChanges.addListener(identityChanged);
    model.load();
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!model.busy) model.load();
    });
  }

  void identityChanged() {
    if (!widget.isCurrent()) {
      search.clear();
      model.clear();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    widget.identityChanges.removeListener(identityChanged);
    search.dispose();
    model.dispose();
    super.dispose();
  }

  String instant(Object? raw) =>
      DateTime.tryParse('$raw')?.toLocal().toString() ?? 'No registrado';
  String person(Object? id, Object? name) =>
      name is String && name.trim().isNotEmpty
      ? name
      : id == null
      ? 'Autor no registrado'
      : 'Integrante · $id';
  String cage(Object? raw) =>
      raw == null || '$raw'.trim().isEmpty ? 'Sin asignar' : '$raw';
  Widget taskCard(Map<String, dynamic> t) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${t['label']} · ${switch (t['state']) {
              'done' => 'Realización registrada',
              'cancelled' => 'Cancelada',
              _ => 'Pendiente en registro histórico',
            }}',
          ),
          Text('Horario indicado: ${instant(t['due_at'])}'),
          Text(t['instructions'] as String),
          if (t['performed_at'] != null)
            Text(
              'Registrada: ${instant(t['performed_at'])} · ${person(t['performed_by'], t['performed_name'])}',
            ),
          if (t['cancelled_at'] != null)
            Text(
              'Cancelada: ${instant(t['cancelled_at'])} · ${person(t['cancelled_by'], t['cancelled_name'])}',
            ),
          if (t['cancel_reason'] != null) Text('Motivo: ${t['cancel_reason']}'),
          if (t['resolution_kind'] == 'not_given')
            const Text('Resolución: no se aplicó'),
          if (t['resolution_kind'] == 'discharge')
            const Text('Resolución: alta hospitalaria'),
          if (t['medication_record_id'] != null)
            Text(
              'Registro de aplicación vinculado: ${t['medication_record_id']}',
            ),
        ],
      ),
    ),
  );
  List<Widget> details() {
    final d = model.detail!, s = d.stay;
    return [
      Text(
        s['patient_name'] as String,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      Text('Especie: ${s['species']} · Última jaula: ${cage(s['cage'])}'),
      Text(
        'Ingreso: ${instant(s['admitted_at'])} · ${person(s['admitted_by'], s['admitted_name'])}',
      ),
      Text(
        'Alta: ${instant(s['discharged_at'])} · ${person(s['discharged_by'], s['discharged_name'])}',
      ),
      Text('Motivo de alta: ${s['discharge_reason'] ?? 'No registrado'}'),
      const Divider(),
      const Text('Ingreso y movimientos de jaula'),
      if (d.events.isEmpty)
        const Text('No hay eventos de ubicación registrados.'),
      for (final e in d.events)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            e['action'] == 'hospital_admitted' ? 'Ingreso' : 'Cambio de jaula',
          ),
          subtitle: Text(
            '${instant(e['at'])} · ${person(e['actor_id'], null)}\n${e['action'] == 'hospital_admitted' ? cage(e['details']['cage']) : '${cage(e['details']['from'])} → ${cage(e['details']['to'])}'}${e['details']['reason'] == null ? '' : '\n${e['details']['reason']}'}',
          ),
        ),
      const Divider(),
      const Text('Indicaciones y resoluciones registradas'),
      const Text(
        'La consulta del historial no programa avisos ni permite registrar nuevas aplicaciones. Los registros antiguos pueden carecer de vínculos estructurados.',
      ),
      if (d.tasks.isEmpty) const Text('Sin tareas registradas.'),
      ...d.tasks.map(taskCard),
    ];
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Hospitalizaciones dadas de alta')),
      body: !widget.isCurrent()
          ? const Center(
              child: Text(
                'La sesión o clínica cambió. Vuelve a abrir hospitalización.',
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (model.selected == null) ...[
                  TextField(
                    controller: search,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      labelText: 'Buscar por nombre del paciente',
                    ),
                    onSubmitted: (value) => model.load(search: value),
                  ),
                  OutlinedButton(
                    onPressed: () => model.load(search: search.text),
                    child: const Text('Buscar / actualizar altas'),
                  ),
                ] else ...[
                  TextButton(
                    onPressed: model.back,
                    child: const Text('Volver a las altas'),
                  ),
                  OutlinedButton(
                    onPressed: () => model.load(),
                    child: const Text('Actualizar estancia'),
                  ),
                ],
                const Text(
                  'Horas en la zona local de este dispositivo. Requiere conexión y permiso de lectura hospitalaria vigente.',
                ),
                if (model.busy) const LinearProgressIndicator(),
                if (model.error != null) Text(model.error!),
                if (model.selected == null &&
                    !model.busy &&
                    model.error == null &&
                    model.stays.isEmpty)
                  const Text('No hay altas para esta búsqueda.'),
                for (final s in model.stays)
                  Card(
                    child: ListTile(
                      title: Text(s['patient_name'] as String),
                      subtitle: Text(
                        'Alta: ${instant(s['discharged_at'])}\nÚltima jaula: ${cage(s['cage'])}',
                      ),
                      trailing: const Icon(VetIcons.chevronRight),
                      onTap: () => model.load(stay: s['id'] as String),
                    ),
                  ),
                if (model.detail != null) ...details(),
                if (model.next != null)
                  OutlinedButton(
                    onPressed: model.busy ? null : () => model.load(more: true),
                    child: Text(
                      model.selected == null
                          ? 'Ver más altas'
                          : 'Ver más indicaciones',
                    ),
                  ),
              ],
            ),
    ),
  );
}

import 'package:flutter/material.dart';
import '../../auth/domain/clinic_membership.dart';
import '../../forms/clinical/clinical_repository.dart';
import '../domain/hospital_models.dart';
import '../domain/hospital_repository.dart';
import 'hospital_weight_screen.dart';

/// Selects an accessible active stay, then reuses the persisted-weight workflow.
class HospitalDosePatientScreen extends StatefulWidget {
  const HospitalDosePatientScreen({
    super.key,
    required this.hospital,
    required this.clinical,
    required this.member,
    required this.contextIsCurrent,
    required this.onCalculate,
    this.sessionChanges,
  });
  final HospitalRepository hospital;
  final ClinicalRepository clinical;
  final ClinicMembership member;
  final bool Function() contextIsCurrent;
  final HospitalWeightCalculation onCalculate;
  final Listenable? sessionChanges;
  @override
  State<HospitalDosePatientScreen> createState() =>
      _HospitalDosePatientScreenState();
}

class _HospitalDosePatientScreenState extends State<HospitalDosePatientScreen>
    with WidgetsBindingObserver {
  List<HospitalStay> stays = [];
  String query = '';
  final search = TextEditingController();
  String? error;
  bool loading = true;
  int generation = 0;
  bool get current => mounted && widget.contextIsCurrent();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.sessionChanges?.addListener(sessionChanged);
    load();
  }

  @override
  void didUpdateWidget(covariant HospitalDosePatientScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionChanges != widget.sessionChanges) {
      oldWidget.sessionChanges?.removeListener(sessionChanged);
      widget.sessionChanges?.addListener(sessionChanged);
    }
    if (oldWidget.member.userId != widget.member.userId ||
        oldWidget.member.clinicId != widget.member.clinicId ||
        oldWidget.member.role != widget.member.role ||
        oldWidget.hospital != widget.hospital) {
      query = '';
      search.clear();
      load();
    }
  }

  void sessionChanged() {
    if (!current) {
      generation++;
      query = '';
      search.clear();
      if (mounted) {
        setState(() {
          stays = [];
          loading = false;
          error =
              'La sesión o los permisos cambiaron. Vuelve a elegir el paciente.';
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      generation++;
      query = '';
      search.clear();
      if (mounted) {
        setState(() {
          stays = [];
          loading = false;
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      load();
    }
  }

  Future<void> load() async {
    final revision = ++generation;
    setState(() {
      stays = [];
      loading = true;
      error = null;
    });
    try {
      if (!current) throw StateError('session_changed');
      final snapshot = await widget.hospital.load(widget.member.clinicId);
      if (!current || revision != generation) return;
      if (snapshot.stays.any((s) => s.clinicId != widget.member.clinicId)) {
        throw StateError('clinic_changed');
      }
      setState(() => stays = snapshot.stays);
    } catch (_) {
      if (mounted && revision == generation) {
        setState(() {
          stays = [];
          error =
              'No se pudieron consultar los pacientes hospitalizados. Revisa conexión y permisos.';
        });
      }
    } finally {
      if (mounted && revision == generation) setState(() => loading = false);
    }
  }

  Future<void> select(HospitalStay stay) async {
    if (!current) {
      sessionChanged();
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => HospitalWeightScreen(
          hospital: widget.hospital,
          clinical: widget.clinical,
          member: widget.member,
          stay: stay,
          contextIsCurrent: widget.contextIsCurrent,
          onCalculate: (weight, validate) async {
            if (!current) return;
            // Keep the weight page mounted: its validator must remain alive.
            await widget.onCalculate(weight, validate);
          },
        ),
      ),
    );
    if (mounted) await load();
  }

  @override
  void dispose() {
    generation++;
    widget.sessionChanges?.removeListener(sessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Paciente para calcular dosis')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          '1. Elige el paciente hospitalizado.\n2. Revisa y selecciona su medición de peso.\n3. Elige el fármaco y su presentación en la calculadora.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: search,
          decoration: const InputDecoration(
            labelText: 'Buscar paciente',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => query = v),
        ),
        TextButton.icon(
          onPressed: loading ? null : load,
          icon: const Icon(Icons.refresh),
          label: const Text('Actualizar pacientes'),
        ),
        if (loading) const LinearProgressIndicator(),
        if (error != null) Text(error!),
        if (!loading && error == null && stays.isEmpty)
          const Text(
            'No hay pacientes hospitalizados accesibles. Puedes continuar con el cálculo manual o registrar primero la estancia y su peso.',
          ),
        if (current)
          for (final stay in stays.where(
            (s) => '${s.patientName} ${s.species}'.toLowerCase().contains(
              query.toLowerCase().trim(),
            ),
          ))
            Card(
              child: ListTile(
                title: Text(stay.patientName),
                subtitle: Text('${stay.species} · ${stay.cageLabel}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => select(stay),
              ),
            ),
      ],
    ),
  );
}

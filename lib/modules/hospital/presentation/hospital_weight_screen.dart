import 'package:flutter/material.dart';
import '../../auth/domain/clinic_membership.dart';
import '../../forms/clinical/clinical_repository.dart';
import '../../patients/domain/recorded_weight.dart';
import '../../prescribing/presentation/rx_entry_screen.dart';
import '../domain/hospital_models.dart';
import '../domain/hospital_repository.dart';
import 'hospital_weight_view_model.dart';
import '../../../vet_ui/vet_icons.dart';

typedef HospitalWeightCalculation =
    Future<void> Function(
      RecordedPatientWeight weight,
      Future<bool> Function(RecordedPatientWeight) validate,
    );

class HospitalWeightScreen extends StatefulWidget {
  const HospitalWeightScreen({
    super.key,
    required this.clinical,
    required this.hospital,
    required this.member,
    required this.stay,
    this.onCalculate,
    this.contextIsCurrent,
  });
  final ClinicalRepository clinical;
  final HospitalRepository hospital;
  final ClinicMembership member;
  final HospitalStay stay;
  final HospitalWeightCalculation? onCalculate;
  final bool Function()? contextIsCurrent;
  @override
  State<HospitalWeightScreen> createState() => _HospitalWeightScreenState();
}

class _HospitalWeightScreenState extends State<HospitalWeightScreen> {
  late final model = HospitalWeightViewModel(
    widget.clinical,
    widget.hospital,
    widget.member,
    widget.stay,
    contextIsCurrent: widget.contextIsCurrent,
  );
  @override
  void initState() {
    super.initState();
    model.load();
  }

  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  Future<void> capture() async {
    await model.load(caseId: model.selectedCaseId);
    if (!mounted || !model.canRecord) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RxEntryScreen(
          title: 'Registrar peso medido',
          reviewText:
              '${widget.stay.patientName} · Paciente ${widget.stay.patientId}\nCaso ${model.selectedCaseId}\nRegistra una medición que tú realizaste. Se conservarán autor y hora. No modifica órdenes ni recetas.',
          fields: const [
            RxField('value', 'Peso medido (kg)', required: true),
            RxField(
              'at',
              'Fecha y hora observada',
              type: 'local_instant',
              required: true,
            ),
            RxField('notes', 'Notas', type: 'text'),
            RxField(
              'review',
              'Confirmo paciente, peso y hora de mi medición',
              type: 'checkbox',
              required: true,
            ),
          ],
          submit: (data, operation) => model.record(
            data['value'] as String,
            data['at'] as String,
            data['notes'] as String? ?? '',
            operation,
          ),
        ),
      ),
    );
    if (mounted) await model.load(caseId: model.selectedCaseId);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('Peso diario'),
        actions: [
          IconButton(
            tooltip: 'Actualizar pesos',
            onPressed: model.busy
                ? null
                : () => model.load(caseId: model.selectedCaseId),
            icon: const Icon(VetIcons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.stay.patientName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            'Paciente ${widget.stay.patientId}\nIngreso: ${widget.stay.admittedAt.toLocal()}',
          ),
          const Text(
            'Los pesos se consultan en los casos clínicos accesibles de esta estancia. El día corresponde a la fecha local de este dispositivo. Actualiza para comprobar cambios.',
          ),
          if (model.busy) const LinearProgressIndicator(),
          if (model.error != null) Text(model.error!),
          if (!model.busy && model.error == null) ...[
            Text(
              model.hasWeightToday
                  ? 'Hay peso registrado hoy.'
                  : 'Pendiente: registrar el peso de hoy.',
            ),
            if (model.cases.isEmpty)
              const Text(
                'No hay casos clínicos accesibles. Registra o solicita acceso a un caso desde Expediente y documentos.',
              ),
            if (model.cases.isNotEmpty)
              DropdownButtonFormField<String>(
                key: ValueKey(model.selectedCaseId),
                initialValue: model.selectedCaseId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Caso para registrar la medición',
                ),
                items: [
                  for (final c in model.cases)
                    DropdownMenuItem(
                      value: c.id,
                      child: Text(
                        '${c.title} · ${c.id}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (id) => model.load(caseId: id),
              ),
            FilledButton(
              onPressed: model.canRecord ? capture : null,
              child: const Text('Registrar peso'),
            ),
            if (model.selectedCaseId != null && !model.canRecord)
              const Text(
                'Registrar requiere permiso clínico vigente de observaciones en este caso.',
              ),
            const Text(
              'Las correcciones se registran en el caso clínico por el responsable; conservan la medición original. Aquí se muestran las mediciones que no han sido reemplazadas.',
            ),
            for (final w in model.weights)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('${w.kg} kg · ${w.observedAt.toLocal()}'),
                      Text(
                        'Midió: ${w.performedBy}\nRegistró: ${w.recordedBy} · ${w.recordedAt.toLocal()}\nCaso: ${w.caseId}\nMedición: ${w.id}',
                      ),
                      if (widget.onCalculate != null)
                        OutlinedButton(
                          onPressed: () =>
                              widget.onCalculate!(w, model.validateWeight),
                          child: const Text('Revisar peso para cálculo'),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    ),
  );
}

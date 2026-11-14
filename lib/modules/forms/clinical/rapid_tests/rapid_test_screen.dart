import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../auth/domain/clinic_membership.dart';
import '../../../prescribing/presentation/rx_entry_screen.dart';
import '../clinical_models.dart';
import 'rapid_test_repository.dart';
import 'rapid_test_view_model.dart';
import '../../../../vet_ui/vet_icons.dart';

class RapidTestScreen extends StatefulWidget {
  const RapidTestScreen({
    super.key,
    required this.repository,
    required this.member,
    required this.caseData,
  });
  final RapidTestRepository repository;
  final ClinicMembership member;
  final ClinicalCase caseData;
  @override
  State<RapidTestScreen> createState() => _RapidTestScreenState();
}

class _RapidTestScreenState extends State<RapidTestScreen> {
  late final model = RapidTestViewModel(
    widget.repository,
    widget.member,
    widget.caseData,
  );
  bool opening = false;
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

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> entry({Map<String, dynamic>? correction}) async {
    if (opening) return;
    setState(() => opening = true);
    try {
      await model.load();
      if (!mounted || !model.can(correction == null ? 'record' : 'correct')) {
        return;
      }
      RapidTestPhoto? photo;
      if (model.can('photo')) {
        final choice = await showDialog<String>(
          context: context,
          builder: (context) => SimpleDialog(
            title: const Text('Foto opcional de la prueba'),
            children: [
              for (final option in {
                'none': 'Continuar sin foto',
                'gallery': 'Elegir foto',
                'camera': 'Tomar foto',
              }.entries)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, option.key),
                  child: Text(option.value),
                ),
            ],
          ),
        );
        if (choice == null || !mounted) return;
        if (choice != 'none') {
          final file = await ImagePicker().pickImage(
            source: choice == 'camera'
                ? ImageSource.camera
                : ImageSource.gallery,
          );
          if (file == null || !mounted) return;
          if (await file.length() > 8000000) {
            throw const FormatException('La foto supera 8 MB.');
          }
          final ext = file.name.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
          photo = RapidTestPhoto(await file.readAsBytes(), ext);
        }
      }
      if (!mounted) return;
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => RxEntryScreen(
            title: correction == null
                ? 'Registrar mi prueba rápida'
                : 'Corregir prueba rápida',
            reviewText:
                '${widget.caseData.patientName} · ${widget.caseData.title}\n'
                'Captura lo observado y tu resultado. La interpretación profesional es opcional y queda pendiente si se deja vacía. '
                'Las bandas no producen una interpretación automática. Se conserva tu cuenta y la hora del servidor. '
                '${photo == null ? 'Sin foto.' : 'Foto seleccionada; se guardará con esta entrada.'}'
                '${correction == null ? '' : '\nLa corrección conserva el registro original. Vuelve a capturar los datos revisados; la foto anterior se conserva en el original.'}',
            fields: [
              const RxField(
                'test_name',
                'Prueba / kit utilizado',
                required: true,
              ),
              const RxField('sample', 'Muestra e identificación (opcional)'),
              const RxField(
                'observed_at',
                'Fecha y hora reales de lectura',
                type: 'local_instant',
                required: true,
              ),
              const RxField(
                'c_band',
                'Banda C observada',
                type: 'select',
                options: rapidBandLabels,
                required: true,
              ),
              const RxField(
                't_band',
                'Banda T observada',
                type: 'select',
                options: rapidBandLabels,
                required: true,
              ),
              const RxField(
                'result',
                'Resultado leído / descrito por ti',
                required: true,
              ),
              const RxField(
                'interpretation',
                'Tu interpretación profesional (opcional)',
              ),
              const RxField(
                'notes',
                'Notas / referencia del instructivo (opcional)',
              ),
              if (correction != null)
                const RxField(
                  'correction_reason',
                  'Motivo de corrección',
                  required: true,
                ),
            ],
            submit: (data, operation) => model.add(
              {
                ...data,
                if (correction != null) 'replaces_id': correction['id'],
              },
              operation,
              photo: photo,
            ),
          ),
        ),
      );
      if (mounted) await model.load();
    } catch (e) {
      message(
        e is FormatException
            ? e.message
            : 'No se abrió la captura. Revisa permisos y conexión.',
      );
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  Future<void> openPhoto(String path) async {
    if (opening) return;
    setState(() => opening = true);
    try {
      await model.load();
      if (!mounted ||
          model.error != null ||
          !model.records.any((r) => r['photo_path'] == path)) {
        return;
      }
      final bytes = await widget.repository.photo(path);
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Foto de la prueba')),
            body: Center(
              child: InteractiveViewer(
                child: Image.memory(
                  bytes,
                  errorBuilder: (_, error, stack) =>
                      const Text('No se pudo mostrar la imagen.'),
                ),
              ),
            ),
          ),
        ),
      );
    } catch (_) {
      message('No se pudo abrir la foto. Revisa permisos y conexión.');
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pruebas rápidas')),
    body: ListenableBuilder(
      listenable: model,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('${widget.caseData.patientName} · ${widget.caseData.title}'),
          const Text(
            'C/T es una observación manual. El resultado y la interpretación pertenecen a quien los registra.',
          ),
          OutlinedButton(
            onPressed: opening || model.busy ? null : model.load,
            child: const Text('Actualizar'),
          ),
          if (model.busy) const LinearProgressIndicator(),
          if (model.error != null) Text(model.error!),
          if (model.can('record'))
            FilledButton.icon(
              onPressed: opening ? null : entry,
              icon: const Icon(VetIcons.add),
              label: const Text('Registrar prueba rápida'),
            ),
          if (!model.busy && model.error == null && model.records.isEmpty)
            const Text('Sin pruebas registradas en este caso.'),
          for (final row in model.records)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row['test_name'],
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (model.replaced(row['id']))
                      const Text(
                        'Sustituida por corrección · se conserva como antecedente',
                      ),
                    Text(
                      'C: ${rapidBandLabels[row['c_band']]} · T: ${rapidBandLabels[row['t_band']]}',
                    ),
                    Text('Resultado: ${row['result']}'),
                    Text(
                      (row['interpretation'] as String).isEmpty
                          ? 'Interpretación pendiente'
                          : 'Interpretación: ${row['interpretation']}',
                    ),
                    if ((row['sample'] as String).isNotEmpty)
                      Text('Muestra: ${row['sample']}'),
                    if ((row['notes'] as String).isNotEmpty) Text(row['notes']),
                    Text(
                      'Lectura: ${DateTime.parse(row['observed_at']).toLocal()}\nRegistró: ${row['recorded_by']}\nServidor: ${DateTime.parse(row['created_at']).toLocal()}',
                    ),
                    if (row['replaces_id'] != null)
                      Text(
                        'Corrige: ${row['replaces_id']} · ${row['correction_reason']}',
                      ),
                    if (row['photo_path'] != null)
                      TextButton(
                        onPressed: opening || model.busy
                            ? null
                            : () => openPhoto(row['photo_path']),
                        child: const Text('Ver foto'),
                      ),
                    if (model.can('correct') && !model.replaced(row['id']))
                      TextButton(
                        onPressed: opening
                            ? null
                            : () => entry(correction: row),
                        child: const Text('Corregir conservando original'),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

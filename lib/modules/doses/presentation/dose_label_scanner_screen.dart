import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/domain/clinic_membership.dart';
import '../data/catalog_repository.dart';
import '../data/personal_dose_repository.dart';
import '../domain/catalog.dart';
import 'dose_screen.dart';

/// OCR is only a search aid. Neither a dose nor a product concentration is
/// inferred from an untrusted photo; the clinician must choose a known record.
String normalizeDoseLabel(String value) {
  const accented = <String, String>{
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u',
    'ñ': 'n',
  };
  var text = value.toLowerCase();
  for (final item in accented.entries) {
    text = text.replaceAll(item.key, item.value);
  }
  return text.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

List<DrugDose> doseLabelSuggestions(DoseCatalog catalog, String label) {
  final text = normalizeDoseLabel(label);
  if (text.isEmpty) return [];
  final padded = ' $text ';
  bool matches(String value) {
    final term = normalizeDoseLabel(value);
    return term.length >= 4 && padded.contains(' $term ');
  }
  return catalog.drugs.where(
    (drug) => matches(drug.name) ||
        drug.presentations.any((presentation) => matches(presentation.brand)),
  ).toList(growable: false);
}

typedef DoseLabelReader = Future<String?> Function(ImageSource source);

/// Uses the local mobile camera/gallery and on-device ML Kit recognition.
/// Does not send the image or text to Supabase or an external AI service.
Future<String?> readDoseLabelOnDevice(ImageSource source) async {
  final captured = await ImagePicker().pickImage(
    source: source,
    imageQuality: 85,
    maxWidth: 2048,
    maxHeight: 2048,
  );
  if (captured == null) return null;
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final result = await recognizer.processImage(
      InputImage.fromFilePath(captured.path),
    );
    return result.text;
  } finally {
    await recognizer.close();
  }
}

class DoseLabelScannerScreen extends StatefulWidget {
  const DoseLabelScannerScreen({
    super.key,
    required this.member,
    this.personalRepository,
    this.offline = false,
    this.catalogRepository,
    this.reader,
  });

  final ClinicMembership member;
  final PersonalDoseRepository? personalRepository;
  final bool offline;
  final CatalogRepository? catalogRepository;
  final DoseLabelReader? reader;

  @override
  State<DoseLabelScannerScreen> createState() => _DoseLabelScannerScreenState();
}

class _DoseLabelScannerScreenState extends State<DoseLabelScannerScreen> {
  final search = TextEditingController();
  DoseCatalog? catalog;
  String recognizedText = '';
  String? message;
  bool busy = false;
  bool loading = true;

  bool get clinicalRole => const <ClinicRole>{
    ClinicRole.admin,
    ClinicRole.mvz,
  }.contains(widget.member.role);

  bool get supportsCamera => widget.reader != null ||
      (!kIsWeb &&
          const <TargetPlatform>{
            TargetPlatform.android, TargetPlatform.iOS,
          }.contains(defaultTargetPlatform));

  @override
  void initState() {
    super.initState();
    if (clinicalRole) {
      loadCatalog();
    } else {
      loading = false;
    }
  }

  Future<void> loadCatalog() async {
    try {
      final found = await (widget.catalogRepository ??
              AssetCatalogRepository()).load();
      if (mounted) {
        setState(() {
          catalog = found;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          message = 'No se pudo cargar el catálogo de dosis.';
        });
      }
    }
  }

  Future<void> capture(ImageSource source) async {
    if (busy || !clinicalRole || !supportsCamera) return;
    setState(() {
      busy = true;
      message = null;
      recognizedText = '';
    });
    try {
      final text = await (widget.reader ?? readDoseLabelOnDevice)(source);
      if (!mounted) return;
      setState(() {
        recognizedText = text?.trim() ?? '';
        if (text != null && recognizedText.isEmpty) {
          message = 'No se encontró texto legible. Puedes tomar otra foto o '
              'buscar el fármaco manualmente.';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => message =
            'No se pudo leer la etiqueta. Revisa la cámara o los permisos '
            'y vuelve a intentarlo.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  List<DrugDose> get results {
    final data = catalog;
    if (data == null) return [];
    final typed = search.text.trim();
    if (typed.isNotEmpty) return data.search(typed).take(20).toList();
    return doseLabelSuggestions(data, recognizedText).take(20).toList();
  }

  Future<void> choose(DrugDose drug) async {
    if (!clinicalRole || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Revisar dosis')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: DoseScreen(
              repository: widget.catalogRepository,
              personalRepository: widget.personalRepository,
              clinicId: widget.member.clinicId,
              userId: widget.member.userId,
              admin: widget.member.role == ClinicRole.admin,
              offline: widget.offline,
              initialDrug: drug,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!clinicalRole) {
      return const Text('La lectura para cálculos requiere acceso de MVZ o '
          'administrador.');
    }
    final matches = results;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Escanear etiqueta para dosis',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          'Fotografía el nombre del medicamento o selecciona una imagen. '
          'El reconocimiento se hace en el dispositivo. No identifica por '
          'código de barras ni calcula dosis directamente desde la foto.',
        ),
        const SizedBox(height: 12),
        const Text(
          'La lectura puede equivocarse. Comprueba fármaco, especie, '
          'presentación, concentración, fuente y peso antes de calcular. '
          'Ningún dato leído se considera una dosis verificada.',
        ),
        const SizedBox(height: 12),
        if (!supportsCamera)
          const Text('La lectura de imágenes requiere Android o iOS. '
              'Puedes buscar manualmente en el catálogo.'),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: busy || !supportsCamera
                  ? null
                  : () => capture(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Tomar foto de etiqueta'),
            ),
            OutlinedButton.icon(
              onPressed: busy || !supportsCamera
                  ? null
                  : () => capture(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Elegir imagen'),
            ),
          ],
        ),
        if (busy || loading) const LinearProgressIndicator(),
        if (message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(message!),
          ),
        if (recognizedText.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Texto reconocido (sin verificar)',
              style: Theme.of(context).textTheme.titleMedium),
          SelectableText(recognizedText),
        ],
        const SizedBox(height: 20),
        TextField(
          controller: search,
          decoration: const InputDecoration(
            labelText: 'Buscar fármaco o marca en el catálogo',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        if (!loading && catalog == null)
          const Text('Catálogo no disponible. No se pueden sugerir dosis.'),
        if (!loading && catalog != null &&
            recognizedText.isNotEmpty && matches.isEmpty &&
            search.text.trim().isEmpty)
          const Text('La etiqueta no coincide con un registro conocido. '
              'Corrige la búsqueda manualmente; no se inventará una dosis.'),
        if (matches.isNotEmpty) ...[
          Text('Coincidencias para revisar',
              style: Theme.of(context).textTheme.titleMedium),
          for (final item in matches)
            ListTile(
              title: Text(item.name),
              subtitle: Text('${item.species} · '
                  '${item.evidence.verified ? 'Fuente verificada' : 'Sin verificar'}'
                  ' · ${item.presentations.map((e) => e.brand).join(', ')}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => choose(item),
            ),
        ],
      ],
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// Lee el texto de una foto de un reporte de laboratorio, en el dispositivo.
///
/// No envía la imagen ni el texto a Supabase ni a ningún servicio externo.
typedef LabReportReader = Future<String?> Function(ImageSource source);

Future<String?> readLabReportOnDevice(ImageSource source) async {
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

/// Si la cámara o la galería están disponibles en esta plataforma.
bool labReportCaptureSupported() =>
    !kIsWeb &&
    const <TargetPlatform>{
      TargetPlatform.android,
      TargetPlatform.iOS,
    }.contains(defaultTargetPlatform);

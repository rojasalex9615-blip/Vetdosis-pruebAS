import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../domain/backup_cipher.dart';

class DriveBackupReceipt {
  const DriveBackupReceipt(this.fileId, this.sha256Hex);
  final String fileId;
  final String sha256Hex;
}

/// A receipt is returned only after reading the remote bytes back successfully.
class DriveBackupClient {
  DriveBackupClient(this.client);
  final http.Client client;

  Future<DriveBackupReceipt> uploadVerified({
    required String token,
    required String fileName,
    required Uint8List encrypted,
  }) async {
    if (!BackupCipher.isEncrypted(encrypted)) {
      throw const FormatException('Drive solo admite respaldos cifrados.');
    }
    final headers = {'Authorization': 'Bearer $token'};
    // The encrypted JSON envelope cannot contain these raw MIME separators.
    final boundary = 'vetdosis-${DateTime.now().microsecondsSinceEpoch}';
    final body = BytesBuilder()
      ..add(
        utf8.encode(
          '--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n',
        ),
      )
      ..add(
        utf8.encode(
          jsonEncode({
            'name': fileName,
            'mimeType': 'application/octet-stream',
          }),
        ),
      )
      ..add(
        utf8.encode(
          '\r\n--$boundary\r\nContent-Type: application/octet-stream\r\n\r\n',
        ),
      )
      ..add(encrypted)
      ..add(utf8.encode('\r\n--$boundary--\r\n'));
    final uploaded = await client
        .post(
          Uri.https('www.googleapis.com', '/upload/drive/v3/files', {
            'uploadType': 'multipart',
            'fields': 'id',
          }),
          headers: {
            ...headers,
            'Content-Type': 'multipart/related; boundary=$boundary',
          },
          body: body.takeBytes(),
        )
        .timeout(const Duration(minutes: 3));
    if (uploaded.statusCode != 200 && uploaded.statusCode != 201) {
      throw const FormatException(
        'Drive no confirmó la subida. Revisa tu cuenta y sus permisos.',
      );
    }
    final id = (jsonDecode(uploaded.body) as Map<String, dynamic>)['id'];
    if (id is! String || !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) {
      throw const FormatException('Drive no devolvió un identificador válido.');
    }
    final expected = sha256.convert(encrypted).toString();
    try {
      final request =
          http.Request(
              'GET',
              Uri.https('www.googleapis.com', '/drive/v3/files/$id', {
                'alt': 'media',
              }),
            )
            ..headers.addAll(headers)
            ..followRedirects = false;
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) {
        throw const FormatException('Download failed');
      }
      final downloaded = BytesBuilder();
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 60),
      )) {
        if (downloaded.length + chunk.length > encrypted.length) {
          throw const FormatException('Size mismatch');
        }
        downloaded.add(chunk);
      }
      if (downloaded.length != encrypted.length ||
          sha256.convert(downloaded.takeBytes()).toString() != expected) {
        throw const FormatException('Hash mismatch');
      }
    } catch (_) {
      throw const FormatException(
        'La copia se subió, pero NO quedó verificada. Revisa Drive antes de reintentar: podría existir una copia.',
      );
    }
    return DriveBackupReceipt(id, expected);
  }
}

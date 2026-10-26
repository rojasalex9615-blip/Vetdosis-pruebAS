import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vetdosis_pro/modules/backup/data/drive_backup_client.dart';

void main() {
  // Synthetic envelope for transport tests: no patient or real encrypted data.
  final bytes = Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'format': 'vetdosis-encrypted-archive',
        'ciphertext': 'synthetic',
      }),
    ),
  );

  test(
    'Drive receipt requires remote bytes and hash, using only file scope transport',
    () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        expect(request.headers['Authorization'], 'Bearer synthetic');
        expect(request.url.host, 'www.googleapis.com');
        if (request.method == 'POST') {
          expect(request.url.queryParameters['uploadType'], 'multipart');
          expect(
            request.headers['content-type'],
            startsWith('multipart/related;'),
          );
          expect(request.body, contains('backup.vetbackup'));
          expect(request.body, contains('synthetic'));
          expect(request.body, isNot(contains('permissions')));
          return http.Response('{"id":"remote_id"}', 200);
        }
        expect(request.url.path, '/drive/v3/files/remote_id');
        expect(request.url.queryParameters['alt'], 'media');
        return http.Response.bytes(bytes, 200);
      });
      final receipt = await DriveBackupClient(client).uploadVerified(
        token: 'synthetic',
        fileName: 'backup.vetbackup',
        encrypted: bytes,
      );
      expect(calls, 2);
      expect(receipt.sha256Hex, sha256.convert(bytes).toString());
      expect(receipt.fileId, 'remote_id');
    },
  );

  for (final mode in ['corrupt', 'truncated', 'oversized', 'forbidden']) {
    test('Never verifies remote $mode data', () async {
      final client = MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response('{"id":"remote_id"}', 200);
        }
        return switch (mode) {
          'corrupt' => http.Response.bytes(List.filled(bytes.length, 0), 200),
          'truncated' => http.Response.bytes(bytes.sublist(1), 200),
          'oversized' => http.Response.bytes([...bytes, 0], 200),
          _ => http.Response('', 403),
        };
      });
      await expectLater(
        DriveBackupClient(client).uploadVerified(
          token: 'synthetic',
          fileName: 'backup.vetbackup',
          encrypted: bytes,
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'status',
            contains('NO quedó verificada'),
          ),
        ),
      );
    });
  }

  test('Plaintext never reaches Google', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('', 200);
    });
    await expectLater(
      DriveBackupClient(client).uploadVerified(
        token: 'synthetic',
        fileName: 'backup.json',
        encrypted: Uint8List.fromList(utf8.encode('{}')),
      ),
      throwsFormatException,
    );
    expect(calls, 0);
  });

  test(
    'Upload rejection never produces a receipt or downloads a file',
    () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('', 403);
      });
      await expectLater(
        DriveBackupClient(client).uploadVerified(
          token: 'synthetic',
          fileName: 'backup.vetbackup',
          encrypted: bytes,
        ),
        throwsFormatException,
      );
      expect(calls, 1);
    },
  );
}

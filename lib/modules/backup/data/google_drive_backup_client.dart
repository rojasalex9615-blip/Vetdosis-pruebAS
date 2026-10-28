import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/drive_backup_client.dart';

/// Android beta: per-device clinic binding and direct drive.file upload.
/// No Google token or backup password is sent to the VetDosis server.
class GoogleDriveBackupClient implements DriveBackupClient {
  GoogleDriveBackupClient({http.Client? httpClient})
    : _http = httpClient ?? http.Client();
  static const _scope = 'https://www.googleapis.com/auth/drive.file';
  static const _webClientId = String.fromEnvironment(
    'GOOGLE_DRIVE_WEB_CLIENT_ID',
  );
  final http.Client _http;
  final GoogleSignIn _signIn = GoogleSignIn.instance;
  Future<void>? _initialization;
  GoogleSignInAccount? _account;

  @override
  bool get configured =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      _webClientId.isNotEmpty;

  Future<void> _initialize() async {
    if (!configured) throw StateError('drive_oauth_not_configured');
    _initialization ??= _signIn.initialize(serverClientId: _webClientId);
    await _initialization;
  }

  String _key(String userId, String clinicId) =>
      'drive-link-v1:$userId:$clinicId';

  Future<DriveConnection?> _saved(String userId, String clinicId) async {
    final raw = (await SharedPreferences.getInstance()).getString(
      _key(userId, clinicId),
    );
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw) as Map<String, dynamic>;
      final id = value['id'];
      final email = value['email'];
      if (id is String &&
          id.isNotEmpty &&
          email is String &&
          email.isNotEmpty) {
        return DriveConnection(accountId: id, email: email);
      }
    } catch (_) {
      /* Invalid local state never grants Drive access. */
    }
    return null;
  }

  @override
  Future<DriveConnection?> connection(String userId, String clinicId) async =>
      configured ? _saved(userId, clinicId) : null;

  @override
  Future<DriveConnection> connect(String userId, String clinicId) async {
    await _initialize();
    final account = await _signIn.authenticate();
    final previous = await _saved(userId, clinicId);
    if (previous != null && previous.accountId != account.id) {
      await _signIn.signOut();
      throw StateError('drive_account_change_requires_disconnect');
    }
    await account.authorizationClient.authorizeScopes([_scope]);
    _account = account;
    final value = DriveConnection(accountId: account.id, email: account.email);
    await (await SharedPreferences.getInstance()).setString(
      _key(userId, clinicId),
      jsonEncode({'id': value.accountId, 'email': value.email}),
    );
    return value;
  }

  @override
  Future<bool> disconnect(String userId, String clinicId) async {
    await _initialize();
    final saved = await _saved(userId, clinicId);
    if (saved == null) return false;
    final active = _account ?? await _signIn.attemptLightweightAuthentication();
    final revoked = active != null && active.id == saved.accountId;
    if (revoked) {
      await _signIn.disconnect();
    }
    _account = null;
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where(
      (key) => key.startsWith('drive-link-v1:$userId:'),
    )) {
      final raw = prefs.getString(key);
      if (raw != null) {
        try {
          if ((jsonDecode(raw) as Map)['id'] == saved.accountId) {
            await prefs.remove(key);
          }
        } catch (_) {
          await prefs.remove(key);
        }
      }
    }
    return revoked;
  }

  Future<GoogleSignInAccount> _linkedAccount(
    String userId,
    String clinicId,
  ) async {
    await _initialize();
    final saved = await _saved(userId, clinicId);
    if (saved == null) throw StateError('drive_not_connected');
    final account =
        _account ?? await _signIn.attemptLightweightAuthentication();
    if (account == null || account.id != saved.accountId) {
      throw StateError('drive_account_mismatch');
    }
    _account = account;
    return account;
  }

  Future<Map<String, String>> _headers(GoogleSignInAccount account) async {
    final grant = await account.authorizationClient.authorizationForScopes([
      _scope,
    ]);
    if (grant == null) throw StateError('drive_authorization_revoked');
    return {'Authorization': 'Bearer ${grant.accessToken}'};
  }

  Never _fail(http.Response response) {
    if (response.statusCode == 401) {
      throw StateError('drive_authorization_revoked');
    }
    if (response.statusCode == 403) {
      throw StateError('drive_permission_or_quota');
    }
    if (response.statusCode == 429) throw StateError('drive_rate_limited');
    throw StateError('drive_request_failed');
  }

  @override
  Future<DriveBackupReceipt> uploadVerified(
    String userId,
    String clinicId,
    String name,
    Uint8List encryptedBytes,
  ) async {
    if (!name.endsWith('.vetbackup') || encryptedBytes.isEmpty) {
      throw ArgumentError(
        'Only a nonempty encrypted .vetbackup may be uploaded.',
      );
    }
    final account = await _linkedAccount(userId, clinicId);
    final headers = await _headers(account);
    final digest = sha256.convert(encryptedBytes).toString();
    final boundary = 'vetdosis${Random.secure().nextInt(1 << 32)}';
    final metadata = jsonEncode({
      'name': name,
      'mimeType': 'application/octet-stream',
      'appProperties': {'vetdosis_clinic': clinicId, 'vetdosis_sha256': digest},
    });
    final body = BytesBuilder(copy: false)
      ..add(
        utf8.encode(
          '--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n$metadata\r\n',
        ),
      )
      ..add(
        utf8.encode(
          '--$boundary\r\nContent-Type: application/octet-stream\r\n\r\n',
        ),
      )
      ..add(encryptedBytes)
      ..add(utf8.encode('\r\n--$boundary--'));
    final upload = await _http
        .post(
          Uri.parse(
            'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,name,size,md5Checksum,createdTime',
          ),
          headers: {
            ...headers,
            'Content-Type': 'multipart/related; boundary=$boundary',
          },
          body: body.takeBytes(),
        )
        .timeout(const Duration(minutes: 3));
    if (upload.statusCode != 200) _fail(upload);
    final created = jsonDecode(upload.body) as Map<String, dynamic>;
    final id = created['id'];
    if (id is! String ||
        id.isEmpty ||
        created['size'] != '${encryptedBytes.length}' ||
        created['md5Checksum'] != md5.convert(encryptedBytes).toString()) {
      throw StateError('drive_upload_unverified');
    }
    // Download and hash the stored bytes. A successful upload response alone is
    // not evidence that a recoverable copy is present in Drive.
    final request = http.Request(
      'GET',
      Uri.parse(
        'https://www.googleapis.com/drive/v3/files/${Uri.encodeComponent(id)}?alt=media',
      ),
    );
    request.headers.addAll(headers);
    final downloaded = await _http
        .send(request)
        .timeout(const Duration(minutes: 3));
    if (downloaded.statusCode != 200) {
      throw StateError('drive_upload_unverified');
    }
    final checked = await sha256
        .bind(downloaded.stream)
        .first
        .timeout(const Duration(minutes: 3));
    if (checked.toString() != digest) {
      throw StateError('drive_upload_unverified');
    }
    return DriveBackupReceipt(
      fileId: id,
      name: name,
      bytes: encryptedBytes.length,
      sha256: digest,
      createdAt:
          DateTime.tryParse('${created['createdTime']}') ??
          DateTime.now().toUtc(),
    );
  }

  @override
  Future<List<DriveBackupReceipt>> history(
    String userId,
    String clinicId,
  ) async {
    final account = await _linkedAccount(userId, clinicId);
    final headers = await _headers(account);
    final query =
        "trashed = false and appProperties has { key='vetdosis_clinic' and value='$clinicId' }";
    final url = Uri.https('www.googleapis.com', '/drive/v3/files', {
      'q': query,
      'fields': 'nextPageToken,files(id,name,size,createdTime,appProperties)',
      'pageSize': '100',
      'orderBy': 'createdTime desc',
    });
    final response = await _http
        .get(url, headers: headers)
        .timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) _fail(response);
    final rows = (jsonDecode(response.body) as Map)['files'] as List? ?? [];
    return [
      for (final raw in rows)
        if (raw is Map && raw['id'] is String && raw['name'] is String)
          DriveBackupReceipt(
            fileId: raw['id'] as String,
            name: raw['name'] as String,
            bytes: int.tryParse('${raw['size']}') ?? 0,
            sha256:
                '${(raw['appProperties'] as Map?)?['vetdosis_sha256'] ?? ''}',
            createdAt:
                DateTime.tryParse('${raw['createdTime']}') ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          ),
    ];
  }
}

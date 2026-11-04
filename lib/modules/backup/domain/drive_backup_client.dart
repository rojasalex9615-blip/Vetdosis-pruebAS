import 'dart:typed_data';

class DriveConnection {
  const DriveConnection({required this.accountId, required this.email});
  final String accountId;
  final String email;
}

class DriveBackupReceipt {
  const DriveBackupReceipt({
    required this.fileId,
    required this.name,
    required this.bytes,
    required this.sha256,
    required this.createdAt,
  });
  final String fileId;
  final String name;
  final int bytes;
  final String sha256;
  final DateTime createdAt;
}

abstract interface class DriveBackupClient {
  bool get configured;
  Future<DriveConnection?> connection(String userId, String clinicId);
  Future<DriveConnection> connect(String userId, String clinicId);

  /// True only when Google confirmed revocation for the linked account.
  Future<bool> disconnect(String userId, String clinicId);
  Future<DriveBackupReceipt> uploadVerified(
    String userId,
    String clinicId,
    String name,
    Uint8List encryptedBytes,
  );
  Future<List<DriveBackupReceipt>> history(String userId, String clinicId);
}

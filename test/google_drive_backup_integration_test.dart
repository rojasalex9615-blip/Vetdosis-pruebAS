import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';
import 'package:vetdosis_pro/modules/backup/domain/drive_backup_client.dart';
import 'package:vetdosis_pro/modules/backup/presentation/backup_screen.dart';
import 'backup_protection_test.dart' show CountingBackup;

class FakeAuthenticatedDrive implements DriveBackupClient {
  bool linked = false;

  @override
  bool get configured => true;

  @override
  Future<DriveConnection?> connection(String userId, String clinicId) async =>
      linked
          ? const DriveConnection(
              accountId: 'synthetic-account',
              email: 'tester@example.test',
            )
          : null;

  @override
  Future<DriveConnection> connect(String userId, String clinicId) async {
    linked = true;
    return const DriveConnection(
      accountId: 'synthetic-account',
      email: 'tester@example.test',
    );
  }

  @override
  Future<bool> disconnect(String userId, String clinicId) async {
    linked = false;
    return true;
  }

  @override
  Future<DriveBackupReceipt> uploadVerified(
    String userId,
    String clinicId,
    String name,
    Uint8List encryptedBytes,
  ) async => DriveBackupReceipt(
    fileId: 'synthetic-file',
    name: name,
    bytes: encryptedBytes.length,
    sha256: 'a' * 64,
    createdAt: DateTime.utc(2026, 10, 30),
  );

  @override
  Future<List<DriveBackupReceipt>> history(
    String userId,
    String clinicId,
  ) async => linked
      ? [
          DriveBackupReceipt(
            fileId: 'synthetic-file',
            name: 'vetdosis-clinic-synthetic.vetbackup',
            bytes: 512,
            sha256: 'a' * 64,
            createdAt: DateTime.utc(2026, 10, 30),
          ),
        ]
      : [];
}

void main() {
  testWidgets('Authenticated Drive account can be linked and disconnected', (
    tester,
  ) async {
    final drive = FakeAuthenticatedDrive();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BackupScreen(
            repository: CountingBackup(),
            member: const ClinicMembership(
              clinicId: 'clinic',
              clinicName: 'Pruebas',
              userId: 'tester',
              role: ClinicRole.admin,
            ),
            googleDrive: drive,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final connect = find.text('Vincular cuenta Google');
    await tester.ensureVisible(connect);
    expect(connect, findsOneWidget);
    await tester.tap(connect);
    await tester.pumpAndSettle();

    expect(find.textContaining('Cuenta vinculada: tester@example.test'), findsOneWidget);
    expect(find.text('Subir respaldo cifrado verificado'), findsOneWidget);
    expect(find.text('vetdosis-clinic-synthetic.vetbackup'), findsOneWidget);

    final disconnect = find.text('Desconectar cuenta');
    await tester.ensureVisible(disconnect);
    await tester.tap(disconnect);
    await tester.pumpAndSettle();
    expect(find.text('Vincular cuenta Google'), findsOneWidget);
    expect(find.textContaining('Cuenta vinculada: tester@example.test'), findsNothing);
  });
}

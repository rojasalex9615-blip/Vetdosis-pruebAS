import 'dart:convert';
import 'dart:typed_data';
import '../../backup/domain/backup_archive.dart';
import 'pullet_rearing.dart';
import 'rearing_project_repository.dart';

/// Device budgets belong to one signed-in user and workspace, even inside a clinic backup.
class RearingProjectBackup {
  static const assetName = 'pullet-rearing-projects.v1.json';
  static Future<String> capture(
    RearingProjectRepository repo,
    String user,
    String clinic,
  ) async => jsonEncode({
    'format': 'vetdosis-pullet-projects',
    'version': 1,
    'user_id': user,
    'clinic_id': clinic,
    'projects': [
      for (final p in await repo.list(user, clinic))
        {
          'id': p.id,
          'updated_at': p.updatedAt.toUtc().toIso8601String(),
          'plan': p.plan.toJson(),
        },
    ],
  });
  static List<RearingProject> read(String text, String user, String clinic) {
    try {
      final value = jsonDecode(text) as Map;
      if (value['format'] != 'vetdosis-pullet-projects' ||
          value['version'] != 1 ||
          value['user_id'] != user ||
          value['clinic_id'] != clinic) {
        throw const FormatException(
          'El respaldo de proyectos pertenece a otra cuenta o área de trabajo.',
        );
      }
      final ids = <String>{};
      return (value['projects'] as List).map((e) {
        final id = e['id'] as String;
        if (id.isEmpty || !ids.add(id)) {
          throw const FormatException('Proyecto repetido o sin identificador.');
        }
        final plan = PulletRearingPlan.read(
          Map<String, dynamic>.from(e['plan'] as Map),
        );
        if (plan.name.trim().isEmpty) {
          throw const FormatException('Proyecto sin nombre.');
        }
        return RearingProject(
          id: id,
          updatedAt: DateTime.parse(e['updated_at'] as String),
          plan: plan,
        );
      }).toList();
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Respaldo de proyectos incompleto.');
    }
  }

  static List<RearingProject> fromArchive(
    Uint8List bytes,
    String user,
    String clinic,
  ) {
    final assets = BackupArchive.deviceAssets(bytes);
    final text = assets[assetName];
    if (text == null) {
      throw const FormatException(
        'Este respaldo no contiene proyectos de crianza del dispositivo.',
      );
    }
    return read(text, user, clinic);
  }
}

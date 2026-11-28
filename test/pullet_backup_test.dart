import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:vetdosis_pro/modules/aviculture/data/local_rearing_project_store.dart';
import 'package:vetdosis_pro/modules/aviculture/domain/pullet_rearing.dart';
import 'package:vetdosis_pro/modules/aviculture/domain/rearing_project_backup.dart';
import 'package:vetdosis_pro/modules/aviculture/domain/rearing_project_repository.dart';
import 'package:vetdosis_pro/modules/backup/domain/backup_archive.dart';
import 'remaining_test.dart' show FakeBackup;

void main() {
  late Database db;
  late LocalRearingProjectStore projects;
  const plan = PulletRearingPlan(
    name: 'Caseta Norte',
    brand: 'Otra',
    system: 'piso',
    birds: '4275',
    weeks: 1,
    stages: [RearingStage(name: 'Inicio', firstWeek: 1, lastWeek: 1)],
    feedOverrides: {1: '9'},
  );
  setUp(() async {
    db = await newDatabaseFactoryMemory().openDatabase('backup-pullet.db');
    projects = LocalRearingProjectStore(db);
    await projects.save(
      'user',
      'clinic',
      RearingProject(
        id: 'original',
        updatedAt: DateTime.utc(2026, 11, 27),
        plan: plan,
      ),
    );
  });
  tearDown(() => db.close());
  Future<Uint8List> archive() async => BackupArchive.create(
    FakeBackup(),
    'clinic',
    deviceAssets: {
      RearingProjectBackup.assetName: await RearingProjectBackup.capture(
        projects,
        'user',
        'clinic',
      ),
    },
  );
  test(
    'el respaldo incluye proyectos y permite recuperarlos sin sobrescribir',
    () async {
      final bytes = await archive();
      final recovered = RearingProjectBackup.fromArchive(
        bytes,
        'user',
        'clinic',
      );
      expect(recovered.single.plan.toJson(), plan.toJson());
      await projects.restoreCopies('user', 'clinic', recovered);
      final all = await projects.list('user', 'clinic');
      expect(all, hasLength(2));
      expect(all.map((p) => p.id).toSet(), hasLength(2));
      expect(
        all.firstWhere((p) => p.id == 'original').plan.toJson(),
        plan.toJson(),
      );
    },
  );
  test('otra cuenta o clínica no puede recuperar proyectos ajenos', () async {
    final bytes = await archive();
    expect(
      () => RearingProjectBackup.fromArchive(bytes, 'other', 'clinic'),
      throwsFormatException,
    );
    expect(
      () => RearingProjectBackup.fromArchive(bytes, 'user', 'other'),
      throwsFormatException,
    );
  });
  test('un proyecto alterado invalida el archivo antes de recuperar', () async {
    final value = jsonDecode(utf8.decode(await archive())) as Map;
    value['device_assets'][RearingProjectBackup.assetName]['json'] = '{}';
    expect(
      () => BackupArchive.verify(
        Uint8List.fromList(utf8.encode(jsonEncode(value))),
      ),
      throwsFormatException,
    );
    expect(await projects.list('user', 'clinic'), hasLength(1));
  });
  test('el archivo anterior sin proyectos sigue siendo verificable', () async {
    final value =
        jsonDecode(
              utf8.decode(await BackupArchive.create(FakeBackup(), 'clinic')),
            )
            as Map;
    value.remove('device_assets');
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(value)));
    expect(BackupArchive.verify(bytes)['clinic_id'], 'clinic');
    expect(
      () => RearingProjectBackup.fromArchive(bytes, 'user', 'clinic'),
      throwsFormatException,
    );
  });
}

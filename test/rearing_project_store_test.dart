import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:vetdosis_pro/modules/aviculture/data/local_rearing_project_store.dart';
import 'package:vetdosis_pro/modules/aviculture/domain/pullet_rearing.dart';
import 'package:vetdosis_pro/modules/aviculture/domain/rearing_project_repository.dart';

void main() {
  late Database db;
  late LocalRearingProjectStore repo;
  PulletRearingPlan plan(String name) => PulletRearingPlan(
    name: name,
    brand: 'Otra',
    system: 'piso',
    birds: '100',
    weeks: 1,
    stages: const [RearingStage(name: 'Inicio', firstWeek: 1, lastWeek: 1)],
    feedOverrides: const {1: '12'},
    weightOverrides: const {1: '75'},
    lightOverrides: const {1: '20'},
  );
  RearingProject project(String name) => RearingProject(
    id: 'p1',
    updatedAt: DateTime.utc(2026, 11, 27),
    plan: plan(name),
  );
  setUp(() async {
    db = await newDatabaseFactoryMemory().openDatabase('crianza.db');
    repo = LocalRearingProjectStore(db);
  });
  tearDown(() async {
    await db.close();
  });
  test(
    'persiste y reabre el proyecto con consumos y ajustes propios',
    () async {
      await repo.save('u1', 'c1', project('Mi crianza'));
      final result = await repo.list('u1', 'c1');
      expect(result.single.plan.toJson(), plan('Mi crianza').toJson());
    },
  );
  test('cuenta, clínica e identificador juntos aíslan los proyectos', () async {
    await repo.save('u1', 'c1', project('Casa 1'));
    await repo.save('u1', 'c2', project('Casa 2'));
    await repo.save('u2', 'c1', project('Otra cuenta'));
    expect((await repo.list('u1', 'c1')).single.plan.name, 'Casa 1');
    await repo.remove('u2', 'c2', 'p1');
    expect(await repo.list('u1', 'c1'), hasLength(1));
    await repo.remove('u1', 'c1', 'p1');
    expect(await repo.list('u1', 'c1'), isEmpty);
    expect((await repo.list('u1', 'c2')).single.plan.name, 'Casa 2');
  });
  test(
    'conserva el último guardado y descarta filas con clave adulterada',
    () async {
      await repo.save('u1', 'c1', project('Primero'));
      await repo.save('u1', 'c1', project('Revisado'));
      final store = stringMapStoreFactory.store('pullet-rearing-projects-v1');
      await store.record(jsonEncode(['u2', 'c1', 'p2'])).put(db, {
        'schemaVersion': 1,
        'id': 'p2',
        'userId': 'u1',
        'clinicId': 'c1',
        'updatedAt': DateTime.now().toIso8601String(),
        'plan': plan('Fila extra').toJson(),
      });
      expect((await repo.list('u1', 'c1')).single.plan.name, 'Revisado');
    },
  );
  test('sin cuenta/área o sin nombre se rechaza el guardado', () async {
    await expectLater(repo.save('', 'c1', project('X')), throwsFormatException);
    await expectLater(
      repo.save('u1', 'c1', project('')),
      throwsFormatException,
    );
  });
}

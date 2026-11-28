import 'dart:math';
import 'dart:convert';
import 'package:sembast/sembast.dart';
import '../domain/pullet_rearing.dart';
import '../domain/rearing_project_repository.dart';

class LocalRearingProjectStore implements RearingProjectRepository {
  LocalRearingProjectStore(this.database);
  final Database database;
  final _store = stringMapStoreFactory.store('pullet-rearing-projects-v1');
  String _key(String user, String clinic, String id) =>
      jsonEncode([user, clinic, id]);
  void _scope(String user, String clinic) {
    if (user.trim().isEmpty || clinic.trim().isEmpty) {
      throw const FormatException(
        'Conecta una cuenta y un área de trabajo para guardar.',
      );
    }
  }

  @override
  Future<List<RearingProject>> list(String userId, String clinicId) async {
    _scope(userId, clinicId);
    final rows = await _store.find(
      database,
      finder: Finder(
        filter: Filter.and([
          Filter.equals('userId', userId),
          Filter.equals('clinicId', clinicId),
        ]),
      ),
    );
    final projects = <RearingProject>[];
    for (final row in rows) {
      final value = row.value;
      if (value['userId'] != userId ||
          value['clinicId'] != clinicId ||
          value['schemaVersion'] != 1) {
        continue;
      }
      try {
        final id = value['id'] as String;
        if (id.isEmpty || row.key != _key(userId, clinicId, id)) continue;
        projects.add(
          RearingProject(
            id: id,
            updatedAt: DateTime.parse(value['updatedAt'] as String),
            plan: PulletRearingPlan.read(
              Map<String, dynamic>.from(value['plan'] as Map),
            ),
          ),
        );
      } on Object {
        continue;
      }
    }
    projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return projects;
  }

  @override
  Future<void> save(
    String userId,
    String clinicId,
    RearingProject project,
  ) async {
    _scope(userId, clinicId);
    if (project.id.isEmpty || project.plan.name.trim().isEmpty) {
      throw const FormatException('Ponle nombre al proyecto.');
    }
    // Validate schema and snapshot before persistence; incomplete numeric drafts are allowed.
    final plan = PulletRearingPlan.read(project.plan.toJson());
    await _store.record(_key(userId, clinicId, project.id)).put(database, {
      'schemaVersion': 1,
      'id': project.id,
      'userId': userId,
      'clinicId': clinicId,
      'updatedAt': project.updatedAt.toUtc().toIso8601String(),
      'plan': plan.toJson(),
    });
  }

  @override
  Future<void> restoreCopies(
    String userId,
    String clinicId,
    List<RearingProject> projects,
  ) async {
    _scope(userId, clinicId);
    // Parse every plan before starting the transaction; never overwrite originals.
    final plans = projects
        .map((p) => PulletRearingPlan.read(p.plan.toJson()))
        .toList();
    if (plans.any((p) => p.name.trim().isEmpty)) {
      throw const FormatException('Proyecto sin nombre.');
    }
    final random = Random.secure(), now = DateTime.now().toUtc();
    await database.transaction((txn) async {
      for (var i = 0; i < plans.length; i++) {
        final id =
            'restored-${now.microsecondsSinceEpoch}-$i-${random.nextInt(1 << 30)}';
        await _store.record(_key(userId, clinicId, id)).put(txn, {
          'schemaVersion': 1,
          'id': id,
          'userId': userId,
          'clinicId': clinicId,
          'updatedAt': now.toIso8601String(),
          'plan': plans[i].toJson(),
        });
      }
    });
  }

  @override
  Future<void> remove(String userId, String clinicId, String id) async {
    _scope(userId, clinicId);
    final record = _store.record(_key(userId, clinicId, id)),
        row = await _store.record(_key(userId, clinicId, id)).get(database);
    if (row?['userId'] == userId &&
        row?['clinicId'] == clinicId &&
        row?['id'] == id) {
      await record.delete(database);
    }
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;
import 'package:vetdosis_pro/modules/doses/data/local_dose_record_store.dart';
import 'package:vetdosis_pro/modules/doses/data/supabase_dose_record_store.dart';
import 'package:vetdosis_pro/modules/doses/data/syncing_dose_record_store.dart';
import 'package:vetdosis_pro/modules/doses/domain/dose_record.dart';

const _idA = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _idB = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _idC = 'cccccccccccccccccccccccccccccccccccccccccccccccc';
const _idD = 'dddddddddddddddddddddddddddddddddddddddddddddddd';
const _idE = 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';

DoseRecord _registro({
  String id = _idA,
  String? patientId = 'P1',
  String? clinicId = 'C1',
  String? concentracion = '50',
  String? resultadoMl = '5–10 mL',
  DateTime? syncedAt,
}) => DoseRecord(
  id: id,
  createdAt: DateTime.utc(2026, 11, 26, 9),
  principio: 'Fenbendazol',
  pautaId: 'D1',
  indicacion: 'Giardia',
  especie: 'Perro y gato',
  via: 'oral',
  intervalo: 'cada 24 h',
  dosisLiteral: '25–50 mg/kg',
  cita: 'Ramsey, I. (ed.) / BSAVA 2017, p. 275',
  pesoKg: '10,5',
  resultadoMg: '250–500 mg',
  concentracionMgMl: concentracion,
  resultadoMl: resultadoMl,
  clinicId: clinicId,
  patientId: patientId,
  patientName: 'Anestesia',
  actorId: 'U1',
  syncedAt: syncedAt,
);

/// Destino remoto de mentira: guarda en memoria y puede simular falta de red.
class _RemotoFalso implements DoseRecordStore {
  _RemotoFalso({this.sinRed = false});

  bool sinRed;
  final guardados = <DoseRecord>[];
  final enLaNube = <DoseRecord>[];

  @override
  Future<DoseRecord> save(DoseRecord record) async {
    if (sinRed) throw Exception('sin conexión');
    final enviado = record.marcarSincronizado(DateTime.utc(2026, 11, 26, 12));
    guardados.add(record);
    enLaNube.add(enviado);
    return enviado;
  }

  @override
  Future<List<DoseRecord>> forPatient(
    String patientId, {
    int limit = 50,
  }) async {
    if (sinRed) throw Exception('sin conexión');
    return enLaNube.where((r) => r.patientId == patientId).toList();
  }

  @override
  Future<List<DoseRecord>> recent({int limit = 50}) async => enLaNube;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Cada prueba estrena base: la fábrica en memoria conserva el contenido.
  var base = 0;

  group('almacén del dispositivo', () {
    late Database db;
    late LocalDoseRecordStore local;

    setUp(() async {
      db = await databaseFactoryMemory.openDatabase('dosis-${base++}');
      local = LocalDoseRecordStore(db);
    });

    tearDown(() => db.close());

    test('guarda y devuelve los cálculos del paciente', () async {
      final guardado = await local.save(_registro());
      expect(guardado.syncedAt, isNull);
      final delPaciente = await local.forPatient('P1');
      expect(delPaciente, hasLength(1));
      expect(delPaciente.single.indicacion, 'Giardia');
      expect(delPaciente.single.resultadoMl, '5–10 mL');
      expect(await local.forPatient('P2'), isEmpty);
    });

    test(
      'lo pendiente es lo que no llegó a la nube y tiene paciente',
      () async {
        await local.save(_registro(id: _idB));
        await local.save(
          _registro(id: _idC, syncedAt: DateTime.utc(2026, 11, 26, 10)),
        );
        await local.save(_registro(id: _idD, patientId: null, clinicId: null));

        final pendientes = await local.pendientes();
        expect(pendientes.map((r) => r.id), [_idB]);
      },
    );
  });

  group('guardado en el dispositivo y en la ficha', () {
    late Database db;
    late LocalDoseRecordStore local;

    setUp(() async {
      db = await databaseFactoryMemory.openDatabase('dosis-nube-${base++}');
      local = LocalDoseRecordStore(db);
    });

    tearDown(() => db.close());

    test('sin nube el cálculo queda en el dispositivo', () async {
      final store = SyncingDoseRecordStore(local: local);

      final guardado = await store.save(_registro());

      expect(guardado.syncedAt, isNull);
      expect(await local.forPatient('P1'), hasLength(1));
    });

    test('con nube se guarda en los dos y queda la marca', () async {
      final remoto = _RemotoFalso();
      final store = SyncingDoseRecordStore(local: local, remote: remoto);

      final guardado = await store.save(_registro());

      expect(guardado.syncedAt, isNotNull);
      expect(remoto.guardados, hasLength(1));
      final enDispositivo = await local.forPatient('P1');
      expect(enDispositivo.single.syncedAt, isNotNull);
    });

    test('si la nube falla no se pierde lo del dispositivo', () async {
      final remoto = _RemotoFalso(sinRed: true);
      final store = SyncingDoseRecordStore(local: local, remote: remoto);

      final guardado = await store.save(_registro());

      expect(guardado.syncedAt, isNull);
      expect(await local.forPatient('P1'), hasLength(1));
      expect(await local.pendientes(), hasLength(1));
    });

    test('lo pendiente se reenvía y deja de estar pendiente', () async {
      final remoto = _RemotoFalso(sinRed: true);
      final store = SyncingDoseRecordStore(local: local, remote: remoto);
      await store.save(_registro());
      expect(await local.pendientes(), hasLength(1));

      remoto.sinRed = false;
      final enviados = await store.reintentarPendientes();

      expect(enviados, 1);
      expect(remoto.guardados, hasLength(1));
      expect(await local.pendientes(), isEmpty);
    });

    test('un paciente sin cálculo en la nube sigue leyendo lo local', () async {
      final remoto = _RemotoFalso();
      final store = SyncingDoseRecordStore(local: local, remote: remoto);
      await local.save(_registro(id: _idE));

      expect(await store.forPatient('P1'), hasLength(1));
    });
  });

  group('lo que viaja a la tabla', () {
    test('el peso y la concentración van con punto decimal', () {
      final carga = doseCalculationPayload(_registro());
      expect(carga['peso_kg'], '10.5');
      expect(carga['concentracion_mg_ml'], '50');
      expect(carga['resultado_ml'], '5–10 mL');
      expect(carga['cita'], contains('p. 275'));
    });

    test('sin volumen no se manda concentración ni mililitros', () {
      final carga = doseCalculationPayload(
        _registro(concentracion: null, resultadoMl: null),
      );
      expect(carga.containsKey('concentracion_mg_ml'), isFalse);
      expect(carga.containsKey('resultado_ml'), isFalse);
    });

    test('la fila de vuelta se lee como se mostró en pantalla', () {
      final registro = fromRowForTest({
        'id': 'ffffffff-ffff-ffff-ffff-ffffffffffff',
        'clinic_id': 'C1',
        'patient_id': 'P1',
        'created_at': '2026-11-26T12:00:00.123456+00:00',
        'principio': 'Fenbendazol',
        'pauta_id': 'D1',
        'indicacion': 'Giardia',
        'especie': 'Perro y gato',
        'via': 'oral',
        'intervalo': 'cada 24 h',
        'dosis_literal': '25–50 mg/kg',
        'cita': 'Ramsey, I. (ed.) / BSAVA 2017, p. 275',
        'peso_kg': 10.5,
        'resultado_mg': '250–500 mg',
        'concentracion_mg_ml': 50,
        'resultado_ml': '5–10 mL',
      });

      expect(registro.pesoKg, '10,5');
      expect(registro.concentracionMgMl, '50');
      expect(registro.resultadoMl, '5–10 mL');
      expect(registro.syncedAt, isNotNull);
      expect(registro.clinicId, 'C1');
    });

    test('una respuesta vacía no rompe la lectura', () {
      expect(asDoseRows(null), isEmpty);
      expect(asDoseRows(const <dynamic>[]), isEmpty);
      expect(asDoseRows({'id': 'x'}), hasLength(1));
    });

    test('la identidad del cálculo tiene el formato del recibo', () {
      final id = nuevoDoseRecordId();
      expect(id, matches(RegExp(r'^[a-f0-9]{48}$')));
      expect(id, isNot(nuevoDoseRecordId()));
    });
  });
}

DoseRecord fromRowForTest(Map<String, dynamic> row) => doseRecordFromRow(row);

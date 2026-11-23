import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';
import 'package:vetdosis_pro/modules/reproduction/domain/gestation.dart';
import 'package:vetdosis_pro/modules/reproduction/domain/gestation_write_repository.dart';
import 'package:vetdosis_pro/modules/reproduction/presentation/gestation_capture_forms.dart';
import 'package:vetdosis_pro/modules/reproduction/presentation/gestation_panel.dart';

class _FakeRead implements GestationRepository {
  _FakeRead(this.snapshot, {this.fallar = false});
  final GestationSnapshot snapshot;
  final bool fallar;
  int llamadas = 0;
  @override
  Future<GestationSnapshot> load(String clinicId) async {
    llamadas++;
    if (fallar) throw Exception('sin red');
    return snapshot;
  }
}

class _FakeWrite implements GestationWriteRepository {
  _FakeWrite({this.fallarVeces = 0, this.listaHembras = _hembrasPorOmision});
  int fallarVeces;
  List<BreedingFemale> listaHembras;
  bool fallarPadron = false;

  final llamadas = <String>[];
  final operaciones = <String>[];
  final argumentos = <Map<String, Object?>>[];

  Future<String> _registrar(String metodo, Map<String, Object?> args) async {
    llamadas.add(metodo);
    operaciones.add('${args['operation']}');
    argumentos.add(args);
    if (fallarVeces > 0) {
      fallarVeces--;
      throw const GestationWriteException('sin_red', 'No hay conexión.');
    }
    return 'id-${llamadas.length}';
  }

  @override
  Future<String> guardarGestacion({
    required String clinicId,
    String? id,
    required String patientId,
    String? loteId,
    required String especie,
    required DateTime servicio,
    required String metodo,
    String? semental,
    int? dias,
    required String diagnostico,
    DateTime? diagnosticoEl,
    String? notas,
    required String operation,
  }) => _registrar('guardarGestacion', {
    'id': id,
    'patientId': patientId,
    'loteId': loteId,
    'especie': especie,
    'servicio': servicio,
    'metodo': metodo,
    'semental': semental,
    'dias': dias,
    'diagnostico': diagnostico,
    'operation': operation,
  });

  @override
  Future<String> cerrarGestacion({
    required String clinicId,
    required String id,
    required String estado,
    DateTime? parto,
    int? vivas,
    int? muertas,
    String? notas,
    required String operation,
  }) => _registrar('cerrarGestacion', {
    'id': id,
    'estado': estado,
    'parto': parto,
    'vivas': vivas,
    'muertas': muertas,
    'operation': operation,
  });

  @override
  Future<List<BreedingFemale>> hembras(String clinicId) async {
    if (fallarPadron) throw Exception('sin padrón');
    return listaHembras;
  }
}

const _hembrasPorOmision = [
  BreedingFemale(id: 'p1', nombre: 'Lucero', especie: 'Bovino'),
  BreedingFemale(id: 'p2', nombre: 'Canela', especie: 'Hámster sirio'),
  BreedingFemale(id: 'p3', nombre: 'Rayo', especie: 'Dragón de Komodo'),
];

const _catalogo = [
  GestationDays(
    especie: 'bovino',
    nombre: 'Bovino',
    grupo: 'produccion',
    min: 279,
    promedio: 283,
    max: 292,
  ),
  GestationDays(
    especie: 'hamster',
    nombre: 'Hámster',
    grupo: 'exotico',
    min: 15,
    promedio: 16,
    max: 18,
  ),
  GestationDays(
    especie: 'hamster sirio',
    nombre: 'Hámster sirio',
    grupo: 'exotico',
    min: 15,
    promedio: 16,
    max: 18,
  ),
];

const _admin = ClinicMembership(
  clinicId: 'c1',
  clinicName: 'C',
  userId: 'u',
  role: ClinicRole.admin,
);

Gestation _g({
  String id = 'g1',
  String patientId = 'p1',
  String? loteId,
  required DateTime servicio,
  DateTime? estimado,
  GestationState estado = GestationState.enCurso,
  PregnancyCheck diag = PregnancyCheck.gestante,
  int? vivas,
  int? muertas,
}) => Gestation(
  id: id,
  patientId: patientId,
  loteId: loteId,
  especie: 'Bovino',
  servicio: servicio,
  metodo: MatingMethod.montaNatural,
  diagnostico: diag,
  estado: estado,
  partoEstimado: estimado,
  criasVivas: vivas,
  criasMuertas: muertas,
);

Future<void> _montar(
  WidgetTester tester,
  Future<bool> Function(BuildContext) abrir,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (c) => ElevatedButton(
            onPressed: () => abrir(c),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

Future<void> _escribir(
  WidgetTester tester,
  String etiqueta,
  String texto,
) async {
  await tester.enterText(
    find.ancestor(
      of: find.text(etiqueta),
      matching: find.byType(TextFormField),
    ),
    texto,
  );
  await tester.pump();
}

void main() {
  final hoy = DateTime(2026, 11, 23);

  group('normalizarEspecie', () {
    test('baja acentos, mayúsculas y espacios de más', () {
      expect(normalizarEspecie('Hámster  Sirio '), 'hamster sirio');
      expect(normalizarEspecie('BÚFALO'), 'bufalo');
      expect(normalizarEspecie('Ratón'), 'raton');
    });
  });

  group('diasDeEspecie', () {
    test('encuentra la coincidencia exacta', () {
      expect(diasDeEspecie(_catalogo, 'Bovino')?.promedio, 283);
    });

    test('prefiere la coincidencia más específica', () {
      // «Hámster sirio» debe ganar a «hamster», que tambien encaja.
      expect(
        diasDeEspecie(_catalogo, 'Hámster sirio')?.especie,
        'hamster sirio',
      );
    });

    test('devuelve null cuando la especie no está en el catálogo', () {
      // Es el caso importante: no se inventa un numero de dias.
      expect(diasDeEspecie(_catalogo, 'Dragón de Komodo'), isNull);
      expect(diasDeEspecie(_catalogo, ''), isNull);
    });
  });

  group('Gestation', () {
    test('la cuenta regresiva es null sin fecha prevista', () {
      final g = _g(servicio: DateTime(2026, 10, 1));
      expect(g.diasParaParto(hoy), isNull);
      expect(g.vencida(hoy), isFalse);
    });

    test('cuenta los días que faltan y los que sobran', () {
      expect(
        _g(
          servicio: DateTime(2026, 1, 1),
          estimado: DateTime(2026, 11, 30),
        ).diasParaParto(hoy),
        7,
      );
      expect(
        _g(
          servicio: DateTime(2026, 1, 1),
          estimado: DateTime(2026, 11, 20),
        ).diasParaParto(hoy),
        -3,
      );
    });

    test('solo está vencida si sigue abierta', () {
      final pasada = DateTime(2026, 11, 20);
      expect(
        _g(servicio: DateTime(2026, 1, 1), estimado: pasada).vencida(hoy),
        isTrue,
      );
      expect(
        _g(
          servicio: DateTime(2026, 1, 1),
          estimado: pasada,
          estado: GestationState.parida,
        ).vencida(hoy),
        isFalse,
      );
    });

    test('suma las crías solo si hay alguna capturada', () {
      expect(_g(servicio: hoy).criasTotales, isNull);
      expect(_g(servicio: hoy, vivas: 2, muertas: 1).criasTotales, 3);
      expect(_g(servicio: hoy, vivas: 2).criasTotales, 2);
    });
  });

  group('GestationSnapshot', () {
    final datos = GestationSnapshot(
      gestaciones: [
        _g(id: 'a', servicio: DateTime(2026, 2, 1), estimado: DateTime(2026, 11, 20)),
        _g(id: 'b', servicio: DateTime(2026, 3, 1), estimado: DateTime(2026, 12, 1)),
        _g(id: 'c', servicio: DateTime(2026, 4, 1)),
        _g(
          id: 'd',
          servicio: DateTime(2026, 1, 1),
          estimado: DateTime(2026, 10, 1),
          estado: GestationState.parida,
        ),
        _g(id: 'e', loteId: 'L1', servicio: DateTime(2026, 5, 1), estimado: DateTime(2027, 2, 1)),
      ],
      catalogo: _catalogo,
    );

    test('las que no tienen fecha prevista van al final', () {
      expect(datos.abiertas().map((g) => g.id).toList(), [
        'a',
        'b',
        'e',
        'c',
      ]);
    });

    test('separa vencidas de próximas', () {
      expect(datos.vencidas(hoy).map((g) => g.id), ['a']);
      expect(datos.proximas(hoy).map((g) => g.id), ['b']);
    });

    test('la cerrada no cuenta como abierta', () {
      expect(datos.abiertas().any((g) => g.id == 'd'), isFalse);
    });

    test('filtra por lote', () {
      expect(datos.deLote('L1').map((g) => g.id), ['e']);
      expect(datos.deLote('L9'), isEmpty);
    });
  });

  group('permisos', () {
    test('auxiliar sí, recepción no', () {
      for (final r in [
        ClinicRole.admin,
        ClinicRole.mvz,
        ClinicRole.auxiliar,
      ]) {
        expect(
          puedeCapturarGestacion(
            ClinicMembership(
              clinicId: 'c',
              clinicName: 'C',
              userId: 'u',
              role: r,
            ),
          ),
          isTrue,
        );
      }
      expect(
        puedeCapturarGestacion(
          const ClinicMembership(
            clinicId: 'c',
            clinicName: 'C',
            userId: 'u',
            role: ClinicRole.recepcion,
          ),
        ),
        isFalse,
      );
      expect(puedeCapturarGestacion(null), isFalse);
    });
  });

  group('traducirErrorGestacion', () {
    test('explica los cierres incompletos', () {
      expect(
        traducirErrorGestacion(Exception('parto_requerido')).mensaje,
        contains('fecha del parto'),
      );
      expect(
        traducirErrorGestacion(Exception('crias_requeridas')).mensaje,
        contains('crías'),
      );
    });

    test('elige el código más específico', () {
      expect(
        traducirErrorGestacion(
          Exception('diagnostico_antes_del_servicio'),
        ).codigo,
        'diagnostico_antes_del_servicio',
      );
    });

    test('lo desconocido no deja a nadie sin explicación', () {
      expect(
        traducirErrorGestacion(Exception('vaya')).codigo,
        'desconocido',
      );
    });
  });

  group('formulario de gestación', () {
    testWidgets('sin hembras en el padrón nombra el paso que falta', (
      tester,
    ) async {
      final repo = _FakeWrite(listaHembras: const []);
      await _montar(
        tester,
        (c) => capturarGestacion(
          c,
          clinicId: 'c1',
          repo: repo,
          catalogo: _catalogo,
        ),
      );
      expect(find.textContaining('da de alta a la hembra'), findsOneWidget);
      expect(find.text('Registrar'), findsNothing);
    });

    testWidgets('sugiere los días de la especie al elegir la hembra', (
      tester,
    ) async {
      final repo = _FakeWrite();
      await _montar(
        tester,
        (c) => capturarGestacion(
          c,
          clinicId: 'c1',
          repo: repo,
          catalogo: _catalogo,
        ),
      );
      await tester.tap(find.text('Hembra *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lucero · Bovino').last);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, '283'), findsOneWidget);
      expect(find.textContaining('Sugerido para Bovino'), findsOneWidget);
    });

    testWidgets('si la especie no está en el catálogo lo dice y no inventa', (
      tester,
    ) async {
      final repo = _FakeWrite();
      await _montar(
        tester,
        (c) => capturarGestacion(
          c,
          clinicId: 'c1',
          repo: repo,
          catalogo: _catalogo,
        ),
      );
      await tester.tap(find.text('Hembra *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rayo · Dragón de Komodo').last);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('El catálogo no tiene días'),
        findsOneWidget,
      );
      expect(find.text('Se calculará al guardar'), findsNothing);
    });

    testWidgets('manda la especie de la hembra y el lote recibido', (
      tester,
    ) async {
      final repo = _FakeWrite();
      await _montar(
        tester,
        (c) => capturarGestacion(
          c,
          clinicId: 'c1',
          repo: repo,
          catalogo: _catalogo,
          loteId: 'L7',
          nombreDelLote: 'Hato norte',
        ),
      );
      expect(find.textContaining('Hato norte'), findsOneWidget);
      await tester.tap(find.text('Hembra *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lucero · Bovino').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar'));
      await tester.pumpAndSettle();

      final a = repo.argumentos.single;
      expect(a['patientId'], 'p1');
      expect(a['especie'], 'Bovino');
      expect(a['loteId'], 'L7');
      expect(a['dias'], 283);
      expect(a['id'], isNull);
    });

    testWidgets('el reintento reusa la misma operación', (tester) async {
      final repo = _FakeWrite(fallarVeces: 1);
      await _montar(
        tester,
        (c) => capturarGestacion(
          c,
          clinicId: 'c1',
          repo: repo,
          catalogo: _catalogo,
        ),
      );
      await tester.tap(find.text('Hembra *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lucero · Bovino').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No hay conexión'), findsOneWidget);
      await tester.tap(find.text('Registrar'));
      await tester.pumpAndSettle();
      expect(repo.operaciones.length, 2);
      expect(repo.operaciones[0], repo.operaciones[1]);
    });
  });

  group('cierre de gestación', () {
    testWidgets('pide crías solo cuando hubo parto', (tester) async {
      final repo = _FakeWrite();
      await _montar(
        tester,
        (c) => cerrarGestacion(
          c,
          clinicId: 'c1',
          repo: repo,
          gestacion: _g(servicio: DateTime(2026, 2, 1)),
          nombreDeLaHembra: 'Lucero',
        ),
      );
      expect(find.text('Crías vivas *'), findsOneWidget);

      await tester.tap(find.text('Cómo terminó *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aborto').last);
      await tester.pumpAndSettle();
      expect(find.text('Crías vivas *'), findsNothing);
    });

    testWidgets('no deja cerrar un parto sin número de crías', (tester) async {
      final repo = _FakeWrite();
      await _montar(
        tester,
        (c) => cerrarGestacion(
          c,
          clinicId: 'c1',
          repo: repo,
          gestacion: _g(servicio: DateTime(2026, 2, 1)),
          nombreDeLaHembra: 'Lucero',
        ),
      );
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.text('Hace falta este dato'), findsOneWidget);
      expect(repo.llamadas, isEmpty);
    });

    testWidgets('un aborto no manda crías', (tester) async {
      final repo = _FakeWrite();
      await _montar(
        tester,
        (c) => cerrarGestacion(
          c,
          clinicId: 'c1',
          repo: repo,
          gestacion: _g(servicio: DateTime(2026, 2, 1)),
          nombreDeLaHembra: 'Lucero',
        ),
      );
      await tester.tap(find.text('Cómo terminó *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aborto').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();

      final a = repo.argumentos.single;
      expect(a['estado'], 'aborto');
      expect(a['vivas'], isNull);
      expect(a['muertas'], isNull);
    });

    testWidgets('guarda el parto con sus crías', (tester) async {
      final repo = _FakeWrite();
      await _montar(
        tester,
        (c) => cerrarGestacion(
          c,
          clinicId: 'c1',
          repo: repo,
          gestacion: _g(servicio: DateTime(2026, 2, 1)),
          nombreDeLaHembra: 'Lucero',
        ),
      );
      await _escribir(tester, 'Crías vivas *', '2');
      await _escribir(tester, 'Crías muertas', '1');
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();

      final a = repo.argumentos.single;
      expect(a['estado'], 'parida');
      expect(a['vivas'], 2);
      expect(a['muertas'], 1);
      expect(a['id'], 'g1');
    });
  });

  group('GestationPanel', () {
    testWidgets('sin repositorio enseña el vacío, no un error', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: GestationPanel(member: _admin)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Todavía no hay gestaciones registradas'),
        findsOneWidget,
      );
    });

    testWidgets('un fallo de red no se confunde con "no hay nada"', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GestationPanel(
                member: _admin,
                repository: _FakeRead(
                  const GestationSnapshot(),
                  fallar: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('No se pudieron leer las gestaciones'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('destaca las vencidas y nombra a la hembra', (tester) async {
      final datos = GestationSnapshot(
        gestaciones: [
          _g(
            id: 'a',
            servicio: DateTime(2026, 2, 1),
            estimado: DateTime(2026, 11, 20),
          ),
        ],
        catalogo: _catalogo,
        nombresDePaciente: const {'p1': 'Lucero'},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GestationPanel(
                member: _admin,
                repository: _FakeRead(datos),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ya debieron parir'), findsOneWidget);
      expect(find.text('Lucero'), findsOneWidget);
      expect(find.textContaining('Debió parir hace'), findsOneWidget);
    });

    testWidgets('sin poder escribir no dibuja los botones de captura', (
      tester,
    ) async {
      final datos = GestationSnapshot(
        gestaciones: [_g(servicio: DateTime(2026, 2, 1))],
        nombresDePaciente: const {'p1': 'Lucero'},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GestationPanel(
                member: _admin,
                repository: _FakeRead(datos),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Hay lectura pero no escritura: nada de «Nueva gestación».
      expect(find.text('Nueva gestación'), findsNothing);
      expect(find.text('Cerrar'), findsNothing);
    });
  });
}

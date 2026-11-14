import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/laboratory/domain/lab_repository.dart';
import 'package:vetdosis_pro/modules/laboratory/presentation/lab_screen.dart';

/// Repositorio de mentira: devuelve lo que el servidor devolveria, en la
/// misma forma, sin tocar la red.
class _FakeLab implements LabRepository {
  _FakeLab(this.data, {this.catalogo = const []});
  final Map<String, dynamic> data;
  final List<Map<String, dynamic>> catalogo;
  Map<String, dynamic>? guardado;

  @override
  Future<LabWorkspace> workspace(String clinicId, String patientId) async =>
      LabWorkspace.read(data);

  @override
  Future<List<LabAnalyte>> analyteCatalog(
    String clinicId,
    String patientId,
  ) async => [for (final r in catalogo) LabAnalyte.read(r)];

  @override
  Future<String> recordPanel(
    String clinicId,
    String patientId, {
    required DateTime collectedAt,
    required String origin,
    required String labName,
    required String notes,
    required List<LabDraftResult> results,
    required String operationId,
  }) async {
    guardado = {
      'operation': operationId,
      'results': [for (final r in results) r.toJson()],
    };
    return 'panel-1';
  }

  Map<String, dynamic>? corregido;

  @override
  Future<String> correctResult(
    String clinicId,
    String resultId, {
    required String value,
    required String unit,
    required String reason,
    required String operationId,
  }) async {
    corregido = {
      'result': resultId,
      'value': value,
      'unit': unit,
      'reason': reason,
    };
    return 'nuevo-1';
  }
}

Map<String, dynamic> _resultado(
  String analito,
  String valor,
  String unidad,
  List<Map<String, dynamic>> rangos,
) => {
  'id': 'r-$analito',
  'analyte_key': analito,
  'value': valor,
  'unit': unidad,
  'replaces_id': null,
  'correction_reason': null,
  'ranges': rangos,
};

Map<String, dynamic> _rango(
  String bajo,
  String alto,
  String unidad,
  String fuente, {
  bool verificado = true,
}) => {
  'low': bajo,
  'high': alto,
  'unit': unidad,
  'source': fuente,
  'verified': verificado,
};

Map<String, dynamic> _ws(
  List<Map<String, dynamic>> resultados, {
  bool canRecord = true,
}) => {
  'can_record': canRecord,
  'panels': [
    {
      'id': 'p1',
      'patient_name': 'Max',
      'species': 'Canino',
      'collected_at': '2026-11-09T15:30:00Z',
      'origin': 'laboratorio_externo',
      'lab_name': 'Lab del centro',
      'notes': '',
      'results': resultados,
    },
  ],
};

Future<void> _montar(WidgetTester tester, _FakeLab repo) async {
  await tester.pumpWidget(
    MaterialApp(
      home: LabScreen(
        repository: repo,
        clinicId: 'c1',
        patientId: 'pac1',
        patientName: 'Max',
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Dos fuentes que no coinciden: se muestran las dos y se avisa', (
    tester,
  ) async {
    // 36 queda bajo para una fuente y dentro para la otra.
    final repo = _FakeLab(
      _ws([
        _resultado('hematocrito', '36', '%', [
          _rango('37', '55', '%', 'NRC 2012'),
          _rango('35', '57', '%', 'Pork School', verificado: false),
        ]),
      ]),
    );
    await _montar(tester, repo);

    expect(find.textContaining('NRC 2012'), findsOneWidget);
    expect(find.textContaining('Pork School'), findsOneWidget);
    // Los limites sin el .0 que trae el double.
    expect(find.textContaining('37 – 55 %'), findsOneWidget);
    expect(find.text('Bajo'), findsOneWidget);
    expect(find.text('Dentro'), findsOneWidget);
    expect(find.textContaining('Las fuentes no coinciden'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cuando las fuentes coinciden no se avisa de desacuerdo', (
    tester,
  ) async {
    final repo = _FakeLab(
      _ws([
        _resultado('hematocrito', '45', '%', [
          _rango('37', '55', '%', 'NRC 2012'),
          _rango('35', '57', '%', 'Pork School'),
        ]),
      ]),
    );
    await _montar(tester, repo);
    expect(find.text('Dentro'), findsNWidgets(2));
    expect(find.textContaining('Las fuentes no coinciden'), findsNothing);
  });

  testWidgets('Sin rango para la especie se guarda el valor y no se juzga', (
    tester,
  ) async {
    final repo = _FakeLab(
      _ws([_resultado('albumina', '3.25', 'g/dL', const [])]),
    );
    await _montar(tester, repo);
    expect(find.text('3.25 g/dL'), findsOneWidget);
    expect(find.textContaining('Sin rango de referencia'), findsOneWidget);
    expect(find.text('Dentro'), findsNothing);
    expect(find.text('Bajo'), findsNothing);
    expect(find.text('Alto'), findsNothing);
  });

  testWidgets('Sin permiso de captura no se ofrece el formulario', (
    tester,
  ) async {
    final repo = _FakeLab(
      _ws([
        _resultado('hematocrito', '45', '%', [_rango('37', '55', '%', 'NRC')]),
      ], canRecord: false),
    );
    await _montar(tester, repo);
    expect(find.text('Registrar una toma'), findsNothing);
    expect(find.textContaining('no registrarlas'), findsOneWidget);
  });

  testWidgets('La correccion exige motivo y conserva el original', (
    tester,
  ) async {
    final repo = _FakeLab(
      _ws([
        _resultado('hematocrito', '36', '%', [_rango('37', '55', '%', 'NRC')]),
      ]),
    );
    await _montar(tester, repo);

    await tester.tap(find.byTooltip('Corregir este resultado'));
    await tester.pumpAndSettle();
    // Sin motivo no se envia nada.
    await tester.tap(find.text('Guardar la corrección'));
    await tester.pumpAndSettle();
    expect(find.textContaining('por qué se corrige'), findsOneWidget);
    expect(repo.corregido, isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'Motivo de la corrección'),
      'Captura equivocada',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Valor corregido'),
      '41',
    );
    await tester.tap(find.text('Guardar la corrección'));
    await tester.pumpAndSettle();
    expect(repo.corregido, {
      'result': 'r-hematocrito',
      'value': '41',
      'unit': '%',
      'reason': 'Captura equivocada',
    });
  });

  testWidgets('Sin permiso de escritura no se ofrece corregir', (
    tester,
  ) async {
    final repo = _FakeLab(
      _ws([
        _resultado('hematocrito', '36', '%', [_rango('37', '55', '%', 'NRC')]),
      ], canRecord: false),
    );
    await _montar(tester, repo);
    expect(find.byTooltip('Corregir este resultado'), findsNothing);
  });

  testWidgets('La captura rechaza la coma decimal antes de enviar', (
    tester,
  ) async {
    final repo = _FakeLab(_ws(const []));
    await _montar(tester, repo);
    await tester.tap(find.text('Registrar una toma'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Analito 1'),
      'hematocrito',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Valor'), '1,200');
    await tester.enterText(find.widgetWithText(TextField, 'Unidad'), '%');
    await tester.tap(find.text('Guardar la toma'));
    await tester.pumpAndSettle();

    // «punto decimal» tambien esta en el subtitulo de la hoja, asi que se
    // busca el mensaje concreto, que nombra el analito que fallo.
    expect(
      find.textContaining('hematocrito: Valor: usa punto decimal'),
      findsOneWidget,
    );
    expect(repo.guardado, isNull, reason: 'no debe enviarse nada al servidor');
  });

  testWidgets('Una captura valida llega al repositorio', (tester) async {
    final repo = _FakeLab(_ws(const []));
    await _montar(tester, repo);
    await tester.tap(find.text('Registrar una toma'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Analito 1'),
      'hematocrito',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Valor'), '45.5');
    await tester.enterText(find.widgetWithText(TextField, 'Unidad'), '%');
    await tester.tap(find.text('Guardar la toma'));
    await tester.pumpAndSettle();

    expect(repo.guardado, isNotNull);
    expect(repo.guardado!['results'], [
      {'analyte_key': 'hematocrito', 'value': '45.5', 'unit': '%'},
    ]);
    // La clave de operacion es la que exige el servidor: 48 hexadecimales.
    expect(
      RegExp(r'^[0-9a-f]{48}$').hasMatch('${repo.guardado!['operation']}'),
      isTrue,
    );
  });

  testWidgets('El catalogo ofrece el analito y llena su unidad', (
    tester,
  ) async {
    final repo = _FakeLab(
      _ws(const []),
      catalogo: const [
        {'analyte_key': 'Hematocrito', 'unit': '%', 'sources': 2},
        {'analyte_key': 'Glucosa', 'unit': 'mg/dL', 'sources': 1},
      ],
    );
    await _montar(tester, repo);
    await tester.tap(find.text('Registrar una toma'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Analito 1'),
      'hemat',
    );
    await tester.pumpAndSettle();
    // La opcion dice cuantas fuentes hay: dos es el caso en que pueden no
    // coincidir.
    expect(find.text('Hematocrito · % · 2 fuentes'), findsOneWidget);
    await tester.tap(find.text('Hematocrito · % · 2 fuentes'));
    await tester.pumpAndSettle();

    // Al elegir, el nombre queda exacto y la unidad se llena sola: las dos
    // mitades de que el rango aparezca.
    await tester.enterText(find.widgetWithText(TextField, 'Valor'), '45');
    await tester.tap(find.text('Guardar la toma'));
    await tester.pumpAndSettle();
    expect(repo.guardado!['results'], [
      {'analyte_key': 'Hematocrito', 'value': '45', 'unit': '%'},
    ]);
  });

  testWidgets('Sin catalogo la captura sigue aceptando el nombre a mano', (
    tester,
  ) async {
    final repo = _FakeLab(_ws(const []));
    await _montar(tester, repo);
    await tester.tap(find.text('Registrar una toma'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Analito 1'),
      'analito raro',
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Valor'), '1.5');
    await tester.enterText(find.widgetWithText(TextField, 'Unidad'), 'mg/dL');
    await tester.tap(find.text('Guardar la toma'));
    await tester.pumpAndSettle();
    expect(repo.guardado!['results'], [
      {'analyte_key': 'analito raro', 'value': '1.5', 'unit': 'mg/dL'},
    ]);
  });
}

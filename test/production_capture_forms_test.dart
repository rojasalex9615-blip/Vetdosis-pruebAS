import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/core/widgets/capture_sheet.dart';
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';
import 'package:vetdosis_pro/modules/production/domain/production_farm.dart';
import 'package:vetdosis_pro/modules/production/domain/production_write_repository.dart';
import 'package:vetdosis_pro/modules/production/presentation/production_capture_forms.dart';

/// Escritura de mentira: apunta lo que le piden y puede fallar a voluntad,
/// que es como se comprueba que el reintento no duplica.
class _FakeWrite implements ProductionWriteRepository {
  _FakeWrite({this.fallarVeces = 0});

  int fallarVeces;
  List<SpeciesPurpose> pares = _paresPorOmision;
  bool fallarCatalogo = false;

  final llamadas = <String>[];
  final operaciones = <String>[];
  final argumentos = <Map<String, Object?>>[];

  Future<String> _registrar(String metodo, Map<String, Object?> args) async {
    llamadas.add(metodo);
    operaciones.add('${args['operation']}');
    argumentos.add(args);
    if (fallarVeces > 0) {
      fallarVeces--;
      throw const ProductionWriteException('sin_red', 'No hay conexión.');
    }
    return 'id-${llamadas.length}';
  }

  @override
  Future<String> guardarLote({
    required String clinicId,
    required Map<String, dynamic> data,
    required String operation,
  }) => _registrar('guardarLote', {'data': data, 'operation': operation});

  @override
  Future<String> guardarRegistro({
    required String clinicId,
    required String loteId,
    required DateTime fecha,
    required Map<String, double> metricas,
    String? notas,
    required String operation,
  }) => _registrar('guardarRegistro', {
    'loteId': loteId,
    'fecha': fecha,
    'metricas': metricas,
    'notas': notas,
    'operation': operation,
  });

  @override
  Future<String> guardarEvento({
    required String clinicId,
    required String loteId,
    required DateTime fecha,
    required String tipo,
    String? subtipo,
    int? animales,
    Map<String, dynamic>? detalle,
    required String operation,
  }) => _registrar('guardarEvento', {
    'loteId': loteId,
    'tipo': tipo,
    'subtipo': subtipo,
    'animales': animales,
    'detalle': detalle,
    'operation': operation,
  });

  @override
  Future<List<SpeciesPurpose>> propositosPorEspecie() async {
    if (fallarCatalogo) throw Exception('sin catálogo');
    return pares;
  }
}

const _paresPorOmision = [
  SpeciesPurpose('bovino', 'carne'),
  SpeciesPurpose('bovino', 'leche'),
  SpeciesPurpose('bovino', 'mixto'),
  SpeciesPurpose('cerdo', 'engorda'),
];

final _lote = FarmBatch(
  id: 'lote-1',
  codigo: 'L-01',
  nombre: 'Corral norte',
  especie: 'bovino',
  proposito: 'leche',
  estado: 'activo',
  cabezas: 40,
  fechaInicio: DateTime(2026, 1, 10),
);

final _loteCerrado = FarmBatch(
  id: 'lote-2',
  codigo: 'L-02',
  nombre: 'Corral viejo',
  especie: 'bovino',
  proposito: 'carne',
  estado: 'cerrado',
  cabezas: 10,
  fechaInicio: DateTime(2025, 1, 10),
);

const _metricas = [
  FarmMetricDef(
    especie: 'bovino',
    clave: 'leche_litros',
    etiqueta: 'Leche producida',
    unidad: 'L',
    minimo: 0,
    maximo: 100000,
  ),
  FarmMetricDef(
    especie: 'bovino',
    clave: 'grasa_pct',
    etiqueta: 'Grasa de la leche',
    unidad: '%',
    minimo: 0,
    maximo: 100,
  ),
  FarmMetricDef(
    especie: 'cerdo',
    clave: 'peso_total_kg',
    etiqueta: 'Peso total del lote',
    unidad: 'kg',
    minimo: 0,
    maximo: 2000000,
  ),
];

/// Monta un botón que abre el formulario y devuelve si guardó.
Future<void> _montar(
  WidgetTester tester,
  Future<bool> Function(BuildContext) abrir, {
  List<bool>? resultados,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              final r = await abrir(context);
              resultados?.add(r);
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

Future<void> _escribir(WidgetTester tester, String etiqueta, String texto) async {
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
  group('captureOperationId', () {
    test('cumple el formato que exige el servidor', () {
      final id = captureOperationId();
      expect(id, matches(RegExp(r'^[a-f0-9]{48}$')));
    });

    test('no se repite', () {
      final vistos = {for (var i = 0; i < 50; i++) captureOperationId()};
      expect(vistos.length, 50);
    });
  });

  group('permisos', () {
    test('auxiliar captura registros pero no da de alta lotes', () {
      const aux = ClinicMembership(
        clinicId: 'c',
        clinicName: 'C',
        userId: 'u',
        role: ClinicRole.auxiliar,
      );
      expect(puedeCapturarProduccion(aux), isTrue);
      expect(puedeGestionarLotes(aux), isFalse);
    });

    test('admin y MVZ pueden todo', () {
      for (final rol in [ClinicRole.admin, ClinicRole.mvz]) {
        final m = ClinicMembership(
          clinicId: 'c',
          clinicName: 'C',
          userId: 'u',
          role: rol,
        );
        expect(puedeCapturarProduccion(m), isTrue);
        expect(puedeGestionarLotes(m), isTrue);
      }
    });

    test('recepción no captura nada, y sin sesión tampoco', () {
      const rec = ClinicMembership(
        clinicId: 'c',
        clinicName: 'C',
        userId: 'u',
        role: ClinicRole.recepcion,
      );
      expect(puedeCapturarProduccion(rec), isFalse);
      expect(puedeGestionarLotes(rec), isFalse);
      expect(puedeCapturarProduccion(null), isFalse);
      expect(puedeGestionarLotes(null), isFalse);
    });
  });

  group('traducirErrorProduccion', () {
    test('explica el rechazo del catálogo de métricas', () {
      final e = traducirErrorProduccion(Exception('metricas_invalidas'));
      expect(e.codigo, 'metricas_invalidas');
      expect(e.mensaje, contains('rango'));
    });

    test('distingue el permiso de lote del de registro', () {
      expect(
        traducirErrorProduccion(Exception('admin_or_mvz_required')).mensaje,
        contains('administrador'),
      );
      expect(
        traducirErrorProduccion(Exception('produccion_write_required')).mensaje,
        contains('auxiliar'),
      );
    });

    test('un error desconocido no deja a nadie sin explicación', () {
      final e = traducirErrorProduccion(Exception('vaya_sorpresa'));
      expect(e.codigo, 'desconocido');
      expect(e.mensaje, isNotEmpty);
    });

    test('elige el código más específico cuando varios encajan', () {
      // 'subtipo_too_long' contiene a 'subtipo' y ambos podrian casar; debe
      // ganar el largo, que es el que de verdad lanzo el servidor.
      final e = traducirErrorProduccion(Exception('subtipo_too_long'));
      expect(e.codigo, 'subtipo_too_long');
    });
  });

  group('ProductionCaptureBar', () {
    testWidgets('al auxiliar no le ofrece «Nuevo lote»', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductionCaptureBar(
              member: const ClinicMembership(
                clinicId: 'c',
                clinicName: 'C',
                userId: 'u',
                role: ClinicRole.auxiliar,
              ),
              onNuevoLote: () {},
              onRegistro: () {},
              onEvento: () {},
            ),
          ),
        ),
      );
      expect(find.text('Nuevo lote'), findsNothing);
      expect(find.text('Registro productivo'), findsOneWidget);
      expect(find.text('Evento de manejo'), findsOneWidget);
    });

    testWidgets('a recepción no le dibuja ningún botón', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductionCaptureBar(
              member: const ClinicMembership(
                clinicId: 'c',
                clinicName: 'C',
                userId: 'u',
                role: ClinicRole.recepcion,
              ),
              onNuevoLote: () {},
              onRegistro: () {},
              onEvento: () {},
            ),
          ),
        ),
      );
      expect(find.byType(FilledButton), findsNothing);
    });
  });

  group('capturarRegistro', () {
    testWidgets('sin lotes abiertos nombra el paso que falta', (tester) async {
      final repo = _FakeWrite();
      await _montar(
        tester,
        (c) => capturarRegistro(
          c,
          clinicId: 'c1',
          repo: repo,
          lotes: [_loteCerrado],
          metricas: _metricas,
        ),
      );
      expect(find.textContaining('da de alta un lote activo'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
    });

    testWidgets('genera un campo por métrica del catálogo de la especie', (
      tester,
    ) async {
      final repo = _FakeWrite();
      await _montar(
        tester,
        (c) => capturarRegistro(
          c,
          clinicId: 'c1',
          repo: repo,
          lotes: [_lote],
          metricas: _metricas,
        ),
      );
      // Las dos de bovino si, la de cerdo no.
      expect(find.text('Leche producida'), findsOneWidget);
      expect(find.text('Grasa de la leche'), findsOneWidget);
      expect(find.text('Peso total del lote'), findsNothing);
    });

    testWidgets('enseña el rango que el servidor va a exigir', (tester) async {
      final repo = _FakeWrite();
      await _montar(
        tester,
        (c) => capturarRegistro(
          c,
          clinicId: 'c1',
          repo: repo,
          lotes: [_lote],
          metricas: _metricas,
        ),
      );
      expect(find.textContaining('Rango admitido'), findsWidgets);
    });

    testWidgets('rechaza un valor fuera de rango sin ir al servidor', (
      tester,
    ) async {
      final repo = _FakeWrite();
      await _montar(
        tester,
        (c) => capturarRegistro(
          c,
          clinicId: 'c1',
          repo: repo,
          lotes: [_lote],
          metricas: _metricas,
        ),
      );
      await _escribir(tester, 'Grasa de la leche', '150');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No puede ser mayor'), findsOneWidget);
      expect(repo.llamadas, isEmpty);
    });

    testWidgets('no guarda si no se capturó ninguna métrica', (tester) async {
      final repo = _FakeWrite();
      await _montar(
        tester,
        (c) => capturarRegistro(
          c,
          clinicId: 'c1',
          repo: repo,
          lotes: [_lote],
          metricas: _metricas,
        ),
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('al menos una métrica'), findsOneWidget);
    });

    testWidgets('acepta coma decimal y manda solo lo capturado', (
      tester,
    ) async {
      final repo = _FakeWrite();
      final res = <bool>[];
      await _montar(
        tester,
        (c) => capturarRegistro(
          c,
          clinicId: 'c1',
          repo: repo,
          lotes: [_lote],
          metricas: _metricas,
        ),
        resultados: res,
      );
      await _escribir(tester, 'Leche producida', '412,5');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(repo.llamadas, ['guardarRegistro']);
      final metricas =
          repo.argumentos.single['metricas']! as Map<String, double>;
      expect(metricas, {'leche_litros': 412.5});
      // La métrica vacía no viaja: el servidor no debe recibir nulos.
      expect(metricas.containsKey('grasa_pct'), isFalse);
      expect(res, [true]);
    });

    testWidgets('el reintento reusa la misma operación', (tester) async {
      final repo = _FakeWrite(fallarVeces: 1);
      await _montar(
        tester,
        (c) => capturarRegistro(
          c,
          clinicId: 'c1',
          repo: repo,
          lotes: [_lote],
          metricas: _metricas,
        ),
      );
      await _escribir(tester, 'Leche producida', '10');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No hay conexión'), findsOneWidget);

      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(repo.operaciones.length, 2);
      expect(repo.operaciones[0], repo.operaciones[1]);
    });
  });

  group('capturarEvento', () {
    testWidgets('sin lotes nombra el paso que falta', (tester) async {
      final repo = _FakeWrite();
      await _montar(
        tester,
        (c) => capturarEvento(c, clinicId: 'c1', repo: repo, lotes: const []),
      );
      expect(find.textContaining('da de alta un lote'), findsOneWidget);
    });

    testWidgets('un evento sanitario exige decir de qué se trata', (
      tester,
    ) async {
      final repo = _FakeWrite();
      await _montar(
        tester,
        (c) => capturarEvento(c, clinicId: 'c1', repo: repo, lotes: [_lote]),
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Hace falta este dato'), findsOneWidget);
      expect(repo.llamadas, isEmpty);
    });

    testWidgets('guarda el detalle como objeto y el subtipo sugerido', (
      tester,
    ) async {
      final repo = _FakeWrite();
      await _montar(
        tester,
        (c) => capturarEvento(c, clinicId: 'c1', repo: repo, lotes: [_lote]),
      );
      await tester.tap(find.text('Vacunación'));
      await tester.pump();
      await _escribir(tester, 'Detalle', 'Lote completo');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      final args = repo.argumentos.single;
      expect(args['tipo'], 'sanitario');
      expect(args['subtipo'], 'Vacunación');
      expect(args['detalle'], {'nota': 'Lote completo'});
      expect(args['loteId'], 'lote-1');
    });
  });

  group('capturarLote', () {
    testWidgets('solo ofrece propósitos válidos para la especie', (
      tester,
    ) async {
      final repo = _FakeWrite();
      await _montar(
        tester,
        (c) => capturarLote(
          c,
          clinicId: 'c1',
          repo: repo,
          especiesPermitidas: const ['bovino'],
        ),
      );
      await tester.tap(find.text('Especie *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bovino').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Propósito *'));
      await tester.pumpAndSettle();
      // Los tres de bovino, nunca «Engorda», que es de cerdo.
      expect(find.text('Engorda'), findsNothing);
      expect(find.text('Leche'), findsWidgets);
      expect(find.text('Carne'), findsWidgets);
      expect(find.text('Mixto'), findsWidgets);
    });

    testWidgets('la especie se acota a la pestaña del panel', (tester) async {
      final repo = _FakeWrite();
      await _montar(
        tester,
        (c) => capturarLote(
          c,
          clinicId: 'c1',
          repo: repo,
          especiesPermitidas: const ['cerdo'],
        ),
      );
      await tester.tap(find.text('Especie *'));
      await tester.pumpAndSettle();
      expect(find.text('Bovino'), findsNothing);
      expect(find.text('Cerdo').last, findsOneWidget);
    });

    testWidgets('si el catálogo no carga lo dice, no abre un formulario roto', (
      tester,
    ) async {
      final repo = _FakeWrite()..fallarCatalogo = true;
      await _montar(
        tester,
        (c) => capturarLote(
          c,
          clinicId: 'c1',
          repo: repo,
          especiesPermitidas: const ['bovino'],
        ),
      );
      expect(find.textContaining('catálogo'), findsWidgets);
      expect(find.text('Crear lote'), findsNothing);
    });

    testWidgets('manda las cabezas como texto, que es lo que el RPC valida', (
      tester,
    ) async {
      final repo = _FakeWrite();
      await _montar(
        tester,
        (c) => capturarLote(
          c,
          clinicId: 'c1',
          repo: repo,
          especiesPermitidas: const ['bovino'],
        ),
      );
      await _escribir(tester, 'Código del lote *', 'L-99');
      await _escribir(tester, 'Nombre *', 'Corral sur');
      await _escribir(tester, 'Cabezas *', '120');
      await tester.tap(find.text('Especie *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bovino').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Propósito *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Carne').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crear lote'));
      await tester.pumpAndSettle();

      final data = repo.argumentos.single['data']! as Map<String, dynamic>;
      expect(data['codigo'], 'L-99');
      expect(data['cabezas'], '120');
      expect(data['especie'], 'bovino');
      expect(data['proposito'], 'carne');
      expect(data['estado'], 'activo');
      // Los opcionales vacíos no viajan.
      expect(data.containsKey('identificador_hato'), isFalse);
      expect(data.containsKey('sistema'), isFalse);
      expect(data.containsKey('fecha_fin'), isFalse);
      // La fecha de inicio va como día de calendario, sin hora.
      expect(data['fecha_inicio'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    });

    testWidgets('al editar no deja cambiar la especie', (tester) async {
      final repo = _FakeWrite();
      await _montar(
        tester,
        (c) => capturarLote(
          c,
          clinicId: 'c1',
          repo: repo,
          especiesPermitidas: const ['bovino'],
          inicial: _lote,
        ),
      );
      expect(find.text('Editar lote'), findsOneWidget);
      final campo = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>).first,
      );
      expect(campo.onChanged, isNull);
    });

    testWidgets('al editar manda el id, para que sea actualización', (
      tester,
    ) async {
      final repo = _FakeWrite();
      await _montar(
        tester,
        (c) => capturarLote(
          c,
          clinicId: 'c1',
          repo: repo,
          especiesPermitidas: const ['bovino'],
          inicial: _lote,
        ),
      );
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      final data = repo.argumentos.single['data']! as Map<String, dynamic>;
      expect(data['id'], 'lote-1');
      expect(data['codigo'], 'L-01');
    });
  });

  group('lectura de números', () {
    test('acepta coma y punto, y rechaza lo que no es número', () {
      expect(readDecimal('36,5'), 36.5);
      expect(readDecimal('36.5'), 36.5);
      expect(readDecimal(' 7 '), 7);
      expect(readDecimal(''), isNull);
      expect(readDecimal(null), isNull);
      expect(readDecimal('abc'), isNull);
    });

    test('emptyToNull no deja cadenas en blanco', () {
      expect(emptyToNull('  '), isNull);
      expect(emptyToNull(' hola '), 'hola');
    });
  });

  group('catálogos', () {
    test('los tipos de evento son los que el RPC admite', () {
      expect(tiposDeEvento.keys.toSet(), {
        'sanitario',
        'mortalidad',
        'pesaje',
        'traslado',
        'sacrificio',
        'otro',
      });
    });

    test('los sistemas son los del CHECK de la tabla', () {
      expect(sistemasDeProduccion.keys.toSet(), {
        'piso',
        'jaula',
        'corral',
        'pastoreo',
        'estanque',
        'colmena',
        'otro',
      });
    });

    test('todas las especies del catálogo tienen nombre legible', () {
      for (final codes in codigosDeEspecie.values) {
        for (final c in codes) {
          expect(nombresDeEspecie.containsKey(c), isTrue, reason: c);
        }
      }
    });
  });
}

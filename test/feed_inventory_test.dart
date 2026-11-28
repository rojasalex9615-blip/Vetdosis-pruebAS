import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';
import 'package:vetdosis_pro/modules/production/domain/feed_inventory.dart';
import 'package:vetdosis_pro/modules/production/domain/feed_write_repository.dart';
import 'package:vetdosis_pro/modules/production/presentation/feed_capture_forms.dart';
import 'package:vetdosis_pro/modules/production/presentation/feed_inventory_panel.dart';

class _FakeRead implements FeedInventoryRepository {
  _FakeRead(this.snapshot, {this.fallar = false});
  final FeedSnapshot snapshot;
  final bool fallar;
  int llamadas = 0;
  @override
  Future<FeedSnapshot> load(String clinicId) async {
    llamadas++;
    if (fallar) throw Exception('sin red');
    return snapshot;
  }
}

class _FakeWrite implements FeedWriteRepository {
  final llamadas = <String>[];
  final argumentos = <Map<String, Object?>>[];

  Future<String> _registrar(String metodo, Map<String, Object?> args) async {
    llamadas.add(metodo);
    argumentos.add(args);
    return 'id-${llamadas.length}';
  }

  @override
  Future<String> guardarAlimento({
    required String clinicId,
    required Map<String, dynamic> data,
    required String operation,
  }) => _registrar('guardarAlimento', {
    'data': data,
    'operation': operation,
  });

  @override
  Future<String> guardarSilo({
    required String clinicId,
    required Map<String, dynamic> data,
    required String operation,
  }) => _registrar('guardarSilo', {'data': data, 'operation': operation});

  @override
  Future<String> moverAlimento({
    required String clinicId,
    required String alimentoId,
    String? siloId,
    String? loteId,
    required DateTime fecha,
    required String tipo,
    required double kg,
    double? costoKg,
    String? proveedor,
    String? referencia,
    String? nota,
    required String operation,
  }) => _registrar('moverAlimento', {
    'alimentoId': alimentoId,
    'siloId': siloId,
    'loteId': loteId,
    'fecha': fecha,
    'tipo': tipo,
    'kg': kg,
    'costoKg': costoKg,
    'operation': operation,
  });
}

const _admin = ClinicMembership(
  clinicId: 'c1',
  clinicName: 'C',
  userId: 'u',
  role: ClinicRole.admin,
);
const _auxiliar = ClinicMembership(
  clinicId: 'c1',
  clinicName: 'C',
  userId: 'u',
  role: ClinicRole.auxiliar,
);
const _recepcion = ClinicMembership(
  clinicId: 'c1',
  clinicName: 'C',
  userId: 'u',
  role: ClinicRole.recepcion,
);

FeedItem _a({
  String id = 'a1',
  String nombre = 'Concentrado',
  FeedKind tipo = FeedKind.concentrado,
  FeedUnit unidad = FeedUnit.kg,
  double kgPorUnidad = 1,
  double? materiaSeca,
  double? proteina,
  bool activo = true,
}) => FeedItem(
  id: id,
  nombre: nombre,
  tipo: tipo,
  unidad: unidad,
  kgPorUnidad: kgPorUnidad,
  materiaSecaPct: materiaSeca,
  proteinaPct: proteina,
  activo: activo,
  version: 1,
);

FeedStore _s({
  String id = 's1',
  String nombre = 'Silo 1',
  double? capacidad = 25000,
  String? alimentoId,
  bool activo = true,
}) => FeedStore(
  id: id,
  nombre: nombre,
  tipo: StoreKind.silo,
  capacidadKg: capacidad,
  alimentoId: alimentoId,
  activo: activo,
  version: 1,
);

FeedStock _x({
  String alimentoId = 'a1',
  String? siloId = 's1',
  double kg = 10000,
  double valor = 75000,
  double salida30d = 0,
  DateTime? primeraSalida,
}) => FeedStock(
  alimentoId: alimentoId,
  siloId: siloId,
  kg: kg,
  valor: valor,
  kgSalida30d: salida30d,
  primeraSalida30d: primeraSalida,
);

BatchEfficiency _l({
  String loteId = 'l1',
  String codigo = 'L-1',
  String nombre = 'Alta producción',
  String especie = 'bovino',
  String proposito = 'leche',
  int cabezas = 50,
  String estado = 'activo',
  double kgAlimento = 0,
  double? kgMateriaSeca,
  double costoAlimento = 0,
  double lecheL = 0,
  double huevos = 0,
  double mielKg = 0,
  double? pesoInicial,
  double? pesoFinal,
}) => BatchEfficiency(
  loteId: loteId,
  codigo: codigo,
  nombre: nombre,
  especie: especie,
  proposito: proposito,
  cabezas: cabezas,
  estado: estado,
  kgAlimento: kgAlimento,
  kgMateriaSeca: kgMateriaSeca,
  costoAlimento: costoAlimento,
  lecheL: lecheL,
  huevos: huevos,
  mielKg: mielKg,
  diasConRegistro: 10,
  pesoInicialKg: pesoInicial,
  pesoFinalKg: pesoFinal,
);

Future<void> _montar(
  WidgetTester tester, {
  required FeedInventoryRepository? repo,
  FeedWriteRepository? write,
  ClinicMembership? member = _admin,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: FeedInventoryPanel(
            member: member,
            repository: repo,
            writeRepository: write,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Unidades y conversión a kilos', () {
    test('un saco se convierte con el peso que se capturó, no con el típico', () {
      final a = _a(unidad: FeedUnit.saco, kgPorUnidad: 42);
      expect(a.aKilos(20), 840);
      expect(a.seCompraEnKilos, isFalse);
    });

    test('en kilos no hay conversión', () {
      expect(_a().aKilos(500), 500);
      expect(_a().seCompraEnKilos, isTrue);
    });

    test('un código desconocido no revienta, cae en otro', () {
      expect(FeedKind.desdeCodigo('marciano'), FeedKind.otro);
      expect(FeedUnit.desdeCodigo(null), FeedUnit.kg);
      expect(FeedMoveKind.desdeCodigo('x'), FeedMoveKind.ajuste);
      expect(StoreKind.desdeCodigo('silo'), StoreKind.silo);
    });

    test('read respeta nulos y rellena lo que falta', () {
      final a = FeedItem.read({
        'id': 'a9',
        'nombre': 'Ensilado',
        'tipo': 'ensilado',
        'unidad': 'ton',
        'kg_por_unidad': 1000,
        'materia_seca_pct': null,
        'activo': true,
        'notas': '   ',
        'version': 3,
      });
      expect(a.materiaSecaPct, isNull);
      expect(a.notas, isNull);
      expect(a.kgPorUnidad, 1000);
      expect(a.version, 3);
    });
  });

  group('Existencias', () {
    final hoy = DateTime(2026, 11, 23);

    test('el consumo diario se divide entre los días observados, no entre 30', () {
      // 1000 kg salieron a lo largo de 5 días (del 19 al 23).
      final e = _x(salida30d: 1000, primeraSalida: DateTime(2026, 11, 19));
      expect(e.kgPorDia(hoy), closeTo(200, 0.01));
    });

    test('sin salidas no se inventa un ritmo ni unos días de existencia', () {
      final e = _x();
      expect(e.kgPorDia(hoy), isNull);
      expect(e.diasQueAguanta(hoy), isNull);
    });

    test('los días que aguanta salen de lo que hay entre el ritmo', () {
      final e = _x(
        kg: 2000,
        salida30d: 1000,
        primeraSalida: DateTime(2026, 11, 19),
      );
      expect(e.diasQueAguanta(hoy), closeTo(10, 0.01));
    });

    test('una existencia negativa se enseña, no se recorta a cero', () {
      final e = _x(kg: -300, valor: -1500);
      expect(e.enNumerosRojos, isTrue);
      expect(e.costoPromedioKg, isNull);
    });

    test('el costo promedio sale del valor entre los kilos', () {
      expect(_x(kg: 10000, valor: 78000).costoPromedioKg, closeTo(7.8, 0.001));
    });
  });

  group('Conversión alimenticia', () {
    test('leche con materia seca se da en kg MS por litro', () {
      final e = _l(kgAlimento: 1200, kgMateriaSeca: 1056, lecheL: 800);
      final c = e.conversion;
      expect(c.hayDato, isTrue);
      expect(c.valor, closeTo(1.32, 0.001));
      expect(c.unidad, 'kg MS / L');
    });

    test('leche sin materia seca lo dice en vez de cambiar la etiqueta', () {
      final e = _l(kgAlimento: 1200, lecheL: 800);
      final c = e.conversion;
      expect(c.hayDato, isTrue);
      expect(c.valor, closeTo(1.5, 0.001));
      expect(c.unidad, 'kg / L');
      expect(c.detalle, contains('Sin materia seca'));
    });

    test('postura se da en gramos por huevo', () {
      final e = _l(proposito: 'postura', kgAlimento: 100, huevos: 1000);
      final c = e.conversion;
      expect(c.unidad, 'g / huevo');
      expect(c.valor, closeTo(100, 0.001));
    });

    test('engorda usa lo que engordó, no el peso final', () {
      final e = _l(
        proposito: 'engorda',
        kgAlimento: 300,
        pesoInicial: 500,
        pesoFinal: 600,
      );
      expect(e.pesoGanadoKg, 100);
      expect(e.conversion.valor, closeTo(3, 0.001));
      expect(e.conversion.unidad, 'kg / kg');
    });

    test('sin alimento cargado no hay conversión, hay motivo', () {
      final c = _l(lecheL: 500).conversion;
      expect(c.hayDato, isFalse);
      expect(c.motivo, contains('alimento'));
    });

    test('sin producción tampoco, y lo dice', () {
      final c = _l(kgAlimento: 1000).conversion;
      expect(c.hayDato, isFalse);
      expect(c.motivo, contains('producción'));
    });

    test('una pesada que no subió no se cuenta como ganancia', () {
      expect(_l(pesoInicial: 600, pesoFinal: 580).pesoGanadoKg, isNull);
      expect(_l(pesoInicial: 600).pesoGanadoKg, isNull);
    });

    test('la abeja se mide en miel aunque su propósito sea mixto', () {
      final e = _l(
        especie: 'abeja',
        proposito: 'mixto',
        kgAlimento: 20,
        mielKg: 40,
      );
      expect(e.produccion, 40);
      expect(e.unidadProducida, 'kg de miel');
    });
  });

  group('Costo por unidad producida', () {
    test('sale del costo del alimento entre lo producido', () {
      final e = _l(kgAlimento: 1200, costoAlimento: 9400, lecheL: 1000);
      final c = e.costoPorUnidad;
      expect(c.hayDato, isTrue);
      expect(c.valor, closeTo(9.4, 0.001));
      expect(c.unidad, r'$ / L');
    });

    test('sin precio capturado se dice qué falta', () {
      final c = _l(kgAlimento: 1200, lecheL: 1000).costoPorUnidad;
      expect(c.hayDato, isFalse);
      expect(c.motivo, contains('precio'));
    });
  });

  group('Resumen del inventario', () {
    final hoy = DateTime(2026, 11, 23);

    FeedSnapshot armar() => FeedSnapshot(
      alimentos: [_a(), _a(id: 'a2', nombre: 'Ensilado', activo: false)],
      silos: [_s(), _s(id: 's2', nombre: 'Silo 2', capacidad: 10000)],
      existencias: [
        _x(kg: 8000, valor: 60000),
        _x(siloId: 's2', kg: 1000, valor: 7500, salida30d: 900,
            primeraSalida: DateTime(2026, 11, 21)),
        _x(alimentoId: 'a2', siloId: null, kg: -200, valor: -240),
      ],
      eficiencias: const [],
      movimientos: const [],
    );

    test('los kilos de un alimento suman todos sus silos', () {
      expect(armar().kgDeAlimento('a1'), 9000);
      expect(armar().kgEnSilo('s2'), 1000);
    });

    test('el valor total suma todas las líneas, negativas incluidas', () {
      expect(armar().valorTotal, 67260);
    });

    test('solo se ofrecen los activos al capturar', () {
      expect(armar().alimentosActivos.length, 1);
      expect(armar().silosActivos.length, 2);
    });

    test('se avisa del silo que se vacía antes', () {
      // El silo 2 gasta 300 kg/día y tiene 1000: aguanta poco más de 3 días.
      final urgentes = armar().silosPorAgotarse(hoy);
      expect(urgentes.length, 1);
      expect(urgentes.first.id, 's2');
    });

    test('las existencias en rojo se listan aparte', () {
      expect(armar().existenciasNegativas.length, 1);
      expect(armar().existenciasNegativas.first.alimentoId, 'a2');
    });

    test('un id desconocido no revienta el nombre', () {
      expect(armar().nombreDeAlimento('zzz'), 'Sin alimento');
      expect(armar().nombreDeSilo(null), 'Sin silo');
    });
  });

  group('Permisos', () {
    test('el catálogo lo lleva administrador o MVZ', () {
      expect(puedeGestionarCatalogoAlimento(_admin), isTrue);
      expect(puedeGestionarCatalogoAlimento(_auxiliar), isFalse);
      expect(puedeGestionarCatalogoAlimento(null), isFalse);
    });

    test('mover alimento también lo puede el auxiliar, que es quien reparte', () {
      expect(puedeMoverAlimento(_auxiliar), isTrue);
      expect(puedeMoverAlimento(_admin), isTrue);
      expect(puedeMoverAlimento(_recepcion), isFalse);
    });
  });

  group('Traducción de errores', () {
    test('gana la coincidencia más larga', () {
      final e = traducirErrorAlimento(
        Exception('PostgrestException: invalid_kg_por_unidad'),
      );
      expect(e.codigo, 'invalid_kg_por_unidad');
      expect(e.mensaje, contains('kilos por unidad'));
    });

    test('un lote cerrado se explica con su salida', () {
      final e = traducirErrorAlimento(Exception('lote_closed'));
      expect(e.mensaje, contains('cerrado'));
    });

    test('lo desconocido no se queda mudo', () {
      final e = traducirErrorAlimento(Exception('boom'));
      expect(e.codigo, 'desconocido');
      expect(e.mensaje, contains('conexión'));
    });
  });

  group('Panel', () {
    testWidgets('sin repositorio enseña para qué sirve', (tester) async {
      await _montar(tester, repo: null);
      expect(find.textContaining('Inventario de alimento'), findsWidgets);
      expect(find.textContaining('conversión alimenticia'), findsOneWidget);
    });

    testWidgets('un fallo de red se distingue de no tener nada', (
      tester,
    ) async {
      final repo = _FakeRead(const FeedSnapshot.vacio(), fallar: true);
      await _montar(tester, repo: repo);
      expect(find.text('No se pudo leer el alimento'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(repo.llamadas, 2);
    });

    testWidgets('el silo enseña cuánto aguanta', (tester) async {
      final repo = _FakeRead(
        FeedSnapshot(
          alimentos: [_a()],
          silos: [_s(capacidad: 10000)],
          existencias: [
            _x(
              kg: 1000,
              valor: 7500,
              salida30d: 900,
              primeraSalida: DateTime.now().subtract(
                const Duration(days: 2),
              ),
            ),
          ],
          eficiencias: const [],
          movimientos: const [],
        ),
      );
      await _montar(tester, repo: repo);
      expect(find.text('Silo 1'), findsOneWidget);
      expect(find.textContaining('Aguanta'), findsOneWidget);
    });

    testWidgets('una existencia negativa se explica, no se esconde', (
      tester,
    ) async {
      final repo = _FakeRead(
        FeedSnapshot(
          alimentos: [_a()],
          silos: [_s()],
          existencias: [_x(kg: -300, valor: -2250)],
          eficiencias: const [],
          movimientos: const [],
        ),
      );
      await _montar(tester, repo: repo);
      expect(find.text('Existencias en negativo'), findsOneWidget);
      expect(find.textContaining('falta registrar una compra'), findsOneWidget);
    });

    testWidgets('cuando no hay dato se enseña el motivo y no un cero', (
      tester,
    ) async {
      final repo = _FakeRead(
        FeedSnapshot(
          alimentos: [_a()],
          silos: const [],
          existencias: const [],
          eficiencias: [_l(kgAlimento: 1200, lecheL: 0)],
          movimientos: const [],
        ),
      );
      await _montar(tester, repo: repo);
      expect(find.text('Sin dato'), findsWidgets);
      expect(find.textContaining('todavía no tiene producción'), findsWidgets);
    });

    testWidgets('quien no puede capturar no ve los botones', (tester) async {
      final repo = _FakeRead(
        FeedSnapshot(
          alimentos: [_a()],
          silos: [_s()],
          existencias: [_x()],
          eficiencias: const [],
          movimientos: const [],
        ),
      );
      await _montar(tester, repo: repo, write: _FakeWrite(), member: _recepcion);
      expect(find.text('Entró alimento'), findsNothing);
      expect(find.text('Nuevo alimento'), findsNothing);
    });

    testWidgets('el auxiliar mueve alimento pero no toca el catálogo', (
      tester,
    ) async {
      final repo = _FakeRead(
        FeedSnapshot(
          alimentos: [_a()],
          silos: [_s()],
          existencias: [_x()],
          eficiencias: const [],
          movimientos: const [],
        ),
      );
      await _montar(tester, repo: repo, write: _FakeWrite(), member: _auxiliar);
      expect(find.text('Entró alimento'), findsOneWidget);
      expect(find.text('Nuevo alimento'), findsNothing);
    });
  });

  group('Formulario de movimiento', () {
    testWidgets('sin alimentos dados de alta se dice qué falta primero', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => capturarMovimiento(
                  context,
                  clinicId: 'c1',
                  repo: _FakeWrite(),
                  datos: const FeedSnapshot.vacio(),
                  tipoInicial: FeedMoveKind.compra,
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Primero da de alta un alimento'),
          findsOneWidget);
    });

    testWidgets('el consumo sin lotes activos no deja seguir', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => capturarMovimiento(
                  context,
                  clinicId: 'c1',
                  repo: _FakeWrite(),
                  datos: FeedSnapshot(
                    alimentos: [_a()],
                    silos: const [],
                    existencias: const [],
                    eficiencias: [_l(estado: 'cerrado')],
                    movimientos: const [],
                  ),
                  tipoInicial: FeedMoveKind.consumo,
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Primero da de alta un lote activo'),
          findsOneWidget);
    });
  });
}

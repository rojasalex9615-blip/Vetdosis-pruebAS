import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/auth/domain/clinic_membership.dart';
import 'package:vetdosis_pro/modules/exotics/domain/exotic_dashboard.dart';
import 'package:vetdosis_pro/modules/exotics/domain/exotic_write_repository.dart';
import 'package:vetdosis_pro/modules/exotics/presentation/exotic_capture_forms.dart';
import 'package:vetdosis_pro/modules/exotics/presentation/exotics_dashboard.dart';

/// Repositorio de lectura de mentira.
class _FakeRead implements ExoticDashboardRepository {
  _FakeRead(this.snapshot);
  final ExoticSnapshot snapshot;
  int llamadas = 0;
  @override
  Future<ExoticSnapshot> load(String clinicId) async {
    llamadas++;
    return snapshot;
  }
}

/// Repositorio de escritura que apunta lo que le piden y puede fallar a
/// voluntad, para comprobar el reintento sin duplicado.
class _FakeWrite implements ExoticWriteRepository {
  _FakeWrite({this.fallarVeces = 0});

  /// Cuántas de las primeras llamadas deben fallar antes de funcionar.
  int fallarVeces;

  final llamadas = <String>[];
  final operaciones = <String>[];
  final argumentos = <Map<String, Object?>>[];

  Future<String> _registrar(String metodo, Map<String, Object?> args) async {
    llamadas.add(metodo);
    operaciones.add('${args['operation']}');
    argumentos.add(args);
    if (fallarVeces > 0) {
      fallarVeces--;
      throw const ExoticWriteException('sin_red', 'No hay conexión.');
    }
    return 'id-${llamadas.length}';
  }

  @override
  Future<String> guardarRecinto({
    required String clinicId,
    String? id,
    required String nombre,
    required String tipo,
    String? especie,
    required Map<String, double?> rangos,
    String? notas,
    required String operation,
  }) => _registrar('guardarRecinto', {
    'nombre': nombre,
    'tipo': tipo,
    'rangos': rangos,
    'operation': operation,
  });

  @override
  Future<String> registrarLectura({
    required String clinicId,
    required String enclosureId,
    DateTime? medidoEn,
    required Map<String, double?> valores,
    String? nota,
    required String operation,
  }) => _registrar('registrarLectura', {
    'enclosureId': enclosureId,
    'valores': valores,
    'operation': operation,
  });

  @override
  Future<String> registrarToma({
    required String clinicId,
    required String patientId,
    DateTime? ofrecidoEn,
    required String alimento,
    required bool aceptado,
    double? cantidadG,
    String? nota,
    required String operation,
  }) => _registrar('registrarToma', {
    'patientId': patientId,
    'alimento': alimento,
    'aceptado': aceptado,
    'cantidadG': cantidadG,
    'operation': operation,
  });

  @override
  Future<String> registrarEvento({
    required String clinicId,
    required String patientId,
    required String tipo,
    DateTime? ocurrioEn,
    String? detalle,
    required String operation,
  }) => _registrar('registrarEvento', {
    'patientId': patientId,
    'tipo': tipo,
    'operation': operation,
  });

  @override
  Future<String> guardarMarcaje({
    required String clinicId,
    required String patientId,
    required String tipo,
    required String codigo,
    DateTime? colocadoEl,
    String? ubicacion,
    required String operation,
  }) => _registrar('guardarMarcaje', {
    'patientId': patientId,
    'tipo': tipo,
    'codigo': codigo,
    'operation': operation,
  });

  @override
  Future<String> guardarEstatusLegal({
    required String clinicId,
    String? id,
    required String patientId,
    required String regimen,
    String? apendice,
    String? numero,
    DateTime? desde,
    DateTime? hasta,
    String? procedencia,
    required bool documentada,
    String? notas,
    required String operation,
  }) => _registrar('guardarEstatusLegal', {
    'patientId': patientId,
    'regimen': regimen,
    'apendice': apendice,
    'operation': operation,
  });

  @override
  Future<String> guardarNidada({
    required String clinicId,
    String? id,
    String? enclosureId,
    String? patientId,
    required String especie,
    required DateTime puesta,
    required int huevos,
    int? fertiles,
    double? temp,
    double? humedad,
    int? dias,
    required String estado,
    String? notas,
    required String operation,
  }) => _registrar('guardarNidada', {
    'especie': especie,
    'huevos': huevos,
    'fertiles': fertiles,
    'dias': dias,
    'operation': operation,
  });

  @override
  Future<String> fijarCuarentena({
    required String clinicId,
    required String stayId,
    required int dias,
    String? motivo,
    required String operation,
  }) => _registrar('fijarCuarentena', {
    'stayId': stayId,
    'dias': dias,
    'operation': operation,
  });
}

ClinicMembership _miembroCon(ClinicRole rol) => ClinicMembership(
  clinicId: 'c1',
  clinicName: 'Clínica de prueba',
  userId: 'u1',
  role: rol,
);

/// El taxón no importa en estas pruebas: lo que se ejercita es la captura.
const _tortuga = ExoticSpecimen(
  id: 'p1',
  nombre: 'Kiwi',
  especie: 'Tortuga de orejas rojas',
  taxon: null,
);

const _terrario = ExoticEnclosure(
  id: 'r1',
  nombre: 'Terrario 1',
  tipo: 'terrario',
  tempCalienteMin: 38,
  tempCalienteMax: 42,
  humedadMin: 30,
  humedadMax: 40,
);

const _acuario = ExoticEnclosure(
  id: 'r2',
  nombre: 'Acuario marino',
  tipo: 'acuario',
  phMin: 8,
  phMax: 8.4,
  amoniacoMax: 0.02,
);

Future<void> _montar(
  WidgetTester tester, {
  required ExoticSnapshot datos,
  ExoticWriteRepository? escritura,
  ClinicRole rol = ClinicRole.mvz,
}) async {
  // La ventana de prueba por omision mide 800x600. Estas hojas son mas
  // altas: su ListView ni siquiera construye el boton de guardar, y un tap
  // sobre algo que quedo fuera de pantalla no acierta. Se le da alto de
  // telefono real conservando el ancho, que es el que cuidan las otras
  // pruebas.
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ExoticsDashboard(
            member: _miembroCon(rol),
            repository: _FakeRead(datos),
            writeRepository: escritura,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('traducción de errores de escritura', () {
    test('convierte el código seco en una frase entendible', () {
      final e = traducirErrorExotico(
        Exception('PostgrestException: codigo_duplicado'),
      );
      expect(e.codigo, 'codigo_duplicado');
      expect(e.mensaje, contains('ya está activo en otro ejemplar'));
    });

    test('el permiso legal se distingue del permiso general', () {
      // Son dos reglas distintas en la base y deben leerse distinto: a un
      // auxiliar hay que decirle por que ESTE registro no, si los demas si.
      final general = traducirErrorExotico(Exception('exotic_write_required'));
      final legal = traducirErrorExotico(
        Exception('exotic_legal_write_required'),
      );
      expect(general.mensaje, isNot(legal.mensaje));
      expect(legal.mensaje, contains('administrador o un MVZ'));
    });

    test('un error desconocido no enseña el volcado de Postgres', () {
      // Lo que no se reconoce no se reenvia crudo: puede traer nombres de
      // tablas y no le sirve a quien esta capturando.
      final e = traducirErrorExotico(
        Exception('relation "private.foo" does not exist'),
      );
      expect(e.codigo, 'desconocido');
      expect(e.mensaje, isNot(contains('private.foo')));
      expect(e.mensaje, contains('No se pudo guardar'));
    });
  });

  group('quién puede capturar', () {
    test('admin, MVZ y auxiliar registran; recepción no', () {
      expect(puedeCapturarExoticos(_miembroCon(ClinicRole.admin)), isTrue);
      expect(puedeCapturarExoticos(_miembroCon(ClinicRole.mvz)), isTrue);
      expect(puedeCapturarExoticos(_miembroCon(ClinicRole.auxiliar)), isTrue);
      expect(puedeCapturarExoticos(_miembroCon(ClinicRole.recepcion)), isFalse);
      expect(puedeCapturarExoticos(null), isFalse);
    });

    test('el estatus legal solo lo firma admin o MVZ', () {
      // Un auxiliar puede anotar una toma pero no responder ante SEMARNAT.
      expect(puedeFirmarEstatusLegal(_miembroCon(ClinicRole.admin)), isTrue);
      expect(puedeFirmarEstatusLegal(_miembroCon(ClinicRole.mvz)), isTrue);
      expect(
        puedeFirmarEstatusLegal(_miembroCon(ClinicRole.auxiliar)),
        isFalse,
      );
    });
  });

  group('lectura de números', () {
    test('acepta coma decimal, que es como se teclea aquí', () {
      expect(leerNumero('36,5'), 36.5);
      expect(leerNumero('36.5'), 36.5);
      expect(leerNumero(' 7 '), 7);
    });

    test('vacío es nulo, no cero', () {
      // Cero es un dato: "no medi nada" no puede acabar guardado como 0.
      expect(leerNumero(''), isNull);
      expect(leerNumero(null), isNull);
      expect(leerNumero('   '), isNull);
    });

    test('la basura no se guarda como número', () {
      expect(leerNumero('treinta'), isNull);
      expect(leerNumero('--'), isNull);
    });
  });

  group('los catálogos coinciden con los CHECK de la base', () {
    test('tipos de recinto', () {
      expect(tiposDeRecinto.keys, containsAll(<String>[
        'terrario',
        'aviario',
        'acuaterrario',
        'acuario',
        'encierro',
        'incubadora',
      ]));
      expect(tiposDeRecinto, hasLength(6));
    });

    test('tipos de marcaje y regímenes', () {
      expect(tiposDeMarcaje.keys, containsAll(<String>[
        'microchip',
        'anillo',
        'muesca',
        'tatuaje',
        'foto',
      ]));
      expect(regimenesLegales.keys, containsAll(<String>[
        'cites',
        'semarnat',
        'uma',
        'pimvs',
        'otro',
      ]));
    });

    test('eventos fisiológicos incluyen ecdisis retenida y postura', () {
      // Son las dos que el expediente clinico general no sabia nombrar.
      expect(tiposDeEvento.containsKey('ecdisis_retenida'), isTrue);
      expect(tiposDeEvento.containsKey('postura'), isTrue);
      expect(tiposDeEvento, hasLength(7));
    });

    test('estados de nidada', () {
      expect(estadosDeNidada.keys, containsAll(<String>[
        'incubando',
        'eclosionada',
        'perdida',
        'cancelada',
      ]));
    });
  });

  group('los botones de captura aparecen según permiso', () {
    testWidgets('sin repositorio de escritura no hay botones', (tester) async {
      // Ofrecer un boton que el servidor va a rechazar es peor que no tenerlo.
      await _montar(tester, datos: const ExoticSnapshot(specimens: [_tortuga]));
      expect(find.text('Nuevo recinto'), findsNothing);
      expect(find.text('Toma de alimento'), findsNothing);
      expect(find.text('Registrar marcaje'), findsNothing);
    });

    testWidgets('con permiso de MVZ aparecen todos', (tester) async {
      await _montar(
        tester,
        datos: const ExoticSnapshot(specimens: [_tortuga]),
        escritura: _FakeWrite(),
      );
      expect(find.text('Nuevo recinto'), findsOneWidget);
      expect(find.text('Registrar lectura'), findsOneWidget);
      expect(find.text('Toma de alimento'), findsOneWidget);
      expect(find.text('Evento fisiológico'), findsOneWidget);
      expect(find.text('Nueva nidada'), findsOneWidget);
      expect(find.text('Registrar marcaje'), findsOneWidget);
      expect(find.text('Estatus legal'), findsOneWidget);
    });

    testWidgets('a recepción no se le ofrece capturar', (tester) async {
      await _montar(
        tester,
        datos: const ExoticSnapshot(specimens: [_tortuga]),
        escritura: _FakeWrite(),
        rol: ClinicRole.recepcion,
      );
      expect(find.text('Nuevo recinto'), findsNothing);
      expect(find.text('Registrar marcaje'), findsNothing);
    });

    testWidgets('al auxiliar se le oculta solo el estatus legal', (
      tester,
    ) async {
      await _montar(
        tester,
        datos: const ExoticSnapshot(specimens: [_tortuga]),
        escritura: _FakeWrite(),
        rol: ClinicRole.auxiliar,
      );
      expect(find.text('Toma de alimento'), findsOneWidget);
      expect(find.text('Estatus legal'), findsNothing);
    });
  });

  group('el formulario de lectura respeta lo que el recinto declara', () {
    testWidgets('solo pregunta por los parámetros declarados', (tester) async {
      await _montar(
        tester,
        datos: const ExoticSnapshot(
          specimens: [_tortuga],
          enclosures: [_terrario],
        ),
        escritura: _FakeWrite(),
      );
      await tester.tap(find.text('Registrar lectura'));
      await tester.pumpAndSettle();

      // El terrario declara punto caliente y humedad, pero no pH ni amoniaco.
      expect(find.text('Punto caliente'), findsOneWidget);
      expect(find.text('Humedad'), findsOneWidget);
      expect(find.text('pH'), findsNothing);
      expect(find.text('Amoniaco'), findsNothing);
      // Tampoco el punto frio: este terrario no lo declara.
      expect(find.text('Punto frío'), findsNothing);
    });

    testWidgets('un acuario sí pregunta por pH y amoniaco', (tester) async {
      await _montar(
        tester,
        datos: const ExoticSnapshot(
          specimens: [_tortuga],
          enclosures: [_acuario],
        ),
        escritura: _FakeWrite(),
      );
      await tester.tap(find.text('Registrar lectura'));
      await tester.pumpAndSettle();
      expect(find.text('pH'), findsOneWidget);
      expect(find.text('Amoniaco'), findsOneWidget);
      expect(find.text('Punto caliente'), findsNothing);
    });

    testWidgets('sin recintos dice qué falta en vez de un menú vacío', (
      tester,
    ) async {
      await _montar(
        tester,
        datos: const ExoticSnapshot(specimens: [_tortuga]),
        escritura: _FakeWrite(),
      );
      await tester.tap(find.text('Registrar lectura'));
      await tester.pumpAndSettle();
      expect(find.textContaining('hace falta dar de alta'), findsOneWidget);
    });
  });

  group('guardado', () {
    testWidgets('la toma exige decir si aceptó o rechazó', (tester) async {
      // Si la opcion viniera marcada en "acepto", un descuido registraria
      // comidas que no ocurrieron y la racha de rechazos dejaria de servir.
      final escritura = _FakeWrite();
      await _montar(
        tester,
        datos: const ExoticSnapshot(specimens: [_tortuga]),
        escritura: escritura,
      );
      await tester.tap(find.text('Toma de alimento'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Qué se le ofreció *'),
        'Grillo',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(escritura.llamadas, isEmpty);
      expect(find.text('Indica qué pasó'), findsOneWidget);
    });

    testWidgets('el reintento reusa el mismo recibo y no duplica', (
      tester,
    ) async {
      // El primer intento falla por red. Al volver a pulsar debe viajar el
      // MISMO operation: asi el servidor reconoce la operacion y devuelve el
      // registro que ya creo en lugar de crear otro.
      final escritura = _FakeWrite(fallarVeces: 1);
      await _montar(
        tester,
        datos: const ExoticSnapshot(specimens: [_tortuga]),
        escritura: escritura,
      );
      await tester.tap(find.text('Evento fisiológico'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ecdisis (muda)').last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('No hay conexión.'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(escritura.llamadas, ['registrarEvento', 'registrarEvento']);
      expect(
        escritura.operaciones.first,
        escritura.operaciones.last,
        reason: 'el recibo debe sobrevivir al reintento',
      );
    });

    testWidgets('el recibo tiene el formato que exige la base', (tester) async {
      // private.vet_receipt valida ^[a-f0-9]{48}$ y rechaza cualquier otra
      // cosa con invalid_operation.
      final escritura = _FakeWrite();
      await _montar(
        tester,
        datos: const ExoticSnapshot(specimens: [_tortuga]),
        escritura: escritura,
      );
      await tester.tap(find.text('Evento fisiológico'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Postura').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(escritura.operaciones.single, matches(RegExp(r'^[a-f0-9]{48}$')));
    });

    testWidgets('el recinto no manda rangos de agua si no tiene agua', (
      tester,
    ) async {
      // Un terrario no declara pH: mandarlo haria que el panel juzgara un
      // parametro que ese recinto no vigila.
      final escritura = _FakeWrite();
      await _montar(
        tester,
        datos: const ExoticSnapshot(specimens: [_tortuga]),
        escritura: escritura,
      );
      await tester.tap(find.text('Nuevo recinto'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre *'),
        'Terrario nuevo',
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terrario').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      final rangos = escritura.argumentos.single['rangos']! as Map;
      expect(rangos.containsKey('ph_min'), isFalse);
      expect(rangos.containsKey('amoniaco_max'), isFalse);
      expect(rangos.containsKey('temp_caliente_min'), isTrue);
    });
  });
}

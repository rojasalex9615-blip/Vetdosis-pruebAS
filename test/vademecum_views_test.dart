import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/calculations/data/reference_library_repository.dart';
import 'package:vetdosis_pro/modules/calculations/presentation/reference_library_screen.dart';
import 'package:vetdosis_pro/modules/doses/data/catalog_repository.dart';
import 'package:vetdosis_pro/modules/doses/domain/catalog.dart';
import 'package:vetdosis_pro/modules/doses/domain/manufacturer_pauta.dart';
import 'package:vetdosis_pro/modules/doses/presentation/vademecum_screen.dart';
import 'package:vetdosis_pro/modules/doses/presentation/vademecum_views.dart';

const _pautasJson = '''
{"schema_version":1,"note":"","pautas":[
  {"id":"a","product_name":"PRODUCTO A","manufacturer":"LAB A",
   "product_url":"https://example.test/a",
   "ingredients":"Fenbendazol + Prazicuantel","dose_amount":"1",
   "dose_unit":"mL","dose_reference":"por 10 kg de peso",
   "rule":"proporcional al peso","species":"Caninos",
   "literal":"1 mL por 10 kg"},
  {"id":"b","product_name":"PRODUCTO B","manufacturer":"LAB B",
   "product_url":"https://example.test/b","ingredients":"Fenbendazol",
   "dose_amount":"5","dose_unit":"mg","dose_reference":"por 1 kg",
   "rule":"proporcional al peso","species":"Bovinos","literal":"5 mg/kg"}
]}
''';

String _pautasGrandes(int cuantas) {
  final items = [
    for (var i = 0; i < cuantas; i++)
      '{"id":"p$i","product_name":"PRODUCTO $i","manufacturer":"LAB $i",'
          '"product_url":"https://example.test/p$i","ingredients":"Agente $i",'
          '"dose_amount":"1","dose_unit":"mL","dose_reference":"por 10 kg",'
          '"rule":"proporcional al peso","species":"Caninos",'
          '"literal":"1 mL por 10 kg"}',
  ];
  return '{"schema_version":1,"note":"","pautas":[${items.join(',')}]}';
}

String _pautasMixtas() =>
    '{"schema_version":1,"note":"","pautas":['
    '{"id":"c1","product_name":"CANINO 1","manufacturer":"LAB C",'
    '"product_url":"https://example.test/c1","ingredients":"Fenbendazol",'
    '"dose_amount":"1","dose_unit":"mL","dose_reference":"por 10 kg",'
    '"rule":"proporcional al peso","species":"Caninos","literal":"1 mL/10 kg"},'
    '{"id":"b1","product_name":"BOVINO 1","manufacturer":"LAB B",'
    '"product_url":"https://example.test/b1","ingredients":"Oxitetraciclina",'
    '"dose_amount":"5","dose_unit":"mg","dose_reference":"por 1 kg",'
    '"rule":"proporcional al peso","species":"Bovinos","literal":"5 mg/kg"}'
    ']}';

class _EmptyCatalog implements CatalogRepository {
  @override
  Future<DoseCatalog> load() async => DoseCatalog.parse(
    '{"schema_version":1,"catalog_version":"0.1.0",'
    '"estado":"sin verificar","fuentes":[],"farmacos":[]}',
  );
}

class _LibraryFixture implements ReferenceLibraryRepository {
  final sections = <String>[];

  @override
  Future<ReferenceLibraryPage> list(
    String clinicId,
    String section,
    String search,
    int offset,
  ) async {
    sections.add(section);
    return const ReferenceLibraryPage([], 0);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ManufacturerPautaCatalog catalog;

  setUpAll(() async {
    catalog = ManufacturerPautaCatalog.parse(_pautasJson);
  });

  test('El índice agrupa por principio activo y no pierde pautas', () {
    final index = indexByIngredient(catalog.pautas);
    expect(
      index.map((i) => i.name),
      containsAll(['Fenbendazol', 'Prazicuantel']),
    );
    final fenbendazol = index.firstWhere((i) => i.name == 'Fenbendazol');
    expect(fenbendazol.pautas.length, 2);
    expect(fenbendazol.products.length, 2);
    final prazicuantel = index.firstWhere((i) => i.name == 'Prazicuantel');
    expect(prazicuantel.pautas.single.productName, 'PRODUCTO A');
  });

  testWidgets('El vademécum por fármaco filtra por principio activo', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VademecumDrugView(pautas: catalog.pautas, query: 'fenben'),
          ),
        ),
      ),
    );
    expect(find.text('Fenbendazol'), findsOneWidget);
    expect(find.text('Prazicuantel'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('El vademécum comercial filtra por nombre comercial', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VademecumCommercialView(
              pautas: catalog.pautas,
              query: 'producto a',
            ),
          ),
        ),
      ),
    );
    expect(find.text('PRODUCTO A'), findsOneWidget);
    expect(find.text('PRODUCTO B'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('La biblioteca ofrece los dos vademécums sin consultar la base', (
    tester,
  ) async {
    final fixture = _LibraryFixture();
    await tester.pumpWidget(
      MaterialApp(
        home: ReferenceLibraryScreen(
          repository: fixture,
          clinicId: 'synthetic-clinic',
          pautas: catalog,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Vademécum por fármaco'), findsOneWidget);
    await tester.ensureVisible(find.text('Vademécum por nombre comercial'));
    await tester.tap(find.text('Vademécum por nombre comercial'));
    await tester.pumpAndSettle();
    expect(find.textContaining('productos comerciales'), findsOneWidget);
    expect(fixture.sections, ['fisiologia']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('La pantalla del vademécum separa las dos calculadoras', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VademecumScreen(catalog: _EmptyCatalog(), pautas: catalog),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Por principio activo'), findsOneWidget);
    expect(find.text('Por nombre comercial'), findsOneWidget);
    await tester.tap(find.text('Por nombre comercial'));
    await tester.pumpAndSettle();
    expect(find.textContaining('productos comerciales'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('El vademécum cabe en un teléfono estrecho', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VademecumScreen(catalog: _EmptyCatalog(), pautas: catalog),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('El adelanto no esconde el resto del índice', (tester) async {
    final grande = ManufacturerPautaCatalog.parse(_pautasGrandes(25));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VademecumDrugView(pautas: grande.pautas),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Mostrando 15 de 25'), findsOneWidget);
    await tester.ensureVisible(find.text('Ver los 25 principios activos'));
    await tester.tap(find.text('Ver los 25 principios activos'));
    await tester.pumpAndSettle();
    expect(find.text('Agente 24'), findsOneWidget);
  });

  testWidgets('El vademécum comercial tampoco esconde productos', (
    tester,
  ) async {
    final grande = ManufacturerPautaCatalog.parse(_pautasGrandes(25));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VademecumCommercialView(pautas: grande.pautas),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Mostrando 20 de 25'), findsOneWidget);
    await tester.ensureVisible(find.text('Ver los 25 productos'));
    await tester.tap(find.text('Ver los 25 productos'));
    await tester.pumpAndSettle();
    expect(find.text('PRODUCTO 24'), findsOneWidget);
  });

  test('El filtro de especie agrupa los textos libres de la fuente', () {
    expect(
      gruposDeEspecie('Caninos y felinos'),
      containsAll(['Caninos', 'Felinos']),
    );
    expect(
      gruposDeEspecie('Perros y gatos'),
      containsAll(['Caninos', 'Felinos']),
    );
    expect(gruposDeEspecie('Cerdos'), ['Porcinos']);
    expect(gruposDeEspecie('Bovinos'), ['Bovinos']);
    expect(gruposDeEspecie('no especificado'), ['Sin especificar']);
  });

  testWidgets('El índice nombra la marca junto al principio activo', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VademecumDrugView(pautas: catalog.pautas),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('PRODUCTO A · LAB A'), findsWidgets);
    expect(find.textContaining('(1)'), findsWidgets);
  });

  testWidgets('El filtro de especie recorta el índice', (tester) async {
    final mixto = ManufacturerPautaCatalog.parse(_pautasMixtas());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VademecumDrugView(pautas: mixto.pautas),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Fenbendazol'), findsOneWidget);
    expect(find.text('Oxitetraciclina'), findsOneWidget);
    await tester.ensureVisible(find.text('Bovinos (1)'));
    await tester.tap(find.text('Bovinos (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Oxitetraciclina'), findsOneWidget);
    expect(find.text('Fenbendazol'), findsNothing);
  });
}

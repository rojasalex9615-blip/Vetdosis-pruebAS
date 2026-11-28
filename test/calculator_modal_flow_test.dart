import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/doses/data/catalog_repository.dart';
import 'package:vetdosis_pro/modules/doses/domain/catalog.dart';
import 'package:vetdosis_pro/modules/doses/domain/pauta_farmacologica.dart';
import 'package:vetdosis_pro/modules/doses/presentation/dose_screen.dart';
import 'package:vetdosis_pro/modules/doses/presentation/farmacologico_dose_screen.dart';
import 'package:vetdosis_pro/modules/prescribing/presentation/rx_entry_screen.dart';

class _EmptyCatalog implements CatalogRepository {
  @override
  Future<DoseCatalog> load() async => DoseCatalog('empty', []);
}

void main() {
  testWidgets(
    'unsaved modal preserves edits or discards without writing at large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var writes = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RxEntryScreen(
                      title: 'Registro',
                      fields: const [RxField('name', 'Nombre')],
                      submit: (_, _) async {
                        writes++;
                      },
                    ),
                  ),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Borrador');
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Cambios sin guardar'), findsOneWidget);
      await tester.tap(find.text('Seguir editando'));
      await tester.pumpAndSettle();
      expect(find.text('Borrador'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salir sin guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Abrir'), findsOneWidget);
      expect(writes, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'default active ingredient entry loads the bibliographic catalog despite empty legacy data',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DoseScreen(repository: _EmptyCatalog()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      });
      await tester.pumpAndSettle();
      final screen = tester.widget<FarmacologicoDoseScreen>(
        find.byType(FarmacologicoDoseScreen),
      );
      expect(screen.catalog.principios.length, 540);
      expect(
        screen.catalog.pautas
            .where((p) => p.autor?.contains('Ramsey') == true)
            .length,
        1023,
      );
      expect(find.text('Especie'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'volume per kg is displayed in mL without a second mass conversion',
    (tester) async {
      final catalog = FarmacologicoCatalog.parse(
        '''{"schema_version":1,"version":"test","farmacos":[{"id":"F","principio_activo":"Prueba"}],"dosis":[{"id":"P","id_farmaco":"F","especies":["Perro"],"dosis_original":"1","unidad_original":"mL/kg","dosis_min":"1","base_calculo":"volumen"}]}''',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: FarmacologicoDoseScreen(catalog: catalog)),
        ),
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Perro').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Prueba'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sin indicación'));
      await tester.pumpAndSettle();
      final weight = find.widgetWithText(TextField, 'Peso en kg');
      await tester.ensureVisible(weight);
      await tester.enterText(weight, '10');
      await tester.pumpAndSettle();
      expect(find.text('10 mL'), findsOneWidget);
      expect(find.text('Dosis en volumen'), findsOneWidget);
      expect(find.text('Concentración en mg/mL'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

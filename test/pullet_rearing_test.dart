import 'package:vetdosis_pro/modules/exports/presentation/branded_export_action.dart'
    show brandedPdf;
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:vetdosis_pro/modules/aviculture/domain/pullet_guide.dart';
import 'package:vetdosis_pro/modules/aviculture/domain/pullet_rearing.dart';
import 'package:vetdosis_pro/modules/aviculture/domain/pullet_rearing_export.dart';
import 'package:vetdosis_pro/modules/exports/domain/branded_export.dart';

final catalog = PulletGuideCatalog.parse(
  File('assets/clinical/aviculture/guia_linea.v1.json').readAsStringSync(),
);
PulletRearingPlan plan({
  String birds = '4275',
  int weeks = 18,
  String waste = '7',
  Map<int, String>? feed,
  PulletGuide? guide,
  String system = 'piso',
  String brand = 'Otra',
  bool mortality = false,
  Map<int, String> mortalities = const {},
  List<RearingItem> equipment = const [],
  List<RearingItem> vaccines = const [],
  String density = '8',
  String gas = '2.50',
  String margin = '35',
}) => PulletRearingPlan(
  name: 'Proyecto de prueba',
  brand: brand,
  system: system,
  birds: birds,
  weeks: weeks,
  waste: waste,
  guide: guide,
  feedOverrides: feed ?? {for (var i = 1; i <= weeks; i++) i: '10'},
  adjustMortality: mortality,
  mortalityOverrides: mortalities,
  stages: [
    if (weeks <= 6)
      RearingStage(
        name: 'Inicio',
        firstWeek: 1,
        lastWeek: weeks,
        price: '12.50',
        density: density,
      )
    else ...[
      RearingStage(
        name: 'Inicio',
        firstWeek: 1,
        lastWeek: 6,
        price: '12.50',
        density: density,
      ),
      RearingStage(
        name: 'Crecimiento',
        firstWeek: 7,
        lastWeek: weeks < 12 ? weeks : 12,
        price: '11.50',
        density: density,
      ),
      if (weeks > 12)
        RearingStage(
          name: 'Desarrollo',
          firstWeek: 13,
          lastWeek: weeks,
          price: '10.50',
          density: density,
        ),
    ],
  ],
  equipment: equipment,
  vaccines: vaccines,
  chickPrice: '0',
  gasPerBird: gas,
  beddingKgPerBird: '0.3',
  beddingPriceKg: '4.00',
  electricityPrice: '0',
  electricityPeriods: '0',
  margin: margin,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Caso exacto de Claude: compra semanal al kg más cercano, no ×10', () {
    const values = [
      9,
      14,
      20,
      25,
      30,
      35,
      40,
      44,
      47,
      50,
      53,
      56,
      59,
      62,
      65,
      68,
      73,
      76,
    ];
    final r = calculatePulletRearing(
      plan(
        feed: {for (var i = 0; i < values.length; i++) i + 1: '${values[i]}'},
      ),
    );
    expect(r.stages.map((s) => s.purchase!.low.toInt()), [4258, 9286, 12903]);
    expect(r.stages.map((s) => s.cost!.low.toInt()), [
      5322500,
      10678900,
      13548150,
    ]);
    expect(r.purchase!.low.toInt(), 26447);
    expect(r.categories['Alimento']!.low.toInt(), 29549550);
    expect(r.categories['Gas']!.low.toInt(), 1068750);
    expect(r.beddingKg!.display(places: 1), '1282,5');
    expect(r.categories['Cama']!.low.toInt(), 513000);
    expect(r.total!.low.toInt(), 31131300);
    expect(r.costPerBird!.low.toInt(), 7282);
    expect(r.salePrice!.low.toInt(), 9831);
  });
  test('m², piezas y frascos siempre se redondean hacia arriba', () {
    final r = calculatePulletRearing(
      plan(
        birds: '3155',
        weeks: 1,
        density: '13',
        equipment: [
          const RearingItem(
            name: 'Vitrolero',
            basis: 'birds',
            coverage: '60',
            price: '100',
          ),
          const RearingItem(
            name: 'LED',
            basis: 'area',
            coverage: '15',
            price: '20',
          ),
        ],
        vaccines: [
          const RearingItem(
            name: 'Producto elegido',
            basis: 'birds',
            coverage: '1000',
            price: '50',
            applications: 2,
          ),
        ],
      ),
    );
    expect(r.area, BigInt.from(243));
    expect(r.equipment.map((e) => e.count), [BigInt.from(53), BigInt.from(17)]);
    expect(r.vaccines.single.count, BigInt.from(8));
    expect(r.vaccines.single.cost, BigInt.from(40000));
  });
  test('precios vacíos dejan pendientes, cero debe ser explícito', () {
    final original = plan(gas: '');
    final r = calculatePulletRearing(original);
    expect(r.categories['Gas'], isNull);
    expect(r.total, isNull);
    expect(r.costPerBird, isNull);
    expect(r.knownSubtotal, isNotNull);
    expect(r.warnings.join(' '), contains('Gas'));
  });
  test('rangos completos de una sola guía sin elegir promedio', () {
    final guide = catalog.guides.firstWhere((g) => g.id == 'bovans-cage');
    final r = calculatePulletRearing(
      plan(
        birds: '1000',
        weeks: 1,
        waste: '0',
        brand: 'Bovans',
        system: 'jaula',
        guide: guide,
        feed: {},
      ),
    );
    expect(r.weekly.single.feed!.low.display(), '9');
    expect(r.weekly.single.feed!.high.display(), '11');
    expect(r.purchase!.low, BigInt.from(63));
    expect(r.purchase!.high, BigInt.from(77));
    expect(r.weekly.single.edited, isFalse);
    expect(r.weekly.single.source, contains('p. 6'));
  });
  test('la edición nueva de Lohmann no hereda consumos de la de 2019', () {
    final guide = catalog.guides.firstWhere(
      (g) => g.id == 'lohmann-cage-v01-24',
    );
    final r = calculatePulletRearing(
      plan(weeks: 1, brand: 'Lohmann', system: 'jaula', guide: guide, feed: {}),
    );
    expect(r.weekly.single.feed, isNull);
    expect(r.purchase, isNull);
    expect(r.total, isNull);
    expect(r.weekly.single.source, contains('Sin datos'));
  });
  test('una semana fuera de guía nunca se interpola; puede capturarse', () {
    final guide = catalog.guides.first;
    final r = calculatePulletRearing(
      plan(weeks: 21, guide: guide, brand: 'Bovans', system: 'jaula', feed: {}),
    );
    expect(r.weekly.last.feed, isNull);
    expect(r.warnings.first, contains('18 semanas'));
    final edited = calculatePulletRearing(
      plan(
        weeks: 1,
        guide: guide,
        brand: 'Bovans',
        system: 'jaula',
        feed: {1: '12.5'},
      ),
    );
    expect(edited.weekly.single.edited, isTrue);
    expect(edited.weekly.single.feed!.low.display(), '12,5');
  });
  test('mortalidad ajusta aves y consumo; no inventa semanas faltantes', () {
    final r = calculatePulletRearing(
      plan(
        birds: '100',
        weeks: 1,
        waste: '0',
        mortality: true,
        mortalities: {1: '10'},
      ),
    );
    expect(r.weekly.single.alive!.display(), '90');
    expect(r.weekly.single.consumption!.low.display(), '6,3');
    expect(
      calculatePulletRearing(plan(weeks: 1, mortality: true)).purchase,
      isNull,
    );
    expect(
      () => calculatePulletRearing(
        plan(weeks: 2, mortality: true, mortalities: {1: '2', 2: '1'}),
      ),
      throwsFormatException,
    );
  });
  test(
    'sin ajustar mortalidad usa las alojadas incluso si la guía la publica',
    () {
      final guide = catalog.guides.firstWhere((g) => g.id == 'hyline-cage');
      final r = calculatePulletRearing(
        plan(
          birds: '100',
          weeks: 1,
          guide: guide,
          brand: 'Hy-Line',
          system: 'jaula',
          feed: {},
        ),
      );
      expect(r.weekly.single.alive!.display(), '100');
    },
  );
  test('un sistema o marca distinto se rechaza antes de calcular', () {
    expect(
      () => calculatePulletRearing(plan(guide: catalog.guides.first)),
      throwsFormatException,
    );
  });
  test(
    'pollitas cero, fracciones, NaN, precios con milésimas y merma inválida',
    () {
      for (final birds in ['0', '1.5', 'NaN', 'Infinity', '-4']) {
        expect(
          () => calculatePulletRearing(plan(birds: birds)),
          throwsFormatException,
        );
      }
      expect(
        () => calculatePulletRearing(plan(gas: '1.001')),
        throwsFormatException,
      );
      expect(
        () => calculatePulletRearing(plan(waste: '101')),
        throwsFormatException,
      );
      expect(
        () => calculatePulletRearing(plan(margin: '150')),
        returnsNormally,
      );
    },
  );
  test('comparación a 17 semanas usa consumo sin merma y conserva la cita', () {
    final guide = catalog.guides.firstWhere((g) => g.id == 'bovans-cage');
    final r = calculatePulletRearing(
      plan(
        weeks: 17,
        guide: guide,
        brand: 'Bovans',
        system: 'jaula',
        feed: {for (var i = 1; i <= 17; i++) i: '1'},
      ),
    );
    expect(r.warnings.join(' '), contains('17 semanas'));
    expect(r.warnings.join(' '), contains('p. 6'));
  });
  test('guardar/reabrir conserva todos los inputs y la tabla de la guía', () {
    final original = plan(
      guide: catalog.guides.first,
      brand: 'Bovans',
      system: 'jaula',
    );
    final json = jsonEncode(original.toJson());
    final copy = PulletRearingPlan.read(
      jsonDecode(json) as Map<String, dynamic>,
    );
    expect(copy.toJson(), original.toJson());
    copy.guide!.data['edition'] = 'Otra edición';
    expect(original.guide!.edition, isNot('Otra edición'));
  });
  test(
    'exportación Excel real conserva unidades, fuente y no inyecta fórmulas',
    () {
      final r = calculatePulletRearing(plan(weeks: 1));
      final rows = pulletRearingExportRows(r);
      final bytes = brandedXlsx(
        const ExportBranding(name: 'VetDosis'),
        '=Proyecto',
        rows,
      );
      final zip = ZipDecoder().decodeBytes(bytes);
      final xml = utf8.decode(
        zip.findFile('xl/worksheets/sheet1.xml')!.content as List<int>,
      );
      expect(xml, contains('g/ave/día'));
      expect(xml, contains('Compra semanal'));
      expect(xml, contains('=Proyecto'));
      expect(xml, isNot(contains('<f>')));
    },
  );
  test(
    'PDF de 18 semanas puede generarse con rangos, fuentes e insumos',
    () async {
      final result = calculatePulletRearing(plan());
      final bytes = await brandedPdf(
        const ExportBranding(name: 'VetDosis'),
        'Crianza de aves de postura',
        pulletRearingExportRows(result),
      );
      expect(utf8.decode(bytes.take(5).toList()), '%PDF-');
      expect(bytes.length, greaterThan(5000));
    },
  );
}

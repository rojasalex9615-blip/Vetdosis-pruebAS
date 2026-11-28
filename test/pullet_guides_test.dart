import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/aviculture/domain/pullet_guide.dart';

void main() {
  final catalog = PulletGuideCatalog.parse(
    File('assets/clinical/aviculture/guia_linea.v1.json').readAsStringSync(),
  );
  test(
    'cada marca tiene jaula y piso con página, edición, enlace oficial y huella',
    () {
      for (final brand in ['Bovans', 'Hy-Line', 'Lohmann']) {
        expect(catalog.forBrand(brand).map((g) => g.system).toSet(), {
          'jaula',
          'piso',
        });
      }
      for (final g in catalog.guides) {
        expect(g.data['sha256'], matches(RegExp(r'^[a-f0-9]{64}$')));
        expect(g.edition, isNotEmpty);
        final host = Uri.parse(g.url).host;
        expect(
          host,
          anyOf('www.bovans.com', 'www.hyline.com', 'lohmann-breeders.com'),
        );
        expect(g.week(17), isNotNull);
        expect(g.week(17)!['page'], greaterThan(0));
      }
    },
  );
  test(
    'Hy-Line alternativo 2026 convierte acumulados de kg a g, no ×1 ni ×100',
    () {
      final g = catalog.guides.firstWhere((g) => g.id == 'hyline-floor');
      expect(g.week(1)!['cumulativeMin'], '120');
      expect(g.week(17)!['cumulativeMax'], '6730');
      expect(g.week(18)!['feedMin'], '87');
      expect(g.week(18)!['mortality'], isNull);
    },
  );
  test('la mortalidad de postura no reinicia la acumulada de crianza', () {
    final g = catalog.guides.firstWhere((g) => g.id == 'hyline-cage');
    expect(g.week(17)!['mortality'], '2.00');
    expect(g.week(18)!['mortality'], isNull);
  });
  test('Lohmann conserva diferencias de ediciones, no las reconcilia', () {
    final old = catalog.guides.firstWhere((g) => g.id == 'lohmann-cage-2019');
    final current = catalog.guides.firstWhere(
      (g) => g.id == 'lohmann-cage-v01-24',
    );
    expect(old.week(17)!['weightMin'], '1394');
    expect(current.week(17)!['weightMin'], '1378');
    expect(old.week(17)!['feedMin'], '72');
    expect(current.week(17)!['feedMin'], isNull);
  });
  test(
    'Bovans usa su columna correcta y los sistemas se conservan separados',
    () {
      final a = catalog.guides.firstWhere((g) => g.id == 'bovans-cage');
      final b = catalog.guides.firstWhere((g) => g.id == 'bovans-floor');
      expect(a.week(17)!['feedMin'], '81');
      expect(b.week(17)!['feedMin'], '80');
      expect(a.week(17)!['weightMin'], '1389');
    },
  );
  test(
    'luz de Lohmann solo se ofrece para el programa citado; semana uno variable no se resume',
    () {
      final g = catalog.guides.firstWhere((g) => g.id == 'lohmann-floor-2018');
      expect(g.week(1)!['lightMin'], isNull);
      expect(g.week(17)!['lightMin'], '10');
      expect(g.week(17)!['lightPage'], 15);
    },
  );
}

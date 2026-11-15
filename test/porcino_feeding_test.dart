import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/production/domain/porcino_feeding.dart';

/// Fija los datos del CSV
/// `VetDosis_Sistemas_Alimentacion_PorkSchool.csv` (Pork School, ago-2026):
/// transporte, silos-tolva, tolva-báscula, comederos y tamaño de partícula.
void main() {
  test('El transporte conserva capacidad y longitud por modelo', () {
    final byModel = {for (final t in porcinoFeedTransports) t.model: t};
    expect(byModel['220']!.capacity, 400);
    expect(byModel['220']!.unit, 'kg/h');
    expect(byModel['220']!.maxLengthM, 75);
    expect(byModel['300']!.capacity, 1.36);
    expect(byModel['350']!.capacity, 2.72);
    expect(byModel['500']!.capacity, 5.99);
    expect(porcinoFeedTransports, hasLength(4));
  });

  test('La boca de salida del silo depende del número de sistemas', () {
    expect(porcinoSiloOutletInches(1), '16"');
    expect(porcinoSiloOutletInches(2), '16"');
    expect(porcinoSiloOutletInches(3), '22"');
    expect(porcinoSiloOutletInches(4), '22"');
    // Fuera de 1-4 no hay dato: null, no se inventa.
    expect(porcinoSiloOutletInches(0), isNull);
    expect(porcinoSiloOutletInches(5), isNull);
  });

  test('Los catálogos de silo y partícula conservan el material', () {
    expect(porcinoSiloDiametersFt, [6, 7, 9, 12, 15]);
    expect(porcinoSiloHopperAngles, [45, 60, 67]);
    expect(porcinoSiloRoofSlopes, [30, 40]);
    expect(porcinoOptimalParticleMicrons, 700);
  });

  test('Toda fila declara categoría, dato y sección', () {
    expect(porcinoFeedingRefs, hasLength(13));
    for (final ref in porcinoFeedingRefs) {
      expect(ref.category, isNotEmpty);
      expect(ref.dato, isNotEmpty);
      expect(ref.section, isNotEmpty);
      expect(ref.id, matches(RegExp(r'^[a-z][a-z0-9_]+$')));
    }
    expect(porcinoFeedingSource, contains('Pork School'));
  });
}

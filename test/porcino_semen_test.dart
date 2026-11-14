import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/production/domain/porcino_semen.dart';

void main() {
  group('Concentración', () {
    test('Conteo en 5 cuadros: células × dilución × 50 000 ÷ 10⁶', () {
      final c = SemenConcentration.fromCount(
        cells: 76,
        dilution: 200,
        chamber: SemenChamber.smallSquares,
      );
      expect(c.millionsPerMl, closeTo(760, 1e-9));
    });

    test('Cuadro grande de 1 mm² usa 10 000 por ml', () {
      final c = SemenConcentration.fromCount(
        cells: 38,
        dilution: 100,
        chamber: SemenChamber.largeSquare,
      );
      expect(c.millionsPerMl, closeTo(38, 1e-9));
    });

    test('Concentración capturada a mano se conserva', () {
      expect(SemenConcentration.direct(380).millionsPerMl, 380);
    });

    test('Rechaza conteos y concentraciones imposibles', () {
      expect(
        () => SemenConcentration.fromCount(
          cells: 0,
          dilution: 200,
          chamber: SemenChamber.smallSquares,
        ),
        throwsFormatException,
      );
      expect(
        () => SemenConcentration.fromCount(
          cells: 76,
          dilution: 0,
          chamber: SemenChamber.smallSquares,
        ),
        throwsFormatException,
      );
      expect(() => SemenConcentration.direct(0), throwsFormatException);
      expect(() => SemenConcentration.direct(9999), throwsFormatException);
    });
  });

  group('Reparto en dosis', () {
    // Conteo 76 × 200 × 50 000 = 760 ×10⁶/ml; 200 ml, 90 % motilidad,
    // 88 % morfología, sin pérdida → 200 × 760 × 0.9 × 0.88 × 10⁶ espermios.
    SemenDosePlan plan({
      double volumeMl = 200,
      double concentration = 760,
      double motility = 90,
      double morphology = 88,
      double spermPerDose = 2,
      double doseVolume = 80,
      double loss = 0,
      int shelf = 3,
    }) => SemenDosePlan(
      volumeMl: volumeMl,
      concentrationMillionsPerMl: concentration,
      motilityPercent: motility,
      morphologyPercent: morphology,
      spermPerDoseBillion: spermPerDose,
      doseVolumeMl: doseVolume,
      lossPercent: loss,
      shelfLifeDays: shelf,
      collectedOn: DateTime(2026, 11, 13),
    );

    test('Cuenta dosis completas, volumen final y diluyente', () {
      final p = plan();
      // 200 × 760 × 10⁶ × 0.9 × 0.88 = 120 384 ×10⁶ = 120.384 ×10⁹.
      expect(p.usableSpermBillion, closeTo(120.384, 1e-6));
      // 120.384 ÷ 2 = 60.192 → 60 dosis.
      expect(p.doses, 60);
      expect(p.finalVolumeMl, closeTo(4800, 1e-9));
      expect(p.diluentToAddMl, closeTo(4600, 1e-9));
      // Sobrante = 120.384 − 120 = 0.384 ×10⁹.
      expect(p.leftoverSpermBillion, closeTo(0.384, 1e-6));
      expect(p.volumeShortfall, isFalse);
    });

    test('El margen de pérdida reduce los espermatozoides útiles', () {
      final p = plan(loss: 10);
      expect(p.usableSpermBillion, closeTo(108.3456, 1e-4));
      expect(p.doses, 54);
    });

    test('Una fracción no completa una dosis y queda como sobrante', () {
      final p = plan(volumeMl: 10, concentration: 100, spermPerDose: 1);
      // 10 × 100 × 10⁶ × 0.9 × 0.88 = 792 ×10⁶ = 0.792 ×10⁹ → 0 dosis.
      expect(p.doses, 0);
      expect(p.leftoverSpermBillion, closeTo(0.792, 1e-6));
      expect(p.diluentToAddMl, 0);
    });

    test('Avisa cuando el volumen final no cubre el eyaculado', () {
      final p = plan(doseVolume: 3);
      // 60 dosis × 3 ml = 180 ml, por debajo de los 200 ml del eyaculado.
      expect(p.doses, 60);
      expect(p.finalVolumeMl, closeTo(180, 1e-9));
      expect(p.volumeShortfall, isTrue);
      expect(p.diluentToAddMl, 0);
    });

    test('Usar antes de = colecta + días del diluyente', () {
      expect(plan(shelf: 7).useBefore, DateTime(2026, 11, 20));
      expect(plan(shelf: 14).useBefore, DateTime(2026, 11, 27));
    });

    test('Rechaza entradas fuera de rango', () {
      for (final build in [
        () => plan(volumeMl: 0),
        () => plan(volumeMl: 2000),
        () => plan(concentration: 0),
        () => plan(motility: 120),
        () => plan(morphology: -1),
        () => plan(spermPerDose: 0),
        () => plan(doseVolume: 0),
        () => plan(loss: 100),
        () => plan(shelf: 0),
      ]) {
        expect(build, throwsFormatException);
      }
    });
  });

  group('Aptitud de calidad', () {
    SemenQualityAssessment assess({
      double motility = 90,
      double progressive = 75,
      double str = 75,
      double vsl = 35,
      SemenQualityThresholds thresholds = const SemenQualityThresholds(),
    }) => SemenQualityAssessment(
      motilityPercent: motility,
      progressivePercent: progressive,
      strPercent: str,
      vslMicronsPerSecond: vsl,
      thresholds: thresholds,
    );

    test('Los valores por defecto cumplen los mínimos', () {
      final a = assess();
      expect(a.isApt, isTrue);
      expect(a.failures, isEmpty);
      expect(a.verdict, 'Cumple los mínimos de calidad.');
    });

    test('Lista cada criterio por debajo del umbral', () {
      final a = assess(motility: 80, progressive: 60, vsl: 20, str: 65);
      expect(a.isApt, isFalse);
      expect(a.failures, [
        'motilidad total <85 %',
        'progresiva <70 %',
        'VSL <30 µm/s',
        'STR <70 %',
      ]);
      expect(a.verdict, startsWith('No apto para inseminar: '));
    });

    test('Los umbrales editables cambian el veredicto', () {
      const lax = SemenQualityThresholds(
        motilityTotalMin: 70,
        progressiveMin: 50,
        vslMin: 20,
        strMin: 60,
      );
      expect(assess(motility: 80, progressive: 60, vsl: 25, str: 65,
          thresholds: lax).isApt, isTrue);
    });

    test('Rechaza umbrales y valores imposibles', () {
      expect(
        () => assess(
          thresholds: const SemenQualityThresholds(motilityTotalMin: 120),
        ),
        throwsFormatException,
      );
      expect(() => assess(vsl: 600), throwsFormatException);
      expect(() => assess(str: -1), throwsFormatException);
    });
  });

  group('Alertas del reparto', () {
    test('Sin alertas cuando todo cuadra', () {
      final p = SemenDosePlan(
        volumeMl: 200,
        concentrationMillionsPerMl: 380,
        motilityPercent: 90,
        morphologyPercent: 88,
        spermPerDoseBillion: 2,
        doseVolumeMl: 80,
        lossPercent: 0,
        shelfLifeDays: 3,
        collectedOn: DateTime(2026, 11, 13),
        doseVolumeRange: SemenInsemination.postCervical.doseVolumeRange,
      );
      expect(p.alerts, isEmpty);
    });

    test('Acumula eyaculado corto, pocos espermatozoides y rango', () {
      final p = SemenDosePlan(
        volumeMl: 40,
        concentrationMillionsPerMl: 100,
        motilityPercent: 90,
        morphologyPercent: 88,
        spermPerDoseBillion: 2,
        doseVolumeMl: 50,
        lossPercent: 0,
        shelfLifeDays: 3,
        collectedOn: DateTime(2026, 11, 13),
        doseVolumeRange: SemenInsemination.postCervical.doseVolumeRange,
      );
      // 40 ml < 50 ml mínimos; 40 × 100 ×10⁶ = 4 ×10⁹ < 10; 50 ml < 60 del
      // rango poscervical. Hay 1 dosis (final 50 ml), así que no hay aviso de
      // volumen corto.
      expect(p.alerts.length, 3);
      expect(p.alerts.first, contains('Eyaculado <50 ml'));
      expect(p.alerts.join(' '), contains('Menos de 10 × 10⁹'));
      expect(p.alerts.join(' '), contains('fuera del rango de 60–80 ml'));
    });

    test('Avisa cuando el volumen final no cubre el eyaculado', () {
      final p = SemenDosePlan(
        volumeMl: 200,
        concentrationMillionsPerMl: 380,
        motilityPercent: 90,
        morphologyPercent: 88,
        spermPerDoseBillion: 2,
        doseVolumeMl: 3,
        lossPercent: 0,
        shelfLifeDays: 3,
        collectedOn: DateTime(2026, 11, 13),
        doseVolumeRange: SemenInsemination.postCervical.doseVolumeRange,
      );
      // 30 dosis × 3 ml = 90 ml < 200 ml del eyaculado; 3 ml también queda por
      // debajo del rango poscervical (60–80).
      expect(p.alerts.join(' '), contains('menor al eyaculado'));
      expect(p.alerts.join(' '), contains('fuera del rango de 60–80 ml'));
    });
  });
}

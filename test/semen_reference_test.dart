import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/production/domain/porcino_semen.dart';
import 'package:vetdosis_pro/modules/production/domain/semen_reference.dart';
import 'package:vetdosis_pro/modules/production/presentation/semen_reference_screen.dart';

void main() {
  group('Perfiles por especie', () {
    test('Cerdo reparte en dosis; perro solo evalúa el eyaculado', () {
      final cerdo = semenSpeciesProfile('cerdo');
      final perro = semenSpeciesProfile('perro');
      final caballo = semenSpeciesProfile('caballo');
      expect(cerdo.assessesDoses, isTrue);
      expect(caballo.assessesDoses, isTrue);
      expect(perro.assessesDoses, isFalse);
      expect(perro.doseTypes, isEmpty);
      expect(cerdo.showDiluent, isTrue);
      expect(perro.showDiluent, isFalse);
      expect(() => semenSpeciesProfile('tortuga'), throwsFormatException);
    });

    test('El conteo del atajo (1:200 y 5 cuadros) da 380 ×10⁶/ml', () {
      final conc = SemenConcentration.fromCount(
        cells: 38,
        dilution: 200,
        chamber: SemenChamber.smallSquares,
      );
      expect(conc.millionsPerMl, closeTo(380, 1e-9));
      expect(semenSpeciesProfile('cerdo').exampleConcentration, 380);
    });
  });

  group('Cerdo', () {
    SemenEvaluation cerdo({SemenThresholds? thresholds}) {
      final p = semenSpeciesProfile('cerdo');
      return SemenEvaluation(
        profile: p,
        volumeMl: 200,
        concentrationMillionsPerMl: 380,
        motilityPercent: 90,
        morphologyPercent: 88,
        progressivePercent: 75,
        spermPerDoseBillion: p.doseTypes[1].spermPerDoseBillion,
        doseVolumeMl: 80,
        lossPercent: 0,
        shelfLifeDays: 3,
        collectedOn: DateTime(2026, 11, 15),
        thresholds: thresholds,
      );
    }

    test('Ejemplo por defecto: 30 dosis poscervicales', () {
      final r = cerdo();
      expect(r.totalSpermBillion, closeTo(76, 1e-9));
      expect(r.usableSpermBillion, closeTo(60.192, 1e-9));
      expect(r.doses, 30);
      expect(r.finalVolumeMl, closeTo(2400, 1e-9));
      expect(r.diluentToAddMl, closeTo(2200, 1e-9));
      expect(r.leftoverSpermBillion, closeTo(0.192, 1e-9));
      expect(r.volumeShortfall, isFalse);
      expect(r.alerts, isEmpty);
      expect(r.isApt, isTrue);
      expect(r.useBefore, DateTime(2026, 11, 18));
    });

    test('La dosis cervical cambia el reparto a 20 dosis', () {
      final p = semenSpeciesProfile('cerdo');
      final r = SemenEvaluation(
        profile: p,
        volumeMl: 200,
        concentrationMillionsPerMl: 380,
        motilityPercent: 90,
        morphologyPercent: 88,
        progressivePercent: 75,
        spermPerDoseBillion: p.doseTypes[0].spermPerDoseBillion,
        doseVolumeMl: 80,
        lossPercent: 0,
        shelfLifeDays: 3,
        collectedOn: DateTime(2026, 11, 15),
      );
      expect(r.doses, 20);
      expect(r.alerts, isEmpty);
    });

    test('Calidad baja por debajo de los umbrales', () {
      final r = cerdo(
        thresholds: const SemenThresholds(
          motilityMin: 95,
          morphologyMin: 90,
          progressiveMin: 80,
          vslMin: 30,
          strMin: 70,
          volumeMinMl: 50,
          totalSpermMinBillion: 10,
        ),
      );
      expect(r.isApt, isFalse);
      expect(r.qualityFailures, contains('motilidad <95 %'));
      expect(r.qualityFailures, contains('morfología normal <90 %'));
    });

    test('Avisos: volumen bajo, eyaculado pobre y volumen por dosis fuera', () {
      final p = semenSpeciesProfile('cerdo');
      final r = SemenEvaluation(
        profile: p,
        volumeMl: 40,
        concentrationMillionsPerMl: 100,
        motilityPercent: 90,
        morphologyPercent: 88,
        progressivePercent: 75,
        spermPerDoseBillion: 2,
        doseVolumeMl: 40,
        doseVolumeRange: (min: 60, max: 80),
        lossPercent: 0,
        shelfLifeDays: 3,
        collectedOn: DateTime(2026, 11, 15),
      );
      expect(r.alerts.length, 3);
      expect(r.alerts.join(' '), contains('rango de 60–80 ml'));
      expect(r.alerts.join(' '), contains('posible colecta incompleta'));
      expect(r.alerts.join(' '), contains('Menos de 10 × 10⁹'));
    });

    test('Rechaza entradas inválidas', () {
      final p = semenSpeciesProfile('cerdo');
      SemenEvaluation build({double vol = 200, double conc = 380}) =>
          SemenEvaluation(
            profile: p,
            volumeMl: vol,
            concentrationMillionsPerMl: conc,
            motilityPercent: 90,
            morphologyPercent: 88,
            progressivePercent: 75,
            spermPerDoseBillion: 2,
            doseVolumeMl: 80,
            lossPercent: 0,
            shelfLifeDays: 3,
            collectedOn: DateTime(2026, 11, 15),
          );
      expect(() => build(vol: 0), throwsFormatException);
      expect(() => build(vol: 2000), throwsFormatException);
      expect(() => build(conc: 0), throwsFormatException);
      expect(() => build(conc: 9999), throwsFormatException);
      expect(
        () => SemenEvaluation(
          profile: p,
          volumeMl: 200,
          concentrationMillionsPerMl: 380,
          motilityPercent: 90,
          morphologyPercent: 88,
          progressivePercent: 75,
          spermPerDoseBillion: 0,
          doseVolumeMl: 80,
          lossPercent: 0,
          shelfLifeDays: 3,
          collectedOn: DateTime(2026, 11, 15),
        ),
        throwsFormatException,
      );
    });
  });

  group('Caballo', () {
    SemenEvaluation caballo({int doseIndex = 2, double progressive = 60}) {
      final p = semenSpeciesProfile('caballo');
      return SemenEvaluation(
        profile: p,
        volumeMl: 50,
        concentrationMillionsPerMl: 200,
        motilityPercent: 75,
        progressivePercent: progressive,
        spermPerDoseBillion: p.doseTypes[doseIndex].spermPerDoseBillion,
      );
    }

    test('Ejemplo por defecto: 9 dosis de 500 ×10⁶ progresivos', () {
      final r = caballo();
      expect(r.totalSpermBillion, closeTo(10, 1e-9));
      expect(r.usableSpermBillion, closeTo(4.5, 1e-9));
      expect(r.doses, 9);
      expect(r.finalVolumeMl, isNull);
      expect(r.isApt, isTrue);
      expect(r.alerts, isEmpty);
    });

    test('La dosis de 300 ×10⁶ da 15 dosis', () {
      expect(caballo(doseIndex: 0).doses, 15);
    });

    test('Sin morfología no se descuenta; sí la progresiva', () {
      final r = caballo();
      // 50 × 200e6 × 0.75 × 0.60 = 4.5e9 (no hay factor de morfología).
      expect(r.usableSpermBillion, closeTo(4.5, 1e-9));
    });

    test('Rechaza progresiva fuera de rango', () {
      expect(() => caballo(progressive: 120), throwsFormatException);
    });
  });

  group('Perro', () {
    SemenEvaluation perro({double totalSpermMin = 0.2}) {
      final p = semenSpeciesProfile('perro');
      return SemenEvaluation(
        profile: p,
        volumeMl: 3,
        concentrationMillionsPerMl: 80,
        motilityPercent: 80,
        morphologyPercent: 80,
        thresholds: SemenThresholds(
          motilityMin: 70,
          morphologyMin: 70,
          volumeMinMl: 0.5,
          totalSpermMinBillion: totalSpermMin,
        ),
      );
    }

    test('Solo evalúa el eyaculado (sin dosis)', () {
      final r = perro();
      expect(r.doses, isNull);
      expect(r.finalVolumeMl, isNull);
      expect(r.totalSpermBillion, closeTo(0.24, 1e-9));
      expect(r.isApt, isTrue);
      expect(r.alerts, isEmpty);
    });

    test('Avisa si el eyaculado queda por debajo del total mínimo', () {
      final r = perro(totalSpermMin: 0.5);
      expect(r.alerts.join(' '), contains('Menos de 0.5 × 10⁹'));
    });

    test('Umbrales fuera de rango', () {
      expect(
        () => perro().thresholds.validate(),
        returnsNormally,
      );
      expect(
        () => SemenThresholds(
          motilityMin: 120,
          volumeMinMl: 0.5,
          totalSpermMinBillion: 0.2,
        ).validate(),
        throwsFormatException,
      );
    });
  });

  testWidgets('La pantalla muestra el reparto y cambia de especie', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: SemenReferenceScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('30'), findsWidgets);
    expect(find.text('dosis'), findsOneWidget);
    expect(find.textContaining('Espermatozoides útiles totales'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('semen-especie')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perro').last);
    await tester.pumpAndSettle();
    expect(
      find.text('millones de espermatozoides por eyaculado'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/production/domain/porcino_bandas.dart';

/// Fija los números de la hoja de clase `Flujo_produccion_bandas.xlsx`:
/// 550 vientres, banda de 14 días.
void main() {
  test('Flujo por bandas reproduce el ejemplo de la diapositiva', () {
    final flow = PorcinoBandFlow(sows: 550);
    expect(flow.cycleDays, 149); // 114 + 28 + 7
    expect(flow.cycleBands, closeTo(10.6428571428571, 1e-9)); // 149 / 14
    expect(flow.servicesPerBand, closeTo(51.6778523489933, 1e-6));
    expect(flow.farrowingsPerBand, closeTo(43.9261744966443, 1e-6));
    expect(flow.bornAlivePerBand, closeTo(549.077181208054, 1e-6));
    expect(flow.weanedPerBand, closeTo(494.169463087248, 1e-6));
    expect(flow.nursingCrates, closeTo(131.778523489933, 1e-6));
    expect(flow.annualReplacements, closeTo(247.5, 1e-9));
    expect(flow.replacementsPerMonth, closeTo(20.625, 1e-9));
  });

  test('El destete semanal divide entre las semanas de la banda', () {
    final flow = PorcinoBandFlow(sows: 550);
    // 494.169… ÷ (14 / 7) = 247.0847…
    expect(flow.weanedPerWeek, closeTo(247.084731543624, 1e-6));
  });

  test('Inventario por etapa reproduce la tabla y el total', () {
    final flow = PorcinoBandFlow(sows: 550);
    final inventory = PorcinoStageInventory(weanedPerWeek: flow.weanedPerWeek);
    final stages = inventory.stages;
    expect(stages.map((s) => s.name), [
      'Pre-iniciación',
      'Iniciación',
      'Crecimiento y desarrollo',
      'Finalización',
    ]);
    expect(stages[0].finalPerWeek, closeTo(239.672189597315, 1e-6));
    expect(stages[0].total, closeTo(719.016568791946, 1e-6));
    expect(stages[1].finalPerWeek, closeTo(237.275467701342, 1e-6));
    expect(stages[2].finalPerWeek, closeTo(236.089090362836, 1e-6));
    expect(stages[3].finalPerWeek, closeTo(234.908644911021, 1e-6));
    expect(inventory.total, closeTo(4259.19027444274, 1e-6));
  });

  test('Cada etapa hereda la población final de la anterior', () {
    final inventory = PorcinoStageInventory(
      weanedPerWeek: 100,
      specs: const [
        PorcinoStageSpec('A', weeks: 2, mortality: 0.10),
        PorcinoStageSpec('B', weeks: 3, mortality: 0.00),
      ],
    );
    final stages = inventory.stages;
    expect(stages[0].initialPerWeek, 100);
    expect(stages[0].finalPerWeek, closeTo(90, 1e-9));
    expect(stages[1].initialPerWeek, closeTo(90, 1e-9));
    expect(inventory.total, closeTo(2 * 90 + 3 * 90, 1e-9));
  });

  test('Rendimiento de etapa reproduce el pizarrón (15–30 kg, 23 días)', () {
    final perf = PorcinoStagePerformance(
      startKg: 15,
      endKg: 30,
      days: 23,
      dailyFeedKg: 0.9,
    );
    expect(perf.dailyGain, closeTo(0.652173913043478, 1e-9));
    expect(perf.averageKg, closeTo(22.5, 1e-9));
    expect(perf.totalFeed, closeTo(20.7, 1e-9));
    expect(perf.feedConversion, closeTo(1.38, 1e-2));
  });

  test('Conversión nula si la ganancia diaria es cero', () {
    final perf = PorcinoStagePerformance(
      startKg: 20,
      endKg: 20.0000001,
      days: 30,
      dailyFeedKg: 0.9,
    );
    expect(perf.feedConversion, greaterThan(0));
  });

  test('Rendimiento de canal reproduce el ejemplo (90 → 67.5 = 75 %)', () {
    final yield = PorcinoYield(inputKg: 90, outputKg: 67.5);
    expect(yield.percent, closeTo(75, 1e-9));
  });

  test('Rechaza entradas imposibles', () {
    expect(() => PorcinoBandFlow(sows: 0), throwsFormatException);
    expect(
      () => PorcinoBandFlow(sows: 550, infertility: 1),
      throwsFormatException,
    );
    expect(
      () => PorcinoBandFlow(sows: 550, bandIntervalDays: 0),
      throwsFormatException,
    );
    expect(
      () => PorcinoBandFlow(sows: 550, bornAlivePerLitter: 0),
      throwsFormatException,
    );
    expect(
      () => PorcinoStagePerformance(
        startKg: 30,
        endKg: 15,
        days: 10,
        dailyFeedKg: 1,
      ),
      throwsFormatException,
    );
    expect(
      () => PorcinoStagePerformance(
        startKg: 15,
        endKg: 30,
        days: 0,
        dailyFeedKg: 1,
      ),
      throwsFormatException,
    );
    expect(() => PorcinoYield(inputKg: 0, outputKg: 10), throwsFormatException);
    expect(
      () => PorcinoStageInventory(weanedPerWeek: -1),
      throwsFormatException,
    );
  });
}

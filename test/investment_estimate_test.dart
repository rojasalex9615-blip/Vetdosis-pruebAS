import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/finance/domain/investment_estimate.dart';

PriceSample s(int pesos, [String src = 'a']) =>
    PriceSample(pesos * 100, source: src);

void main() {
  group('PriceEstimate', () {
    test('mediana y cuartiles de cinco precios', () {
      final e = PriceEstimate.fromSamples([
        s(100, 'a'),
        s(110, 'b'),
        s(120, 'c'),
        s(130, 'd'),
        s(140, 'e'),
      ]);
      expect(e.medianCents, 12000);
      expect(e.lowCents, 11000);
      expect(e.highCents, 13000);
      expect(e.used, 5);
      expect(e.discarded, 0);
      expect(e.isReliable, isTrue);
    });

    test('descarta un valor atípico con cuatro o más precios', () {
      final e = PriceEstimate.fromSamples([
        s(100, 'a'),
        s(105, 'b'),
        s(110, 'c'),
        s(115, 'd'),
        s(9000, 'e'),
      ]);
      expect(e.discarded, 1);
      expect(e.used, 4);
      expect(e.medianCents, closeTo(10750, 1));
    });

    test('con tres precios no descarta nada', () {
      final e = PriceEstimate.fromSamples([s(10, 'a'), s(20, 'b'), s(900, 'c')]);
      expect(e.discarded, 0);
      expect(e.medianCents, 2000);
    });

    test('pocos precios o una sola fuente no es confiable', () {
      expect(PriceEstimate.fromSamples([s(10), s(12)]).isReliable, isFalse);
      expect(
        PriceEstimate.fromSamples([s(10), s(11), s(12)]).isReliable,
        isFalse, // las tres de la misma fuente
      );
    });

    test('ignora precios cero o negativos y falla si no queda ninguno', () {
      final e = PriceEstimate.fromSamples([
        const PriceSample(0, source: 'x'),
        const PriceSample(-5, source: 'x'),
        s(50, 'a'),
      ]);
      expect(e.used, 1);
      expect(
        () => PriceEstimate.fromSamples([const PriceSample(0, source: 'x')]),
        throwsFormatException,
      );
      expect(() => PriceEstimate.fromSamples([]), throwsFormatException);
    });
  });

  group('InvestmentPlan', () {
    PriceEstimate est(int a, int b, int c) => PriceEstimate.fromSamples([
      s(a, 'a'),
      s(b, 'b'),
      s(c, 'c'),
    ]);

    test('suma rangos por cantidad', () {
      final plan = InvestmentPlan([
        InvestmentItem(
          concept: 'Ventilador 36"',
          unit: 'pieza',
          quantity: 4,
          estimate: est(1000, 1200, 1400),
        ),
        InvestmentItem(
          concept: 'Comedero',
          unit: 'pieza',
          quantity: 10,
          estimate: est(200, 250, 300),
        ),
      ]);
      expect(plan.midCents, (1200 * 4 + 250 * 10) * 100);
      expect(plan.lowCents, (1100 * 4 + 225 * 10) * 100);
      expect(plan.highCents, (1300 * 4 + 275 * 10) * 100);
      expect(plan.isComplete, isTrue);
    });

    test('el precio manual manda y cierra el rango', () {
      final item = InvestmentItem(
        concept: 'Silo 10 t',
        unit: 'pieza',
        quantity: 2,
        manualUnitCents: 8000000,
        estimate: est(1, 2, 3),
      );
      expect(item.lowCents, 16000000);
      expect(item.highCents, 16000000);
      expect(item.isManual, isTrue);
      expect(item.isWeak, isFalse);
    });

    test('un concepto sin precio no entra al total y se avisa', () {
      final plan = InvestmentPlan([
        InvestmentItem(concept: 'Cielo-raso', unit: 'm²', quantity: 100),
        InvestmentItem(
          concept: 'Bebedero',
          unit: 'pieza',
          quantity: 5,
          manualUnitCents: 10000,
        ),
      ]);
      expect(plan.midCents, 50000);
      expect(plan.unpriced.map((i) => i.concept), ['Cielo-raso']);
      expect(plan.isComplete, isFalse);
    });

    test('estimado débil se marca', () {
      final plan = InvestmentPlan([
        InvestmentItem(
          concept: 'X',
          unit: 'pieza',
          quantity: 1,
          estimate: PriceEstimate.fromSamples([s(10)]),
        ),
      ]);
      expect(plan.weak.length, 1);
    });

    test('validaciones', () {
      expect(
        () => InvestmentItem(concept: ' ', unit: 'pieza', quantity: 1),
        throwsFormatException,
      );
      expect(
        () => InvestmentItem(concept: 'X', unit: 'pieza', quantity: 0),
        throwsFormatException,
      );
      expect(
        () => InvestmentItem(
          concept: 'X',
          unit: 'pieza',
          quantity: 1,
          manualUnitCents: -1,
        ),
        throwsFormatException,
      );
      expect(() => InvestmentPlan([]), throwsFormatException);
    });
  });
}

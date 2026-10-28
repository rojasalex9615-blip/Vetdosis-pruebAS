import '../../doses/domain/quantity.dart';
import 'inventory_models.dart';

Money partialReturnQuote(Map<String, dynamic> line, String input) {
  final sold = Quantity.parse('${line['quantity']}');
  final previous = Quantity.parse('${line['returned_quantity']}');
  final quantity = Quantity.parse(input);
  final cumulative = Quantity(
    previous.n * quantity.d + quantity.n * previous.d,
    previous.d * quantity.d,
  );
  if (!sold.positive || !quantity.positive || cumulative.compareTo(sold) > 0) {
    throw const FormatException('La cantidad supera lo pendiente de devolver.');
  }
  if (['unidad', 'frasco', 'caja'].contains(line['unit']) &&
      quantity.n % quantity.d != BigInt.zero) {
    throw const FormatException(
      'Esta presentación se devuelve en unidades enteras.',
    );
  }
  final result =
      Money.parse('${line['total']}').times(cumulative / sold) -
      Money.parse('${line['returned_amount']}');
  if (result.cents < BigInt.zero) {
    throw const FormatException('Actualiza la venta antes de devolver.');
  }
  return result;
}

class SaleReturnQuote {
  const SaleReturnQuote(this.credit, this.refund, this.commission);
  final Money credit, refund, commission;
  Money get balanceReduction => credit - refund;
}

SaleReturnQuote saleReturnQuote(
  Map<String, dynamic> line,
  String input,
  Map<String, dynamic> account,
) {
  final credit = partialReturnQuote(line, input);
  final commission = partialReturnQuote({
    ...line,
    'total': line['commission'] ?? '0',
    'returned_amount': line['returned_commission'] ?? '0',
  }, input);
  final excess =
      Money.parse('${account['paid']}') -
      Money.parse('${account['refunded']}') -
      (Money.parse('${account['net_total']}') - credit);
  final refund = excess.cents > BigInt.zero ? excess : Money(BigInt.zero);
  if (refund.cents > credit.cents) {
    throw const FormatException('Actualiza la cuenta antes de devolver.');
  }
  return SaleReturnQuote(credit, refund, commission);
}

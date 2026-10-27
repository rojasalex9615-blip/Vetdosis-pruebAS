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

import '../../doses/domain/quantity.dart';

class ApiaryHarvest {
  ApiaryHarvest({
    required String kilograms,
    required String productiveHives,
    required String days,
    required String priceKg,
    required String capturedCost,
  }) {
    total = positive(kilograms, 'Cosecha', zero: true);
    hives = positive(productiveHives, 'Colmenas productivas');
    duration = positive(days, 'Días');
    if (hives.n % hives.d != BigInt.zero ||
        duration.n % duration.d != BigInt.zero) {
      throw const FormatException('Colmenas y días deben ser enteros.');
    }
    perHive = total / hives;
    perDay = total / duration;
    revenue = priceKg.trim().isEmpty
        ? null
        : total * positive(priceKg, 'Precio', zero: true);
    cost = capturedCost.trim().isEmpty
        ? null
        : positive(capturedCost, 'Costo capturado', zero: true);
    balance = revenue == null || cost == null
        ? null
        : Quantity(
            revenue!.n * cost!.d - cost!.n * revenue!.d,
            revenue!.d * cost!.d,
          );
  }
  late final Quantity total, hives, duration, perHive, perDay;
  late final Quantity? revenue, cost, balance;
  static Quantity positive(String text, String label, {bool zero = false}) {
    final s = text.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d+(?:\.\d+)?$').hasMatch(s)) {
      throw FormatException(
        '$label: captura un número sin separadores de miles.',
      );
    }
    final q = Quantity.parse(s);
    if (q.n < BigInt.zero || (!zero && q.n == BigInt.zero)) {
      throw FormatException(
        '$label: debe ser ${zero ? 'cero o positivo' : 'mayor que cero'}.',
      );
    }
    return q;
  }
}

/// Maximum occupancy uses exact decimal multiplication and always rounds down.
class CapturedCapacity {
  CapturedCapacity({
    required String width,
    required String length,
    required String animalsPerM2,
  }) {
    area =
        ApiaryHarvest.positive(width, 'Ancho') *
        ApiaryHarvest.positive(length, 'Largo');
    final capacity = area * ApiaryHarvest.positive(animalsPerM2, 'Densidad');
    animals = capacity.n ~/ capacity.d;
  }
  late final Quantity area;
  late final BigInt animals;
}

String signedSessionAmount(Quantity value, {int places = 2}) =>
    '${value.n < BigInt.zero ? '-' : ''}${Quantity(value.n.abs(), value.d).display(places: places)}';

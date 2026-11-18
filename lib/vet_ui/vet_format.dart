/// Formato único de la app.
///
/// Existe porque cada pantalla traía su propia versión: Inicio pintaba
/// «$0,00 MXN» y Planes «$0.00 MXN», y las fechas aparecían en ISO
/// («2026-11-16») o en barras según dónde se mirara. Un mismo dato con dos
/// formatos se lee como dos datos distintos.
///
/// Este archivo es Dart puro, sin `material`, para que el dominio (dinero,
/// inventario, respaldo) pueda formatear sin arrastrar la capa de UI.
abstract final class VetFormat {
  const VetFormat._();

  static const _months = <String>[
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  /// Miles con separador de coma, como se escribe en México: `50000` → `50,000`.
  ///
  /// Conserva el signo y los decimales que ya traiga la cadena.
  static String thousands(Object? value) {
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty) return '';
    final match = RegExp(r'^(-?)(\d+)(\.\d+)?$').firstMatch(text);
    if (match == null) return text;
    final whole = match.group(2)!;
    final buffer = StringBuffer(match.group(1) ?? '');
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
      buffer.write(whole[i]);
    }
    buffer.write(match.group(3) ?? '');
    return buffer.toString();
  }

  /// Formato único de dinero: `$1,990.00 MXN`.
  ///
  /// Recibe un decimal ya resuelto («1990.00», «0», «-1.01»). El signo va
  /// delante del `$`. Si la entrada no es un número, la devuelve tal cual para
  /// no inventar una cifra.
  static String money(String decimal) {
    final text = decimal.trim();
    final match = RegExp(r'^(-?)(\d+)(?:\.(\d+))?$').firstMatch(text);
    if (match == null) return '\$$text MXN';
    final negative = match.group(1) == '-';
    final whole = thousands(match.group(2)!);
    final fraction = (match.group(3) ?? '').padRight(2, '0').substring(0, 2);
    return '${negative ? '-' : ''}\$$whole.$fraction MXN';
  }

  /// Igual que [money] pero sin el sufijo «MXN», para donde el contexto ya lo
  /// deja claro (una lista de precios de servicios).
  static String amount(String decimal) =>
      money(decimal).replaceAll(' MXN', '');

  /// Igual que [money] pero a partir de centavos enteros.
  static String moneyFromCents(Object? cents, {bool signed = false}) {
    final value = cents is BigInt
        ? cents
        : BigInt.tryParse('${cents ?? ''}'.trim()) ?? BigInt.zero;
    final n = value.abs();
    final decimal =
        '${signed && value.isNegative ? '-' : ''}'
        '${n ~/ BigInt.from(100)}.'
        '${(n % BigInt.from(100)).toString().padLeft(2, '0')}';
    return money(decimal);
  }

  /// Fecha corta legible: `22 oct 2026`. Nunca ISO ni barras.
  static String date(DateTime value) {
    final d = value.toLocal();
    return '${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  /// Convierte una fecha ISO (`2026-10-22T11:19:59.624686+00:00` o
  /// `2026-11-16`) a la forma corta. Devuelve la entrada si no es fecha.
  static String dateFromIso(Object? value) {
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty) return '';
    final parsed = DateTime.tryParse(text);
    return parsed == null ? text : date(parsed);
  }

  /// Rango de fechas: `22 oct 2026 → 21 dic 2026`.
  static String dateRange(Object? start, Object? end) =>
      '${dateFromIso(start)} → ${dateFromIso(end)}';

  /// Tamaño de almacenamiento redondeado: `0 MiB de 10 GiB`, no `0.0 MiB`.
  ///
  /// Quita el `.0` final para que un valor entero se lea entero y no como un
  /// decimal falso.
  static String size(Object? bytes) {
    final value = num.tryParse('${bytes ?? ''}'.trim()) ?? 0;
    if (value >= 1024 * 1024 * 1024) {
      return '${_trimZero(value / (1024 * 1024 * 1024))} GiB';
    }
    return '${_trimZero(value / (1024 * 1024))} MiB';
  }

  static String _trimZero(double value) {
    final text = value.toStringAsFixed(1);
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }

  /// Plural dinámico: `1 producto`, `2 productos`.
  static String plural(int count, String singular, String plural) =>
      '$count ${count == 1 ? singular : plural}';

  /// Zona horaria IANA a nombre legible: `America/Mexico_City` →
  /// `Ciudad de México (CST)`.
  static String timezone(String? iana) {
    final text = (iana ?? '').trim();
    if (text.isEmpty) return '';
    const known = <String, String>{
      'America/Mexico_City': 'Ciudad de México (CST)',
      'America/Monterrey': 'Monterrey (CST)',
      'America/Cancun': 'Cancún (EST)',
      'America/Chihuahua': 'Chihuahua (CST)',
      'America/Tijuana': 'Tijuana (PST)',
      'America/Mazatlan': 'Mazatlán (MST)',
      'America/Hermosillo': 'Hermosillo (MST)',
      'America/Merida': 'Mérida (CST)',
    };
    final direct = known[text];
    if (direct != null) return direct;
    // Desconocida: al menos quita el continente y cambia guiones por espacios,
    // para no mostrar una ruta interna cruda.
    final parts = text.split('/');
    final city = (parts.length > 1 ? parts.last : text).replaceAll('_', ' ');
    return city;
  }

  /// Traduce valores internos (enums, códigos) a texto legible.
  ///
  /// Sin esto se ven cosas como «clinic» o «beta» en medio de una frase en
  /// español.
  static String enumLabel(Object? value) {
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty) return '';
    const known = <String, String>{
      'clinic': 'Clínica',
      'personal': 'Personal',
      'beta': 'Beta',
      'free': 'Gratis',
      'individual': 'Individual',
      'team': 'Equipo',
      'monthly': 'Mensual',
      'annual': 'Anual',
      'admin': 'Administración',
      'mvz': 'MVZ',
      'revisor': 'Revisión',
    };
    return known[text.toLowerCase()] ?? text;
  }

  /// Une etiquetas evitando repetir la misma dos veces: «Clínica · clínica»
  /// pasa a «Clínica».
  static String joinDistinct(Iterable<Object?> parts, {String separator = ' · '}) {
    final seen = <String>{};
    final out = <String>[];
    for (final part in parts) {
      final label = '${part ?? ''}'.trim();
      if (label.isEmpty) continue;
      final key = label.toLowerCase();
      if (seen.add(key)) out.add(label);
    }
    return out.join(separator);
  }
}

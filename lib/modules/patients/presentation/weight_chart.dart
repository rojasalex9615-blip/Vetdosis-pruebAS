import 'package:flutter/material.dart';
import '../domain/patient_models.dart';

/// Peso en kg aceptando la coma decimal que se escribe en la consulta.
/// Un texto inválido no entra a la curva: se omite en vez de romper la hoja.
double? _kg(Object? value) {
  final texto = '${value ?? ''}'.trim().replaceAll(',', '.');
  if (texto.isEmpty) return null;
  final kg = double.tryParse(texto);
  return kg != null && kg > 0 ? kg : null;
}

class WeightChart extends StatelessWidget {
  const WeightChart({super.key, required this.events});
  final List<PatientEvent> events;
  @override
  Widget build(BuildContext context) {
    final weights = events
        .where(
          (e) =>
              e.kind == EventKind.weight &&
              _kg(e.data['kg']) != null &&
              DateTime.tryParse('${e.data['date']}') != null,
        )
        .toList()
      ..sort((a, b) {
        final date = (a.data['date'] as String).compareTo(
          b.data['date'] as String,
        );
        return date == 0 ? a.createdAt.compareTo(b.createdAt) : date;
      });
    if (weights.isEmpty) return const Text('Sin pesos registrados.');
    final values = weights.map((e) => _kg(e.data['kg'])!).toList();
    final min = values.reduce((a, b) => a < b ? a : b),
        max = values.reduce((a, b) => a > b ? a : b);
    final days = weights
        .map(
          (e) => DateTime.parse(
            e.data['date'] as String,
          ).millisecondsSinceEpoch.toDouble(),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Curva de peso (kg)'),
        Text(
          'Escala: $min–$max kg · ${weights.first.data['date']} a ${weights.last.data['date']}',
        ),
        if (weights.length > 1)
          SizedBox(
            height: 160,
            child: CustomPaint(
              painter: _WeightPainter(
                values,
                days,
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        for (final event in weights)
          Text(
            '${event.data['date']} · ${(event.data['kg'] as String).replaceAll('.', ',')} kg',
          ),
      ],
    );
  }
}

class _WeightPainter extends CustomPainter {
  _WeightPainter(this.values, this.days, this.color);
  final List<double> values, days;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final min = values.reduce((a, b) => a < b ? a : b),
        max = values.reduce((a, b) => a > b ? a : b);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    Offset point(int i) {
      final x = days.last == days.first
          ? (i / (values.length - 1))
          : (days[i] - days.first) / (days.last - days.first);
      final y = max == min ? 0.5 : 1 - (values[i] - min) / (max - min);
      return Offset(10 + x * (size.width - 20), 10 + y * (size.height - 20));
    }

    for (var i = 0; i < values.length; i++) {
      if (i > 0) canvas.drawLine(point(i - 1), point(i), paint);
      canvas.drawCircle(point(i), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WeightPainter old) => true;
}

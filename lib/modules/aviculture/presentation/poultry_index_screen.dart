import 'package:flutter/material.dart';
import '../../../core/widgets/calculator_surface.dart';
import '../../doses/domain/quantity.dart';
import '../data/aviculture_repository.dart';
import '../domain/poultry_formulas.dart';

/// Índices productivos de aves: engorda (conversión, ganancia) y postura
/// (viabilidad, mortalidad, % postura, peso de huevo, consumo, IP, forma).
class PoultryIndexScreen extends StatefulWidget {
  const PoultryIndexScreen({super.key});
  @override
  State<PoultryIndexScreen> createState() => _PoultryIndexScreenState();
}

class _PoultryIndexScreenState extends State<PoultryIndexScreen> {
  final repository = AvicultureRepository();
  late final future = repository.loadFormulas();
  final inputs = <String, TextEditingController>{};
  String selected = 'viabilidad';
  String result = '', error = '';
  TextEditingController controller(String key) =>
      inputs.putIfAbsent(key, TextEditingController.new);
  Quantity q(String key) => Quantity.parse(controller(key).text);
  @override
  void dispose() {
    for (final c in inputs.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget input(String key, String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: TextField(
      controller: controller(key),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => setState(() => result = ''),
    ),
  );

  void calculate() {
    const layers = LayerFormulas();
    const broilers = BroilerFormulas();
    try {
      final lines = <String>[];
      switch (selected) {
        case 'viabilidad':
          final v = layers.viability(q('actual'), q('inicial'));
          lines.add(
            'Viabilidad: ${q('actual').display()} × 100 / '
            '${q('inicial').display()} = ${v.display(places: 4)} %.',
          );
        case 'mortalidad_dia':
          final v = layers.dailyMortality(q('bajas'), q('actual'));
          lines.add(
            'Mortalidad del día: ${q('bajas').display()} × 100 / '
            '${q('actual').display()} = ${v.display(places: 4)} %.',
          );
        case 'mortalidad_acum':
          final v = layers.accumulatedMortality(q('bajas'), q('alojadas'));
          lines.add(
            'Mortalidad acumulada: ${q('bajas').display()} × 100 / '
            '${q('alojadas').display()} = ${v.display(places: 4)} %.',
          );
        case 'postura_pct':
          final v = layers.layingPercent(q('huevos'), q('existencia'));
          lines.add(
            '% postura: ${q('huevos').display()} × 100 / '
            '${q('existencia').display()} = ${v.display(places: 4)} %.',
          );
        case 'peso_huevo':
          final v = layers.eggWeightGrams(q('kg'), q('huevos'));
          lines.add(
            'Peso de huevo: ${q('kg').display()} kg × 1000 / '
            '${q('huevos').display()} = ${v.display(places: 4)} g.',
          );
        case 'consumo':
          final v = layers.intakeGramsPerBird(q('kg'), q('existencia'));
          lines.add(
            'Consumo: ${q('kg').display()} kg × 1000 / '
            '${q('existencia').display()} = ${v.display(places: 4)} g/ave/día.',
          );
        case 'ic_postura':
          final v = layers.feedConversion(q('kg_alimento'), q('kg_huevo'));
          lines.add(
            'Conversión de postura: ${q('kg_alimento').display()} / '
            '${q('kg_huevo').display()} = ${v.display(places: 4)} kg/kg.',
          );
        case 'masa_huevo_ave_dia':
          final v = layers.eggMassPerBirdDay(q('pct'), q('g'));
          lines.add(
            'Masa de huevo: ${q('pct').display()} % × ${q('g').display()} g / '
            '100 = ${v.display(places: 4)} g/ave/día.',
          );
        case 'indice_productividad':
          final v = layers.productivityIndex(q('masa'), q('dias'), q('ic'));
          lines.add(
            'IP: (${q('masa').display()} / ${q('dias').display()} / '
            '${q('ic').display()}) × 100 = ${v.display(places: 4)}.',
          );
          lines.add('Categoría: ${productivityIndexBand(v)}.');
        case 'indice_forma_huevo':
          final v = layers.shapeIndex(q('ancho'), q('largo'));
          lines.add(
            'Índice de forma: ${q('ancho').display()} / '
            '${q('largo').display()} × 100 = ${v.display(places: 4)}.',
          );
          lines.add('Categoría: ${shapeIndexBand(v)}.');
        case 'ic_engorda':
          final v = broilers.feedConversion(
            q('kg_alimento'),
            q('kg_vendida'),
            q('peso_pollito'),
          );
          lines.add(
            'Conversión de engorda: ${q('kg_alimento').display()} / '
            '(${q('kg_vendida').display()} − ${q('peso_pollito').display()}) = '
            '${v.display(places: 4)} kg/kg.',
          );
        case 'gdp_engorda':
          final v = broilers.dailyGain(q('peso'), q('dias'));
          lines.add(
            'Ganancia diaria: ${q('peso').display()} / '
            '${q('dias').display()} = ${v.display(places: 4)} kg/día.',
          );
      }
      setState(() {
        result = lines.join('\n\n');
        error = '';
      });
    } catch (e) {
      setState(() {
        result = '';
        error = e is FormatException ? e.message : 'Revisa los campos.';
      });
    }
  }

  static const _fields = <String, List<(String, String)>>{
    'viabilidad': [
      ('actual', 'Existencia actual'),
      ('inicial', 'Existencia inicial'),
    ],
    'mortalidad_dia': [
      ('bajas', 'Bajas del día'),
      ('actual', 'Existencia actual'),
    ],
    'mortalidad_acum': [
      ('bajas', 'Bajas acumuladas'),
      ('alojadas', 'Aves alojadas'),
    ],
    'postura_pct': [
      ('huevos', 'Huevos del día'),
      ('existencia', 'Existencias'),
    ],
    'peso_huevo': [('kg', 'Kg recolectados'), ('huevos', 'Huevos pesados')],
    'consumo': [
      ('kg', 'Alimento ofrecido (kg)'),
      ('existencia', 'Existencias'),
    ],
    'ic_postura': [
      ('kg_alimento', 'Kg de alimento'),
      ('kg_huevo', 'Kg de huevo'),
    ],
    'masa_huevo_ave_dia': [('pct', '% postura'), ('g', 'Peso del huevo (g)')],
    'indice_productividad': [
      ('masa', 'Masa de huevo acumulada'),
      ('dias', 'Días del periodo'),
      ('ic', 'Conversión'),
    ],
    'indice_forma_huevo': [('ancho', 'Ancho (mm)'), ('largo', 'Longitud (mm)')],
    'ic_engorda': [
      ('kg_alimento', 'Kg de alimento consumido'),
      ('kg_vendida', 'Kg de carne vendida'),
      ('peso_pollito', 'Peso del pollito (kg)'),
    ],
    'gdp_engorda': [('peso', 'Peso promedio (kg)'), ('dias', 'Días a venta')],
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Índices productivos avícolas')),
    body: FutureBuilder<PoultryFormulaCatalog>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('No se pudieron cargar las fórmulas avícolas.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final formula = snapshot.data!.byId(selected);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: CalculatorSurface(
            id: 'poultryIndex',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Índices productivos · fórmulas de clase sin verificar '
                  '(engorda: pptx CUCBA; postura: pdf exposición CUCBA 2024). '
                  'Cálculo racional exacto; no certifica desempeño.',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selected,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Índice'),
                  items: [
                    for (final f in snapshot.data!.formulas)
                      DropdownMenuItem(value: f.id, child: Text(f.title)),
                  ],
                  onChanged: (v) => setState(() {
                    if (v != null) selected = v;
                    result = '';
                  }),
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formula.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        SelectableText('Fórmula: ${formula.expression}'),
                        Text('Entradas: ${formula.inputs}'),
                        Text('Fuente: ${formula.source} · ${formula.status}'),
                        if (formula.note.isNotEmpty)
                          Text('Nota: ${formula.note}'),
                      ],
                    ),
                  ),
                ),
                for (final (key, label) in _fields[selected]!)
                  input(key, label),
                CalculatorActionButton(
                  id: 'poultryIndex',
                  onPressed: calculate,
                  child: const Text('Calcular índice'),
                ),
                if (error.isNotEmpty)
                  Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (result.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(result),
                    ),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Índices disponibles: engorda (conversión, ganancia diaria) '
                  'y postura (viabilidad, mortalidad diaria y acumulada, '
                  '% postura, peso de huevo, consumo, conversión, masa de '
                  'huevo, índice de productividad e índice de forma).',
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

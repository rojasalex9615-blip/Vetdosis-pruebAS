import 'package:flutter/material.dart';
import '../../../core/widgets/calculator_surface.dart';
import '../../doses/domain/quantity.dart';
import '../data/aviculture_repository.dart';
import '../domain/broiler_reference.dart';

/// Pollo de engorda: capacidad geométrica y por carga de lote, además de las
/// referencias de clase (densidad, cama, aire, temperatura, dietas).
class BroilerScreen extends StatefulWidget {
  const BroilerScreen({super.key});
  @override
  State<BroilerScreen> createState() => _BroilerScreenState();
}

class _BroilerScreenState extends State<BroilerScreen> {
  final repository = AvicultureRepository();
  late final future = repository.loadBroiler();
  final inputs = <String, TextEditingController>{};
  String ventilation = 'lados_abiertos_ventilacion_natural';
  String? densityStage;
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

  Widget input(String key, String label, {String? help}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: TextField(
      controller: controller(key),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, helperText: help),
      onChanged: (_) => setState(() => result = ''),
    ),
  );

  void calculate(BroilerCatalog catalog) {
    try {
      final area = q('area');
      final lines = <String>[];
      final stage = densityStage;
      if (stage != null) {
        final row = catalog.refs.firstWhere((r) => r.stage == stage);
        final lo = row.minQuantity!;
        final hi = row.maxQuantity!;
        lines.add(
          'Densidad de la fuente (${row.range}): capacidad entre '
          '${broilerCapacity(area, lo)} y ${broilerCapacity(area, hi)} aves '
          'para ${area.display()} m².',
        );
      }
      final load = catalog.maxDensityByVentilation(ventilation)!;
      final weight = q('weight');
      lines.add(
        'Carga máxima (${load.range}) a ${weight.display()} kg/ave: '
        '${broilerBirdsByLoad(area, load.minQuantity!, weight)} aves. '
        'Si la densidad por edad da más, manda el límite de carga.',
      );
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pollo de engorda · capacidad')),
    body: FutureBuilder<BroilerCatalog>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('No se pudieron cargar las referencias de engorda.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final catalog = snapshot.data!;
        final densities = catalog.byParameter('densidad');
        final ventilationRows = catalog.byParameter('densidad_maxima_lote');
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: CalculatorSurface(
            id: 'broiler',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Pollo de engorda · referencias de clase sin verificar '
                  '(CUCBA; tabla Cobb). Estimación geométrica y de carga; no '
                  'certifica ventilación, bienestar ni desempeño. No se elige '
                  'un valor de diseño automáticamente.',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: densityStage,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Densidad por edad (días)',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('No calcular densidad por edad'),
                    ),
                    for (final d in densities)
                      DropdownMenuItem<String?>(
                        value: d.stage,
                        child: Text('${d.stage} · ${d.range}'),
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    densityStage = v;
                    result = '';
                  }),
                ),
                DropdownButtonFormField<String>(
                  initialValue: ventilation,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Sistema de ventilación',
                  ),
                  items: [
                    for (final v in ventilationRows)
                      DropdownMenuItem(
                        value: v.system,
                        child: Text('${v.system} · ${v.range}'),
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    if (v != null) ventilation = v;
                    result = '';
                  }),
                ),
                input('area', 'Área de caseta (m²)'),
                input(
                  'weight',
                  'Peso objetivo de venta (kg/ave)',
                  help: 'La fuente fija el sacrificio a los 42 días.',
                ),
                CalculatorActionButton(
                  id: 'broiler',
                  onPressed: () => calculate(catalog),
                  child: const Text('Calcular capacidad'),
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
                _table('Temperatura de la caseta', [
                  for (final r in catalog.refs.where(
                    (r) => r.parameter.contains('temperatura'),
                  ))
                    '${r.stage}: ${r.range} · ${r.status}',
                ]),
                _table('Calidad del aire', [
                  for (final r in catalog.refs.where(
                    (r) =>
                        r.parameter.contains('calidad_aire') ||
                        r.parameter.contains('humedad'),
                  ))
                    '${r.parameter.replaceAll('_', ' ')}: ${r.range}',
                ]),
                _table('Cama y preparación', [
                  for (final r in catalog.refs.where(
                    (r) => r.stage == 'preparacion_caseta',
                  ))
                    '${r.system}: ${r.parameter.replaceAll('_', ' ')} · '
                        '${r.range}',
                ]),
                _table('Dieta y calendario', [
                  for (final r in catalog.refs.where(
                    (r) =>
                        r.parameter.contains('proteina') ||
                        r.stage == 'calendario' ||
                        r.parameter.startsWith('etapa_dias'),
                  ))
                    '${r.stage}: ${r.parameter.replaceAll('_', ' ')} · '
                        '${r.range}',
                ]),
                const Text(
                  'Todos los valores quedan sin verificar y no se '
                  'preseleccionan. La fila «alternativa» procede de otra '
                  'figura de la clase; se conserva la discrepancia.',
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Widget _table(String title, List<String> rows) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          for (final r in rows) Text(r),
        ],
      ),
    ),
  );
}

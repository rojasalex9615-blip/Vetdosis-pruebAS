import 'package:flutter/material.dart';
import '../../../core/widgets/calculator_surface.dart';
import '../../doses/domain/quantity.dart';
import '../data/aviculture_repository.dart';
import '../domain/layer_reference.dart';

/// Gallina de postura: plan de luz, huevos por ave y año según sistema,
/// metas de la ponedora eficiente, curva mensual y calidad del huevo.
class LayerReferenceScreen extends StatefulWidget {
  const LayerReferenceScreen({super.key});
  @override
  State<LayerReferenceScreen> createState() => _LayerReferenceScreenState();
}

class _LayerReferenceScreenState extends State<LayerReferenceScreen> {
  final repository = AvicultureRepository();
  late final future = repository.loadLayer();
  final inputs = <String, TextEditingController>{};
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

  void classify(LayerCatalog catalog) {
    try {
      final grams = q('egg_weight');
      final lines = <String>[];
      final weightClass = catalog.eggWeightClassFor(grams);
      lines.add(
        weightClass == null
            ? 'Peso de huevo ${grams.display()} g: fuera de las clases de la '
                  'fuente (S 0–53, M 53–63, L 63–73, XL ≥ 73 g). No se '
                  'aproxima.'
            : 'Peso de huevo ${grams.display()} g → clase '
                  '${weightClass.parameter.replaceAll('peso_huevo_', '')} '
                  '(${weightClass.range}).',
      );
      final air = q('air_cell');
      final category = catalog.airCellCategoryFor(air);
      lines.add(
        category == null
            ? 'Cámara de aire ${air.display()} mm: por encima de la '
                  'categoría B (hasta 9 mm).'
            : 'Cámara de aire ${air.display()} mm → '
                  '${category.stage.replaceAll('categoria_', 'categoría ')} '
                  '(${category.range}).',
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
    appBar: AppBar(title: const Text('Postura · referencias adicionales')),
    body: FutureBuilder<LayerCatalog>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('No se pudieron cargar las referencias de postura.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final catalog = snapshot.data!;
        final bySystem = catalog.byParameter('huevos_por_ave_por_ano');
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: CalculatorSurface(
            id: 'layer_reference',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Postura · referencias de clase sin verificar (CUCBA). No '
                  'certifica desempeño ni reemplaza el manual del proveedor. '
                  'La fila «alternativa» procede de otra figura de la clase; '
                  'se conserva la discrepancia en lugar de elegir una.',
                ),
                const SizedBox(height: 12),
                _table('Huevos por ave y año por sistema', [
                  for (final r in bySystem)
                    '${r.system.replaceAll('_', ' ')}: ${r.range}',
                ]),
                _table('Plan de luz', [
                  for (final r in catalog.lighting)
                    '${r.parameter.replaceAll('_', ' ')}: ${r.range}'
                        '${r.isAlert ? '' : ' · ${r.status}'}',
                ]),
                _table('Ponedora eficiente (18–90 semanas)', [
                  for (final r in catalog.refs.where(
                    (r) => r.parameter.startsWith('parametro_eficiente'),
                  ))
                    '${r.parameter.replaceAll('parametro_eficiente_', '').replaceAll('_', ' ')}: '
                        '${r.range}',
                ]),
                _table('Curva mensual (huevos/ave y peso del huevo)', [
                  for (final r in catalog.refs.where(
                    (r) =>
                        r.stage.startsWith('mes_') ||
                        r.stage == 'promedio_ciclo',
                  ))
                    '${r.stage.replaceAll('_', ' ')} · '
                        '${r.parameter.replaceAll('_', ' ')}: ${r.range}',
                ]),
                _table('Calidad del huevo', [
                  for (final r in catalog.refs.where(
                    (r) =>
                        r.stage == 'huevo' ||
                        r.stage.startsWith('huevo_') ||
                        r.stage == 'categoria_A' ||
                        r.stage == 'categoria_B',
                  ))
                    '${r.stage.replaceAll('_', ' ')} · '
                        '${r.parameter.replaceAll('_', ' ')}: ${r.range}',
                ]),
                const SizedBox(height: 12),
                input(
                  'egg_weight',
                  'Peso del huevo (g)',
                  help: 'Clasifica en S / M / L / XL con los cortes de la '
                      'fuente.',
                ),
                input('air_cell', 'Altura de cámara de aire (mm)'),
                CalculatorActionButton(
                  id: 'layer_reference',
                  onPressed: () => classify(catalog),
                  child: const Text('Clasificar'),
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
                  'Todos los valores quedan sin verificar y no se '
                  'preseleccionan. La crisis de las semanas 18–35 se conserva '
                  'como aviso (sin rango), no como valor de diseño.',
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

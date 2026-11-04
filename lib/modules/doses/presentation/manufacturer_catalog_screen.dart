import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../domain/manufacturer_catalog.dart';
import 'commercial_package_dose_screen.dart';

class ManufacturerEvidence extends StatelessWidget {
  const ManufacturerEvidence({super.key, required this.product});
  final ManufacturerProduct product;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(product.name, style: Theme.of(context).textTheme.titleLarge),
      Text(product.manufacturer),
      Text('Forma: ${product.form}'),
      Text('Ingredientes del índice: ${product.ingredients}'),
      Text('Investigación Grok: ${product.researchStatus}'),
      const Text(
        'Confirma que la ficha corresponde a la especie, concentración, presentación y vía del producto que usarás.',
      ),
      SelectableText(product.notes),
      TextButton(
        onPressed: () => launchUrl(
          Uri.parse(product.sourceUrl),
          mode: LaunchMode.externalApplication,
        ),
        child: const Text('Abrir ficha original PLM'),
      ),
      SelectableText(product.sourceUrl),
      ExpansionTile(
        title: const Text('Informe y fuentes de investigación'),
        children: [
          const Text(
            'El informe puede incluir otros productos. Usa únicamente la pauta de esta ficha y presentación.',
          ),
          SelectableText(product.reportText),
          TextButton(
            onPressed: () => launchUrl(
              Uri.parse(product.reportUrl),
              mode: LaunchMode.externalApplication,
            ),
            child: const Text('Abrir informe en Drive'),
          ),
        ],
      ),
    ],
  );
}

class ManufacturerCatalogScreen extends StatefulWidget {
  const ManufacturerCatalogScreen({
    super.key,
    this.selectOnly = false,
    this.canCalculate = false,
    this.catalog,
  });
  final bool selectOnly, canCalculate;
  final ManufacturerCatalog? catalog;
  @override
  State<ManufacturerCatalogScreen> createState() =>
      _ManufacturerCatalogScreenState();
}

class _ManufacturerCatalogScreenState extends State<ManufacturerCatalogScreen> {
  late final Future<ManufacturerCatalog> loading = widget.catalog == null
      ? ManufacturerCatalog.load()
      : Future.value(widget.catalog!);
  String query = '';
  int limit = 20;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Catálogo de fabricantes')),
    body: FutureBuilder<ManufacturerCatalog>(
      future: loading,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('No se pudo abrir el catálogo comercial.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final catalog = snapshot.data!;
        final matches = catalog.search(query);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${catalog.products.length} fichas comerciales · investigación Grok',
            ),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar producto, laboratorio o ingrediente',
              ),
              onChanged: (value) => setState(() {
                query = value;
                limit = 20;
              }),
            ),
            Text('${matches.length} resultados'),
            if (matches.isEmpty) const Text('No hay coincidencias.'),
            for (final product in matches.take(limit))
              Card(
                child: ListTile(
                  title: Text(product.name),
                  subtitle: Text('${product.manufacturer}\n${product.form}'),
                  onTap: () {
                    if (widget.selectOnly) {
                      Navigator.pop(context, product);
                      return;
                    }
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: Text(product.name)),
                          body: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              ManufacturerEvidence(product: product),
                              if (widget.canCalculate)
                                FilledButton.icon(
                                  icon: const Icon(Icons.calculate),
                                  label: const Text(
                                    'Calcular según el empaque',
                                  ),
                                  onPressed: () => Navigator.push<void>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          CommercialPackageDoseScreen(
                                            initialProduct: product,
                                          ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (limit < matches.length)
              TextButton(
                onPressed: () => setState(() => limit += 20),
                child: const Text('Mostrar más'),
              ),
            ExpansionTile(
              title: const Text('Historial de investigación'),
              children: [SelectableText(catalog.historyText)],
            ),
          ],
        );
      },
    ),
  );
}

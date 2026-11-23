import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../domain/manufacturer_catalog.dart';
import '../domain/manufacturer_pauta.dart';
import '../domain/pauta_review_gate.dart';
import 'commercial_package_dose_screen.dart';
import 'manufacturer_pauta_section.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_icons.dart';

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
    this.pautas,
  });
  final bool selectOnly, canCalculate;
  final ManufacturerCatalog? catalog;
  final ManufacturerPautaCatalog? pautas;
  @override
  State<ManufacturerCatalogScreen> createState() =>
      _ManufacturerCatalogScreenState();
}

class _ManufacturerCatalogScreenState extends State<ManufacturerCatalogScreen> {
  late final Future<ManufacturerCatalog> loading = widget.catalog == null
      ? ManufacturerCatalog.load()
      : Future.value(widget.catalog!);
  late final Future<ManufacturerPautaCatalog> pautaLoading =
      widget.pautas == null
      ? ManufacturerPautaCatalog.load()
      : Future.value(widget.pautas!);
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
                        builder: (_) => _ManufacturerProductDetail(
                          product: product,
                          canCalculate: widget.canCalculate,
                          pautas: pautaLoading,
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

/// Detalle de una ficha comercial con sus pautas documentadas.
///
/// El nombre comercial y la posología del empaque pertenecen a la calculadora
/// de empaque; por eso el botón solo aparece con una pauta proporcional al peso
/// en unidad de empaque y sin avisos. La dosis en mg/kg se muestra y se marca
/// para la calculadora por agente farmacéutico, que exige un fármaco verificado
/// del catálogo general (hoy vacío): no se precarga desde aquí.
class _ManufacturerProductDetail extends StatelessWidget {
  const _ManufacturerProductDetail({
    required this.product,
    required this.canCalculate,
    required this.pautas,
  });
  final ManufacturerProduct product;
  final bool canCalculate;
  final Future<ManufacturerPautaCatalog> pautas;

  void _calcular(BuildContext context, ManufacturerPauta pauta) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CommercialPackageDoseScreen(
          initialProduct: product,
          initialPauta: pauta,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(product.name)),
    body: FutureBuilder<ManufacturerPautaCatalog>(
      future: pautas,
      builder: (context, snapshot) {
        final catalog = snapshot.data;
        final delProducto = pautasVisibles(
          catalog?.forProduct(product.sourceUrl) ?? const [],
        );
        final deEmpaque = delProducto
            .where(
              (p) => p.canCalculate && p.calculator == PautaCalculator.package,
            )
            .toList();
        // Duplicados exactos (misma especie y misma pauta) no son una eleccion.
        final distintas = <ManufacturerPauta>[];
        for (final p in deEmpaque) {
          final key = '${p.species}|${p.doseAmount}|${p.doseUnit}|'
              '${p.doseReference}';
          if (distintas.any((q) => '${q.species}|${q.doseAmount}|'
              '${q.doseUnit}|${q.doseReference}' == key)) {
            continue;
          }
          distintas.add(p);
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ManufacturerEvidence(product: product),
            const Divider(),
            if (snapshot.hasError)
              const Text(
                'No se pudieron abrir las pautas. Usa la posología del empaque.',
              )
            else if (catalog == null)
              const Center(child: CircularProgressIndicator())
            else if (!mostrarPautasSinRevisar())
              const Text(
                'Las pautas del fabricante están pendientes de revisión '
                'clínica: esta versión no las muestra.',
              )
            else
              ManufacturerPautaSection(pautas: delProducto),
            if (canCalculate && deEmpaque.isNotEmpty) ...[
              const SizedBox(height: 8),
              // Con una sola pauta no hay nada que elegir. Con varias se pide
              // la especie: elegir la primera precargaba la dosis de otra
              // especie (FLUNIVET da 1 mL/45 kg en bovino y 2 mL/45 kg en
              // porcino, el doble).
              if (distintas.length == 1)
                FilledButton.icon(
                  icon: const Icon(VetIcons.calculator),
                  label: const Text('Calcular según el empaque'),
                  onPressed: () => _calcular(context, distintas.single),
                )
              else ...[
                const VetNotice(
                  text: 'Este producto tiene una pauta distinta por especie. '
                      'Elige la del animal que vas a tratar.',
                  icon: VetIcons.alertOctagon,
                  kind: VetBadgeKind.danger,
                ),
                for (final pauta in distintas)
                  OutlinedButton.icon(
                    icon: const Icon(VetIcons.calculator),
                    label: Text(
                      '${pauta.species.isEmpty ? 'Especie sin indicar' : pauta.species}'
                      ' · ${pauta.doseAmount} ${pauta.doseUnit} ${pauta.doseReference}',
                    ),
                    onPressed: () => _calcular(context, pauta),
                  ),
              ],
            ],
          ],
        );
      },
    ),
  );
}

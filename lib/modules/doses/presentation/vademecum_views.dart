import 'package:flutter/material.dart';

import '../../../vet_ui/vet_icons.dart';
import '../domain/catalog.dart';
import '../domain/manufacturer_pauta.dart';
import 'commercial_package_dose_screen.dart';
import 'manufacturer_pauta_section.dart';

/// Vademécum por fármaco: índice de principios activos de las pautas.
///
/// Es la vista de consulta de la calculadora por agente farmacéutico (mg/kg).
/// No convierte una mezcla comercial en una dosis: solo dice qué pautas
/// mencionan cada principio activo. El campo de búsqueda lo pone el padre.
class VademecumDrugView extends StatelessWidget {
  const VademecumDrugView({
    super.key,
    required this.pautas,
    this.query = '',
    this.canCalculate = false,
    this.onOpenDrugCalculator,
  });
  final List<ManufacturerPauta> pautas;
  final String query;
  final bool canCalculate;
  final VoidCallback? onOpenDrugCalculator;

  @override
  Widget build(BuildContext context) {
    final index = indexByIngredient(pautas);
    final needle = normalizeDoseSearch(query);
    final matches = needle.isEmpty
        ? index.take(15).toList()
        : index
              .where((i) => normalizeDoseSearch(i.name).contains(needle))
              .take(40)
              .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${index.length} principios activos en ${pautas.length} '
          'pautas del fabricante',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Text(
          'Consulta por principio activo. La dosis en mg/kg se calcula en la '
          'calculadora por agente farmacéutico con el catálogo verificado.',
        ),
        if (onOpenDrugCalculator != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onOpenDrugCalculator,
            icon: const Icon(VetIcons.calculator),
            label: const Text('Abrir calculadora por agente farmacéutico'),
          ),
        ],
        const SizedBox(height: 8),
        if (needle.isEmpty)
          const Text('Los 15 principios con más pautas. Escribe para buscar.'),
        if (needle.isNotEmpty && matches.isEmpty)
          const Text('No hay principios activos que coincidan.'),
        if (needle.isNotEmpty) Text('${matches.length} resultados'),
        for (final ingredient in matches)
          Card(
            margin: const EdgeInsets.only(top: 8),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(VetIcons.pills)),
              title: Text(ingredient.name),
              subtitle: Text(
                '${ingredient.pautas.length} pauta(s) · '
                '${ingredient.products.length} producto(s)',
              ),
              trailing: const Icon(VetIcons.chevronRight),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => PautaListScreen(
                    title: ingredient.name,
                    subtitle: 'Principio activo · solo consulta',
                    pautas: ingredient.pautas,
                    canCalculate: canCalculate,
                    onOpenDrugCalculator: onOpenDrugCalculator,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Vademécum por nombre comercial: productos con sus pautas.
///
/// Es la vista de consulta de la calculadora de dosis de empaque (mL,
/// tableta o sobre por kg). La calculadora solo aparece con una pauta
/// proporcional al peso y sin avisos de integridad.
class VademecumCommercialView extends StatelessWidget {
  const VademecumCommercialView({
    super.key,
    required this.pautas,
    this.query = '',
    this.canCalculate = false,
  });
  final List<ManufacturerPauta> pautas;
  final String query;
  final bool canCalculate;

  List<_ProductGroup> _groups(String needle) {
    final map = <String, _ProductGroup>{};
    for (final pauta in pautas) {
      final key = '${pauta.productName}|${pauta.manufacturer}';
      if (needle.isNotEmpty &&
          !normalizeDoseSearch(
            '${pauta.productName} ${pauta.manufacturer} ${pauta.ingredients}',
          ).contains(needle)) {
        continue;
      }
      map
          .putIfAbsent(
            key,
            () => _ProductGroup(pauta.productName, pauta.manufacturer),
          )
          .pautas
          .add(pauta);
    }
    final result = map.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final needle = normalizeDoseSearch(query);
    final all = _groups(needle);
    final shown = all.take(needle.isEmpty ? 20 : 40).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${all.length} productos comerciales · ${pautas.length} pautas',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Text(
          'Consulta por nombre comercial. El texto literal manda; la '
          'calculadora de empaque solo precarga reglas proporcionales.',
        ),
        const SizedBox(height: 8),
        if (needle.isEmpty)
          const Text(
            'Los primeros 20 productos. Escribe para buscar entre todos.',
          ),
        if (needle.isNotEmpty && shown.isEmpty)
          const Text('No hay productos que coincidan.'),
        if (needle.isNotEmpty) Text('${shown.length} resultados'),
        for (final group in shown)
          Card(
            margin: const EdgeInsets.only(top: 8),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(VetIcons.medicineBottle)),
              title: Text(group.name),
              subtitle: Text(
                '${group.manufacturer}\n${group.pautas.length} pauta(s)',
              ),
              isThreeLine: true,
              trailing: const Icon(VetIcons.chevronRight),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => PautaListScreen(
                    title: group.name,
                    subtitle: group.manufacturer,
                    pautas: group.pautas,
                    canCalculate: canCalculate,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProductGroup {
  _ProductGroup(this.name, this.manufacturer);
  final String name, manufacturer;
  final List<ManufacturerPauta> pautas = [];
}

/// Detalle de pautas de un principio activo o de un producto comercial.
class PautaListScreen extends StatelessWidget {
  const PautaListScreen({
    super.key,
    required this.title,
    required this.pautas,
    this.subtitle,
    this.canCalculate = false,
    this.onOpenDrugCalculator,
  });
  final String title;
  final String? subtitle;
  final List<ManufacturerPauta> pautas;
  final bool canCalculate;
  final VoidCallback? onOpenDrugCalculator;

  ManufacturerPauta? get _packagePauta {
    for (final pauta in pautas) {
      if (pauta.canCalculate && pauta.calculator == PautaCalculator.package) {
        return pauta;
      }
    }
    return null;
  }

  bool get _hasAgentPauta => pautas.any(
    (p) => p.canCalculate && p.calculator == PautaCalculator.agent,
  );

  @override
  Widget build(BuildContext context) {
    final packagePauta = canCalculate ? _packagePauta : null;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (subtitle != null && subtitle!.isNotEmpty) Text(subtitle!),
          if (packagePauta != null) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CommercialPackageDoseScreen(initialPauta: packagePauta),
                ),
              ),
              icon: const Icon(VetIcons.calculator),
              label: const Text('Calcular según el empaque'),
            ),
          ],
          if (_hasAgentPauta) ...[
            const SizedBox(height: 8),
            if (onOpenDrugCalculator != null)
              OutlinedButton.icon(
                onPressed: onOpenDrugCalculator,
                icon: const Icon(VetIcons.calculator),
                label: const Text('Calcular dosis en mg/kg'),
              )
            else
              const Text(
                'La dosis en mg/kg se calcula en la calculadora por agente '
                'farmacéutico con el catálogo verificado.',
              ),
          ],
          const SizedBox(height: 8),
          ManufacturerPautaSection(pautas: pautas),
        ],
      ),
    );
  }
}

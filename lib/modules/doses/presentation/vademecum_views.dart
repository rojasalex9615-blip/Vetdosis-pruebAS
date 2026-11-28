import 'package:flutter/material.dart';

import '../../../vet_ui/vet_icons.dart';
import '../domain/catalog.dart';
import '../domain/manufacturer_pauta.dart';
import 'commercial_package_dose_screen.dart';
import 'manufacturer_pauta_section.dart';

/// Vademécum por principio activo: índice de agentes de las pautas.
///
/// Es la vista de consulta de la calculadora por agente farmacéutico (mg/kg).
/// No convierte una mezcla comercial en una dosis: dice qué marcas contienen
/// cada principio activo y qué pautas lo mencionan. Tiene su propia búsqueda y
/// su filtro de especie: no comparte estado con el vademécum comercial.
class VademecumDrugView extends StatefulWidget {
  const VademecumDrugView({
    super.key,
    required this.pautas,
    this.query = '',
    this.canCalculate = false,
    this.onOpenDrugCalculator,
  });
  final List<ManufacturerPauta> pautas;

  /// Búsqueda con la que abre la vista. Después manda el campo de la pantalla.
  final String query;

  final bool canCalculate;
  final VoidCallback? onOpenDrugCalculator;

  @override
  State<VademecumDrugView> createState() => _VademecumDrugViewState();
}

class _VademecumDrugViewState extends State<VademecumDrugView> {
  late String _query = widget.query;
  String _especie = 'Todas';
  bool _verTodo = false;

  @override
  void didUpdateWidget(VademecumDrugView old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) _query = widget.query;
  }

  void _cambiarEspecie(String especie) => setState(() {
    _especie = especie;
    _verTodo = false;
  });

  @override
  Widget build(BuildContext context) {
    final porEspecie = [
      for (final p in widget.pautas)
        if (pautaDeEspecie(p, _especie)) p,
    ];
    final index = indexByIngredient(porEspecie);
    final needle = normalizeDoseSearch(_query);
    final matches = needle.isEmpty
        ? index
        : index
              .where((i) => normalizeDoseSearch(i.name).contains(needle))
              .toList();
    final adelanto = needle.isEmpty ? 15 : 40;
    final shown = _verTodo ? matches : matches.take(adelanto).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: 'Buscar principio activo',
            prefixIcon: Icon(VetIcons.search),
          ),
          onChanged: (value) => setState(() {
            _query = value;
            _verTodo = false;
          }),
        ),
        const SizedBox(height: 8),
        SpeciesFilter(
          pautas: widget.pautas,
          seleccion: _especie,
          onChanged: _cambiarEspecie,
        ),
        const SizedBox(height: 8),
        Text(
          '${index.length} principios activos en ${porEspecie.length} pautas '
          'del fabricante',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Text(
          'Consulta por principio activo: qué marcas lo contienen y en qué '
          'especie. La dosis en mg/kg se calcula en la calculadora por agente '
          'farmacéutico con el catálogo verificado.',
        ),
        if (widget.onOpenDrugCalculator != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: widget.onOpenDrugCalculator,
            icon: const Icon(VetIcons.calculator),
            label: const Text('Abrir calculadora por agente farmacéutico'),
          ),
        ],
        const SizedBox(height: 8),
        if (needle.isEmpty && index.isNotEmpty)
          Text(
            'Mostrando ${shown.length} de ${index.length}, los de más pautas '
            'primero. Escribe para buscar.',
          ),
        if (needle.isNotEmpty) Text('${matches.length} resultados'),
        if (matches.isEmpty && needle.isNotEmpty)
          const Text('No hay principios activos que coincidan.'),
        for (final ingredient in shown)
          Card(
            margin: const EdgeInsets.only(top: 8),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(VetIcons.pills)),
              title: Text(ingredient.name),
              subtitle: Text(_marcas(ingredient)),
              isThreeLine: true,
              trailing: const Icon(VetIcons.chevronRight),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => PautaListScreen(
                    title: ingredient.name,
                    subtitle:
                        'Principio activo · ${ingredient.products.length} '
                        'marca(s)',
                    pautas: ingredient.pautas,
                    canCalculate: widget.canCalculate,
                    onOpenDrugCalculator: widget.onOpenDrugCalculator,
                  ),
                ),
              ),
            ),
          ),
        if (matches.length > shown.length)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton(
              onPressed: () => setState(() => _verTodo = true),
              child: Text('Ver los ${matches.length} principios activos'),
            ),
          ),
      ],
    );
  }

  /// «3 pauta(s) · 2 producto(s)» y las primeras marcas, para que el nombre
  /// comercial aparezca junto al principio activo y no solo dentro de la ficha.
  String _marcas(ManufacturerIngredient ingredient) {
    final productos = ingredient.products.toList()..sort();
    final muestra = productos.take(2).join(', ');
    final resto = productos.length - 2;
    final marcas = resto > 0 ? '$muestra y $resto más' : muestra;
    return '${ingredient.pautas.length} pauta(s) · '
        '${productos.length} producto(s)\n$marcas';
  }
}

/// Vademécum por nombre comercial: productos con sus pautas.
///
/// Es la vista de consulta de la calculadora de dosis de empaque (mL,
/// tableta o sobre por kg). La calculadora solo aparece con una pauta
/// proporcional al peso y sin avisos de integridad.
class VademecumCommercialView extends StatefulWidget {
  const VademecumCommercialView({
    super.key,
    required this.pautas,
    this.query = '',
    this.canCalculate = false,
  });
  final List<ManufacturerPauta> pautas;

  /// Búsqueda con la que abre la vista. Después manda el campo de la pantalla.
  final String query;

  final bool canCalculate;

  @override
  State<VademecumCommercialView> createState() =>
      _VademecumCommercialViewState();
}

class _VademecumCommercialViewState extends State<VademecumCommercialView> {
  late String _query = widget.query;
  String _especie = 'Todas';
  bool _verTodo = false;

  @override
  void didUpdateWidget(VademecumCommercialView old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) _query = widget.query;
  }

  void _cambiarEspecie(String especie) => setState(() {
    _especie = especie;
    _verTodo = false;
  });

  List<_ProductGroup> _groups(String needle) {
    final map = <String, _ProductGroup>{};
    for (final pauta in widget.pautas) {
      if (!pautaDeEspecie(pauta, _especie)) continue;
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
    final needle = normalizeDoseSearch(_query);
    final all = _groups(needle);
    final adelanto = needle.isEmpty ? 20 : 40;
    final shown = _verTodo ? all : all.take(adelanto).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: 'Buscar marca, laboratorio o principio activo',
            prefixIcon: Icon(VetIcons.search),
          ),
          onChanged: (value) => setState(() {
            _query = value;
            _verTodo = false;
          }),
        ),
        const SizedBox(height: 8),
        SpeciesFilter(
          pautas: widget.pautas,
          seleccion: _especie,
          onChanged: _cambiarEspecie,
        ),
        const SizedBox(height: 8),
        Text(
          '${all.length} productos comerciales · ${widget.pautas.length} pautas',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Text(
          'Consulta por nombre comercial: qué contiene la marca y qué pautas '
          'indica el fabricante. El texto literal manda; la calculadora de '
          'empaque solo precarga reglas proporcionales.',
        ),
        const SizedBox(height: 8),
        if (needle.isEmpty && all.isNotEmpty)
          Text(
            'Mostrando ${shown.length} de ${all.length}, en orden alfabético. '
            'Escribe para buscar.',
          ),
        if (needle.isNotEmpty) Text('${all.length} resultados'),
        if (all.isEmpty && needle.isNotEmpty)
          const Text('No hay productos que coincidan.'),
        for (final group in shown)
          Card(
            margin: const EdgeInsets.only(top: 8),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(VetIcons.medicineBottle)),
              title: Text(group.name),
              subtitle: Text(
                '${group.manufacturer}\n'
                '${group.pautas.length} pauta(s) · '
                '${group.pautas.first.ingredients}',
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
                    canCalculate: widget.canCalculate,
                  ),
                ),
              ),
            ),
          ),
        if (all.length > shown.length)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton(
              onPressed: () => setState(() => _verTodo = true),
              child: Text('Ver los ${all.length} productos'),
            ),
          ),
      ],
    );
  }
}

/// Filtro por especie. Cuenta las pautas de cada grupo y solo enseña los que
/// aparecen en el archivo, para no llenar la fila de ceros.
class SpeciesFilter extends StatelessWidget {
  const SpeciesFilter({
    super.key,
    required this.pautas,
    required this.seleccion,
    required this.onChanged,
  });

  final List<ManufacturerPauta> pautas;
  final String seleccion;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final conteo = <String, int>{};
    for (final pauta in pautas) {
      for (final grupo in gruposDeEspecie(pauta.species)) {
        conteo[grupo] = (conteo[grupo] ?? 0) + 1;
      }
    }
    final grupos = [
      'Todas',
      ...especiesDelVademecum.where((g) => (conteo[g] ?? 0) > 0),
      if ((conteo['Sin especificar'] ?? 0) > 0) 'Sin especificar',
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          for (final grupo in grupos)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  grupo == 'Todas'
                      ? 'Todas (${pautas.length})'
                      : '$grupo (${conteo[grupo]})',
                ),
                selected: seleccion == grupo,
                onSelected: (_) => onChanged(grupo),
              ),
            ),
        ],
      ),
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

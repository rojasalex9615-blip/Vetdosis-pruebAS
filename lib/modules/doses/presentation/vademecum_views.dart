import 'package:flutter/material.dart';

import '../../../vet_ui/vet_icons.dart';
import '../domain/catalog.dart';
import '../domain/manufacturer_pauta.dart';
import 'commercial_package_dose_screen.dart';
import 'manufacturer_pauta_section.dart';

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

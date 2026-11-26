import 'package:flutter/material.dart';

import '../../../vet_ui/vet_icons.dart';
import '../domain/catalog.dart';
import '../domain/manufacturer_pauta.dart';
import '../domain/pauta_farmacologica.dart';

/// Vademécum por principio activo, alimentado por la tabla de dosis.
///
/// Cada pauta conserva autor, edición y página. Las marcas aparecen dentro de
/// la ficha del principio: sirven para reconocer el producto en el mostrador,
/// nunca para convertir una presentación comercial en una dosis.
class VademecumFarmacologicoView extends StatefulWidget {
  const VademecumFarmacologicoView({
    super.key,
    required this.catalog,
    this.marcas = const [],
    this.query = '',
    this.onOpenDrugCalculator,
  });

  final FarmacologicoCatalog catalog;

  /// Pautas comerciales, solo para nombrar las marcas que contienen cada
  /// principio. No aportan dosis a esta vista.
  final List<ManufacturerPauta> marcas;

  final String query;
  final VoidCallback? onOpenDrugCalculator;

  @override
  State<VademecumFarmacologicoView> createState() =>
      _VademecumFarmacologicoViewState();
}

class _VademecumFarmacologicoViewState
    extends State<VademecumFarmacologicoView> {
  late String _query = widget.query;
  String _especie = 'Todas';
  bool _verTodo = false;
  late Map<String, Set<String>> _marcasPorPrincipio = _indexarMarcas();
  late final Map<String, int> _pautasPorPrincipio = _contarPautas();

  Map<String, int> _contarPautas() {
    final cuenta = <String, int>{};
    for (final pauta in widget.catalog.pautas) {
      cuenta[pauta.idFarmaco] = (cuenta[pauta.idFarmaco] ?? 0) + 1;
    }
    return cuenta;
  }

  @override
  void didUpdateWidget(VademecumFarmacologicoView old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) _query = widget.query;
    if (old.marcas != widget.marcas) _marcasPorPrincipio = _indexarMarcas();
  }

  /// Qué productos declaran cada principio. Se compara sobre el nombre sin
  /// acentos y solo con nombres de cuatro letras o más, para no emparejar por
  /// fragmentos («ácido» con «ácido acetilsalicílico»).
  Map<String, Set<String>> _indexarMarcas() {
    if (widget.marcas.isEmpty) return const {};
    final porNombre = <String, Set<String>>{};
    for (final ingrediente in indexByIngredient(widget.marcas)) {
      final clave = normalizeDoseSearch(ingrediente.name);
      if (clave.length < 4) continue;
      porNombre.putIfAbsent(clave, () => <String>{}).addAll(
        ingrediente.products,
      );
    }
    final resultado = <String, Set<String>>{};
    for (final principio in widget.catalog.principios) {
      final nombre = normalizeDoseSearch(principio.nombre);
      final marcas = <String>{};
      for (final entrada in porNombre.entries) {
        if (nombre == entrada.key ||
            (entrada.key.length >= 4 && nombre.contains(entrada.key))) {
          marcas.addAll(entrada.value);
        }
      }
      if (marcas.isNotEmpty) resultado[principio.id] = marcas;
    }
    return resultado;
  }

  void _cambiarEspecie(String especie) => setState(() {
    _especie = especie;
    _verTodo = false;
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final especie = _especie == 'Todas' ? null : _especie;
    final principios = [...widget.catalog.buscar(_query, especie: especie)]
      ..sort((a, b) {
        final porPautas = (_pautasPorPrincipio[b.id] ?? 0).compareTo(
          _pautasPorPrincipio[a.id] ?? 0,
        );
        return porPautas != 0
            ? porPautas
            : a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
      });
    final hayBusqueda = normalizeDoseSearch(_query).isNotEmpty;
    final adelanto = hayBusqueda ? 40 : 25;
    final mostrados = _verTodo
        ? principios
        : principios.take(adelanto).toList(growable: false);
    final totalPautas = widget.catalog.pautas
        .where((p) => especie == null || p.especies.contains(especie))
        .length;

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
        _FiltroEspecie(
          especies: widget.catalog.especies,
          seleccion: _especie,
          onChanged: _cambiarEspecie,
        ),
        const SizedBox(height: 8),
        Text(
          '${principios.length} principios activos · $totalPautas pautas',
          style: theme.textTheme.titleMedium,
        ),
        const Text(
          'Cada pauta indica su autor, edición y página. Las marcas que '
          'aparecen en la ficha sirven para reconocer el producto; la dosis '
          'sale siempre de la pauta, no de la presentación comercial.',
        ),
        if (widget.onOpenDrugCalculator != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: widget.onOpenDrugCalculator,
            icon: const Icon(VetIcons.calculator),
            label: const Text('Abrir calculadora de dosis'),
          ),
        ],
        const SizedBox(height: 8),
        if (hayBusqueda) Text('${principios.length} resultados'),
        if (!hayBusqueda && principios.length > mostrados.length)
          Text(
            'Mostrando ${mostrados.length} de ${principios.length}, los de más '
            'pautas primero.',
          ),
        if (principios.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('No hay principios activos que coincidan.'),
          ),
        for (final principio in mostrados)
          _PrincipioCard(
            principio: principio,
            pautas: widget.catalog.pautasDe(principio.id, especie: especie),
            marcas: _marcasPorPrincipio[principio.id] ?? const {},
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => PrincipioActivoScreen(
                  principio: principio,
                  pautas: widget.catalog.pautasDe(principio.id),
                  marcas: _marcasPorPrincipio[principio.id] ?? const {},
                ),
              ),
            ),
          ),
        if (principios.length > mostrados.length)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton(
              onPressed: () => setState(() => _verTodo = true),
              child: Text('Ver los ${principios.length} principios activos'),
            ),
          ),
      ],
    );
  }
}

class _PrincipioCard extends StatelessWidget {
  const _PrincipioCard({
    required this.principio,
    required this.pautas,
    required this.marcas,
    required this.onTap,
  });

  final PrincipioActivo principio;
  final List<PautaFarmacologica> pautas;
  final Set<String> marcas;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final especies = {
      for (final p in pautas) ...p.especies,
    }.toList()..sort();
    final detalle = [
      '${pautas.length} pauta(s)',
      if (especies.isNotEmpty) especies.join(', '),
      if (marcas.isNotEmpty) '${marcas.length} marca(s)',
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(VetIcons.pills)),
        title: Text(principio.nombre),
        subtitle: Text(detalle),
        isThreeLine: false,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (principio.grupo != null) _GrupoChip(grupo: principio.grupo!),
            const Icon(VetIcons.chevronRight),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Ficha de un principio: todas sus pautas con su cita, y las marcas que lo
/// declaran.
class PrincipioActivoScreen extends StatelessWidget {
  const PrincipioActivoScreen({
    super.key,
    required this.principio,
    required this.pautas,
    this.marcas = const {},
  });

  final PrincipioActivo principio;
  final List<PautaFarmacologica> pautas;
  final Set<String> marcas;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Se agrupa por la especie que escribe la fuente, no por cada especie de
    // la lista: una pauta de «perro y gato» es una sola pauta.
    final porEspecie = <String, List<PautaFarmacologica>>{};
    for (final pauta in pautas) {
      final grupo = pauta.especie.isEmpty ? 'Sin especie' : pauta.especie;
      porEspecie.putIfAbsent(grupo, () => []).add(pauta);
    }
    final especies = porEspecie.keys.toList()..sort();
    return Scaffold(
      appBar: AppBar(title: Text(principio.nombre)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (principio.grupo != null) ...[
            Row(
              children: [
                _GrupoChip(grupo: principio.grupo!),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Acuerdo DOF 05/03/2012 · nivel de riesgo'),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'Dosis publicadas',
            style: theme.textTheme.titleMedium,
          ),
          if (pautas.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Este principio no tiene pautas cargadas.'),
            ),
          for (final especie in especies) ...[
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 4),
              child: Text(especie, style: theme.textTheme.titleSmall),
            ),
            for (final pauta in porEspecie[especie]!) _PautaCard(pauta: pauta),
          ],
          const SizedBox(height: 24),
          Text(
            marcas.isEmpty
                ? 'Marcas que lo contienen'
                : 'Marcas que lo contienen (${marcas.length})',
            style: theme.textTheme.titleMedium,
          ),
          if (marcas.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Ninguna marca del catálogo comercial declara este principio. '
                'Eso no significa que no exista: significa que no está '
                'registrada en la app.',
              ),
            )
          else
            for (final marca in (marcas.toList()..sort()))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('· $marca'),
              ),
        ],
      ),
    );
  }
}

class _PautaCard extends StatelessWidget {
  const _PautaCard({required this.pauta});

  final PautaFarmacologica pauta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final datos = <(String, String?)>[
      ('Vía', pauta.via),
      ('Frecuencia', pauta.intervalo),
      ('Duración', pauta.duracion),
    ];
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pauta.indicacion.isNotEmpty)
              Text(pauta.indicacion, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(pauta.dosisTexto, style: theme.textTheme.headlineSmall),
            if (pauta.especie.isNotEmpty)
              Text(pauta.especie, style: theme.textTheme.bodySmall),
            for (final (etiqueta, valor) in datos)
              if (valor != null && valor.isNotEmpty && valor != '--')
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('$etiqueta: $valor'),
                ),
            if (pauta.contraindicaciones != null &&
                pauta.contraindicaciones!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Precauciones: ${pauta.contraindicaciones}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            if (!pauta.calculable)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  pauta.dosisMin == null
                      ? 'Sin rango numérico: se lee, no se calcula.'
                      : 'Unidad no convertible al peso: se lee, no se calcula.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Text(
              pauta.cita,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GrupoChip extends StatelessWidget {
  const _GrupoChip({required this.grupo});

  final String grupo;

  @override
  Widget build(BuildContext context) {
    final color = switch (grupo) {
      'I' => const Color(0xFFB3261E),
      'II' => const Color(0xFFB26A00),
      _ => const Color(0xFF3F6212),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        'Grupo $grupo',
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _FiltroEspecie extends StatelessWidget {
  const _FiltroEspecie({
    required this.especies,
    required this.seleccion,
    required this.onChanged,
  });

  final List<String> especies;
  final String seleccion;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final opciones = ['Todas', ...especies];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final especie in opciones)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(especie),
                selected: seleccion == especie,
                onSelected: (_) => onChanged(especie),
              ),
            ),
        ],
      ),
    );
  }
}

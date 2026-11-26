import 'package:flutter/material.dart';

import '../../../vet_ui/vet_icons.dart';
import '../domain/manufacturer_pauta.dart';
import '../domain/pauta_farmacologica.dart';
import '../domain/tabla_dosis.dart';

/// Carga los dos vademécums y arma la tabla acumulativa una sola vez.
class TablaDosisLoader extends StatefulWidget {
  const TablaDosisLoader({super.key, this.tabla});

  /// Tabla ya armada, para pruebas o para reusar la que está en memoria.
  final TablaDosis? tabla;

  /// Arma la tabla con los dos catálogos que trae la app.
  static Future<TablaDosis> cargarReal() async {
    final principios = await FarmacologicoCatalog.load();
    final marcas = await ManufacturerPautaCatalog.load();
    return TablaDosis.desde(principios: principios, marcas: marcas.pautas);
  }

  @override
  State<TablaDosisLoader> createState() => _TablaDosisLoaderState();
}

class _TablaDosisLoaderState extends State<TablaDosisLoader> {
  late final Future<TablaDosis> _futuro = _cargar();

  Future<TablaDosis> _cargar() async {
    final inyectada = widget.tabla;
    if (inyectada != null) return inyectada;
    return TablaDosisLoader.cargarReal();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<TablaDosis>(
    future: _futuro,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No se pudo armar la tabla. Revisa que los dos vademécums estén '
            'en la app.',
          ),
        );
      }
      final tabla = snapshot.data;
      if (tabla == null) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Reuniendo principios y marcas…'),
        );
      }
      return TablaDosisScreen(tabla: tabla);
    },
  );
}

/// Tabla acumulativa de dosis: las 15 columnas de los dos catálogos en una
/// sola lista de consulta.
class TablaDosisScreen extends StatefulWidget {
  const TablaDosisScreen({super.key, required this.tabla});

  final TablaDosis tabla;

  @override
  State<TablaDosisScreen> createState() => _TablaDosisScreenState();
}

class _TablaDosisScreenState extends State<TablaDosisScreen> {
  final search = TextEditingController();
  String consulta = '';
  OrigenDosis? origen;
  String? especie;

  @override
  void initState() {
    super.initState();
    search.addListener(() {
      if (mounted) setState(() => consulta = search.text);
    });
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filas = widget.tabla.buscar(consulta, origen: origen, especie: especie);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Tabla acumulativa de dosis',
          style: theme.textTheme.titleLarge,
        ),
        Text(widget.tabla.nota, style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        Text(
          '${widget.tabla.filas.length} filas · '
          '${widget.tabla.dePrincipios} de principios activos · '
          '${widget.tabla.deMarcas} de marcas',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: search,
          decoration: const InputDecoration(
            labelText: 'Buscar en las 15 columnas',
            prefixIcon: Icon(VetIcons.search),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Todo'),
              selected: origen == null,
              onSelected: (_) => setState(() => origen = null),
            ),
            for (final opcion in OrigenDosis.values)
              ChoiceChip(
                label: Text(opcion.etiqueta),
                selected: origen == opcion,
                onSelected: (_) => setState(() => origen = opcion),
              ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          initialValue: especie,
          decoration: const InputDecoration(labelText: 'Especie'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Todas')),
            for (final valor in widget.tabla.especies)
              DropdownMenuItem(value: valor, child: Text(valor)),
          ],
          onChanged: (valor) => setState(() => especie = valor),
        ),
        const SizedBox(height: 12),
        Text(
          filas.isEmpty
              ? 'Ninguna fila coincide con la búsqueda.'
              : '${filas.length} filas',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        for (final fila in filas.take(200)) _FilaCard(fila),
        if (filas.length > 200)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Se muestran las primeras 200. Escribe en el buscador para '
              'llegar al resto.',
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _FilaCard extends StatelessWidget {
  const _FilaCard(this.fila);

  final FilaDosis fila;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(fila.origen.etiqueta),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fila.titulo,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (final campo in fila.columnas.entries.skip(1))
              _Campo(campo.key, campo.value),
          ],
        ),
      ),
    );
  }
}

class _Campo extends StatelessWidget {
  const _Campo(this.etiqueta, this.valor);

  final String etiqueta, valor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$etiqueta: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: valor),
          ],
        ),
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}

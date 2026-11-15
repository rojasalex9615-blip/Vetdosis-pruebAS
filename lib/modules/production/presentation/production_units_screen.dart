import 'package:flutter/material.dart';

import '../../../core/widgets/contrast.dart';
import '../domain/production_unit.dart';
import '../domain/production_unit_repository.dart';

/// Registro de unidades de produccion de una especie y actividad.
///
/// Es el primer apartado de produccion que guarda de verdad. Hasta ahora la
/// seccion solo ofrecia una lista de nombres con «En preparacion».
///
/// La pantalla no evalua ni clasifica: muestra lo que se ha escrito. El
/// conteo es un dato capturado por el profesional, no una meta ni un calculo.
class ProductionUnitsScreen extends StatefulWidget {
  const ProductionUnitsScreen({
    super.key,
    required this.repository,
    required this.userId,
    required this.clinicId,
    required this.species,
    required this.activity,
  });

  /// Donde se guardan las unidades.
  final ProductionUnitRepository repository;

  /// Cuenta que las consulta.
  final String userId;

  /// Espacio de trabajo activo.
  final String clinicId;

  /// Especie seleccionada en el menu.
  final String species;

  /// Actividad seleccionada en el menu.
  final String activity;

  @override
  State<ProductionUnitsScreen> createState() => _ProductionUnitsScreenState();
}

class _ProductionUnitsScreenState extends State<ProductionUnitsScreen> {
  List<ProductionUnit>? _unidades;
  String? _error;
  // Cada carga lleva numero: si llega tarde una respuesta vieja, se descarta
  // en vez de pisar la nueva.
  var _carga = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final mia = ++_carga;
    try {
      final unidades = await widget.repository.list(
        widget.userId,
        widget.clinicId,
        species: widget.species,
        activity: widget.activity,
      );
      if (!mounted || mia != _carga) return;
      setState(() {
        _unidades = unidades;
        _error = null;
      });
    } on Object {
      if (!mounted || mia != _carga) return;
      // Sin detalle del fallo: lo que se enseña no tiene por que exponer el
      // interior del almacen.
      setState(() => _error = 'No se pudieron leer las unidades.');
    }
  }

  Future<void> _registrar() async {
    final unidad = await showDialog<ProductionUnit>(
      context: context,
      builder: (_) => _FormularioUnidad(
        species: widget.species,
        activity: widget.activity,
        clinicId: widget.clinicId,
      ),
    );
    if (unidad == null) return;
    await widget.repository.save(widget.userId, unidad);
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final unidades = _unidades;
    return Scaffold(
      appBar: AppBar(title: Text(widget.activity)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _registrar,
        icon: const Icon(Icons.add),
        label: const Text('Registrar unidad'),
      ),
      body: switch ((unidades, _error)) {
        (_, final String mensaje) => _Centrado(mensaje: mensaje),
        (null, _) => const Center(child: CircularProgressIndicator()),
        (final List<ProductionUnit> lista, _) when lista.isEmpty =>
          const _Centrado(
            mensaje:
                'Todavía no hay unidades registradas aquí.\n'
                'Usa «Registrar unidad» para añadir la primera.',
          ),
        (final List<ProductionUnit> lista, _) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: lista.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _TarjetaUnidad(
            unidad: lista[i],
            textTheme: tema.textTheme,
            fondo: tema.colorScheme.surface,
          ),
        ),
      },
    );
  }
}

class _Centrado extends StatelessWidget {
  const _Centrado({required this.mensaje});
  final String mensaje;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(mensaje, textAlign: TextAlign.center),
    ),
  );
}

/// Una unidad en la lista: el nombre, el conteo en grande y la nota debajo.
///
/// El conteo va grande porque es el dato que se busca de un vistazo; el resto
/// queda en segundo plano en lugar de ocupar un parrafo.
class _TarjetaUnidad extends StatelessWidget {
  const _TarjetaUnidad({
    required this.unidad,
    required this.textTheme,
    required this.fondo,
  });

  final ProductionUnit unidad;
  final TextTheme textTheme;
  final Color fondo;

  @override
  Widget build(BuildContext context) {
    final tinta = inkOn(fondo);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unidad.name,
                  style: textTheme.titleMedium?.copyWith(color: tinta),
                ),
                if (unidad.notes case final String nota)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(nota, style: textTheme.bodySmall),
                  ),
              ],
            ),
          ),
          if (unidad.headcount case final int cuantos)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$cuantos',
                  style: textTheme.headlineSmall?.copyWith(color: tinta),
                ),
                Text('animales', style: textTheme.labelSmall),
              ],
            ),
        ],
      ),
    );
  }
}

/// Alta de una unidad. Solo el nombre es obligatorio.
class _FormularioUnidad extends StatefulWidget {
  const _FormularioUnidad({
    required this.species,
    required this.activity,
    required this.clinicId,
  });

  final String species, activity, clinicId;

  @override
  State<_FormularioUnidad> createState() => _FormularioUnidadState();
}

class _FormularioUnidadState extends State<_FormularioUnidad> {
  final _nombre = TextEditingController();
  final _conteo = TextEditingController();
  final _nota = TextEditingController();
  String? _avisoNombre;

  @override
  void dispose() {
    _nombre.dispose();
    _conteo.dispose();
    _nota.dispose();
    super.dispose();
  }

  void _guardar() {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) {
      setState(() => _avisoNombre = 'Ponle un nombre a la unidad');
      return;
    }
    final conteo = int.tryParse(_conteo.text.trim());
    final nota = _nota.text.trim();
    Navigator.of(context).pop(
      ProductionUnit(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        clinicId: widget.clinicId,
        species: widget.species,
        activity: widget.activity,
        name: nombre,
        headcount: conteo != null && conteo >= 0 ? conteo : null,
        notes: nota.isEmpty ? null : nota,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Registrar unidad'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nombre,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Nombre',
              hintText: 'Lote 3, Caseta A, Apiario norte',
              errorText: _avisoNombre,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _conteo,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Animales',
              helperText: 'Opcional. Lo que cuentes tú; no se calcula.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nota,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Nota (opcional)'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _guardar, child: const Text('Guardar')),
    ],
  );
}

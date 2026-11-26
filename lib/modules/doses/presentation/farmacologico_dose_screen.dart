import 'package:flutter/material.dart';

import '../../../vet_ui/vet_icons.dart';
import '../domain/dosis_farmacologica.dart';
import '../domain/pauta_farmacologica.dart';
import '../domain/quantity.dart';
import 'farmacologico_views.dart' show GrupoChip;

/// Abre la calculadora cargando antes el activo.
///
/// Sirve para los accesos que no tienen el catálogo en la mano. Mientras lee el
/// archivo muestra el aviso; si falla, lo dice en vez de abrir en blanco.
class FarmacologicoDoseLoader extends StatelessWidget {
  const FarmacologicoDoseLoader({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Dosis por principio activo')),
    body: FutureBuilder<FarmacologicoCatalog>(
      future: FarmacologicoCatalog.load(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No se pudo cargar el vademécum de dosis. Revisa el activo '
              'farmacologico.v1.json.',
            ),
          );
        }
        final catalog = snapshot.data;
        if (catalog == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: FarmacologicoDoseScreen(catalog: catalog),
        );
      },
    ),
  );
}

/// Calculadora por principio activo.
///
/// El orden es obligatorio: especie, principio, pauta y peso. La especie va
/// primero porque la misma dosis no vale para un perro y para un bovino, y la
/// pauta la elige el médico veterinario: la app no escoge por él.
class FarmacologicoDoseScreen extends StatefulWidget {
  const FarmacologicoDoseScreen({super.key, required this.catalog});

  final FarmacologicoCatalog catalog;

  @override
  State<FarmacologicoDoseScreen> createState() =>
      _FarmacologicoDoseScreenState();
}

class _FarmacologicoDoseScreenState extends State<FarmacologicoDoseScreen> {
  final _peso = TextEditingController();
  String? _especie;
  String _query = '';
  PrincipioActivo? _principio;
  PautaFarmacologica? _pauta;
  String? _pesoError;

  @override
  void dispose() {
    _peso.dispose();
    super.dispose();
  }

  void _elegirEspecie(String? especie) => setState(() {
    _especie = especie;
    _principio = null;
    _pauta = null;
    _peso.clear();
    _pesoError = null;
  });

  void _elegirPrincipio(PrincipioActivo principio) => setState(() {
    _principio = principio;
    _pauta = null;
    _peso.clear();
    _pesoError = null;
  });

  void _elegirPauta(PautaFarmacologica pauta) => setState(() {
    _pauta = pauta;
    _pesoError = null;
  });

  Quantity? get _pesoValido {
    final texto = _peso.text.trim();
    if (texto.isEmpty) return null;
    try {
      final cantidad = Quantity.parse(texto);
      return cantidad.positive ? cantidad : null;
    } on FormatException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pautas = _principio == null
        ? const <PautaFarmacologica>[]
        : widget.catalog.pautasDe(_principio!.id, especie: _especie);
    final principios = _especie == null
        ? const <PrincipioActivo>[]
        : widget.catalog.buscar(_query, especie: _especie);
    final calculo = _pauta == null || _pesoValido == null
        ? null
        : calcularDosisFarmacologica(pauta: _pauta!, peso: _pesoValido!);

    return Scaffold(
      appBar: AppBar(title: const Text('Dosis por principio activo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _especie,
            decoration: const InputDecoration(labelText: 'Especie'),
            items: [
              for (final especie in widget.catalog.especies)
                DropdownMenuItem(value: especie, child: Text(especie)),
            ],
            onChanged: _elegirEspecie,
          ),
          const SizedBox(height: 12),
          if (_especie == null)
            const Text(
              'Elige la especie. Las pautas cambian con el paciente, así que '
              'no se muestran dosis hasta saber de qué especie se trata.',
            )
          else ...[
            TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar principio activo',
                prefixIcon: Icon(VetIcons.search),
              ),
              onChanged: (value) => setState(() {
                _query = value;
                _principio = null;
                _pauta = null;
              }),
            ),
            const SizedBox(height: 4),
            Text('${principios.length} principios con pauta en $_especie'),
            for (final principio in principios.take(25))
              ListTile(
                dense: true,
                leading: const Icon(VetIcons.pills),
                title: Text(principio.nombre),
                subtitle: Text(
                  '${widget.catalog.pautasDe(principio.id, especie: _especie).length} '
                  'pauta(s)',
                ),
                trailing: principio.grupo == null
                    ? null
                    : GrupoChip(grupo: principio.grupo!),
                selected: _principio?.id == principio.id,
                onTap: () => _elegirPrincipio(principio),
              ),
            if (principios.length > 25)
              Text('Escribe para acotar: hay ${principios.length}.'),
          ],
          if (_principio != null) ...[
            const Divider(),
            Text(
              'Pautas de ${_principio!.nombre} en $_especie',
              style: theme.textTheme.titleMedium,
            ),
            const Text('Elige la indicación. La app no elige por ti.'),
            if (pautas.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Este principio no tiene pauta para esa especie.'),
              ),
            for (final pauta in pautas)
              Card(
                margin: const EdgeInsets.only(top: 8),
                color: _pauta?.id == pauta.id
                    ? theme.colorScheme.secondaryContainer
                    : null,
                child: ListTile(
                  title: Text(
                    pauta.indicacion.isEmpty ? 'Sin indicación' : pauta.indicacion,
                  ),
                  subtitle: Text(
                    '${pauta.dosisTexto}\n${pauta.cita}',
                    style: theme.textTheme.bodySmall,
                  ),
                  isThreeLine: true,
                  trailing: _pauta?.id == pauta.id
                      ? const Icon(Icons.check_circle)
                      : null,
                  onTap: () => _elegirPauta(pauta),
                ),
              ),
          ],
          if (_pauta != null) ...[
            const Divider(),
            Text('Peso del paciente', style: theme.textTheme.titleMedium),
            TextField(
              controller: _peso,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Peso en kg',
                errorText: _pesoError,
              ),
              onChanged: (_) => setState(() => _pesoError = null),
            ),
            if (!_pauta!.calculable)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Esta pauta no se calcula automáticamente: su unidad no se '
                  'convierte al peso del paciente (mg/m², gotas). Se consulta.',
                ),
              )
            else if (_pesoValido != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dosis calculada', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(
                        calculo!.texto,
                        style: theme.textTheme.headlineMedium,
                      ),
                      if (_pauta!.intervalo != null &&
                          _pauta!.intervalo!.isNotEmpty &&
                          _pauta!.intervalo != '--')
                        Text('Frecuencia: ${_pauta!.intervalo}'),
                      if (_pauta!.via != null &&
                          _pauta!.via!.isNotEmpty &&
                          _pauta!.via != '--')
                        Text('Vía: ${_pauta!.via}'),
                      const SizedBox(height: 8),
                      Text(
                        'Desde ${_pauta!.dosisTexto} × ${_peso.text.trim()} kg',
                      ),
                      Text(
                        _pauta!.cita,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

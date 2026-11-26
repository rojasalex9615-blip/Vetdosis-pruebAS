import 'dart:async';

import 'package:flutter/material.dart';

import '../../../vet_ui/vet_icons.dart';
import '../../patients/domain/recorded_weight.dart';
import '../data/local_dose_record_store.dart';
import '../data/syncing_dose_record_store.dart';
import '../domain/catalog.dart';
import '../domain/dose_record.dart';
import '../domain/dosis_farmacologica.dart';
import '../domain/manufacturer_pauta.dart';
import '../domain/pauta_farmacologica.dart';
import '../domain/peso_del_expediente.dart';
import '../domain/quantity.dart';
import 'farmacologico_views.dart' show GrupoChip;

/// Abre la calculadora cargando antes el activo.
///
/// Sirve para los accesos que no tienen el catálogo en la mano. Mientras lee el
/// archivo muestra el aviso; si falla, lo dice en vez de abrir en blanco.
class FarmacologicoDoseLoader extends StatelessWidget {
  const FarmacologicoDoseLoader({
    super.key,
    this.recordedWeight,
    this.pesoDelExpediente,
    this.onChoosePatient,
    this.validateRecordedWeight,
  });

  final RecordedPatientWeight? recordedWeight;
  final PesoDelExpediente? pesoDelExpediente;
  final Future<void> Function()? onChoosePatient;

  /// Revalida que el peso medido siga vigente antes de calcular con él.
  final Future<bool> Function(RecordedPatientWeight)? validateRecordedWeight;

  @override
  Widget build(BuildContext context) => FutureBuilder<FarmacologicoCatalog>(
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
        // Texto y no rueda: una animación infinita impide que las pruebas de
        // pantalla se asienten mientras el activo grande se lee en su isolate.
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Cargando el vademécum de dosis…'),
        );
      }
      return FarmacologicoDoseScreen(
        catalog: catalog,
        recordedWeight: recordedWeight,
        pesoDelExpediente: pesoDelExpediente,
        onChoosePatient: onChoosePatient,
        validateRecordedWeight: validateRecordedWeight,
      );
    },
  );
}

/// Calculadora por principio activo.
///
/// El orden es obligatorio: especie, principio, pauta y peso. La especie va
/// primero porque la misma dosis no vale para un perro y para un bovino, y la
/// pauta la elige el médico veterinario: la app no escoge por él.
class FarmacologicoDoseScreen extends StatefulWidget {
  const FarmacologicoDoseScreen({
    super.key,
    required this.catalog,
    this.marcas = const [],
    this.recordedWeight,
    this.pesoDelExpediente,
    this.onChoosePatient,
    this.validateRecordedWeight,
    this.records,
    this.actorId,
  });

  final FarmacologicoCatalog catalog;

  /// Pautas comerciales: solo para ofrecer la concentración del empaque cuando
  /// el dato es inequívoco. No aportan dosis.
  final List<ManufacturerPauta> marcas;

  /// Peso medido y guardado del paciente. Si viene, no se escribe a mano.
  final RecordedPatientWeight? recordedWeight;

  /// Peso que ya está anotado en el expediente. Se ofrece escrito, con su
  /// fecha a la vista, y el cálculo queda ligado a ese paciente.
  final PesoDelExpediente? pesoDelExpediente;

  final Future<void> Function()? onChoosePatient;

  /// Revalida que el peso medido siga vigente antes de calcular con él.
  final Future<bool> Function(RecordedPatientWeight)? validateRecordedWeight;

  /// Destino de los cálculos. Sin almacén no se ofrece guardar.
  final DoseRecordStore? records;

  final String? actorId;

  @override
  State<FarmacologicoDoseScreen> createState() =>
      _FarmacologicoDoseScreenState();
}

class _FarmacologicoDoseScreenState extends State<FarmacologicoDoseScreen> {
  final _peso = TextEditingController();
  final _concentracion = TextEditingController();
  String? _especie;
  String _query = '';
  PrincipioActivo? _principio;
  PautaFarmacologica? _pauta;
  Quantity? _graduacion;
  DoseRecord? _guardado;
  String? _guardandoError;
  bool _guardando = false;
  DoseRecordStore? _registros;
  bool _pesoVigente = true;

  @override
  void initState() {
    super.initState();
    final peso = widget.recordedWeight;
    if (peso != null) _peso.text = peso.kg;
    final expediente = widget.pesoDelExpediente;
    if (peso == null && expediente != null) _peso.text = expediente.kg;
    _abrirAlmacen();
    final revisar = widget.validateRecordedWeight;
    if (peso != null && revisar != null) _revisarPeso(peso, revisar);
  }

  Future<void> _revisarPeso(
    RecordedPatientWeight peso,
    Future<bool> Function(RecordedPatientWeight) revisar,
  ) async {
    var vigente = false;
    try {
      vigente = await revisar(peso);
    } catch (_) {
      vigente = false;
    }
    if (mounted) setState(() => _pesoVigente = vigente);
  }

  /// El almacén usa la misma base sin conexión que el resto de la app y, si hay
  /// sesión con paciente, también la ficha de la clínica. Si no se puede abrir,
  /// el botón de guardar no aparece: mejor eso que fingir guardar.
  Future<void> _abrirAlmacen() async {
    final inyectado = widget.records;
    if (inyectado != null) {
      _registros = inyectado;
      return;
    }
    try {
      _registros = await abrirDoseRecordStore(
        clinicId: _clinica,
      );
    } catch (_) {
      _registros = null;
    }
    if (mounted) setState(() {});
    // Lo que quedó pendiente de otro día se reintenta al abrir la pantalla.
    final almacen = _registros;
    if (almacen is SyncingDoseRecordStore) {
      unawaited(almacen.reintentarPendientes());
    }
  }

  @override
  void dispose() {
    _peso.dispose();
    _concentracion.dispose();
    super.dispose();
  }

  void _elegirEspecie(String? especie) => setState(() {
    _especie = especie;
    _principio = null;
    _pauta = null;
    _concentracion.clear();
    _guardado = null;
    _guardandoError = null;
  });

  void _elegirPrincipio(PrincipioActivo principio) => setState(() {
    _principio = principio;
    _pauta = null;
    _concentracion.clear();
    _guardado = null;
  });

  void _elegirPauta(PautaFarmacologica pauta) => setState(() {
    _pauta = pauta;
    _guardado = null;
    _guardandoError = null;
  });

  String? get _clinica =>
      widget.recordedWeight?.clinicId ?? widget.pesoDelExpediente?.clinicId;

  String get _pacienteId =>
      widget.recordedWeight?.patientId ??
      widget.pesoDelExpediente?.patientId ??
      '';

  String? get _pacienteNombre =>
      widget.recordedWeight?.patientName ??
      widget.pesoDelExpediente?.patientName;

  Quantity? _cantidad(TextEditingController controller) {
    final texto = controller.text.trim();
    if (texto.isEmpty) return null;
    try {
      final cantidad = Quantity.parse(texto);
      return cantidad.positive ? cantidad : null;
    } on FormatException {
      return null;
    }
  }

  Quantity? get _pesoValido => _cantidad(_peso);

  Quantity? get _concentracionValida => _cantidad(_concentracion);

  /// Concentraciones que el empaque declara para este principio, cuando el dato
  /// no deja duda: un solo principio y masa por mililitro.
  List<(String, String)> get _presets {
    final principio = _principio;
    if (principio == null) return const [];
    final nombre = normalizeDoseSearch(principio.nombre);
    final vistos = <String>{};
    final salida = <(String, String)>[];
    for (final marca in widget.marcas) {
      if (marca.ingredients.contains('+')) continue;
      if (!normalizeDoseSearch(marca.ingredients).contains(nombre)) continue;
      final base = marca.ingredientBase.toLowerCase().replaceAll(' ', '');
      final unit = marca.ingredientUnit.toLowerCase();
      final amount = double.tryParse(
        marca.ingredientAmount.replaceAll(',', '.').trim(),
      );
      if (amount == null || amount <= 0) continue;
      double? mgMl;
      if (unit == 'mg' && base == 'porml') mgMl = amount;
      if (unit == 'g' && base == 'por100ml') mgMl = amount * 10;
      if (mgMl == null) continue;
      final texto = mgMl
          .toStringAsFixed(mgMl < 1 ? 3 : 2)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');
      final clave = '$texto|${marca.productName}';
      if (!vistos.add(clave)) continue;
      salida.add(('${marca.productName} · ${marca.presentation}', texto));
    }
    return salida.take(6).toList();
  }

  DoseRecord _registro(DosisCalculada dosis, VolumenDeEmpaque? volumen) {
    final ahora = DateTime.now().toUtc();
    final pauta = _pauta!;
    return DoseRecord(
      id: nuevoDoseRecordId(),
      createdAt: ahora,
      principio: _principio!.nombre,
      pautaId: pauta.id,
      indicacion: pauta.indicacion,
      especie: pauta.especie,
      via: pauta.via ?? '',
      intervalo: pauta.intervalo ?? '',
      dosisLiteral: pauta.dosisTexto,
      cita: pauta.cita,
      pesoKg: _peso.text.trim(),
      resultadoMg: dosis.texto,
      concentracionMgMl: volumen?.concentracion.display(),
      resultadoMl: volumen?.texto,
      clinicId: _clinica,
      patientId: _pacienteId.isEmpty ? null : _pacienteId,
      patientName: _pacienteNombre,
      actorId: widget.actorId,
    );
  }

  Future<void> _guardar(DosisCalculada dosis, VolumenDeEmpaque? volumen) async {
    final store = _registros;
    if (store == null) return;
    setState(() {
      _guardando = true;
      _guardandoError = null;
    });
    try {
      final registro = _registro(dosis, volumen);
      final guardado = await store.save(registro);
      if (!mounted) return;
      setState(() => _guardado = guardado);
    } catch (_) {
      if (mounted) {
        setState(
          () => _guardandoError =
              'No se pudo guardar el cálculo en este dispositivo.',
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
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
    final peso = _pesoVigente ? _pesoValido : null;
    final dosis = _pauta == null || peso == null
        ? null
        : calcularDosisFarmacologica(pauta: _pauta!, peso: peso);
    final concentracion = _concentracionValida;
    final volumen = dosis == null || concentracion == null
        ? null
        : volumenDeEmpaque(
            dosisMg: dosis.minimas,
            dosisMaximaMg: dosis.maximas,
            concentracionMgMl: concentracion,
          );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.recordedWeight != null && !_pesoVigente) ...[
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'El peso registrado ya no está vigente o cambió. Elige el '
                'paciente otra vez antes de calcular.',
              ),
            ),
          ),
          const SizedBox(height: 12),
        ] else if (widget.recordedWeight != null)
          _PacienteCard(widget.recordedWeight!)
        else if (widget.pesoDelExpediente case final expediente?) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expediente.patientName,
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(expediente.detalle),
                  Text(
                    'Revisa que sea el peso de hoy; si no, mide y registra el '
                    'peso en el expediente antes de calcular.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ] else if (widget.onChoosePatient != null) ...[
          const Text(
            'Sin peso registrado, la dosis se calcula con un peso escrito a '
            'mano y el cálculo no queda ligado a ningún paciente.',
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: widget.onChoosePatient,
            icon: const Icon(VetIcons.userSearch),
            label: const Text('Elegir paciente y peso registrado'),
          ),
          const SizedBox(height: 12),
        ],
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
                  pauta.indicacion.isEmpty
                      ? 'Sin indicación'
                      : pauta.indicacion,
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
            readOnly: widget.recordedWeight != null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Peso en kg',
              helperText: widget.recordedWeight == null
                  ? null
                  : 'Peso medido y registrado; no se escribe aquí',
            ),
            onChanged: (_) => setState(() => _guardado = null),
          ),
          if (!_pauta!.calculable)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Esta pauta no se calcula automáticamente: su unidad no se '
                'convierte al peso del paciente (mg/m², gotas). Se consulta.',
              ),
            )
          else if (peso != null) ...[
            const SizedBox(height: 12),
            Text('Dosis en masa', style: theme.textTheme.titleMedium),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dosis!.texto, style: theme.textTheme.headlineMedium),
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
                    Text(_pauta!.cita, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Concentración del empaque',
              style: theme.textTheme.titleMedium,
            ),
            const Text(
              'Lee la concentración del frasco o de la caja que tienes en la '
              'mano. Es la que manda, no la del catálogo.',
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _concentracion,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Concentración en mg/mL',
              ),
              onChanged: (_) => setState(() => _guardado = null),
            ),
            if (_presets.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Declaradas por el fabricante (toca para usar):',
                style: theme.textTheme.bodySmall,
              ),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final (etiqueta, valor) in _presets)
                    ActionChip(
                      label: Text('$etiqueta · $valor mg/mL'),
                      onPressed: () => setState(() {
                        _concentracion.text = valor;
                        _guardado = null;
                      }),
                    ),
                ],
              ),
            ],
            if (volumen != null) ...[
              const SizedBox(height: 12),
              Card(
                color: theme.colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Volumen a administrar',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        volumen.texto,
                        style: theme.textTheme.headlineMedium,
                      ),
                      Text(
                        '${dosis.texto} ÷ ${volumen.concentracion.display()} mg/mL',
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: [
                          for (final paso in const ['0,01', '0,1', '1'])
                            ChoiceChip(
                              label: Text('Jeringa $paso mL'),
                              selected:
                                  _graduacion != null &&
                                  _graduacion!.compareTo(
                                        Quantity.parse(paso),
                                      ) ==
                                      0,
                              onSelected: (_) => setState(
                                () => _graduacion = Quantity.parse(paso),
                              ),
                            ),
                        ],
                      ),
                      if (volumen.redondeado(_graduacion) case final texto?)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '$texto. El número exacto es el de arriba.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_registros != null)
              CalculatorSaveButton(
                enabled: !_guardando,
                onPressed: () => _guardar(dosis, volumen),
                paciente: _pacienteNombre,
                guardando: _guardando,
              ),
            if (_guardado != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cálculo guardado: ${_guardado!.resumen}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    Text(
                      _guardado!.syncedAt != null
                          ? 'En la ficha del paciente, con su cita y su '
                                'concentración.'
                          : 'En este dispositivo. Se envía a la ficha cuando '
                                'haya sesión y paciente; si no, queda '
                                'pendiente aquí.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            if (_guardandoError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _guardandoError!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
          ],
        ],
      ],
    );
  }
}

class _PacienteCard extends StatelessWidget {
  const _PacienteCard(this.peso);

  final RecordedPatientWeight peso;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(peso.patientName, style: theme.textTheme.titleMedium),
            Text(
              'Peso medido: ${peso.kg} kg · '
              '${peso.observedAt.toLocal().toString().split('.').first}',
            ),
            Text(
              'Midió: ${peso.performedBy} · Registró: ${peso.recordedBy}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón de guardado, con el nombre del paciente cuando lo hay.
class CalculatorSaveButton extends StatelessWidget {
  const CalculatorSaveButton({
    super.key,
    required this.enabled,
    required this.onPressed,
    required this.guardando,
    this.paciente,
  });

  final bool enabled, guardando;
  final VoidCallback onPressed;
  final String? paciente;

  @override
  Widget build(BuildContext context) {
    final destino = paciente == null
        ? 'el dispositivo'
        : 'la ficha de $paciente';
    return FilledButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: guardando
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.save_outlined),
      label: Text(guardando ? 'Guardando…' : 'Guardar en $destino'),
    );
  }
}

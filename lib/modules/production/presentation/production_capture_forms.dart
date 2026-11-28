/// Los formularios que le faltaban al Dashboard Pecuario.
///
/// Los tres RPC de escritura (`produccion_lote_guardar`,
/// `produccion_registro_guardar` y `produccion_evento_guardar`) llevaban
/// tiempo desplegados y validados en la base, pero ninguna pantalla los
/// llamaba: el panel solo sabía leer, y por eso enseñaba «Registros en
/// preparación». Aquí está la parte que faltaba.
///
/// La decisión de diseño que manda en este archivo es que **el formulario de
/// registro se genera desde el catálogo**, no se escribe a mano. El servidor
/// (`private.produccion_metricas_ok`) rechaza cualquier clave que no esté en
/// `produccion_metricas` para la especie del lote y cualquier valor fuera de
/// su rango. Un formulario escrito a mano se desincronizaría del catálogo en
/// cuanto alguien añadiera una métrica; uno generado desde él no puede.
library;

import 'package:flutter/material.dart';

import '../../../core/widgets/capture_sheet.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_icons.dart';
import '../../auth/domain/clinic_membership.dart';
import '../domain/production_farm.dart';
import '../domain/production_write_repository.dart';

// ---------------------------------------------------------------------------
// Quién puede qué
// ---------------------------------------------------------------------------

/// Registros y eventos: administrador, MVZ y auxiliar.
///
/// Es quien está en el corral a las seis de la mañana, así que negarle la
/// captura diaria dejaría el módulo sin uso.
bool puedeCapturarProduccion(ClinicMembership? member) =>
    member != null &&
    (member.role == ClinicRole.admin ||
        member.role == ClinicRole.mvz ||
        member.role == ClinicRole.auxiliar);

/// Alta y edición de lotes: solo administrador y MVZ.
///
/// Un lote define la unidad contable de toda la granja; el servidor lo
/// reserva a esos dos roles y la interfaz no debe ofrecer un botón que el
/// servidor va a rechazar.
bool puedeGestionarLotes(ClinicMembership? member) =>
    member != null &&
    (member.role == ClinicRole.admin || member.role == ClinicRole.mvz);

// ---------------------------------------------------------------------------
// Catálogos fijos (los que la base declara como CHECK, no como tabla)
// ---------------------------------------------------------------------------

/// Sistemas de alojamiento que admite `lotes_produccion_sistema_check`.
const Map<String, String> sistemasDeProduccion = {
  'piso': 'Piso',
  'jaula': 'Jaula',
  'corral': 'Corral',
  'pastoreo': 'Pastoreo',
  'estanque': 'Estanque',
  'colmena': 'Colmena',
  'otro': 'Otro',
};

/// Estados que admite `lotes_produccion_estado_check`.
const Map<String, String> estadosDeLote = {
  'activo': 'Activo',
  'cerrado': 'Cerrado',
};

/// Tipos de evento que admite `produccion_evento_guardar`.
const Map<String, String> tiposDeEvento = {
  'sanitario': 'Sanitario',
  'mortalidad': 'Mortalidad',
  'pesaje': 'Pesaje',
  'traslado': 'Traslado',
  'sacrificio': 'Sacrificio',
  'otro': 'Otro',
};

/// Subtipos sugeridos para un evento sanitario, que es el único que los exige.
const List<String> subtiposSanitarios = [
  'Vacunación',
  'Desparasitación',
  'Tratamiento',
  'Revisión',
  'Muestreo',
];

/// Nombres legibles de las especies del catálogo.
const Map<String, String> nombresDeEspecie = {
  'bovino': 'Bovino',
  'cerdo': 'Cerdo',
  'gallina': 'Gallina',
  'pavo': 'Pavo',
  'ovino': 'Ovino',
  'caprino': 'Caprino',
  'tilapia': 'Tilapia',
  'langostino': 'Langostino',
  'abeja': 'Abeja',
};

/// Nombres legibles de los propósitos.
const Map<String, String> nombresDeProposito = {
  'carne': 'Carne',
  'leche': 'Leche',
  'mixto': 'Mixto',
  'engorda': 'Engorda',
  'postura': 'Postura',
};

String nombreDeEspecie(String code) => nombresDeEspecie[code] ?? code;
String nombreDeProposito(String code) => nombresDeProposito[code] ?? code;
String nombreDeSistema(String? code) =>
    code == null ? 'Sin definir' : (sistemasDeProduccion[code] ?? code);
String nombreDeTipoEvento(String code) => tiposDeEvento[code] ?? code;

/// Cómo se nombra un lote en un desplegable.
String nombreDeLote(FarmBatch b) =>
    '${b.codigo} · ${b.nombre} (${nombreDeEspecie(b.especie)})';

// ---------------------------------------------------------------------------
// 1. Alta y edición de lote
// ---------------------------------------------------------------------------

/// Abre el formulario de lote. [inicial] no nulo significa edición.
Future<bool> capturarLote(
  BuildContext context, {
  required String clinicId,
  required ProductionWriteRepository repo,
  required List<String> especiesPermitidas,
  FarmBatch? inicial,
}) => openCaptureSheet(
  context,
  _LoteSheet(
    clinicId: clinicId,
    repo: repo,
    especiesPermitidas: especiesPermitidas,
    inicial: inicial,
  ),
);

class _LoteSheet extends StatefulWidget {
  const _LoteSheet({
    required this.clinicId,
    required this.repo,
    required this.especiesPermitidas,
    this.inicial,
  });
  final String clinicId;
  final ProductionWriteRepository repo;
  final List<String> especiesPermitidas;
  final FarmBatch? inicial;

  @override
  State<_LoteSheet> createState() => _LoteSheetState();
}

class _LoteSheetState extends State<_LoteSheet> {
  late final TextEditingController _codigo;
  late final TextEditingController _nombre;
  late final TextEditingController _cabezas;
  late final TextEditingController _hato;
  String? _especie;
  String? _proposito;
  String? _sistema;
  String _estado = 'activo';
  DateTime? _inicio;
  DateTime? _fin;

  /// Pares especie/propósito del catálogo. Hasta que carguen, el desplegable
  /// de propósito no puede ofrecer nada fiable.
  List<SpeciesPurpose> _pares = const [];
  bool _cargandoPares = true;
  String? _errorPares;

  @override
  void initState() {
    super.initState();
    final i = widget.inicial;
    _codigo = TextEditingController(text: i?.codigo ?? '');
    _nombre = TextEditingController(text: i?.nombre ?? '');
    _cabezas = TextEditingController(text: i == null ? '' : '${i.cabezas}');
    _hato = TextEditingController(text: i?.identificadorHato ?? '');
    _especie = i?.especie;
    _proposito = i?.proposito;
    _sistema = i?.sistema;
    _estado = i?.estado ?? 'activo';
    _inicio = i?.fechaInicio ?? DateTime.now();
    _cargarPares();
  }

  Future<void> _cargarPares() async {
    try {
      final pares = await widget.repo.propositosPorEspecie();
      if (!mounted) return;
      setState(() {
        _pares = pares;
        _cargandoPares = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoPares = false;
        _errorPares = 'No se pudo leer el catálogo de especies.';
      });
    }
  }

  @override
  void dispose() {
    _codigo.dispose();
    _nombre.dispose();
    _cabezas.dispose();
    _hato.dispose();
    super.dispose();
  }

  /// Especies del catálogo, acotadas a la pestaña en que está el usuario.
  List<String> get _especies {
    final todas = <String>{for (final p in _pares) p.especie};
    final permitidas = widget.especiesPermitidas;
    final lista = permitidas.isEmpty
        ? todas.toList()
        : todas.where(permitidas.contains).toList();
    lista.sort();
    return lista;
  }

  /// Propósitos válidos para la especie elegida. Ofrecer «engorda» a un
  /// bovino daría un error de clave foránea al guardar.
  List<String> get _propositos {
    if (_especie == null) return const [];
    final lista = _pares
        .where((p) => p.especie == _especie)
        .map((p) => p.proposito)
        .toList();
    lista.sort();
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.inicial != null;
    if (_cargandoPares) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorPares != null) {
      return MissingPrerequisiteSheet(
        title: 'Catálogo no disponible',
        icon: VetIcons.alertTriangle,
        text: '$_errorPares Revisa la conexión e inténtalo de nuevo.',
      );
    }
    return CaptureSheet(
      title: editando ? 'Editar lote' : 'Nuevo lote',
      icon: VetIcons.layers,
      saveLabel: editando ? 'Guardar cambios' : 'Crear lote',
      translateError: (e) => traducirErrorProduccion(e).mensaje,
      fields: (busy) => [
        CaptureTextField(
          controller: _codigo,
          label: 'Código del lote',
          busy: busy,
          required: true,
          maxLength: 40,
          help: 'Como lo identifican en la granja. No se repite dentro de la '
              'misma cuenta.',
        ),
        CaptureTextField(
          controller: _nombre,
          label: 'Nombre',
          busy: busy,
          required: true,
          maxLength: 120,
        ),
        CaptureChoiceField<String>(
          value: _especies.contains(_especie) ? _especie : null,
          label: 'Especie',
          options: _especies,
          nameOf: nombreDeEspecie,
          busy: busy || editando,
          help: editando
              ? 'La especie no se cambia: los registros ya guardados dependen '
                    'de su catálogo de métricas.'
              : null,
          onChanged: (v) => setState(() {
            _especie = v;
            // El proposito anterior puede no existir para la especie nueva.
            if (!_propositos.contains(_proposito)) _proposito = null;
          }),
        ),
        CaptureChoiceField<String>(
          // La clave depende de la especie a proposito: al cambiarla, el campo
          // se reconstruye desde cero en vez de conservar el proposito
          // anterior, que para la especie nueva podria no existir.
          key: ValueKey('proposito-$_especie'),
          value: _propositos.contains(_proposito) ? _proposito : null,
          label: 'Propósito',
          options: _propositos,
          nameOf: nombreDeProposito,
          busy: busy || _especie == null,
          help: _especie == null
              ? 'Elige primero la especie.'
              : 'Solo se ofrecen los propósitos que el catálogo admite para '
                    '${nombreDeEspecie(_especie!)}.',
          onChanged: (v) => setState(() => _proposito = v),
        ),
        CaptureIntField(
          controller: _cabezas,
          label: 'Cabezas',
          busy: busy,
          required: true,
          min: 1,
          max: 1000000,
        ),
        CaptureDateField(
          value: _inicio,
          label: 'Fecha de inicio',
          busy: busy,
          required: true,
          pastOnly: false,
          onChanged: (v) => setState(() => _inicio = v),
        ),
        CaptureDateField(
          value: _fin,
          label: 'Fecha de cierre',
          busy: busy,
          pastOnly: false,
          onChanged: (v) => setState(() => _fin = v),
        ),
        _OpcionalChoice(
          value: _sistema,
          label: 'Sistema de alojamiento',
          catalogo: sistemasDeProduccion,
          busy: busy,
          onChanged: (v) => setState(() => _sistema = v),
        ),
        CaptureTextField(
          controller: _hato,
          label: 'Identificador de hato (UPP)',
          busy: busy,
          maxLength: 80,
          help: 'Opcional. El número con que la unidad está registrada.',
        ),
        if (editando)
          _OpcionalChoice(
            value: _estado,
            label: 'Estado',
            catalogo: estadosDeLote,
            busy: busy,
            permitirVacio: false,
            onChanged: (v) => setState(() => _estado = v ?? 'activo'),
          ),
      ],
      onSave: (operation) async {
        final inicio = _inicio;
        if (_especie == null || _proposito == null || inicio == null) {
          throw const ProductionWriteException(
            'lote_fields_required',
            'Faltan datos: especie, propósito y fecha de inicio.',
          );
        }
        if (_fin != null && _fin!.isBefore(inicio)) {
          throw const ProductionWriteException(
            'invalid_fecha',
            'La fecha de cierre no puede ser anterior a la de inicio.',
          );
        }
        final data = <String, dynamic>{
          if (widget.inicial != null) 'id': widget.inicial!.id,
          'codigo': _codigo.text.trim(),
          'nombre': _nombre.text.trim(),
          'especie': _especie,
          'proposito': _proposito,
          'cabezas': _cabezas.text.trim(),
          'fecha_inicio': _soloDia(inicio),
          'estado': _estado,
          if (_fin != null) 'fecha_fin': _soloDia(_fin!),
          if (_sistema != null) 'sistema': _sistema,
          if (_hato.text.trim().isNotEmpty)
            'identificador_hato': _hato.text.trim(),
        };
        return widget.repo.guardarLote(
          clinicId: widget.clinicId,
          data: data,
          operation: operation,
        );
      },
    );
  }
}

String _soloDia(DateTime d) => d.toIso8601String().substring(0, 10);

/// Desplegable que admite «sin definir», para los campos que la base deja
/// nulos. `CaptureChoiceField` exige valor; este no.
class _OpcionalChoice extends StatelessWidget {
  const _OpcionalChoice({
    required this.value,
    required this.label,
    required this.catalogo,
    required this.busy,
    required this.onChanged,
    this.permitirVacio = true,
  });
  final String? value;
  final String label;
  final Map<String, String> catalogo;
  final bool busy, permitirVacio;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<String?>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        if (permitirVacio)
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Sin definir'),
          ),
        for (final e in catalogo.entries)
          DropdownMenuItem<String?>(
            value: e.key,
            child: Text(e.value, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: busy ? null : onChanged,
    ),
  );
}

// ---------------------------------------------------------------------------
// 2. Registro productivo, generado desde el catálogo de métricas
// ---------------------------------------------------------------------------

/// Abre el formulario de registro para [lotes].
///
/// Si no hay lotes no se abre un formulario con un desplegable vacío: se dice
/// que primero hay que dar de alta un lote.
Future<bool> capturarRegistro(
  BuildContext context, {
  required String clinicId,
  required ProductionWriteRepository repo,
  required List<FarmBatch> lotes,
  required List<FarmMetricDef> metricas,
  FarmBatch? loteInicial,
}) {
  final abiertos = lotes.where((l) => l.estado != 'cerrado').toList();
  if (abiertos.isEmpty) {
    return openCaptureSheet(
      context,
      const MissingPrerequisiteSheet(
        title: 'Registro productivo',
        icon: VetIcons.gauge,
        text: 'Primero da de alta un lote activo. El registro diario cuelga '
            'de un lote, y hoy no hay ninguno abierto en esta especie.',
      ),
    );
  }
  return openCaptureSheet(
    context,
    _RegistroSheet(
      clinicId: clinicId,
      repo: repo,
      lotes: abiertos,
      metricas: metricas,
      loteInicial: loteInicial,
    ),
  );
}

class _RegistroSheet extends StatefulWidget {
  const _RegistroSheet({
    required this.clinicId,
    required this.repo,
    required this.lotes,
    required this.metricas,
    this.loteInicial,
  });
  final String clinicId;
  final ProductionWriteRepository repo;
  final List<FarmBatch> lotes;
  final List<FarmMetricDef> metricas;
  final FarmBatch? loteInicial;

  @override
  State<_RegistroSheet> createState() => _RegistroSheetState();
}

class _RegistroSheetState extends State<_RegistroSheet> {
  late FarmBatch _lote;
  DateTime _fecha = DateTime.now();
  final _notas = TextEditingController();

  /// Un controlador por clave de métrica. Se conservan entre cambios de lote
  /// para no borrar lo tecleado si la métrica también existe en la especie
  /// nueva.
  final Map<String, TextEditingController> _valores = {};

  @override
  void initState() {
    super.initState();
    final inicial = widget.loteInicial;
    _lote = inicial != null && widget.lotes.any((l) => l.id == inicial.id)
        ? inicial
        : widget.lotes.first;
  }

  @override
  void dispose() {
    for (final c in _valores.values) {
      c.dispose();
    }
    _notas.dispose();
    super.dispose();
  }

  /// Las métricas que el catálogo declara para la especie del lote elegido.
  List<FarmMetricDef> get _defs {
    final lista = widget.metricas
        .where((m) => m.especie == _lote.especie)
        .toList();
    lista.sort((a, b) => a.etiqueta.compareTo(b.etiqueta));
    return lista;
  }

  TextEditingController _ctrl(String clave) =>
      _valores.putIfAbsent(clave, () => TextEditingController());

  @override
  Widget build(BuildContext context) {
    final defs = _defs;
    if (defs.isEmpty) {
      return MissingPrerequisiteSheet(
        title: 'Registro productivo',
        icon: VetIcons.gauge,
        text: 'El catálogo no define métricas para '
            '${nombreDeEspecie(_lote.especie)}, así que no hay nada que '
            'capturar todavía.',
      );
    }
    return CaptureSheet(
      title: 'Registro productivo',
      icon: VetIcons.gauge,
      translateError: (e) => traducirErrorProduccion(e).mensaje,
      notice: 'Captura solo lo que midas hoy. Los campos vacíos no se guardan.',
      fields: (busy) => [
        CaptureChoiceField<FarmBatch>(
          key: ValueKey('lote-${_lote.id}'),
          value: _lote,
          label: 'Lote',
          options: widget.lotes,
          nameOf: nombreDeLote,
          busy: busy,
          onChanged: (v) => setState(() => _lote = v ?? _lote),
        ),
        CaptureDateField(
          value: _fecha,
          label: 'Fecha',
          busy: busy,
          required: true,
          onChanged: (v) => setState(() => _fecha = v ?? _fecha),
        ),
        captureBlockLabel(
          context,
          'Métricas de ${nombreDeEspecie(_lote.especie)}',
        ),
        for (final d in defs)
          CaptureNumberField(
            // Sin clave, al cambiar de lote Flutter reusaria los campos por
            // posicion y el valor tecleado saltaria a otra metrica.
            key: ValueKey(d.clave),
            controller: _ctrl(d.clave),
            label: d.etiqueta,
            busy: busy,
            suffix: d.unidad.isEmpty ? null : d.unidad,
            help: 'Rango admitido: ${d.rango}',
            // Se valida aqui el mismo rango que el servidor aplica, para que
            // el aviso salga antes del viaje de red y señalando el campo.
            extraValidator: (n) {
              if (d.minimo != null && n < d.minimo!) {
                return 'No puede ser menor que ${d.minimo}';
              }
              if (d.maximo != null && n > d.maximo!) {
                return 'No puede ser mayor que ${d.maximo}';
              }
              return null;
            },
          ),
        CaptureTextField(
          controller: _notas,
          label: 'Notas',
          busy: busy,
          lines: 3,
          maxLength: 2000,
        ),
      ],
      onSave: (operation) async {
        final metricas = <String, double>{};
        for (final d in _defs) {
          final n = readDecimal(_valores[d.clave]?.text);
          if (n != null) metricas[d.clave] = n;
        }
        if (metricas.isEmpty) {
          throw const ProductionWriteException(
            'metricas_required',
            'Captura al menos una métrica antes de guardar.',
          );
        }
        return widget.repo.guardarRegistro(
          clinicId: widget.clinicId,
          loteId: _lote.id,
          fecha: _fecha,
          metricas: metricas,
          notas: emptyToNull(_notas.text),
          operation: operation,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Evento de manejo
// ---------------------------------------------------------------------------

/// Abre el formulario de evento de manejo.
Future<bool> capturarEvento(
  BuildContext context, {
  required String clinicId,
  required ProductionWriteRepository repo,
  required List<FarmBatch> lotes,
  FarmBatch? loteInicial,
  String? tipoInicial,
}) {
  if (lotes.isEmpty) {
    return openCaptureSheet(
      context,
      const MissingPrerequisiteSheet(
        title: 'Evento de manejo',
        icon: VetIcons.calendar,
        text: 'Primero da de alta un lote. Los eventos de manejo cuelgan de '
            'un lote y hoy no hay ninguno en esta especie.',
      ),
    );
  }
  return openCaptureSheet(
    context,
    _EventoSheet(
      clinicId: clinicId,
      repo: repo,
      lotes: lotes,
      loteInicial: loteInicial,
      tipoInicial: tipoInicial,
    ),
  );
}

class _EventoSheet extends StatefulWidget {
  const _EventoSheet({
    required this.clinicId,
    required this.repo,
    required this.lotes,
    this.loteInicial,
    this.tipoInicial,
  });
  final String clinicId;
  final ProductionWriteRepository repo;
  final List<FarmBatch> lotes;
  final FarmBatch? loteInicial;
  final String? tipoInicial;

  @override
  State<_EventoSheet> createState() => _EventoSheetState();
}

class _EventoSheetState extends State<_EventoSheet> {
  late FarmBatch _lote;
  late String _tipo;
  DateTime _fecha = DateTime.now();
  final _subtipo = TextEditingController();
  final _animales = TextEditingController();
  final _nota = TextEditingController();

  @override
  void initState() {
    super.initState();
    final inicial = widget.loteInicial;
    _lote = inicial != null && widget.lotes.any((l) => l.id == inicial.id)
        ? inicial
        : widget.lotes.first;
    final t = widget.tipoInicial;
    _tipo = t != null && tiposDeEvento.containsKey(t) ? t : 'sanitario';
  }

  @override
  void dispose() {
    _subtipo.dispose();
    _animales.dispose();
    _nota.dispose();
    super.dispose();
  }

  bool get _esSanitario => _tipo == 'sanitario';

  @override
  Widget build(BuildContext context) => CaptureSheet(
    title: 'Evento de manejo',
    icon: VetIcons.calendar,
    translateError: (e) => traducirErrorProduccion(e).mensaje,
    fields: (busy) => [
      CaptureChoiceField<FarmBatch>(
        value: _lote,
        label: 'Lote',
        options: widget.lotes,
        nameOf: nombreDeLote,
        busy: busy,
        onChanged: (v) => setState(() => _lote = v ?? _lote),
      ),
      CaptureChoiceField<String>(
        value: _tipo,
        label: 'Tipo',
        options: tiposDeEvento.keys.toList(),
        nameOf: nombreDeTipoEvento,
        busy: busy,
        onChanged: (v) => setState(() => _tipo = v ?? _tipo),
      ),
      CaptureDateField(
        value: _fecha,
        label: 'Fecha',
        busy: busy,
        required: true,
        onChanged: (v) => setState(() => _fecha = v ?? _fecha),
      ),
      CaptureTextField(
        controller: _subtipo,
        label: _esSanitario ? 'De qué se trata' : 'Subtipo',
        busy: busy,
        // El servidor exige subtipo cuando el evento es sanitario: «sanitario»
        // a secas no dice si fue vacuna, desparasitacion o tratamiento.
        required: _esSanitario,
        maxLength: 60,
        help: _esSanitario
            ? 'Por ejemplo: ${subtiposSanitarios.join(", ")}.'
            : 'Opcional.',
      ),
      if (_esSanitario)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in subtiposSanitarios)
                ActionChip(
                  label: Text(s),
                  onPressed: busy ? null : () => _subtipo.text = s,
                ),
            ],
          ),
        ),
      CaptureIntField(
        controller: _animales,
        label: 'Animales afectados',
        busy: busy,
        min: 0,
        max: 1000000,
        help: 'Opcional. Cuántas cabezas entran en este evento.',
      ),
      CaptureTextField(
        controller: _nota,
        label: 'Detalle',
        busy: busy,
        lines: 3,
        maxLength: 500,
      ),
    ],
    onSave: (operation) async {
      final animales = int.tryParse(_animales.text.trim());
      final nota = emptyToNull(_nota.text);
      return widget.repo.guardarEvento(
        clinicId: widget.clinicId,
        loteId: _lote.id,
        fecha: _fecha,
        tipo: _tipo,
        subtipo: emptyToNull(_subtipo.text),
        animales: animales,
        detalle: nota == null ? null : {'nota': nota},
        operation: operation,
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Barra de acciones reutilizable
// ---------------------------------------------------------------------------

/// Los botones de captura del panel, ya filtrados por rol.
///
/// Si el rol no puede usar un botón, no se dibuja desactivado: se omite. Un
/// botón gris que nunca se enciende solo genera preguntas.
class ProductionCaptureBar extends StatelessWidget {
  const ProductionCaptureBar({
    super.key,
    required this.member,
    required this.onNuevoLote,
    required this.onRegistro,
    required this.onEvento,
  });

  final ClinicMembership? member;
  final VoidCallback onNuevoLote;
  final VoidCallback onRegistro;
  final VoidCallback onEvento;

  @override
  Widget build(BuildContext context) {
    if (!puedeCapturarProduccion(member)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          if (puedeGestionarLotes(member))
            VetActionButton(
              label: 'Nuevo lote',
              icon: VetIcons.layers,
              onPressed: onNuevoLote,
            ),
          VetActionButton(
            label: 'Registro productivo',
            icon: VetIcons.gauge,
            style: VetActionStyle.secondary,
            onPressed: onRegistro,
          ),
          VetActionButton(
            label: 'Evento de manejo',
            icon: VetIcons.calendar,
            style: VetActionStyle.secondary,
            onPressed: onEvento,
          ),
        ],
      ),
    );
  }
}

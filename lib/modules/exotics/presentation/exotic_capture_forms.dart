/// Las pantallas de captura del módulo de exóticos.
///
/// Hasta ahora el panel solo sabía leer: las tablas existían y nadie podía
/// llenarlas desde la app. Aquí están los ocho formularios que faltaban.
///
/// Dos decisiones que recorren todo el archivo:
///
/// **1. No se pregunta lo que el recinto no declara.** Si un terrario no tiene
/// rango de pH, el formulario de lectura ni siquiera enseña el campo de pH.
/// Preguntarlo invitaría a capturar un dato que el panel luego no juzga, y el
/// profesional se quedaría esperando una alerta que nunca va a llegar.
///
/// **2. El recibo de idempotencia se conserva mientras se reintenta.** Si el
/// guardado falla por red y la persona vuelve a pulsar, el servidor reconoce
/// la misma operación y devuelve el registro que ya creó en lugar de
/// duplicarlo. Solo al cerrar con éxito se genera uno nuevo.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/capture_sheet.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_icons.dart';
import '../../auth/domain/clinic_membership.dart';
import '../domain/exotic_dashboard.dart';
import '../domain/exotic_write_repository.dart';

/// Resultado de abrir un formulario: `true` si se guardó algo.
typedef CapturaGuardada = CaptureSaved;

// ---------------------------------------------------------------------------
// Andamio comun: el marco y los campos viven en core
// ---------------------------------------------------------------------------

String _traducirError(Object error) => error is ExoticWriteException
    ? error.mensaje
    : traducirErrorExotico(error).mensaje;

/// El marco de captura del core, con los nombres del módulo.
class _HojaDeCaptura extends StatelessWidget {
  const _HojaDeCaptura({
    required this.titulo,
    required this.icono,
    required this.campos,
    required this.guardar,
    this.etiquetaGuardar = 'Guardar',
    this.aviso,
  });

  final String titulo;
  final IconData icono;
  final List<Widget> Function(bool ocupado) campos;

  /// Devuelve el id creado. Debe lanzar [ExoticWriteException] si algo falla.
  /// El `operation` se le pasa para que el reintento no duplique.
  final Future<String> Function(String operation) guardar;

  final String etiquetaGuardar;
  final String? aviso;

  @override
  Widget build(BuildContext context) => CaptureSheet(
    title: titulo,
    icon: icono,
    fields: campos,
    onSave: guardar,
    saveLabel: etiquetaGuardar,
    notice: aviso,
    translateError: _traducirError,
  );
}

/// Abre un formulario como hoja inferior y dice si se guardó algo.
Future<CapturaGuardada> _abrir(BuildContext context, Widget hoja) =>
    openCaptureSheet(context, hoja);

// ---------------------------------------------------------------------------
// Piezas de campo: reenvíos a core
// ---------------------------------------------------------------------------

double? leerNumero(String? texto) => readDecimal(texto);

class _CampoNumero extends StatelessWidget {
  const _CampoNumero({
    required this.control,
    required this.etiqueta,
    required this.ocupado,
    this.sufijo,
    this.ayuda,
  });

  final TextEditingController control;
  final String etiqueta;
  final bool ocupado;
  final String? sufijo;
  final String? ayuda;

  @override
  Widget build(BuildContext context) => CaptureNumberField(
    controller: control,
    label: etiqueta,
    busy: ocupado,
    suffix: sufijo,
    help: ayuda,
  );
}

class _CampoTexto extends StatelessWidget {
  const _CampoTexto({
    required this.control,
    required this.etiqueta,
    required this.ocupado,
    this.obligatorio = false,
    this.lineas = 1,
    this.maximo,
    this.ayuda,
  });

  final TextEditingController control;
  final String etiqueta;
  final bool ocupado, obligatorio;
  final int lineas;
  final int? maximo;
  final String? ayuda;

  @override
  Widget build(BuildContext context) => CaptureTextField(
    controller: control,
    label: etiqueta,
    busy: ocupado,
    required: obligatorio,
    lines: lineas,
    maxLength: maximo,
    help: ayuda,
  );
}

class _CampoFecha extends StatelessWidget {
  const _CampoFecha({
    required this.valor,
    required this.etiqueta,
    required this.ocupado,
    required this.alCambiar,
    this.soloPasado = true,
    this.obligatorio = false,
  });

  final DateTime? valor;
  final String etiqueta;
  final bool ocupado, soloPasado, obligatorio;
  final ValueChanged<DateTime?> alCambiar;

  @override
  Widget build(BuildContext context) => CaptureDateField(
    value: valor,
    label: etiqueta,
    busy: ocupado,
    onChanged: alCambiar,
    pastOnly: soloPasado,
    required: obligatorio,
  );
}

class _CampoOpcion<T> extends StatelessWidget {
  const _CampoOpcion({
    required this.valor,
    required this.etiqueta,
    required this.opciones,
    required this.nombrar,
    required this.ocupado,
    required this.alCambiar,
    this.ayuda,
  });

  final T? valor;
  final String etiqueta;
  final List<T> opciones;
  final String Function(T) nombrar;
  final bool ocupado;
  final ValueChanged<T?> alCambiar;
  final String? ayuda;

  @override
  Widget build(BuildContext context) => CaptureChoiceField<T>(
    value: valor,
    label: etiqueta,
    options: opciones,
    nameOf: nombrar,
    busy: ocupado,
    onChanged: alCambiar,
    help: ayuda,
  );
}

Widget _bloque(BuildContext context, String texto) =>
    captureBlockLabel(context, texto);

// ---------------------------------------------------------------------------
// Catalogos: deben coincidir con los CHECK de la base
// ---------------------------------------------------------------------------

/// Tipos de recinto. Mismos valores que el `check` de `exotic_enclosures`.
const tiposDeRecinto = <String, String>{
  'terrario': 'Terrario',
  'aviario': 'Aviario',
  'acuaterrario': 'Acuaterrario',
  'acuario': 'Acuario',
  'encierro': 'Encierro',
  'incubadora': 'Incubadora',
};

/// Los que tienen agua y por eso preguntan pH, amoniaco, nitrito y salinidad.
const _recintosConAgua = {'acuario', 'acuaterrario'};

/// Tipos de marcaje. Mismos valores que el `check` de `exotic_identifiers`.
const tiposDeMarcaje = <String, String>{
  'microchip': 'Microchip',
  'anillo': 'Anillo cerrado',
  'muesca': 'Muesca',
  'tatuaje': 'Tatuaje',
  'foto': 'Fotoidentificación',
};

/// Regímenes legales. Mismos valores que el `check` de `exotic_legal_status`.
const regimenesLegales = <String, String>{
  'cites': 'CITES',
  'semarnat': 'SEMARNAT',
  'uma': 'UMA',
  'pimvs': 'PIMVS',
  'otro': 'Otro',
};

/// Eventos fisiológicos. Mismos valores que el `check` de `exotic_events`.
const tiposDeEvento = <String, String>{
  'ecdisis': 'Ecdisis (muda)',
  'ecdisis_retenida': 'Ecdisis retenida',
  'postura': 'Postura',
  'vocalizacion': 'Vocalización',
  'actividad_anormal': 'Actividad anormal',
  'enriquecimiento': 'Enriquecimiento',
  'otro': 'Otro',
};

/// Estados de una nidada. Mismos valores que el `check` de `exotic_clutches`.
const estadosDeNidada = <String, String>{
  'incubando': 'Incubando',
  'eclosionada': 'Eclosionada',
  'perdida': 'Perdida',
  'cancelada': 'Cancelada',
};

// ---------------------------------------------------------------------------
// 1. Recinto
// ---------------------------------------------------------------------------

/// Alta de un recinto con su rango objetivo.
///
/// Los rangos son opcionales a propósito. Un rango vacío significa «este
/// recinto no vigila este parámetro», y el panel respeta esa decisión: no
/// juzga lo que no se declaró. Obligar a llenarlos todos produciría rangos
/// inventados, que es peor que no tener ninguno.
Future<CapturaGuardada> capturarRecinto(
  BuildContext context, {
  required ExoticWriteRepository repositorio,
  required String clinicId,
}) => _abrir(
  context,
  _FormularioRecinto(repositorio: repositorio, clinicId: clinicId),
);

class _FormularioRecinto extends StatefulWidget {
  const _FormularioRecinto({required this.repositorio, required this.clinicId});
  final ExoticWriteRepository repositorio;
  final String clinicId;
  @override
  State<_FormularioRecinto> createState() => _FormularioRecintoState();
}

class _FormularioRecintoState extends State<_FormularioRecinto> {
  final _nombre = TextEditingController();
  final _especie = TextEditingController();
  final _notas = TextEditingController();
  final _rangos = <String, TextEditingController>{
    for (final k in [
      'temp_caliente_min',
      'temp_caliente_max',
      'temp_fria_min',
      'temp_fria_max',
      'humedad_min',
      'humedad_max',
      'uv_min',
      'uv_max',
      'ph_min',
      'ph_max',
      'amoniaco_max',
      'nitrito_max',
      'salinidad_min',
      'salinidad_max',
    ])
      k: TextEditingController(),
  };
  String? _tipo;

  @override
  void dispose() {
    _nombre.dispose();
    _especie.dispose();
    _notas.dispose();
    for (final c in _rangos.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _par(
    bool ocupado,
    String etiqueta,
    String claveMin,
    String claveMax,
    String unidad,
  ) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: _CampoNumero(
          control: _rangos[claveMin]!,
          etiqueta: '$etiqueta mín.',
          sufijo: unidad,
          ocupado: ocupado,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _CampoNumero(
          control: _rangos[claveMax]!,
          etiqueta: '$etiqueta máx.',
          sufijo: unidad,
          ocupado: ocupado,
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final conAgua = _recintosConAgua.contains(_tipo);
    return _HojaDeCaptura(
      titulo: 'Nuevo recinto',
      icono: VetIcons.thermometer,
      aviso:
          'Deja en blanco los rangos que este recinto no vigile. El panel '
          'no juzga un parámetro que no se declaró.',
      campos: (ocupado) => [
        _CampoTexto(
          control: _nombre,
          etiqueta: 'Nombre',
          obligatorio: true,
          maximo: 80,
          ocupado: ocupado,
          ayuda: 'Como lo llaman en la clínica: «Terrario 3», «Pecera grande».',
        ),
        _CampoOpcion<String>(
          valor: _tipo,
          etiqueta: 'Tipo',
          opciones: tiposDeRecinto.keys.toList(),
          nombrar: (k) => tiposDeRecinto[k]!,
          ocupado: ocupado,
          alCambiar: (v) => setState(() => _tipo = v),
        ),
        _CampoTexto(
          control: _especie,
          etiqueta: 'Especie que aloja',
          ocupado: ocupado,
        ),
        _bloque(context, 'Gradiente térmico'),
        // Se piden los dos puntos por separado porque en un ectotermo son dos
        // exigencias distintas: una media las oculta a las dos.
        _par(
          ocupado,
          'Punto caliente',
          'temp_caliente_min',
          'temp_caliente_max',
          '°C',
        ),
        _par(ocupado, 'Punto frío', 'temp_fria_min', 'temp_fria_max', '°C'),
        _bloque(context, 'Humedad y luz'),
        _par(ocupado, 'Humedad', 'humedad_min', 'humedad_max', '%'),
        _par(ocupado, 'Índice UV', 'uv_min', 'uv_max', ''),
        if (conAgua) ...[
          _bloque(context, 'Calidad del agua'),
          _par(ocupado, 'pH', 'ph_min', 'ph_max', ''),
          // Amoniaco y nitrito solo llevan techo: cualquier cantidad por
          // encima de cero ya es toxica, el limite marca lo intolerable.
          _CampoNumero(
            control: _rangos['amoniaco_max']!,
            etiqueta: 'Amoniaco máx.',
            sufijo: 'mg/L',
            ocupado: ocupado,
            ayuda: 'Solo techo: lo ideal es cero.',
          ),
          _CampoNumero(
            control: _rangos['nitrito_max']!,
            etiqueta: 'Nitrito máx.',
            sufijo: 'mg/L',
            ocupado: ocupado,
          ),
          _par(ocupado, 'Salinidad', 'salinidad_min', 'salinidad_max', 'ppt'),
        ],
        _bloque(context, 'Notas'),
        _CampoTexto(
          control: _notas,
          etiqueta: 'Notas',
          lineas: 3,
          ocupado: ocupado,
        ),
      ],
      guardar: (operacion) => widget.repositorio.guardarRecinto(
        clinicId: widget.clinicId,
        nombre: _nombre.text.trim(),
        tipo: _tipo!,
        especie: _vacioANulo(_especie.text),
        // Si el tipo no tiene agua no se mandan sus rangos aunque hubieran
        // quedado escritos antes de cambiar el tipo.
        rangos: {
          for (final e in _rangos.entries)
            if (conAgua || !_clavesDeAgua.contains(e.key))
              e.key: leerNumero(e.value.text),
        },
        notas: _vacioANulo(_notas.text),
        operation: operacion,
      ),
    );
  }
}

const _clavesDeAgua = {
  'ph_min',
  'ph_max',
  'amoniaco_max',
  'nitrito_max',
  'salinidad_min',
  'salinidad_max',
};

String? _vacioANulo(String texto) {
  final t = texto.trim();
  return t.isEmpty ? null : t;
}

// ---------------------------------------------------------------------------
// 2. Lectura ambiental
// ---------------------------------------------------------------------------

/// Registra lo que el recinto ES, frente a lo que debería ser.
///
/// Solo pregunta por los parámetros que el recinto elegido declara. Si un
/// terrario no tiene rango de pH, el campo de pH no aparece.
Future<CapturaGuardada> capturarLectura(
  BuildContext context, {
  required ExoticWriteRepository repositorio,
  required String clinicId,
  required List<ExoticEnclosure> recintos,
  ExoticEnclosure? recintoInicial,
}) => _abrir(
  context,
  _FormularioLectura(
    repositorio: repositorio,
    clinicId: clinicId,
    recintos: recintos,
    recintoInicial: recintoInicial,
  ),
);

class _FormularioLectura extends StatefulWidget {
  const _FormularioLectura({
    required this.repositorio,
    required this.clinicId,
    required this.recintos,
    this.recintoInicial,
  });
  final ExoticWriteRepository repositorio;
  final String clinicId;
  final List<ExoticEnclosure> recintos;
  final ExoticEnclosure? recintoInicial;
  @override
  State<_FormularioLectura> createState() => _FormularioLecturaState();
}

class _FormularioLecturaState extends State<_FormularioLectura> {
  final _valores = <String, TextEditingController>{
    for (final k in [
      'temp_caliente',
      'temp_fria',
      'humedad',
      'uv_index',
      'ph',
      'amoniaco',
      'nitrito',
      'salinidad',
    ])
      k: TextEditingController(),
  };
  final _nota = TextEditingController();
  ExoticEnclosure? _recinto;

  @override
  void initState() {
    super.initState();
    _recinto =
        widget.recintoInicial ??
        (widget.recintos.length == 1 ? widget.recintos.first : null);
  }

  @override
  void dispose() {
    for (final c in _valores.values) {
      c.dispose();
    }
    _nota.dispose();
    super.dispose();
  }

  /// Qué parámetros declara el recinto elegido. Sin recinto, ninguno.
  List<Widget> _camposDelRecinto(bool ocupado) {
    final r = _recinto;
    if (r == null) return const [];
    final campos = <Widget>[];
    void si(bool declarado, String clave, String etiqueta, String unidad) {
      if (!declarado) return;
      campos.add(
        _CampoNumero(
          control: _valores[clave]!,
          etiqueta: etiqueta,
          sufijo: unidad,
          ocupado: ocupado,
        ),
      );
    }

    si(
      r.tempCalienteMin != null || r.tempCalienteMax != null,
      'temp_caliente',
      'Punto caliente',
      '°C',
    );
    si(
      r.tempFriaMin != null || r.tempFriaMax != null,
      'temp_fria',
      'Punto frío',
      '°C',
    );
    si(r.humedadMin != null || r.humedadMax != null, 'humedad', 'Humedad', '%');
    si(r.uvMin != null || r.uvMax != null, 'uv_index', 'Índice UV', '');
    si(r.phMin != null || r.phMax != null, 'ph', 'pH', '');
    si(r.amoniacoMax != null, 'amoniaco', 'Amoniaco', 'mg/L');
    si(r.nitritoMax != null, 'nitrito', 'Nitrito', 'mg/L');
    si(
      r.salinidadMin != null || r.salinidadMax != null,
      'salinidad',
      'Salinidad',
      'ppt',
    );

    if (campos.isEmpty) {
      campos.add(
        const VetNotice(
          text:
              'Este recinto no declara ningún rango objetivo todavía. '
              'Edítalo para añadirle rangos y así poder comparar sus lecturas.',
          icon: VetIcons.info,
          kind: VetBadgeKind.warning,
        ),
      );
    }
    return campos;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.recintos.isEmpty) {
      return const _SinRequisito(
        titulo: 'Registrar lectura',
        icono: VetIcons.thermometer,
        texto:
            'Antes de registrar una lectura hace falta dar de alta al menos '
            'un recinto. Una medición sin recinto no se puede comparar con '
            'nada.',
      );
    }
    return _HojaDeCaptura(
      titulo: 'Lectura de ambiente',
      icono: VetIcons.thermometer,
      aviso: 'Se registra con la hora actual. Deja vacío lo que no midas.',
      campos: (ocupado) => [
        _CampoOpcion<ExoticEnclosure>(
          valor: _recinto,
          etiqueta: 'Recinto',
          opciones: widget.recintos,
          nombrar: (r) => r.nombre,
          ocupado: ocupado,
          alCambiar: (v) => setState(() => _recinto = v),
        ),
        ..._camposDelRecinto(ocupado),
        _CampoTexto(
          control: _nota,
          etiqueta: 'Nota',
          lineas: 2,
          ocupado: ocupado,
        ),
      ],
      guardar: (operacion) => widget.repositorio.registrarLectura(
        clinicId: widget.clinicId,
        enclosureId: _recinto!.id,
        valores: {
          for (final e in _valores.entries) e.key: leerNumero(e.value.text),
        },
        nota: _vacioANulo(_nota.text),
        operation: operacion,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Toma de alimento
// ---------------------------------------------------------------------------

/// Registra una toma, aceptada o rechazada.
///
/// El rechazo se captura con el mismo rango que la aceptación porque en
/// reptiles y aves dejar de comer suele ser el primer signo clínico: si el
/// rechazo fuera una nota suelta, el panel no podría contar la racha.
Future<CapturaGuardada> capturarToma(
  BuildContext context, {
  required ExoticWriteRepository repositorio,
  required String clinicId,
  required List<ExoticSpecimen> ejemplares,
  ExoticSpecimen? ejemplarInicial,
}) => _abrir(
  context,
  _FormularioToma(
    repositorio: repositorio,
    clinicId: clinicId,
    ejemplares: ejemplares,
    ejemplarInicial: ejemplarInicial,
  ),
);

class _FormularioToma extends StatefulWidget {
  const _FormularioToma({
    required this.repositorio,
    required this.clinicId,
    required this.ejemplares,
    this.ejemplarInicial,
  });
  final ExoticWriteRepository repositorio;
  final String clinicId;
  final List<ExoticSpecimen> ejemplares;
  final ExoticSpecimen? ejemplarInicial;
  @override
  State<_FormularioToma> createState() => _FormularioTomaState();
}

class _FormularioTomaState extends State<_FormularioToma> {
  final _alimento = TextEditingController();
  final _cantidad = TextEditingController();
  final _nota = TextEditingController();
  ExoticSpecimen? _ejemplar;

  /// Sin valor por omisión: que la persona lo diga explícitamente. Si la
  /// opción viniera marcada en «aceptó», un descuido registraría comidas que
  /// no ocurrieron y la racha de rechazos dejaría de ser fiable.
  bool? _acepto;

  @override
  void initState() {
    super.initState();
    _ejemplar =
        widget.ejemplarInicial ??
        (widget.ejemplares.length == 1 ? widget.ejemplares.first : null);
  }

  @override
  void dispose() {
    _alimento.dispose();
    _cantidad.dispose();
    _nota.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ejemplares.isEmpty) {
      return const _SinRequisito(
        titulo: 'Registrar toma',
        icono: VetIcons.bowlPaw,
        texto:
            'No hay ejemplares registrados en esta clínica todavía. '
            'Da de alta al paciente en Pacientes y vuelve aquí.',
      );
    }
    return _HojaDeCaptura(
      titulo: 'Toma de alimento',
      icono: VetIcons.bowlPaw,
      campos: (ocupado) => [
        _CampoOpcion<ExoticSpecimen>(
          valor: _ejemplar,
          etiqueta: 'Ejemplar',
          opciones: widget.ejemplares,
          nombrar: (e) => e.titulo,
          ocupado: ocupado,
          alCambiar: (v) => setState(() => _ejemplar = v),
        ),
        _CampoTexto(
          control: _alimento,
          etiqueta: 'Qué se le ofreció',
          obligatorio: true,
          maximo: 120,
          ocupado: ocupado,
          ayuda: 'Ratón pinky, grillo, mezcla de verdura…',
        ),
        FormField<bool>(
          validator: (_) => _acepto == null ? 'Indica qué pasó' : null,
          builder: (estado) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      label: Text('Lo aceptó'),
                      icon: Icon(VetIcons.check),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text('Lo rechazó'),
                      icon: Icon(VetIcons.close),
                    ),
                  ],
                  selected: _acepto == null ? const {} : {_acepto!},
                  emptySelectionAllowed: true,
                  onSelectionChanged: ocupado
                      ? null
                      : (s) => setState(() {
                          _acepto = s.isEmpty ? null : s.first;
                          estado.didChange(_acepto);
                        }),
                ),
                if (estado.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 12),
                    child: Text(
                      estado.errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        _CampoNumero(
          control: _cantidad,
          etiqueta: 'Cantidad',
          sufijo: 'g',
          ocupado: ocupado,
        ),
        _CampoTexto(
          control: _nota,
          etiqueta: 'Nota',
          lineas: 2,
          ocupado: ocupado,
        ),
      ],
      guardar: (operacion) => widget.repositorio.registrarToma(
        clinicId: widget.clinicId,
        patientId: _ejemplar!.id,
        alimento: _alimento.text.trim(),
        aceptado: _acepto!,
        cantidadG: leerNumero(_cantidad.text),
        nota: _vacioANulo(_nota.text),
        operation: operacion,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Evento fisiologico
// ---------------------------------------------------------------------------

/// Ecdisis, postura, conducta. Lo que el expediente clínico general no nombra.
Future<CapturaGuardada> capturarEvento(
  BuildContext context, {
  required ExoticWriteRepository repositorio,
  required String clinicId,
  required List<ExoticSpecimen> ejemplares,
  ExoticSpecimen? ejemplarInicial,
}) => _abrir(
  context,
  _FormularioEvento(
    repositorio: repositorio,
    clinicId: clinicId,
    ejemplares: ejemplares,
    ejemplarInicial: ejemplarInicial,
  ),
);

class _FormularioEvento extends StatefulWidget {
  const _FormularioEvento({
    required this.repositorio,
    required this.clinicId,
    required this.ejemplares,
    this.ejemplarInicial,
  });
  final ExoticWriteRepository repositorio;
  final String clinicId;
  final List<ExoticSpecimen> ejemplares;
  final ExoticSpecimen? ejemplarInicial;
  @override
  State<_FormularioEvento> createState() => _FormularioEventoState();
}

class _FormularioEventoState extends State<_FormularioEvento> {
  final _detalle = TextEditingController();
  ExoticSpecimen? _ejemplar;
  String? _tipo;

  @override
  void initState() {
    super.initState();
    _ejemplar =
        widget.ejemplarInicial ??
        (widget.ejemplares.length == 1 ? widget.ejemplares.first : null);
  }

  @override
  void dispose() {
    _detalle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ejemplares.isEmpty) {
      return const _SinRequisito(
        titulo: 'Registrar evento',
        icono: VetIcons.lizard,
        texto: 'No hay ejemplares registrados en esta clínica todavía.',
      );
    }
    return _HojaDeCaptura(
      titulo: 'Evento fisiológico',
      icono: VetIcons.lizard,
      campos: (ocupado) => [
        _CampoOpcion<ExoticSpecimen>(
          valor: _ejemplar,
          etiqueta: 'Ejemplar',
          opciones: widget.ejemplares,
          nombrar: (e) => e.titulo,
          ocupado: ocupado,
          alCambiar: (v) => setState(() => _ejemplar = v),
        ),
        _CampoOpcion<String>(
          valor: _tipo,
          etiqueta: 'Qué ocurrió',
          opciones: tiposDeEvento.keys.toList(),
          nombrar: (k) => tiposDeEvento[k]!,
          ocupado: ocupado,
          alCambiar: (v) => setState(() => _tipo = v),
          // La retenida es urgencia: constriñe dedos y cola y puede costar
          // una falange. Por eso el panel la marca aparte.
          ayuda: _tipo == 'ecdisis_retenida'
              ? 'El panel la marcará como urgente.'
              : null,
        ),
        _CampoTexto(
          control: _detalle,
          etiqueta: 'Detalle',
          lineas: 3,
          maximo: 2000,
          ocupado: ocupado,
        ),
      ],
      guardar: (operacion) => widget.repositorio.registrarEvento(
        clinicId: widget.clinicId,
        patientId: _ejemplar!.id,
        tipo: _tipo!,
        detalle: _vacioANulo(_detalle.text),
        operation: operacion,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5. Marcaje
// ---------------------------------------------------------------------------

/// Microchip, anillo cerrado, muesca. Lo que permite buscar al ejemplar.
Future<CapturaGuardada> capturarMarcaje(
  BuildContext context, {
  required ExoticWriteRepository repositorio,
  required String clinicId,
  required List<ExoticSpecimen> ejemplares,
  ExoticSpecimen? ejemplarInicial,
}) => _abrir(
  context,
  _FormularioMarcaje(
    repositorio: repositorio,
    clinicId: clinicId,
    ejemplares: ejemplares,
    ejemplarInicial: ejemplarInicial,
  ),
);

class _FormularioMarcaje extends StatefulWidget {
  const _FormularioMarcaje({
    required this.repositorio,
    required this.clinicId,
    required this.ejemplares,
    this.ejemplarInicial,
  });
  final ExoticWriteRepository repositorio;
  final String clinicId;
  final List<ExoticSpecimen> ejemplares;
  final ExoticSpecimen? ejemplarInicial;
  @override
  State<_FormularioMarcaje> createState() => _FormularioMarcajeState();
}

class _FormularioMarcajeState extends State<_FormularioMarcaje> {
  final _codigo = TextEditingController();
  final _ubicacion = TextEditingController();
  ExoticSpecimen? _ejemplar;
  String? _tipo;
  DateTime? _colocado;

  @override
  void initState() {
    super.initState();
    _ejemplar =
        widget.ejemplarInicial ??
        (widget.ejemplares.length == 1 ? widget.ejemplares.first : null);
  }

  @override
  void dispose() {
    _codigo.dispose();
    _ubicacion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ejemplares.isEmpty) {
      return const _SinRequisito(
        titulo: 'Registrar marcaje',
        icono: VetIcons.tagPaw,
        texto: 'No hay ejemplares registrados en esta clínica todavía.',
      );
    }
    return _HojaDeCaptura(
      titulo: 'Marcaje del ejemplar',
      icono: VetIcons.tagPaw,
      aviso:
          'Un mismo código activo no puede estar en dos ejemplares de la '
          'clínica: el buscador dejaría de ser fiable.',
      campos: (ocupado) => [
        _CampoOpcion<ExoticSpecimen>(
          valor: _ejemplar,
          etiqueta: 'Ejemplar',
          opciones: widget.ejemplares,
          nombrar: (e) => e.titulo,
          ocupado: ocupado,
          alCambiar: (v) => setState(() => _ejemplar = v),
        ),
        _CampoOpcion<String>(
          valor: _tipo,
          etiqueta: 'Tipo de marca',
          opciones: tiposDeMarcaje.keys.toList(),
          nombrar: (k) => tiposDeMarcaje[k]!,
          ocupado: ocupado,
          alCambiar: (v) => setState(() => _tipo = v),
        ),
        _CampoTexto(
          control: _codigo,
          etiqueta: 'Código',
          obligatorio: true,
          maximo: 60,
          ocupado: ocupado,
          ayuda: _tipo == 'microchip'
              ? 'Los 15 dígitos del transpondedor.'
              : null,
        ),
        _CampoFecha(
          valor: _colocado,
          etiqueta: 'Colocado el',
          ocupado: ocupado,
          alCambiar: (v) => setState(() => _colocado = v),
        ),
        _CampoTexto(
          control: _ubicacion,
          etiqueta: 'Ubicación en el cuerpo',
          ocupado: ocupado,
          ayuda: 'Pata izquierda, zona interescapular…',
        ),
      ],
      guardar: (operacion) => widget.repositorio.guardarMarcaje(
        clinicId: widget.clinicId,
        patientId: _ejemplar!.id,
        tipo: _tipo!,
        codigo: _codigo.text.trim(),
        colocadoEl: _colocado,
        ubicacion: _vacioANulo(_ubicacion.text),
        operation: operacion,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 6. Estatus legal
// ---------------------------------------------------------------------------

/// CITES / SEMARNAT. Solo lo firma administrador o MVZ.
Future<CapturaGuardada> capturarEstatusLegal(
  BuildContext context, {
  required ExoticWriteRepository repositorio,
  required String clinicId,
  required List<ExoticSpecimen> ejemplares,
  ExoticSpecimen? ejemplarInicial,
}) => _abrir(
  context,
  _FormularioLegal(
    repositorio: repositorio,
    clinicId: clinicId,
    ejemplares: ejemplares,
    ejemplarInicial: ejemplarInicial,
  ),
);

class _FormularioLegal extends StatefulWidget {
  const _FormularioLegal({
    required this.repositorio,
    required this.clinicId,
    required this.ejemplares,
    this.ejemplarInicial,
  });
  final ExoticWriteRepository repositorio;
  final String clinicId;
  final List<ExoticSpecimen> ejemplares;
  final ExoticSpecimen? ejemplarInicial;
  @override
  State<_FormularioLegal> createState() => _FormularioLegalState();
}

class _FormularioLegalState extends State<_FormularioLegal> {
  final _apendice = TextEditingController();
  final _numero = TextEditingController();
  final _procedencia = TextEditingController();
  final _notas = TextEditingController();
  ExoticSpecimen? _ejemplar;
  String? _regimen;
  DateTime? _desde, _hasta;
  bool _documentada = false;

  @override
  void initState() {
    super.initState();
    _ejemplar =
        widget.ejemplarInicial ??
        (widget.ejemplares.length == 1 ? widget.ejemplares.first : null);
  }

  @override
  void dispose() {
    _apendice.dispose();
    _numero.dispose();
    _procedencia.dispose();
    _notas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ejemplares.isEmpty) {
      return const _SinRequisito(
        titulo: 'Estatus legal',
        icono: VetIcons.certificate,
        texto: 'No hay ejemplares registrados en esta clínica todavía.',
      );
    }
    return _HojaDeCaptura(
      titulo: 'Estatus legal',
      icono: VetIcons.certificate,
      aviso:
          'Este registro solo lo puede firmar un administrador o un MVZ: '
          'es quien responde por él ante la autoridad.',
      campos: (ocupado) => [
        _CampoOpcion<ExoticSpecimen>(
          valor: _ejemplar,
          etiqueta: 'Ejemplar',
          opciones: widget.ejemplares,
          nombrar: (e) => e.titulo,
          ocupado: ocupado,
          alCambiar: (v) => setState(() => _ejemplar = v),
        ),
        _CampoOpcion<String>(
          valor: _regimen,
          etiqueta: 'Régimen',
          opciones: regimenesLegales.keys.toList(),
          nombrar: (k) => regimenesLegales[k]!,
          ocupado: ocupado,
          alCambiar: (v) => setState(() => _regimen = v),
        ),
        if (_regimen == 'cites')
          _CampoTexto(
            control: _apendice,
            etiqueta: 'Apéndice',
            ocupado: ocupado,
            ayuda: 'I, II o III.',
          ),
        _CampoTexto(
          control: _numero,
          etiqueta: 'Número de registro',
          maximo: 80,
          ocupado: ocupado,
        ),
        _CampoFecha(
          valor: _desde,
          etiqueta: 'Vigente desde',
          ocupado: ocupado,
          alCambiar: (v) => setState(() => _desde = v),
        ),
        _CampoFecha(
          valor: _hasta,
          etiqueta: 'Vigente hasta',
          ocupado: ocupado,
          // La vigencia termina en el futuro: ese es justo el caso normal.
          soloPasado: false,
          alCambiar: (v) => setState(() => _hasta = v),
        ),
        _CampoTexto(
          control: _procedencia,
          etiqueta: 'Procedencia',
          ocupado: ocupado,
          ayuda: 'Criadero, UMA de origen, decomiso…',
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _documentada,
          title: const Text('Procedencia documentada'),
          subtitle: const Text(
            'Marca solo si el papel existe y está en el expediente.',
          ),
          onChanged: ocupado ? null : (v) => setState(() => _documentada = v),
        ),
        const SizedBox(height: 8),
        _CampoTexto(
          control: _notas,
          etiqueta: 'Notas',
          lineas: 3,
          ocupado: ocupado,
        ),
      ],
      guardar: (operacion) => widget.repositorio.guardarEstatusLegal(
        clinicId: widget.clinicId,
        patientId: _ejemplar!.id,
        regimen: _regimen!,
        apendice: _regimen == 'cites' ? _vacioANulo(_apendice.text) : null,
        numero: _vacioANulo(_numero.text),
        desde: _desde,
        hasta: _hasta,
        procedencia: _vacioANulo(_procedencia.text),
        documentada: _documentada,
        notas: _vacioANulo(_notas.text),
        operation: operacion,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 7. Nidada
// ---------------------------------------------------------------------------

/// Una puesta en incubación.
///
/// La temperatura se pide por nidada, no por incubadora, porque en varias
/// especies determina el sexo de las crías.
Future<CapturaGuardada> capturarNidada(
  BuildContext context, {
  required ExoticWriteRepository repositorio,
  required String clinicId,
  required List<ExoticEnclosure> recintos,
}) => _abrir(
  context,
  _FormularioNidada(
    repositorio: repositorio,
    clinicId: clinicId,
    recintos: recintos,
  ),
);

class _FormularioNidada extends StatefulWidget {
  const _FormularioNidada({
    required this.repositorio,
    required this.clinicId,
    required this.recintos,
  });
  final ExoticWriteRepository repositorio;
  final String clinicId;
  final List<ExoticEnclosure> recintos;
  @override
  State<_FormularioNidada> createState() => _FormularioNidadaState();
}

class _FormularioNidadaState extends State<_FormularioNidada> {
  final _especie = TextEditingController();
  final _huevos = TextEditingController();
  final _fertiles = TextEditingController();
  final _temp = TextEditingController();
  final _humedad = TextEditingController();
  final _dias = TextEditingController();
  final _notas = TextEditingController();
  DateTime? _puesta = DateTime.now();
  ExoticEnclosure? _recinto;
  String _estado = 'incubando';

  @override
  void dispose() {
    _especie.dispose();
    _huevos.dispose();
    _fertiles.dispose();
    _temp.dispose();
    _humedad.dispose();
    _dias.dispose();
    _notas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _HojaDeCaptura(
    titulo: 'Nueva nidada',
    icono: VetIcons.egg,
    aviso:
        'La fecha de eclosión la calcula el servidor con los días de '
        'incubación, para que no dependa del reloj del teléfono.',
    campos: (ocupado) => [
      _CampoTexto(
        control: _especie,
        etiqueta: 'Especie',
        obligatorio: true,
        ocupado: ocupado,
      ),
      _CampoFecha(
        valor: _puesta,
        etiqueta: 'Fecha de puesta',
        obligatorio: true,
        ocupado: ocupado,
        alCambiar: (v) => setState(() => _puesta = v),
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              controller: _huevos,
              enabled: !ocupado,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Huevos *',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                if (n == null || n < 1) return 'Al menos 1';
                return null;
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _fertiles,
              enabled: !ocupado,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Fértiles',
                helperText: 'Tras ovoscopia',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null;
                final f = int.tryParse(t);
                if (f == null) return 'Número no válido';
                final total = int.tryParse(_huevos.text.trim());
                if (total != null && f > total) return 'Más que el total';
                return null;
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _bloque(context, 'Incubación'),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _CampoNumero(
              control: _temp,
              etiqueta: 'Temperatura',
              sufijo: '°C',
              ocupado: ocupado,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _CampoNumero(
              control: _humedad,
              etiqueta: 'Humedad',
              sufijo: '%',
              ocupado: ocupado,
            ),
          ),
        ],
      ),
      TextFormField(
        controller: _dias,
        enabled: !ocupado,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          labelText: 'Días de incubación',
          helperText: 'Con esto se calcula la fecha estimada de eclosión.',
          border: OutlineInputBorder(),
        ),
        validator: (v) {
          final t = (v ?? '').trim();
          if (t.isEmpty) return null;
          final d = int.tryParse(t);
          if (d == null || d < 1 || d > 400) return 'Entre 1 y 400';
          return null;
        },
      ),
      const SizedBox(height: 12),
      if (widget.recintos.isNotEmpty)
        _CampoOpcion<ExoticEnclosure>(
          valor: _recinto,
          etiqueta: 'Incubadora o recinto',
          opciones: widget.recintos,
          nombrar: (r) => r.nombre,
          ocupado: ocupado,
          alCambiar: (v) => setState(() => _recinto = v),
        ),
      _CampoOpcion<String>(
        valor: _estado,
        etiqueta: 'Estado',
        opciones: estadosDeNidada.keys.toList(),
        nombrar: (k) => estadosDeNidada[k]!,
        ocupado: ocupado,
        alCambiar: (v) => setState(() => _estado = v ?? 'incubando'),
      ),
      _CampoTexto(
        control: _notas,
        etiqueta: 'Notas',
        lineas: 3,
        ocupado: ocupado,
      ),
    ],
    guardar: (operacion) => widget.repositorio.guardarNidada(
      clinicId: widget.clinicId,
      enclosureId: _recinto?.id,
      especie: _especie.text.trim(),
      puesta: _puesta ?? DateTime.now(),
      huevos: int.parse(_huevos.text.trim()),
      fertiles: int.tryParse(_fertiles.text.trim()),
      temp: leerNumero(_temp.text),
      humedad: leerNumero(_humedad.text),
      dias: int.tryParse(_dias.text.trim()),
      estado: _estado,
      notas: _vacioANulo(_notas.text),
      operation: operacion,
    ),
  );
}

// ---------------------------------------------------------------------------
// 8. Plan de cuarentena
// ---------------------------------------------------------------------------

/// Los días previstos de aislamiento de una hospitalización abierta.
Future<CapturaGuardada> capturarCuarentena(
  BuildContext context, {
  required ExoticWriteRepository repositorio,
  required String clinicId,
  required List<ExoticStay> estancias,
  required String Function(ExoticStay) nombrar,
  ExoticStay? estanciaInicial,
}) => _abrir(
  context,
  _FormularioCuarentena(
    repositorio: repositorio,
    clinicId: clinicId,
    estancias: estancias,
    nombrar: nombrar,
    estanciaInicial: estanciaInicial,
  ),
);

class _FormularioCuarentena extends StatefulWidget {
  const _FormularioCuarentena({
    required this.repositorio,
    required this.clinicId,
    required this.estancias,
    required this.nombrar,
    this.estanciaInicial,
  });
  final ExoticWriteRepository repositorio;
  final String clinicId;
  final List<ExoticStay> estancias;
  final String Function(ExoticStay) nombrar;
  final ExoticStay? estanciaInicial;
  @override
  State<_FormularioCuarentena> createState() => _FormularioCuarentenaState();
}

class _FormularioCuarentenaState extends State<_FormularioCuarentena> {
  final _dias = TextEditingController();
  final _motivo = TextEditingController();
  ExoticStay? _estancia;

  @override
  void initState() {
    super.initState();
    _estancia =
        widget.estanciaInicial ??
        (widget.estancias.length == 1 ? widget.estancias.first : null);
    final previos = _estancia?.diasAislamiento;
    if (previos != null) _dias.text = '$previos';
  }

  @override
  void dispose() {
    _dias.dispose();
    _motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.estancias.isEmpty) {
      return const _SinRequisito(
        titulo: 'Plan de cuarentena',
        icono: VetIcons.hospital,
        texto:
            'No hay hospitalizaciones abiertas. La cuarentena se fija '
            'sobre una estancia que ya existe.',
      );
    }
    return _HojaDeCaptura(
      titulo: 'Plan de cuarentena',
      icono: VetIcons.hospital,
      etiquetaGuardar: 'Fijar días',
      aviso:
          'Con esto el panel cuenta hacia atrás los días que faltan para '
          'terminar el aislamiento.',
      campos: (ocupado) => [
        _CampoOpcion<ExoticStay>(
          valor: _estancia,
          etiqueta: 'Hospitalización',
          opciones: widget.estancias,
          nombrar: widget.nombrar,
          ocupado: ocupado,
          alCambiar: (v) => setState(() {
            _estancia = v;
            final previos = v?.diasAislamiento;
            _dias.text = previos == null ? '' : '$previos';
          }),
        ),
        TextFormField(
          controller: _dias,
          enabled: !ocupado,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Días previstos *',
            border: OutlineInputBorder(),
          ),
          validator: (v) {
            final d = int.tryParse((v ?? '').trim());
            if (d == null || d < 1 || d > 365) return 'Entre 1 y 365';
            return null;
          },
        ),
        const SizedBox(height: 12),
        _CampoTexto(
          control: _motivo,
          etiqueta: 'Motivo',
          lineas: 2,
          ocupado: ocupado,
          ayuda: 'Ingreso nuevo, contacto con caso, sospecha…',
        ),
      ],
      guardar: (operacion) => widget.repositorio.fijarCuarentena(
        clinicId: widget.clinicId,
        stayId: _estancia!.id,
        dias: int.parse(_dias.text.trim()),
        motivo: _vacioANulo(_motivo.text),
        operation: operacion,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Falta un requisito previo
// ---------------------------------------------------------------------------

/// Lo que se enseña cuando el formulario no se puede abrir todavía.
///
/// No es un error ni un formulario vacío: es que falta un paso anterior. Se
/// dice cuál, en lugar de dejar un desplegable sin opciones.
class _SinRequisito extends StatelessWidget {
  const _SinRequisito({
    required this.titulo,
    required this.icono,
    required this.texto,
  });
  final String titulo;
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) =>
      MissingPrerequisiteSheet(title: titulo, icon: icono, text: texto);
}

/// Quién puede escribir en exóticos. Coincide con el `has_clinic_role` de los
/// RPC: si el servidor va a rechazar la operación, mejor no enseñar el botón.
bool puedeCapturarExoticos(ClinicMembership? miembro) =>
    miembro != null &&
    const {
      ClinicRole.admin,
      ClinicRole.mvz,
      ClinicRole.auxiliar,
    }.contains(miembro.role);

/// Quién puede firmar el estatus legal. Más restrictivo: solo admin y MVZ.
bool puedeFirmarEstatusLegal(ClinicMembership? miembro) =>
    miembro != null &&
    const {ClinicRole.admin, ClinicRole.mvz}.contains(miembro.role);

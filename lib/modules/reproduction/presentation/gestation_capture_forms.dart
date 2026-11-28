/// Los formularios de gestación.
///
/// Usan el mismo andamio que exóticos y producción (`core/widgets/
/// capture_sheet.dart`), así que heredan sin esfuerzo el recibo de
/// idempotencia, el estado ocupado y la traducción de errores.
///
/// La decisión propia de este archivo es que **los días de gestación se
/// sugieren desde el catálogo pero se pueden corregir**. Al elegir la hembra,
/// el formulario busca su especie en `reproduccion_gestacion_dias` y rellena
/// los días; si la especie no está en el catálogo, el campo queda vacío y se
/// dice por qué, en vez de poner un número inventado que acabaría siendo la
/// fecha de parto que alguien se cree.
library;

import 'package:flutter/material.dart';

import '../../../core/widgets/capture_sheet.dart';
import '../../../vet_ui/vet_icons.dart';
import '../../auth/domain/clinic_membership.dart';
import '../domain/gestation.dart';
import '../domain/gestation_write_repository.dart';

/// Registrar y cerrar gestaciones: administrador, MVZ y auxiliar.
bool puedeCapturarGestacion(ClinicMembership? member) =>
    member != null &&
    (member.role == ClinicRole.admin ||
        member.role == ClinicRole.mvz ||
        member.role == ClinicRole.auxiliar);

/// Cómo se cierra una gestación.
const Map<String, String> cierresDeGestacion = {
  'parida': 'Parió',
  'aborto': 'Aborto',
  'vacia': 'Resultó vacía',
  'cancelada': 'Cancelar el registro',
};

String nombreDeHembra(BreedingFemale h) =>
    h.especie.isEmpty ? h.nombre : '${h.nombre} · ${h.especie}';

// ---------------------------------------------------------------------------
// 1. Alta y edición de gestación
// ---------------------------------------------------------------------------

/// Abre el formulario de gestación. [inicial] no nulo significa edición.
Future<bool> capturarGestacion(
  BuildContext context, {
  required String clinicId,
  required GestationWriteRepository repo,
  required List<GestationDays> catalogo,
  Gestation? inicial,
  String? loteId,
  String? nombreDelLote,
}) => openCaptureSheet(
  context,
  _GestacionSheet(
    clinicId: clinicId,
    repo: repo,
    catalogo: catalogo,
    inicial: inicial,
    loteId: loteId,
    nombreDelLote: nombreDelLote,
  ),
);

class _GestacionSheet extends StatefulWidget {
  const _GestacionSheet({
    required this.clinicId,
    required this.repo,
    required this.catalogo,
    this.inicial,
    this.loteId,
    this.nombreDelLote,
  });
  final String clinicId;
  final GestationWriteRepository repo;
  final List<GestationDays> catalogo;
  final Gestation? inicial;
  final String? loteId;
  final String? nombreDelLote;

  @override
  State<_GestacionSheet> createState() => _GestacionSheetState();
}

class _GestacionSheetState extends State<_GestacionSheet> {
  final _semental = TextEditingController();
  final _dias = TextEditingController();
  final _notas = TextEditingController();

  BreedingFemale? _hembra;
  MatingMethod _metodo = MatingMethod.montaNatural;
  PregnancyCheck _diagnostico = PregnancyCheck.pendiente;
  DateTime _servicio = DateTime.now();
  DateTime? _diagnosticoEl;

  List<BreedingFemale> _hembras = const [];
  bool _cargando = true;
  String? _errorCarga;

  @override
  void initState() {
    super.initState();
    final i = widget.inicial;
    if (i != null) {
      _semental.text = i.semental ?? '';
      _dias.text = i.diasGestacion?.toString() ?? '';
      _notas.text = i.notas ?? '';
      _metodo = i.metodo;
      _diagnostico = i.diagnostico;
      _servicio = i.servicio;
      _diagnosticoEl = i.diagnosticoEl;
    }
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final lista = await widget.repo.hembras(widget.clinicId);
      if (!mounted) return;
      setState(() {
        _hembras = lista;
        _cargando = false;
        final i = widget.inicial;
        if (i != null) {
          for (final h in lista) {
            if (h.id == i.patientId) _hembra = h;
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorCarga = 'No se pudo leer el padrón de hembras.';
      });
    }
  }

  @override
  void dispose() {
    _semental.dispose();
    _dias.dispose();
    _notas.dispose();
    super.dispose();
  }

  /// Al elegir hembra se sugieren los días de su especie, pero solo si el
  /// campo está vacío: si alguien ya escribió un número, no se le pisa.
  void _sugerirDias(BreedingFemale h) {
    if (_dias.text.trim().isNotEmpty) return;
    final d = diasDeEspecie(widget.catalogo, h.especie);
    if (d != null) _dias.text = '${d.promedio}';
  }

  /// La fecha de parto que se irá a guardar, para poder enseñarla antes.
  /// La definitiva la calcula el servidor; esta es la misma cuenta y sirve
  /// para que nadie guarde a ciegas.
  String get _previsto {
    final n = int.tryParse(_dias.text.trim());
    if (n == null || n < 1 || n > 400) return 'Se calculará al guardar';
    final f = _servicio.add(Duration(days: n));
    return '${f.day.toString().padLeft(2, '0')}/'
        '${f.month.toString().padLeft(2, '0')}/${f.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorCarga != null) {
      return MissingPrerequisiteSheet(
        title: 'Padrón no disponible',
        icon: VetIcons.alertTriangle,
        text: '$_errorCarga Revisa la conexión e inténtalo de nuevo.',
      );
    }
    if (_hembras.isEmpty) {
      return const MissingPrerequisiteSheet(
        title: 'Gestación',
        icon: VetIcons.heart,
        text: 'Primero da de alta a la hembra como paciente. Una gestación se '
            'registra sobre un animal concreto, y hoy no hay ninguna hembra '
            'en el padrón de esta cuenta.',
      );
    }

    final editando = widget.inicial != null;
    final sugerencia = _hembra == null
        ? null
        : diasDeEspecie(widget.catalogo, _hembra!.especie);

    return CaptureSheet(
      title: editando ? 'Editar gestación' : 'Nueva gestación',
      icon: VetIcons.heart,
      saveLabel: editando ? 'Guardar cambios' : 'Registrar',
      translateError: (e) => traducirErrorGestacion(e).mensaje,
      notice: widget.nombreDelLote == null
          ? null
          : 'Se vinculará al lote ${widget.nombreDelLote}.',
      fields: (busy) => [
        CaptureChoiceField<BreedingFemale>(
          value: _hembras.contains(_hembra) ? _hembra : null,
          label: 'Hembra',
          options: _hembras,
          nameOf: nombreDeHembra,
          busy: busy,
          help: 'Del padrón de pacientes. Se muestran las hembras y las que '
              'no tienen sexo capturado.',
          onChanged: (v) => setState(() {
            _hembra = v;
            if (v != null) _sugerirDias(v);
          }),
        ),
        CaptureDateField(
          value: _servicio,
          label: 'Fecha del servicio',
          busy: busy,
          required: true,
          onChanged: (v) => setState(() => _servicio = v ?? _servicio),
        ),
        CaptureChoiceField<MatingMethod>(
          value: _metodo,
          label: 'Método',
          options: MatingMethod.values,
          nameOf: (m) => m.label,
          busy: busy,
          onChanged: (v) => setState(() => _metodo = v ?? _metodo),
        ),
        CaptureTextField(
          controller: _semental,
          label: 'Semental o pajilla',
          busy: busy,
          maxLength: 80,
          help: 'Opcional. Con qué macho o qué dosis se sirvió.',
        ),
        CaptureIntField(
          controller: _dias,
          label: 'Días de gestación',
          busy: busy,
          min: 1,
          max: 400,
          help: _hembra == null
              ? 'Elige primero la hembra.'
              : sugerencia != null
              ? 'Sugerido para ${sugerencia.nombre}: ${sugerencia.rango}. '
                    'Puedes corregirlo.'
              : 'El catálogo no tiene días para «${_hembra!.especie}». '
                    'Escríbelos si los conoces; si no, se queda sin fecha '
                    'prevista en vez de inventar una.',
        ),
        captureBlockLabel(context, 'Parto previsto: $_previsto'),
        CaptureChoiceField<PregnancyCheck>(
          value: _diagnostico,
          label: 'Diagnóstico',
          options: PregnancyCheck.values,
          nameOf: (d) => d.label,
          busy: busy,
          onChanged: (v) => setState(() => _diagnostico = v ?? _diagnostico),
        ),
        CaptureDateField(
          value: _diagnosticoEl,
          label: 'Fecha del diagnóstico',
          busy: busy,
          onChanged: (v) => setState(() => _diagnosticoEl = v),
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
        final h = _hembra;
        if (h == null) {
          throw const GestationWriteException(
            'patient_not_found',
            'Elige la hembra.',
          );
        }
        if (_diagnosticoEl != null && _diagnosticoEl!.isBefore(_servicio)) {
          throw const GestationWriteException(
            'diagnostico_antes_del_servicio',
            'El diagnóstico no puede ser anterior al servicio.',
          );
        }
        return widget.repo.guardarGestacion(
          clinicId: widget.clinicId,
          id: widget.inicial?.id,
          patientId: h.id,
          loteId: widget.loteId ?? widget.inicial?.loteId,
          especie: h.especie.isEmpty ? 'sin especificar' : h.especie,
          servicio: _servicio,
          metodo: _metodo.code,
          semental: emptyToNull(_semental.text),
          dias: int.tryParse(_dias.text.trim()),
          diagnostico: _diagnostico.code,
          diagnosticoEl: _diagnosticoEl,
          notas: emptyToNull(_notas.text),
          operation: operation,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Cierre
// ---------------------------------------------------------------------------

/// Abre el formulario de cierre de una gestación.
Future<bool> cerrarGestacion(
  BuildContext context, {
  required String clinicId,
  required GestationWriteRepository repo,
  required Gestation gestacion,
  required String nombreDeLaHembra,
}) => openCaptureSheet(
  context,
  _CierreSheet(
    clinicId: clinicId,
    repo: repo,
    gestacion: gestacion,
    nombre: nombreDeLaHembra,
  ),
);

class _CierreSheet extends StatefulWidget {
  const _CierreSheet({
    required this.clinicId,
    required this.repo,
    required this.gestacion,
    required this.nombre,
  });
  final String clinicId;
  final GestationWriteRepository repo;
  final Gestation gestacion;
  final String nombre;

  @override
  State<_CierreSheet> createState() => _CierreSheetState();
}

class _CierreSheetState extends State<_CierreSheet> {
  String _estado = 'parida';
  DateTime? _parto = DateTime.now();
  final _vivas = TextEditingController();
  final _muertas = TextEditingController();
  final _notas = TextEditingController();

  @override
  void dispose() {
    _vivas.dispose();
    _muertas.dispose();
    _notas.dispose();
    super.dispose();
  }

  bool get _pario => _estado == 'parida';

  @override
  Widget build(BuildContext context) => CaptureSheet(
    title: 'Cerrar gestación',
    icon: VetIcons.checkCircle,
    saveLabel: 'Cerrar',
    translateError: (e) => traducirErrorGestacion(e).mensaje,
    notice: '${widget.nombre} · servicio del '
        '${widget.gestacion.servicio.day.toString().padLeft(2, '0')}/'
        '${widget.gestacion.servicio.month.toString().padLeft(2, '0')}/'
        '${widget.gestacion.servicio.year}',
    fields: (busy) => [
      CaptureChoiceField<String>(
        value: _estado,
        label: 'Cómo terminó',
        options: cierresDeGestacion.keys.toList(),
        nameOf: (c) => cierresDeGestacion[c] ?? c,
        busy: busy,
        onChanged: (v) => setState(() => _estado = v ?? _estado),
      ),
      CaptureDateField(
        value: _parto,
        label: _pario ? 'Fecha del parto' : 'Fecha del desenlace',
        busy: busy,
        // Solo el parto la exige: un aborto puede no tener fecha exacta.
        required: _pario,
        onChanged: (v) => setState(() => _parto = v),
      ),
      // Las crias solo se piden cuando hubo parto. Pedirlas en un «vacia»
      // obligaria a escribir un cero que no significa nada.
      if (_pario) ...[
        CaptureIntField(
          controller: _vivas,
          label: 'Crías vivas',
          busy: busy,
          required: true,
          min: 0,
          max: 10000,
        ),
        CaptureIntField(
          controller: _muertas,
          label: 'Crías muertas',
          busy: busy,
          min: 0,
          max: 10000,
        ),
      ],
      CaptureTextField(
        controller: _notas,
        label: 'Notas',
        busy: busy,
        lines: 3,
        maxLength: 2000,
      ),
    ],
    onSave: (operation) async {
      if (_pario && _parto == null) {
        throw const GestationWriteException(
          'parto_requerido',
          'Para cerrar como parida hace falta la fecha del parto.',
        );
      }
      if (_parto != null && _parto!.isBefore(widget.gestacion.servicio)) {
        throw const GestationWriteException(
          'parto_antes_del_servicio',
          'El parto no puede ser anterior al servicio.',
        );
      }
      return widget.repo.cerrarGestacion(
        clinicId: widget.clinicId,
        id: widget.gestacion.id,
        estado: _estado,
        parto: _parto,
        vivas: _pario ? int.tryParse(_vivas.text.trim()) : null,
        muertas: _pario ? int.tryParse(_muertas.text.trim()) : null,
        notas: emptyToNull(_notas.text),
        operation: operation,
      );
    },
  );
}

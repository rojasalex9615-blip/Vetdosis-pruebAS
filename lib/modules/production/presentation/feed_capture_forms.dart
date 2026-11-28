/// Los formularios del inventario de alimento.
///
/// Usan el mismo andamio que exóticos, producción y gestación
/// (`core/widgets/capture_sheet.dart`), así que heredan el recibo de
/// idempotencia, el estado ocupado y la traducción de errores.
///
/// Las dos decisiones propias de este archivo:
///
/// 1. **Se captura en la unidad con que se compra y se guarda en kilos.** Quien
///    recibe el camión cuenta sacos, no kilos. El formulario enseña la
///    conversión antes de guardar; lo que viaja al servidor son siempre kilos,
///    para que cambiar después el peso del saco no reescriba la historia.
/// 2. **El precio solo se pide en la compra.** En las salidas lo calcula el
///    servidor al promedio ponderado de lo que hay, porque el costo de lo que
///    se comió un lote no es el precio de hoy sino el de lo que estaba cargado.
library;

import 'package:flutter/material.dart';

import '../../../core/widgets/capture_sheet.dart';
import '../../../vet_ui/vet_icons.dart';
import '../../auth/domain/clinic_membership.dart';
import '../domain/feed_inventory.dart';
import '../domain/feed_write_repository.dart';

/// Dar de alta alimentos y silos: solo administrador y MVZ.
///
/// El catálogo define cómo se mide y cuánto vale todo lo demás, igual que el
/// alta de lotes.
bool puedeGestionarCatalogoAlimento(ClinicMembership? member) =>
    member != null &&
    (member.role == ClinicRole.admin || member.role == ClinicRole.mvz);

/// Mover alimento: administrador, MVZ y auxiliar.
///
/// Quien reparte el alimento a las seis de la mañana suele ser auxiliar; si no
/// pudiera registrarlo, el consumo se apuntaría en un cuaderno y nunca llegaría.
bool puedeMoverAlimento(ClinicMembership? member) =>
    member != null &&
    (member.role == ClinicRole.admin ||
        member.role == ClinicRole.mvz ||
        member.role == ClinicRole.auxiliar);

String _fmt(double v) {
  if (v.abs() >= 1000) {
    final entero = v.round().toString();
    final b = StringBuffer();
    for (var i = 0; i < entero.length; i++) {
      if (i > 0 && (entero.length - i) % 3 == 0 && entero[i] != '-') {
        b.write(' ');
      }
      b.write(entero[i]);
    }
    return b.toString();
  }
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(2);
}

// ---------------------------------------------------------------------------
// 1. Alta y edición de alimento
// ---------------------------------------------------------------------------

/// Abre el formulario de alimento. [inicial] no nulo significa edición.
Future<bool> capturarAlimento(
  BuildContext context, {
  required String clinicId,
  required FeedWriteRepository repo,
  FeedItem? inicial,
}) => openCaptureSheet(
  context,
  _AlimentoSheet(clinicId: clinicId, repo: repo, inicial: inicial),
);

class _AlimentoSheet extends StatefulWidget {
  const _AlimentoSheet({
    required this.clinicId,
    required this.repo,
    this.inicial,
  });

  final String clinicId;
  final FeedWriteRepository repo;
  final FeedItem? inicial;

  @override
  State<_AlimentoSheet> createState() => _AlimentoSheetState();
}

class _AlimentoSheetState extends State<_AlimentoSheet> {
  late final TextEditingController _nombre;
  late final TextEditingController _kgPorUnidad;
  late final TextEditingController _materiaSeca;
  late final TextEditingController _proteina;
  late final TextEditingController _notas;
  late FeedKind _tipo;
  late FeedUnit _unidad;
  late bool _activo;

  @override
  void initState() {
    super.initState();
    final i = widget.inicial;
    _nombre = TextEditingController(text: i?.nombre ?? '');
    _kgPorUnidad = TextEditingController(
      text: i == null ? '' : _fmt(i.kgPorUnidad),
    );
    _materiaSeca = TextEditingController(
      text: i?.materiaSecaPct == null ? '' : _fmt(i!.materiaSecaPct!),
    );
    _proteina = TextEditingController(
      text: i?.proteinaPct == null ? '' : _fmt(i!.proteinaPct!),
    );
    _notas = TextEditingController(text: i?.notas ?? '');
    _tipo = i?.tipo ?? FeedKind.concentrado;
    _unidad = i?.unidad ?? FeedUnit.kg;
    _activo = i?.activo ?? true;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _kgPorUnidad.dispose();
    _materiaSeca.dispose();
    _proteina.dispose();
    _notas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.inicial != null;
    final enKilos = _unidad == FeedUnit.kg;

    return CaptureSheet(
      title: editando ? 'Editar alimento' : 'Nuevo alimento',
      icon: VetIcons.feedBag,
      saveLabel: editando ? 'Guardar cambios' : 'Dar de alta',
      translateError: (e) => traducirErrorAlimento(e).mensaje,
      fields: (busy) => [
        CaptureTextField(
          controller: _nombre,
          label: 'Nombre',
          busy: busy,
          required: true,
          maxLength: 120,
          help: 'Como lo pides al proveedor: «Concentrado 18 % lechera».',
        ),
        CaptureChoiceField<FeedKind>(
          value: _tipo,
          label: 'Tipo',
          options: FeedKind.values,
          nameOf: (t) => t.label,
          busy: busy,
          onChanged: (v) => setState(() => _tipo = v ?? _tipo),
        ),
        CaptureChoiceField<FeedUnit>(
          value: _unidad,
          label: 'Se compra por',
          options: FeedUnit.values,
          nameOf: (u) => u.label,
          busy: busy,
          help: 'Solo para capturar cómodo. Las existencias siempre se '
              'guardan y se enseñan en kilos.',
          onChanged: (v) => setState(() {
            _unidad = v ?? _unidad;
            if (_unidad != FeedUnit.kg && _kgPorUnidad.text.trim().isEmpty) {
              _kgPorUnidad.text = '${_unidad.kgSugeridos}';
            }
          }),
        ),
        if (!enKilos)
          CaptureNumberField(
            controller: _kgPorUnidad,
            label: 'Kilos por ${_unidad.label.toLowerCase()}',
            busy: busy,
            suffix: 'kg',
            help: 'Pesa uno y escríbelo. El dato sugerido es el habitual, '
                'no el tuyo.',
            extraValidator: (v) =>
                v <= 0 ? 'Tiene que ser mayor que cero' : null,
          ),
        CaptureNumberField(
          controller: _materiaSeca,
          label: 'Materia seca',
          busy: busy,
          suffix: '%',
          help: 'Opcional. Sin ella la conversión de leche sale en kilos tal '
              'cual y no en kg de materia seca, que es como se compara.',
          extraValidator: (v) =>
              v <= 0 || v > 100 ? 'Va entre 0 y 100' : null,
        ),
        CaptureNumberField(
          controller: _proteina,
          label: 'Proteína cruda',
          busy: busy,
          suffix: '%',
          help: 'Opcional, de la etiqueta del costal.',
          extraValidator: (v) => v > 100 ? 'Va entre 0 y 100' : null,
        ),
        CaptureTextField(
          controller: _notas,
          label: 'Notas',
          busy: busy,
          lines: 3,
          maxLength: 2000,
        ),
        if (editando)
          SwitchListTile(
            value: _activo,
            onChanged: busy ? null : (v) => setState(() => _activo = v),
            title: const Text('Sigue en uso'),
            subtitle: const Text(
              'Si lo apagas deja de ofrecerse al capturar, pero su historial '
              'y su costo se conservan.',
            ),
            contentPadding: EdgeInsets.zero,
          ),
      ],
      onSave: (operation) {
        final i = widget.inicial;
        return widget.repo.guardarAlimento(
          clinicId: widget.clinicId,
          operation: operation,
          data: {
            if (i != null) 'id': i.id,
            if (i != null) 'version': '${i.version}',
            'nombre': _nombre.text.trim(),
            'tipo': _tipo.code,
            'unidad': _unidad.code,
            'kg_por_unidad': enKilos
                ? '1'
                : (emptyToNull(_kgPorUnidad.text) ??
                      '${_unidad.kgSugeridos}'),
            'materia_seca_pct': emptyToNull(_materiaSeca.text) ?? '',
            'proteina_pct': emptyToNull(_proteina.text) ?? '',
            'activo': _activo,
            'notas': _notas.text.trim(),
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Alta y edición de silo
// ---------------------------------------------------------------------------

/// Abre el formulario de silo. [inicial] no nulo significa edición.
Future<bool> capturarSilo(
  BuildContext context, {
  required String clinicId,
  required FeedWriteRepository repo,
  required List<FeedItem> alimentos,
  FeedStore? inicial,
}) => openCaptureSheet(
  context,
  _SiloSheet(
    clinicId: clinicId,
    repo: repo,
    alimentos: alimentos,
    inicial: inicial,
  ),
);

class _SiloSheet extends StatefulWidget {
  const _SiloSheet({
    required this.clinicId,
    required this.repo,
    required this.alimentos,
    this.inicial,
  });

  final String clinicId;
  final FeedWriteRepository repo;
  final List<FeedItem> alimentos;
  final FeedStore? inicial;

  @override
  State<_SiloSheet> createState() => _SiloSheetState();
}

class _SiloSheetState extends State<_SiloSheet> {
  late final TextEditingController _nombre;
  late final TextEditingController _capacidad;
  late final TextEditingController _notas;
  late StoreKind _tipo;
  FeedItem? _alimento;
  late bool _activo;

  @override
  void initState() {
    super.initState();
    final i = widget.inicial;
    _nombre = TextEditingController(text: i?.nombre ?? '');
    _capacidad = TextEditingController(
      text: i?.capacidadKg == null ? '' : _fmt(i!.capacidadKg!),
    );
    _notas = TextEditingController(text: i?.notas ?? '');
    _tipo = i?.tipo ?? StoreKind.silo;
    _activo = i?.activo ?? true;
    for (final a in widget.alimentos) {
      if (a.id == i?.alimentoId) _alimento = a;
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _capacidad.dispose();
    _notas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.inicial != null;

    return CaptureSheet(
      title: editando ? 'Editar silo' : 'Nuevo silo o bodega',
      icon: VetIcons.barn,
      saveLabel: editando ? 'Guardar cambios' : 'Dar de alta',
      translateError: (e) => traducirErrorAlimento(e).mensaje,
      fields: (busy) => [
        CaptureTextField(
          controller: _nombre,
          label: 'Nombre',
          busy: busy,
          required: true,
          maxLength: 80,
          help: 'Como lo nombran en la granja: «Silo 2», «Bodega grande».',
        ),
        CaptureChoiceField<StoreKind>(
          value: _tipo,
          label: 'Tipo',
          options: StoreKind.values,
          nameOf: (t) => t.label,
          busy: busy,
          onChanged: (v) => setState(() => _tipo = v ?? _tipo),
        ),
        CaptureNumberField(
          controller: _capacidad,
          label: 'Capacidad',
          busy: busy,
          suffix: 'kg',
          help: 'Opcional. Sin ella no se puede decir qué tan lleno está, '
              'solo cuántos kilos tiene.',
          extraValidator: (v) =>
              v <= 0 ? 'Tiene que ser mayor que cero' : null,
        ),
        if (widget.alimentos.isNotEmpty)
          CaptureChoiceField<FeedItem>(
            value: widget.alimentos.contains(_alimento) ? _alimento : null,
            label: 'Alimento que suele contener',
            options: widget.alimentos,
            nameOf: (a) => a.nombre,
            busy: busy,
            help: 'Solo para proponerlo al capturar. Un silo puede recibir '
                'otro alimento sin problema.',
            onChanged: (v) => setState(() => _alimento = v),
          ),
        CaptureTextField(
          controller: _notas,
          label: 'Notas',
          busy: busy,
          lines: 3,
          maxLength: 2000,
        ),
        if (editando)
          SwitchListTile(
            value: _activo,
            onChanged: busy ? null : (v) => setState(() => _activo = v),
            title: const Text('Sigue en uso'),
            contentPadding: EdgeInsets.zero,
          ),
      ],
      onSave: (operation) {
        final i = widget.inicial;
        return widget.repo.guardarSilo(
          clinicId: widget.clinicId,
          operation: operation,
          data: {
            if (i != null) 'id': i.id,
            if (i != null) 'version': '${i.version}',
            'nombre': _nombre.text.trim(),
            'tipo': _tipo.code,
            'capacidad_kg': emptyToNull(_capacidad.text) ?? '',
            'alimento_id': _alimento?.id ?? '',
            'activo': _activo,
            'notas': _notas.text.trim(),
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Movimiento: compra, consumo, merma o ajuste
// ---------------------------------------------------------------------------

/// Abre el formulario de movimiento con [tipoInicial] ya elegido.
Future<bool> capturarMovimiento(
  BuildContext context, {
  required String clinicId,
  required FeedWriteRepository repo,
  required FeedSnapshot datos,
  required FeedMoveKind tipoInicial,
  String? loteId,
}) => openCaptureSheet(
  context,
  _MovimientoSheet(
    clinicId: clinicId,
    repo: repo,
    datos: datos,
    tipoInicial: tipoInicial,
    loteId: loteId,
  ),
);

class _MovimientoSheet extends StatefulWidget {
  const _MovimientoSheet({
    required this.clinicId,
    required this.repo,
    required this.datos,
    required this.tipoInicial,
    this.loteId,
  });

  final String clinicId;
  final FeedWriteRepository repo;
  final FeedSnapshot datos;
  final FeedMoveKind tipoInicial;
  final String? loteId;

  @override
  State<_MovimientoSheet> createState() => _MovimientoSheetState();
}

class _MovimientoSheetState extends State<_MovimientoSheet> {
  final _cantidad = TextEditingController();
  final _costo = TextEditingController();
  final _proveedor = TextEditingController();
  final _referencia = TextEditingController();
  final _nota = TextEditingController();

  late FeedMoveKind _tipo;
  FeedItem? _alimento;
  FeedStore? _silo;
  BatchEfficiency? _lote;
  DateTime _fecha = DateTime.now();

  List<FeedItem> get _alimentos => widget.datos.alimentosActivos.toList();
  List<FeedStore> get _silos => widget.datos.silosActivos.toList();

  /// Solo lotes abiertos: a uno cerrado el servidor no deja cargarle nada.
  List<BatchEfficiency> get _lotes =>
      widget.datos.eficiencias.where((e) => e.estado == 'activo').toList();

  @override
  void initState() {
    super.initState();
    _tipo = widget.tipoInicial;
    final a = _alimentos;
    if (a.length == 1) _alimento = a.first;
    final s = _silos;
    if (s.length == 1) _silo = s.first;
    for (final l in _lotes) {
      if (l.loteId == widget.loteId) _lote = l;
    }
    // La conversión a kilos se enseña mientras se escribe.
    _cantidad.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _cantidad.dispose();
    _costo.dispose();
    _proveedor.dispose();
    _referencia.dispose();
    _nota.dispose();
    super.dispose();
  }

  bool get _esCompra => _tipo == FeedMoveKind.compra;
  bool get _esConsumo => _tipo == FeedMoveKind.consumo;
  bool get _esAjuste => _tipo == FeedMoveKind.ajuste;

  /// Los kilos que se van a guardar, ya convertidos.
  double? get _kilos {
    final a = _alimento;
    final n = readDecimal(_cantidad.text);
    if (a == null || n == null) return null;
    return a.seCompraEnKilos ? n : a.aKilos(n);
  }

  String? get _conversion {
    final a = _alimento;
    final kg = _kilos;
    if (a == null || kg == null || a.seCompraEnKilos) return null;
    return 'Son ${_fmt(kg)} kg, que es lo que se guarda.';
  }

  /// Lo que quedará en el silo si se guarda esto. Sirve para ver de golpe que
  /// un consumo de 4800 va a dejar el silo en números rojos.
  String? get _despues {
    final a = _alimento;
    final kg = _kilos;
    if (a == null || kg == null || _esCompra) return null;
    final actual = widget.datos.kgDeAlimento(a.id);
    final resultante = _esAjuste ? actual + kg : actual - kg.abs();
    if (resultante < 0) {
      return 'Quedaría en ${_fmt(resultante)} kg. Se guarda igual, pero '
          'significa que falta capturar una entrada.';
    }
    return 'Quedarían ${_fmt(resultante)} kg de ${a.nombre}.';
  }

  @override
  Widget build(BuildContext context) {
    if (_alimentos.isEmpty) {
      return const MissingPrerequisiteSheet(
        title: 'Inventario de alimento',
        icon: VetIcons.feedBag,
        text: 'Primero da de alta un alimento. Sin catálogo no hay forma de '
            'decir qué entró ni qué se comieron los animales.',
      );
    }
    if (_esConsumo && _lotes.isEmpty) {
      return const MissingPrerequisiteSheet(
        title: 'Consumo de alimento',
        icon: VetIcons.trough,
        text: 'Primero da de alta un lote activo. El consumo se carga a un '
            'lote: es lo que vuelve ciertas la conversión alimenticia y el '
            'costo por litro o por kilo.',
      );
    }

    final a = _alimento;
    final unidadTexto = a == null || a.seCompraEnKilos
        ? 'kg'
        : a.unidad.label.toLowerCase();

    return CaptureSheet(
      title: 'Registrar ${_tipo.label.toLowerCase()}',
      icon: switch (_tipo) {
        FeedMoveKind.compra => VetIcons.truck,
        FeedMoveKind.consumo => VetIcons.trough,
        FeedMoveKind.merma => VetIcons.warningTriangle,
        FeedMoveKind.ajuste => VetIcons.scale,
      },
      saveLabel: 'Registrar',
      translateError: (e) => traducirErrorAlimento(e).mensaje,
      notice: _esAjuste
          ? 'Un ajuste cuadra el papel con lo que de verdad hay. Escribe la '
                'diferencia: en negativo si sobraba en el sistema.'
          : null,
      fields: (busy) => [
        CaptureChoiceField<FeedMoveKind>(
          value: _tipo,
          label: 'Qué pasó',
          options: FeedMoveKind.values,
          nameOf: (t) => '${t.label} · ${t.ayuda}',
          busy: busy,
          onChanged: (v) => setState(() => _tipo = v ?? _tipo),
        ),
        CaptureChoiceField<FeedItem>(
          value: _alimentos.contains(_alimento) ? _alimento : null,
          label: 'Alimento',
          options: _alimentos,
          nameOf: (x) => x.nombre,
          busy: busy,
          onChanged: (v) => setState(() {
            _alimento = v;
            // Si el silo elegido es el de ese alimento, se propone solo.
            if (v != null && _silo == null) {
              for (final s in _silos) {
                if (s.alimentoId == v.id) _silo = s;
              }
            }
          }),
        ),
        if (_silos.isNotEmpty)
          CaptureChoiceField<FeedStore>(
            value: _silos.contains(_silo) ? _silo : null,
            label: 'Silo o bodega',
            options: _silos,
            nameOf: (s) => s.nombre,
            busy: busy,
            help: 'Dónde está físicamente. Es lo que permite avisar de qué '
                'silo se está vaciando.',
            onChanged: (v) => setState(() => _silo = v),
          ),
        if (_esConsumo)
          CaptureChoiceField<BatchEfficiency>(
            value: _lotes.contains(_lote) ? _lote : null,
            label: 'Lote que se lo comió',
            options: _lotes,
            nameOf: (l) => '${l.codigo} · ${l.nombre} (${l.cabezas})',
            busy: busy,
            onChanged: (v) => setState(() => _lote = v),
          ),
        CaptureDateField(
          value: _fecha,
          label: 'Fecha',
          busy: busy,
          required: true,
          onChanged: (v) => setState(() => _fecha = v ?? _fecha),
        ),
        CaptureNumberField(
          controller: _cantidad,
          label: 'Cantidad',
          busy: busy,
          suffix: unidadTexto,
          help: [
            ?_conversion,
            ?_despues,
          ].join(' '),
          extraValidator: (v) {
            if (v == 0) return 'No puede ser cero';
            if (!_esAjuste && v < 0) {
              return 'Escríbelo en positivo: el signo lo pone el tipo de '
                  'movimiento';
            }
            return null;
          },
        ),
        if (_esCompra)
          CaptureNumberField(
            controller: _costo,
            label: 'Precio por kilo',
            busy: busy,
            suffix: '\$/kg',
            help: a == null || a.seCompraEnKilos
                ? 'Sin precio no hay costo por litro ni por kilo producido.'
                : 'Por kilo, no por ${a.unidad.label.toLowerCase()}. Si el '
                      '${a.unidad.label.toLowerCase()} costó \$320 y pesa '
                      '${_fmt(a.kgPorUnidad)} kg, aquí van '
                      '${_fmt(320 / a.kgPorUnidad)}.',
            extraValidator: (v) => v < 0 ? 'No puede ser negativo' : null,
          ),
        if (_esCompra)
          CaptureTextField(
            controller: _proveedor,
            label: 'Proveedor',
            busy: busy,
            maxLength: 120,
          ),
        if (_esCompra)
          CaptureTextField(
            controller: _referencia,
            label: 'Factura o remisión',
            busy: busy,
            maxLength: 60,
          ),
        CaptureTextField(
          controller: _nota,
          label: 'Nota',
          busy: busy,
          lines: 2,
          maxLength: 2000,
        ),
      ],
      onSave: (operation) {
        final elegido = _alimento;
        if (elegido == null) {
          throw const FeedWriteException(
            'alimento_not_found',
            'Elige el alimento.',
          );
        }
        final kg = _kilos;
        if (kg == null || kg == 0) {
          throw const FeedWriteException(
            'invalid_kg',
            'Escribe cuánto fue.',
          );
        }
        if (_esConsumo && _lote == null) {
          throw const FeedWriteException(
            'lote_required',
            'Para registrar consumo hay que decir qué lote se lo comió.',
          );
        }
        final costo = readDecimal(_costo.text);
        if (_esCompra && costo == null) {
          throw const FeedWriteException(
            'costo_required',
            'Una compra necesita su precio por kilo.',
          );
        }
        return widget.repo.moverAlimento(
          clinicId: widget.clinicId,
          alimentoId: elegido.id,
          siloId: _silo?.id,
          loteId: _esConsumo ? _lote?.loteId : null,
          fecha: _fecha,
          tipo: _tipo.code,
          kg: kg,
          costoKg: _esCompra ? costo : null,
          proveedor: _esCompra ? emptyToNull(_proveedor.text) : null,
          referencia: _esCompra ? emptyToNull(_referencia.text) : null,
          nota: emptyToNull(_nota.text),
          operation: operation,
        );
      },
    );
  }
}

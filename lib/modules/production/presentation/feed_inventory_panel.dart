/// El panel de alimento.
///
/// Es la pantalla que vuelve ciertas las tres cifras que el Dashboard Pecuario
/// venía enseñando inventadas: el nivel de los silos, el costo real y la
/// conversión alimenticia.
///
/// Lo primero que se ve es lo que obliga a hacer una llamada hoy: el silo que
/// se vacía esta semana. Después, lo que ya se puede medir por lote. Y cuando
/// un número no se puede calcular, en su lugar va la razón —«falta capturar el
/// precio de las compras»— y no un cero que parecería un dato.
library;

import 'package:flutter/material.dart';

import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_icons.dart';
import '../../../vet_ui/vet_theme.dart';
import '../../auth/domain/clinic_membership.dart';
import '../domain/feed_inventory.dart';
import '../domain/feed_write_repository.dart';
import 'feed_capture_forms.dart';

class FeedInventoryPanel extends StatefulWidget {
  const FeedInventoryPanel({
    super.key,
    this.member,
    this.repository,
    this.writeRepository,
    this.titulo = 'Alimento',
  });

  final ClinicMembership? member;
  final FeedInventoryRepository? repository;
  final FeedWriteRepository? writeRepository;
  final String titulo;

  @override
  State<FeedInventoryPanel> createState() => _FeedInventoryPanelState();
}

class _FeedInventoryPanelState extends State<FeedInventoryPanel> {
  FeedSnapshot? _datos;
  bool _cargando = true;
  Object? _fallo;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    // Cede el turno: la primera llamada sale de initState y ahi el widget
    // todavia se esta montando.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    final repo = widget.repository;
    final clinicId = widget.member?.clinicId;
    if (repo == null || clinicId == null || clinicId.isEmpty) {
      setState(() {
        _datos = const FeedSnapshot.vacio();
        _cargando = false;
        _fallo = null;
      });
      return;
    }
    setState(() {
      _cargando = true;
      _fallo = null;
    });
    try {
      final d = await repo.load(clinicId);
      if (!mounted) return;
      setState(() {
        _datos = d;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fallo = e;
        _cargando = false;
      });
    }
  }

  bool get _puedeMover =>
      widget.writeRepository != null &&
      (widget.member?.clinicId.isNotEmpty ?? false) &&
      puedeMoverAlimento(widget.member);

  bool get _puedeCatalogo =>
      widget.writeRepository != null &&
      (widget.member?.clinicId.isNotEmpty ?? false) &&
      puedeGestionarCatalogoAlimento(widget.member);

  FeedSnapshot get _vista => _datos ?? const FeedSnapshot.vacio();

  Future<void> _abrirMovimiento(FeedMoveKind tipo) async {
    final repo = widget.writeRepository;
    final clinicId = widget.member?.clinicId;
    if (repo == null || clinicId == null) return;
    final guardado = await capturarMovimiento(
      context,
      clinicId: clinicId,
      repo: repo,
      datos: _vista,
      tipoInicial: tipo,
    );
    if (guardado) await _cargar();
  }

  Future<void> _abrirAlimento([FeedItem? inicial]) async {
    final repo = widget.writeRepository;
    final clinicId = widget.member?.clinicId;
    if (repo == null || clinicId == null) return;
    final guardado = await capturarAlimento(
      context,
      clinicId: clinicId,
      repo: repo,
      inicial: inicial,
    );
    if (guardado) await _cargar();
  }

  Future<void> _abrirSilo([FeedStore? inicial]) async {
    final repo = widget.writeRepository;
    final clinicId = widget.member?.clinicId;
    if (repo == null || clinicId == null) return;
    final guardado = await capturarSilo(
      context,
      clinicId: clinicId,
      repo: repo,
      alimentos: _vista.alimentosActivos.toList(),
      inicial: inicial,
    );
    if (guardado) await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    // Un fallo de red no es lo mismo que no tener nada: decirlo evita que
    // alguien crea que se le borró el inventario.
    if (_fallo != null) {
      return VetCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const VetSectionHeader(
              title: 'No se pudo leer el alimento',
              icon: VetIcons.cloudOff,
            ),
            const SizedBox(height: 8),
            const Text(
              'Puede ser la conexión. Tus datos siguen guardados: esta '
              'pantalla solo los lee.',
            ),
            const SizedBox(height: 12),
            VetSecondaryButton(
              label: 'Reintentar',
              icon: VetIcons.refresh,
              onPressed: _cargar,
            ),
          ],
        ),
      );
    }

    final d = _vista;
    if (d.sinDatos) return _vacio();

    final ahora = DateTime.now();
    final porAgotarse = d.silosPorAgotarse(ahora);
    final enRojo = d.existenciasNegativas;
    final conAlimento = d.eficiencias
        .where((e) => e.tieneAlimento)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _resumen(d, porAgotarse.length, enRojo.length),
        const SizedBox(height: 12),
        if (_puedeMover) _acciones(),
        if (enRojo.isNotEmpty) ...[
          const SizedBox(height: 12),
          _avisoRojo(d, enRojo),
        ],
        if (d.silos.isNotEmpty) ...[
          const SizedBox(height: 16),
          const VetSectionHeader(
            title: 'Silos y bodegas',
            subtitle: 'Lo que hay y cuánto aguanta al ritmo de los últimos '
                '30 días',
            icon: VetIcons.barn,
          ),
          const SizedBox(height: 8),
          for (final s in d.silos.where((x) => x.activo))
            _tarjetaSilo(d, s, ahora),
        ],
        if (d.alimentos.isNotEmpty) ...[
          const SizedBox(height: 16),
          const VetSectionHeader(
            title: 'Alimentos',
            icon: VetIcons.feedBag,
          ),
          const SizedBox(height: 8),
          for (final a in d.alimentos.where((x) => x.activo))
            _tarjetaAlimento(d, a),
        ],
        const SizedBox(height: 16),
        const VetSectionHeader(
          title: 'Conversión y costo por lote',
          subtitle: 'Sale de lo que de verdad se cargó y de lo que el lote '
              'produjo',
          icon: VetIcons.kgToMeat,
        ),
        const SizedBox(height: 8),
        if (conAlimento.isEmpty)
          const VetCard(
            child: VetEmptyState(
              icon: VetIcons.trough,
              text: 'Todavía no se ha cargado alimento a ningún lote. En '
                  'cuanto registres el primer consumo aparecen aquí la '
                  'conversión y el costo por litro o por kilo.',
            ),
          )
        else
          for (final e in conAlimento) _tarjetaLote(e),
        if (d.movimientos.isNotEmpty) ...[
          const SizedBox(height: 16),
          const VetSectionHeader(title: 'Últimos movimientos'),
          const SizedBox(height: 8),
          for (final m in d.movimientos.take(15)) _tarjetaMovimiento(d, m),
        ],
        const SizedBox(height: 8),
        if (_puedeCatalogo)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              VetSecondaryButton(
                label: 'Nuevo alimento',
                icon: VetIcons.feedBag,
                onPressed: _abrirAlimento,
              ),
              VetSecondaryButton(
                label: 'Nuevo silo',
                icon: VetIcons.barn,
                onPressed: _abrirSilo,
              ),
            ],
          ),
      ],
    );
  }

  Widget _vacio() => VetCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VetSectionHeader(
          title: 'Inventario de alimento',
          icon: VetIcons.feedBag,
        ),
        const SizedBox(height: 8),
        const Text(
          'Aquí se lleva lo que entra, lo que se comen los animales y lo que '
          'queda en cada silo. Es de donde salen el costo real por litro o '
          'por kilo y la conversión alimenticia: sin esto, esas cifras no se '
          'pueden calcular.',
        ),
        const SizedBox(height: 12),
        if (_puedeCatalogo)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              VetSecondaryButton(
                label: 'Dar de alta un alimento',
                icon: VetIcons.feedBag,
                onPressed: _abrirAlimento,
              ),
              VetSecondaryButton(
                label: 'Dar de alta un silo',
                icon: VetIcons.barn,
                onPressed: _abrirSilo,
              ),
            ],
          )
        else
          const Text(
            'Pídele a un administrador o MVZ que dé de alta los alimentos y '
            'los silos de la granja.',
          ),
      ],
    ),
  );

  Widget _resumen(FeedSnapshot d, int porAgotarse, int enRojo) => Row(
    children: [
      Expanded(
        child: VetKpiCard(
          label: 'Valor del inventario',
          value: '\$${_miles(d.valorTotal)}',
          icon: VetIcons.coins,
          accent: VetColors.turquoise,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: VetKpiCard(
          label: 'Se vacían en 14 días',
          value: '$porAgotarse',
          icon: VetIcons.hayBales,
          accent: porAgotarse > 0 ? VetColors.warning : VetColors.violet,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: VetKpiCard(
          label: 'En números rojos',
          value: '$enRojo',
          icon: VetIcons.alertTriangle,
          accent: enRojo > 0 ? VetColors.danger : VetColors.violet,
        ),
      ),
    ],
  );

  Widget _acciones() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      VetSecondaryButton(
        label: 'Entró alimento',
        icon: VetIcons.truck,
        onPressed: () => _abrirMovimiento(FeedMoveKind.compra),
      ),
      VetSecondaryButton(
        label: 'Se repartió',
        icon: VetIcons.trough,
        onPressed: () => _abrirMovimiento(FeedMoveKind.consumo),
      ),
      VetSecondaryButton(
        label: 'Merma o ajuste',
        icon: VetIcons.scale,
        onPressed: () => _abrirMovimiento(FeedMoveKind.merma),
      ),
    ],
  );

  Widget _avisoRojo(FeedSnapshot d, List<FeedStock> rojos) => VetCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VetSectionHeader(
          title: 'Existencias en negativo',
          icon: VetIcons.alertTriangle,
        ),
        const SizedBox(height: 6),
        const Text(
          'Hay consumo capturado sin la entrada que lo respalde. No se '
          'recorta a cero porque el hueco es el dato: dice que falta '
          'registrar una compra.',
        ),
        const SizedBox(height: 8),
        for (final r in rojos.take(6))
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${d.nombreDeAlimento(r.alimentoId)} en '
              '${d.nombreDeSilo(r.siloId)}: ${_miles(r.kg)} kg',
            ),
          ),
      ],
    ),
  );

  Widget _tarjetaSilo(FeedSnapshot d, FeedStore s, DateTime ahora) {
    final kg = d.kgEnSilo(s.id);
    final cap = s.capacidadKg;
    // clamp devuelve num, no double, y LinearProgressIndicator pide double.
    final lleno = cap != null && cap > 0
        ? (kg / cap).clamp(0.0, 1.0).toDouble()
        : null;

    double? dias;
    for (final e in d.existenciasDeSilo(s.id)) {
      final x = e.diasQueAguanta(ahora);
      if (x == null) continue;
      if (dias == null || x < dias) dias = x;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: VetCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.nombre,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 2),
            Text(
              cap == null
                  ? '${_miles(kg)} kg · ${s.tipo.label}'
                  : '${_miles(kg)} kg de ${_miles(cap)} kg · ${s.tipo.label}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (lleno != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: lleno,
                  minHeight: 8,
                  color: lleno < .15 ? VetColors.danger : VetColors.turquoise,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (dias != null)
                  VetStatusBadge(
                    label: 'Aguanta ${dias.round()} días',
                    kind: dias <= 7
                        ? VetBadgeKind.danger
                        : (dias <= 14
                              ? VetBadgeKind.warning
                              : VetBadgeKind.success),
                  )
                else
                  const VetStatusBadge(
                    label: 'Sin consumo registrado',
                    kind: VetBadgeKind.unverified,
                  ),
                if (lleno != null)
                  VetStatusBadge(
                    label: '${(lleno * 100).round()} % lleno',
                  ),
              ],
            ),
            if (_puedeCatalogo) ...[
              const SizedBox(height: 8),
              VetSecondaryButton(
                label: 'Editar',
                icon: VetIcons.pencil,
                onPressed: () => _abrirSilo(s),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tarjetaAlimento(FeedSnapshot d, FeedItem a) {
    final kg = d.kgDeAlimento(a.id);
    double? costo;
    var valor = 0.0;
    for (final e in d.existencias) {
      if (e.alimentoId == a.id) valor += e.valor;
    }
    if (kg > 0) costo = valor / kg;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: VetCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a.nombre, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              '${_miles(kg)} kg · ${a.tipo.label}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (costo != null)
                  VetStatusBadge(label: '\$${costo.toStringAsFixed(2)} / kg')
                else
                  const VetStatusBadge(
                    label: 'Sin costo capturado',
                    kind: VetBadgeKind.unverified,
                  ),
                if (a.materiaSecaPct != null)
                  VetStatusBadge(
                    label: '${_miles(a.materiaSecaPct!)} % MS',
                  )
                else
                  const VetStatusBadge(
                    label: 'Sin materia seca',
                    kind: VetBadgeKind.unverified,
                  ),
                if (a.proteinaPct != null)
                  VetStatusBadge(label: '${_miles(a.proteinaPct!)} % PC'),
                if (!a.seCompraEnKilos)
                  VetStatusBadge(
                    label: '1 ${a.unidad.label.toLowerCase()} = '
                        '${_miles(a.kgPorUnidad)} kg',
                  ),
              ],
            ),
            if (_puedeCatalogo) ...[
              const SizedBox(height: 8),
              VetSecondaryButton(
                label: 'Editar',
                icon: VetIcons.pencil,
                onPressed: () => _abrirAlimento(a),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tarjetaLote(BatchEfficiency e) {
    final conv = e.conversion;
    final costo = e.costoPorUnidad;
    final estilo = Theme.of(context).textTheme.bodySmall;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: VetCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${e.codigo} · ${e.nombre}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 2),
            Text(
              '${e.cabezas} cabezas · ${_miles(e.kgAlimento)} kg de alimento '
              '· \$${_miles(e.costoAlimento)}',
              style: estilo,
            ),
            const SizedBox(height: 10),
            _renglon(
              'Conversión',
              conv.hayDato
                  ? '${conv.valor!.toStringAsFixed(2)} ${conv.unidad}'
                  : null,
              conv.hayDato ? conv.detalle : conv.motivo!,
            ),
            const SizedBox(height: 8),
            _renglon(
              'Costo de alimento',
              costo.hayDato
                  ? '\$${costo.valor!.toStringAsFixed(2)} ${costo.unidad}'
                  : null,
              costo.hayDato ? costo.detalle : costo.motivo!,
            ),
            if (_puedeMover) ...[
              const SizedBox(height: 10),
              VetSecondaryButton(
                label: 'Cargarle alimento',
                icon: VetIcons.trough,
                onPressed: () async {
                  final repo = widget.writeRepository;
                  final clinicId = widget.member?.clinicId;
                  if (repo == null || clinicId == null) return;
                  final guardado = await capturarMovimiento(
                    context,
                    clinicId: clinicId,
                    repo: repo,
                    datos: _vista,
                    tipoInicial: FeedMoveKind.consumo,
                    loteId: e.loteId,
                  );
                  if (guardado) await _cargar();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Un dato con su explicación debajo. Cuando no hay dato, la explicación
  /// ocupa su lugar: es más útil saber qué falta que leer un cero.
  Widget _renglon(String titulo, String? valor, String detalle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              titulo,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (valor != null)
            Text(
              valor,
              style: Theme.of(context).textTheme.titleMedium,
            )
          else
            const VetStatusBadge(
              label: 'Sin dato',
              kind: VetBadgeKind.unverified,
            ),
        ],
      ),
      const SizedBox(height: 2),
      Text(detalle, style: Theme.of(context).textTheme.bodySmall),
    ],
  );

  Widget _tarjetaMovimiento(FeedSnapshot d, FeedMovement m) {
    final signo = m.kg >= 0 ? '+' : '−';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: VetCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        radius: 16,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${m.tipo.label} · ${d.nombreDeAlimento(m.alimentoId)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    _fecha(m.fecha),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$signo${_miles(m.kg.abs())} kg',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }

  String _fecha(DateTime f) =>
      '${f.day.toString().padLeft(2, '0')}/'
      '${f.month.toString().padLeft(2, '0')}/${f.year}';

  /// Miles separados con espacio fino: en un teléfono de 360 dp la coma se
  /// confunde con el punto decimal.
  String _miles(double v) {
    final negativo = v < 0;
    final entero = v.abs().round().toString();
    final b = StringBuffer();
    for (var i = 0; i < entero.length; i++) {
      if (i > 0 && (entero.length - i) % 3 == 0) b.write(' ');
      b.write(entero[i]);
    }
    return '${negativo ? '−' : ''}$b';
  }
}

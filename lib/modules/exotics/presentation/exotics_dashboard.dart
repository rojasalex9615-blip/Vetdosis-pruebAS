import 'package:flutter/material.dart';

import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_icons.dart';
import '../../../vet_ui/vet_theme.dart';
import '../../auth/domain/clinic_membership.dart';
import '../domain/exotic_dashboard.dart';
import '../domain/exotic_taxon.dart';
import '../domain/exotic_write_repository.dart';
import 'allometric_calculator.dart';
import 'exotic_capture_forms.dart';

/// Dashboard Independiente: Fauna Exótica.
///
/// En producción la unidad es el lote; aquí es el individuo. Lo que mantiene
/// vivo a un ejemplar es la precisión clínica y ambiental, así que el panel se
/// ordena por riesgo: primero lo que puede matarlo hoy (ambiente, aislamiento,
/// papeles), después su fisiología, y al final las herramientas.
///
/// Regla del módulo: **no se inventan datos**. Lo que no tiene tabla todavía
/// se dice en pantalla en lugar de rellenarse con cifras de ejemplo.
class ExoticsDashboard extends StatefulWidget {
  const ExoticsDashboard({
    super.key,
    this.member,
    this.repository,
    this.writeRepository,
    this.initialTaxon,
  });

  final ClinicMembership? member;

  /// De donde salen los ejemplares. Sin repositorio el panel queda vacío y lo
  /// dice; nunca rellena con un catálogo de muestra.
  final ExoticDashboardRepository? repository;

  /// Por dónde se guarda. Sin él el panel es de solo lectura y no enseña
  /// ningún botón de captura: ofrecerlos para que luego fallen sería peor.
  final ExoticWriteRepository? writeRepository;

  final ExoticTaxon? initialTaxon;

  @override
  State<ExoticsDashboard> createState() => _ExoticsDashboardState();
}

class _ExoticsDashboardState extends State<ExoticsDashboard> {
  ExoticSnapshot? _datos;
  bool _cargando = true;
  Object? _fallo;
  ExoticTaxon? _taxon;
  String _busqueda = '';
  final TextEditingController _buscador = TextEditingController();

  @override
  void initState() {
    super.initState();
    _taxon = widget.initialTaxon;
    _cargar();
  }

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    // Cede el turno: la primera llamada sale de initState y ahí el widget
    // todavía se está montando, donde un setState síncrono revienta.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    final repo = widget.repository;
    final clinicId = widget.member?.clinicId;
    if (repo == null || clinicId == null || clinicId.isEmpty) {
      setState(() {
        _datos = const ExoticSnapshot();
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
      final datos = await repo.load(clinicId);
      if (!mounted) return;
      setState(() {
        _datos = datos;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Un corte de red no es «no hay ejemplares»: se distinguen para que
      // nadie lea una caída de conexión como un censo vacío.
      setState(() {
        _fallo = e;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const VetSectionHeader(
          title: 'Dashboard Independiente: Fauna Exótica',
          subtitle:
              'Individuos, microclimas, comportamiento y trazabilidad legal',
          large: true,
        ),
        const SizedBox(height: 12),
        _selectorDeGrupo(),
        const SizedBox(height: 20),

        // Fila 4 del plan, puesta arriba a propósito: la calculadora es lo que
        // más se usa y bajarla obligaría a desplazarse en cada consulta.
        _buscadorPorIdentificador(),
        const SizedBox(height: 12),
        AllometricCalculatorCard(taxonInicial: _taxon),
        const SizedBox(height: 24),

        ..._cuerpo(),
      ],
    );
  }

  List<Widget> _cuerpo() {
    if (_cargando) {
      return const [
        VetCard(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ];
    }
    if (_fallo != null) {
      return [
        VetCard(
          child: Column(
            children: [
              const Icon(VetIcons.cloudOff, size: 28, color: VetColors.muted),
              const SizedBox(height: 8),
              const Text(
                'No se pudieron leer los ejemplares',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              const Text(
                'Revisa la conexión. Esto no significa que no haya ejemplares '
                'registrados: no se alcanzó el servidor.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: VetColors.muted),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _cargar,
                icon: const Icon(VetIcons.refresh, size: 16),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ];
    }

    final datos = _datos ?? const ExoticSnapshot();
    final ahora = DateTime.now();

    return [
      // Fila 1: Control Ambiental y Bioseguridad
      const VetSectionHeader(
        title: 'Control ambiental y bioseguridad',
        subtitle: 'Microclimas, aislamiento y estatus legal de los ejemplares',
      ),
      const SizedBox(height: 10),
      ..._barraDeCaptura([
        (
          'Nuevo recinto',
          VetIcons.thermometer,
          () => capturarRecinto(
            context,
            repositorio: widget.writeRepository!,
            clinicId: widget.member!.clinicId,
          ),
        ),
        (
          'Registrar lectura',
          VetIcons.gauge,
          () => capturarLectura(
            context,
            repositorio: widget.writeRepository!,
            clinicId: widget.member!.clinicId,
            recintos: datos.enclosures,
          ),
        ),
        (
          'Plan de cuarentena',
          VetIcons.hospital,
          () => capturarCuarentena(
            context,
            repositorio: widget.writeRepository!,
            clinicId: widget.member!.clinicId,
            estancias: datos.stays,
            nombrar: _nombreDeEstancia,
          ),
        ),
        // El estatus legal solo lo firma admin o MVZ: a un auxiliar no se le
        // ofrece, porque el servidor se lo rechazaria.
        if (puedeFirmarEstatusLegal(widget.member))
          (
            'Estatus legal',
            VetIcons.certificate,
            () => capturarEstatusLegal(
              context,
              repositorio: widget.writeRepository!,
              clinicId: widget.member!.clinicId,
              ejemplares: datos.specimens,
            ),
          ),
      ]),
      _microclimas(datos),
      const SizedBox(height: 10),
      _cuarentena(datos, ahora),
      const SizedBox(height: 10),
      _estatusNormativo(datos, ahora),
      const SizedBox(height: 24),

      // Fila 2: Seguimiento fisiológico y conductual
      const VetSectionHeader(
        title: 'Seguimiento fisiológico y conductual',
        subtitle: 'Alimentación, rechazos y evolución del peso individual',
      ),
      const SizedBox(height: 10),
      ..._barraDeCaptura([
        (
          'Toma de alimento',
          VetIcons.bowlPaw,
          () => capturarToma(
            context,
            repositorio: widget.writeRepository!,
            clinicId: widget.member!.clinicId,
            ejemplares: datos.specimens,
          ),
        ),
        (
          'Evento fisiológico',
          VetIcons.lizard,
          () => capturarEvento(
            context,
            repositorio: widget.writeRepository!,
            clinicId: widget.member!.clinicId,
            ejemplares: datos.specimens,
          ),
        ),
      ]),
      _pesos(datos),
      const SizedBox(height: 10),
      _alimentacion(datos),
      const SizedBox(height: 24),

      // Fila 3: Ejemplares prioritarios y reproducción
      const VetSectionHeader(
        title: 'Ejemplares prioritarios y reproducción',
        subtitle: 'Incubadoras, nidadas y eventos fisiológicos recientes',
      ),
      const SizedBox(height: 10),
      ..._barraDeCaptura([
        (
          'Nueva nidada',
          VetIcons.egg,
          () => capturarNidada(
            context,
            repositorio: widget.writeRepository!,
            clinicId: widget.member!.clinicId,
            recintos: datos.enclosures,
          ),
        ),
      ]),
      _incubadoras(datos, ahora),
      const SizedBox(height: 10),
      _eventos(datos),
      const SizedBox(height: 24),
    ];
  }

  /// Quien puede capturar. Coincide con el rol que exigen los RPC: si el
  /// servidor va a rechazar la escritura, el boton no deberia existir.
  bool get _puedeCapturar =>
      widget.writeRepository != null &&
      (widget.member?.clinicId.isNotEmpty ?? false) &&
      puedeCapturarExoticos(widget.member);

  /// Barra de botones de alta para una fila del panel.
  ///
  /// Devuelve lista vacia cuando no hay permiso o no hay repositorio de
  /// escritura, de modo que la fila se dibuja igual pero sin botones muertos.
  List<Widget> _barraDeCaptura(List<(String, IconData, Future<bool> Function())> acciones) {
    if (!_puedeCapturar || acciones.isEmpty) return const [];
    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (etiqueta, icono, abrir) in acciones)
            ActionChip(
              avatar: Icon(icono, size: 16),
              label: Text(etiqueta),
              onPressed: () async {
                final guardado = await abrir();
                // Solo se recarga si de verdad se guardo algo: releer tras un
                // "cancelar" haria parpadear el panel sin motivo.
                if (guardado && mounted) await _cargar();
              },
            ),
        ],
      ),
      const SizedBox(height: 12),
    ];
  }

  /// Como se nombra una hospitalizacion en el desplegable de cuarentena.
  String _nombreDeEstancia(ExoticStay s) {
    final datos = _datos;
    final ejemplar = datos?.specimens
        .where((e) => e.id == s.specimenId)
        .firstOrNull;
    final quien = ejemplar?.titulo ?? 'Ejemplar sin nombre';
    return s.recinto.isEmpty ? quien : '$quien · ${s.recinto}';
  }

  Widget _selectorDeGrupo() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: _taxon == null,
              onSelected: (s) {
                if (s) setState(() => _taxon = null);
              },
              label: const Text('Todos'),
            ),
          ),
          for (final t in ExoticTaxon.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: _taxon == t,
                onSelected: (s) {
                  if (s) setState(() => _taxon = t);
                },
                label: Text(t.label),
              ),
            ),
        ],
      ),
    );
  }

  /// Buscador instantáneo por identificador.
  ///
  /// Busca por nombre, especie, raza, identificador interno y marcaje
  /// (microchip, anillo cerrado, muesca), que viven en `exotic_identifiers`.
  Widget _buscadorPorIdentificador() {
    final datos = _datos;
    final resultados = datos == null ? const <ExoticSpecimen>[] : datos.buscar(_busqueda);
    return VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Buscador instantáneo',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _buscador,
            onChanged: (v) => setState(() => _busqueda = v),
            decoration: const InputDecoration(
              hintText: 'Nombre, especie o identificador',
              prefixIcon: Icon(VetIcons.search, size: 18),
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          if (_busqueda.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            if (resultados.isEmpty)
              const VetEmptyState(
                text: 'Ningún ejemplar coincide con esa búsqueda.',
                icon: VetIcons.searchOff,
              )
            else
              for (final e in resultados.take(8))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(VetIcons.paw, size: 16, color: VetColors.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${e.titulo} · ${e.especie}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Text(
                        _etiquetaDe(datos, e),
                        style: const TextStyle(
                          fontSize: 11,
                          color: VetColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
          ],
          const SizedBox(height: 4),
          const Text(
            'Busca por nombre, especie, microchip, anillo o muesca.',
            style: TextStyle(fontSize: 11, color: VetColors.muted),
          ),
          // El alta de marcaje vive aqui porque es lo que alimenta este
          // buscador: sin marca registrada, buscar por microchip no encuentra.
          if (_puedeCapturar) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: const Icon(VetIcons.tagPaw, size: 16),
                label: const Text('Registrar marcaje'),
                onPressed: () async {
                  final guardado = await capturarMarcaje(
                    context,
                    repositorio: widget.writeRepository!,
                    clinicId: widget.member!.clinicId,
                    ejemplares: (_datos ?? const ExoticSnapshot()).specimens,
                  );
                  if (guardado && mounted) await _cargar();
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Estado de los recintos. Compara la última lectura con el rango objetivo.
  /// Que se muestra a la derecha de un resultado de busqueda.
  ///
  /// El codigo de marcaje identifica mejor que el grupo taxonomico cuando se
  /// ha buscado justamente por microchip o anillo.
  String _etiquetaDe(ExoticSnapshot? datos, ExoticSpecimen e) {
    final marcajes = datos?.marcajesDe(e.id) ?? const <ExoticIdentifier>[];
    if (marcajes.isNotEmpty) return marcajes.first.codigo;
    return e.taxon?.label ?? 'Sin grupo';
  }

  Widget _microclimas(ExoticSnapshot datos) {
    if (datos.enclosures.isEmpty) {
      return const _SinRegistrosAun(
        titulo: 'Estado de microclimas y recintos',
        icono: VetIcons.thermometer,
        texto:
            'Aún no hay recintos dados de alta. Al registrarlos con su rango '
            'objetivo, aquí se marcan en rojo las desviaciones de gradiente '
            'térmico, humedad, índice UV y fisicoquímica del agua.',
      );
    }
    final fuera = datos.desviaciones();
    final sinLectura = datos.enclosures
        .where((e) => datos.ultimaLecturaDe(e.id) == null)
        .toList();

    return VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                VetIcons.thermometer,
                size: 20,
                color: fuera.isEmpty ? VetColors.turquoise : VetColors.danger,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Estado de microclimas y recintos',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${datos.enclosures.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (fuera.isEmpty)
            const Text(
              'Todos los recintos con lectura están dentro de su rango.',
              style: TextStyle(fontSize: 12, color: VetColors.success),
            )
          else
            for (final d in fuera)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      VetIcons.alertOctagon,
                      size: 18,
                      color: VetColors.danger,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.enclosure.nombre,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            d.texto,
                            style: const TextStyle(
                              fontSize: 12,
                              color: VetColors.danger,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          if (sinLectura.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              // Un recinto sin lectura no es un recinto correcto: se dice.
              '${sinLectura.length} recinto(s) sin lectura registrada.',
              style: const TextStyle(fontSize: 11, color: VetColors.muted),
            ),
          ],
        ],
      ),
    );
  }

  /// Semáforo CITES / SEMARNAT: vigencias y marcajes pendientes.
  Widget _estatusNormativo(ExoticSnapshot datos, DateTime ahora) {
    final enRiesgo = datos.legalEnRiesgo(ahora);
    final sinMarcaje = datos
        .sinMarcaje()
        .where((e) => _taxon == null || e.taxon == _taxon)
        .toList();

    if (datos.legal.isEmpty && datos.specimens.isEmpty) {
      return const _SinRegistrosAun(
        titulo: 'Estatus normativo (CITES / SEMARNAT)',
        icono: VetIcons.certificate,
        texto:
            'Sin ejemplares registrados todavía. Aquí aparecerán la vigencia '
            'de los registros, los marcajes pendientes y la documentación de '
            'procedencia.',
      );
    }

    return VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                VetIcons.certificate,
                size: 20,
                color: enRiesgo.isEmpty
                    ? VetColors.turquoise
                    : VetColors.warning,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Estatus normativo (CITES / SEMARNAT)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (datos.legal.isEmpty)
            const Text(
              'Ningún ejemplar tiene registro legal capturado.',
              style: TextStyle(fontSize: 12, color: VetColors.muted),
            )
          else if (enRiesgo.isEmpty)
            Text(
              '${datos.legal.length} registro(s) vigente(s), ninguno vence en '
              'los próximos 30 días.',
              style: const TextStyle(fontSize: 12, color: VetColors.success),
            )
          else
            for (final l in enRiesgo)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      l.vencido(ahora)
                          ? VetIcons.alertOctagon
                          : VetIcons.alertTriangle,
                      size: 18,
                      color: l.vencido(ahora)
                          ? VetColors.danger
                          : VetColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_nombreDe(datos, l.specimenId)} · '
                        '${l.regimen.toUpperCase()}'
                        '${l.numeroRegistro.isEmpty ? '' : ' ${l.numeroRegistro}'}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l.vencido(ahora)
                          ? 'Vencido'
                          : 'Vence en ${l.diasParaVencer(ahora)} d',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: l.vencido(ahora)
                            ? VetColors.danger
                            : VetColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
          if (sinMarcaje.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  VetIcons.tagPaw,
                  size: 16,
                  color: VetColors.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${sinMarcaje.length} ejemplar(es) sin microchip ni anillo '
                    'registrado.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: VetColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Incubadoras y nidadas activas, con cuenta regresiva a la eclosión.
  Widget _incubadoras(ExoticSnapshot datos, DateTime ahora) {
    final activas = datos.incubando();
    if (activas.isEmpty) {
      return const _SinRegistrosAun(
        titulo: 'Incubadoras y nidadas activas',
        icono: VetIcons.egg,
        texto:
            'No hay nidadas en incubación. Al registrar una puesta se muestra '
            'aquí su temperatura objetivo —determinante del sexo en varias '
            'especies—, la humedad y la cuenta regresiva a la eclosión.',
      );
    }
    return VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(VetIcons.egg, size: 20, color: VetColors.turquoise),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Incubadoras y nidadas activas',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${activas.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final c in activas)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          c.especie,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _cuentaRegresiva(c, ahora),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: (c.diasParaEclosion(ahora) ?? 99) < 0
                              ? VetColors.warning
                              : VetColors.turquoise,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${c.huevos} huevo(s)'
                    '${c.fertiles == null ? '' : ' · ${c.fertiles} fértil(es)'}'
                    '${c.tempObjetivo == null ? '' : ' · ${c.tempObjetivo} °C'}'
                    '${c.humedadObjetivo == null ? '' : ' · ${c.humedadObjetivo} % HR'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: VetColors.muted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _cuentaRegresiva(ExoticClutch c, DateTime ahora) {
    final d = c.diasParaEclosion(ahora);
    if (d == null) return 'Sin fecha';
    if (d < 0) return 'Vencida ${-d} d';
    if (d == 0) return 'Eclosiona hoy';
    return 'Faltan $d d';
  }

  /// Ejemplares en cuarentena u hospitalización. Esto sí tiene tabla.
  Widget _cuarentena(ExoticSnapshot datos, DateTime ahora) {
    final delGrupo = datos.delTaxon(_taxon).map((e) => e.id).toSet();
    final estancias =
        datos.enCurso().where((s) => delGrupo.contains(s.specimenId)).toList();

    return VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(VetIcons.shieldCheck, size: 20, color: VetColors.turquoise),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Ejemplares en cuarentena u hospitalización',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${estancias.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (estancias.isEmpty)
            const VetEmptyState(
              text: 'Ningún ejemplar está ingresado ahora mismo.',
              icon: VetIcons.checkCircle,
            )
          else
            for (final s in estancias)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _nombreDe(datos, s.specimenId),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _textoEstancia(s, ahora),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: (s.diasRestantes(ahora) ?? 1) <= 0
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: (s.diasRestantes(ahora) ?? 1) <= 0
                            ? VetColors.success
                            : VetColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 4),
          const Text(
            'Cuando la cuarentena tiene días previstos se muestra la cuenta '
            'regresiva; si no, el tiempo que lleva dentro.',
            style: TextStyle(fontSize: 11, color: VetColors.muted),
          ),
        ],
      ),
    );
  }

  /// Curvas de peso individual. El peso sale de los eventos del expediente.
  Widget _pesos(ExoticSnapshot datos) {
    final avisos = datos
        .alertasDePeso()
        .where((a) => _taxon == null || a.specimen.taxon == _taxon)
        .toList();
    final conSerie = datos
        .delTaxon(_taxon)
        .where((e) => datos.serieDe(e.id).isNotEmpty)
        .toList();

    return VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Peso individual',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 2),
          const Text(
            'En gramos: una caída del 5 % avisa y del 10 % es alerta, medida '
            'contra el peso más alto registrado.',
            style: TextStyle(fontSize: 11, color: VetColors.muted),
          ),
          const SizedBox(height: 8),
          if (conSerie.isEmpty)
            const VetEmptyState(
              text: 'Todavía no hay pesos registrados para este grupo.',
              icon: VetIcons.scale,
            )
          else ...[
            if (avisos.isEmpty)
              const Text(
                'Ningún ejemplar baja del 5 % respecto a su peso máximo.',
                style: TextStyle(fontSize: 12, color: VetColors.success),
              )
            else
              for (final a in avisos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        a.esCritica
                            ? VetIcons.alertOctagon
                            : VetIcons.alertTriangle,
                        size: 18,
                        color: a.esCritica
                            ? VetColors.danger
                            : VetColors.warning,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          a.specimen.titulo,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '-${a.caidaPct.toStringAsFixed(1)} % · '
                        '${a.pesoActual.toStringAsFixed(0)} g',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: a.esCritica
                              ? VetColors.danger
                              : VetColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 6),
            Text(
              '${conSerie.length} ejemplar(es) con peso registrado.',
              style: const TextStyle(fontSize: 11, color: VetColors.muted),
            ),
          ],
        ],
      ),
    );
  }

  /// Monitor de alimentación: racha de rechazos por ejemplar.
  Widget _alimentacion(ExoticSnapshot datos) {
    final rachas = datos
        .rachaDeRechazos()
        .where((r) => _taxon == null || r.specimen.taxon == _taxon)
        .toList();
    final conTomas = datos.feedings.isNotEmpty;

    if (!conTomas) {
      return const _SinRegistrosAun(
        titulo: 'Monitor de alimentación y rechazos',
        icono: VetIcons.bowlPaw,
        texto:
            'Sin tomas registradas. En reptiles y aves dejar de comer suele '
            'ser el primer signo clínico, así que al registrar las tomas aquí '
            'aparece la racha de rechazos de cada ejemplar.',
      );
    }

    return VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                VetIcons.bowlPaw,
                size: 20,
                color: rachas.isEmpty ? VetColors.turquoise : VetColors.warning,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Monitor de alimentación y rechazos',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (rachas.isEmpty)
            const Text(
              'Ningún ejemplar acumula rechazos en su última toma.',
              style: TextStyle(fontSize: 12, color: VetColors.success),
            )
          else
            for (final r in rachas)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      // Tres rechazos seguidos dejan de ser una preferencia
                      // alimentaria y pasan a ser un signo que atender.
                      r.rechazos >= 3
                          ? VetIcons.alertOctagon
                          : VetIcons.alertTriangle,
                      size: 18,
                      color: r.rechazos >= 3
                          ? VetColors.danger
                          : VetColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        r.specimen.titulo,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${r.rechazos} rechazo(s)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: r.rechazos >= 3
                            ? VetColors.danger
                            : VetColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  /// Feed de eventos: mezcla los fisiológicos de exóticos con los del
  /// expediente clínico, ordenados juntos por fecha.
  Widget _eventos(ExoticSnapshot datos) {
    final delGrupo = datos.delTaxon(_taxon).map((e) => e.id).toSet();

    // Una sola línea de tiempo: al clínico le importa el orden real de lo que
    // paso al ejemplar, no de que tabla salio cada cosa.
    final fila = <({DateTime cuando, String quien, String que, bool urgente})>[
      for (final e in datos.physioEvents)
        if (delGrupo.contains(e.specimenId))
          (
            cuando: e.ocurrioEn,
            quien: _nombreDe(datos, e.specimenId),
            que: e.detalle.isEmpty ? e.etiqueta : '${e.etiqueta} · ${e.detalle}',
            urgente: e.urgente,
          ),
      for (final e in datos.events)
        if (delGrupo.contains(e.specimenId))
          (
            cuando: e.fecha,
            quien: _nombreDe(datos, e.specimenId),
            que: e.detalle.isEmpty ? e.tipo : '${e.tipo} · ${e.detalle}',
            urgente: false,
          ),
    ]..sort((a, b) => b.cuando.compareTo(a.cuando));

    return VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Eventos recientes',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 2),
          const Text(
            'Mudas, posturas, conducta y enriquecimiento junto al expediente.',
            style: TextStyle(fontSize: 11, color: VetColors.muted),
          ),
          const SizedBox(height: 8),
          if (fila.isEmpty)
            const VetEmptyState(
              text: 'Sin eventos registrados para este grupo.',
              icon: VetIcons.history,
            )
          else
            for (final e in fila.take(10))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      e.urgente ? VetIcons.alertTriangle : VetIcons.dot,
                      size: e.urgente ? 16 : 14,
                      color: e.urgente ? VetColors.warning : VetColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${e.quien} · ${e.que}',
                        style: TextStyle(
                          fontSize: 12,
                          color: e.urgente ? VetColors.warning : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  /// Cuenta regresiva del aislamiento, o tiempo dentro si no se fijo plazo.
  String _textoEstancia(ExoticStay s, DateTime ahora) {
    final restantes = s.diasRestantes(ahora);
    final lugar = s.recinto.isEmpty ? '' : '${s.recinto} · ';
    if (restantes == null) return '$lugar${s.diasDentro(ahora)} d';
    if (restantes <= 0) return '${lugar}Aislamiento cumplido';
    return '$lugar''Faltan $restantes d';
  }

  String _nombreDe(ExoticSnapshot datos, String id) {
    for (final e in datos.specimens) {
      if (e.id == id) return e.titulo;
    }
    return 'Ejemplar';
  }
}

/// Tarjeta para una sección que ya tiene tabla pero todavía no tiene filas.
///
/// Distinta de un error: aquí el sitio donde guardar existe, simplemente
/// nadie ha registrado nada. Se explica qué aparecerá para que el hueco se
/// entienda, en vez de rellenarlo con cifras de ejemplo.
class _SinRegistrosAun extends StatelessWidget {
  const _SinRegistrosAun({
    required this.titulo,
    required this.icono,
    required this.texto,
  });

  final String titulo;
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icono, size: 20, color: VetColors.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const VetStatusBadge(
                label: 'Sin registros',
                kind: VetBadgeKind.unverified,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            texto,
            style: const TextStyle(fontSize: 12, color: VetColors.muted),
          ),
        ],
      ),
    );
  }
}

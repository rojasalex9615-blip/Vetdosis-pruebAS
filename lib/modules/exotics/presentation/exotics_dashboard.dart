import 'package:flutter/material.dart';

import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_icons.dart';
import '../../../vet_ui/vet_theme.dart';
import '../../auth/domain/clinic_membership.dart';
import '../domain/exotic_dashboard.dart';
import '../domain/exotic_taxon.dart';
import 'allometric_calculator.dart';

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
    this.initialTaxon,
  });

  final ClinicMembership? member;

  /// De donde salen los ejemplares. Sin repositorio el panel queda vacío y lo
  /// dice; nunca rellena con un catálogo de muestra.
  final ExoticDashboardRepository? repository;

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
      _microclimas(),
      const SizedBox(height: 10),
      _cuarentena(datos, ahora),
      const SizedBox(height: 10),
      _estatusNormativo(),
      const SizedBox(height: 24),

      // Fila 2: Seguimiento fisiológico y conductual
      const VetSectionHeader(
        title: 'Seguimiento fisiológico y conductual',
        subtitle: 'Alimentación, rechazos y evolución del peso individual',
      ),
      const SizedBox(height: 10),
      _pesos(datos),
      const SizedBox(height: 10),
      _alimentacion(),
      const SizedBox(height: 24),

      // Fila 3: Ejemplares prioritarios y reproducción
      const VetSectionHeader(
        title: 'Ejemplares prioritarios y reproducción',
        subtitle: 'Incubadoras, nidadas y eventos fisiológicos recientes',
      ),
      const SizedBox(height: 10),
      _incubadoras(),
      const SizedBox(height: 10),
      _eventos(datos),
      const SizedBox(height: 24),
    ];
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
  /// Hoy busca por nombre, especie, raza e identificador interno. Microchip,
  /// anillo cerrado y muesca **no tienen columna** en `vet_patients`: cuando
  /// se añadan, entran aquí sin tocar la pantalla.
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
                        e.taxon?.label ?? 'Sin grupo',
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
            'Microchip, anillo cerrado y muesca aún no se guardan en el '
            'expediente; en cuanto existan se buscan desde aquí.',
            style: TextStyle(fontSize: 11, color: VetColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _microclimas() => const _PendienteDeModelar(
        titulo: 'Estado de microclimas y recintos',
        icono: VetIcons.thermometer,
        queFaltaria:
            'Gradiente térmico (punto caliente y frío), humedad relativa, '
            'índice UV y fisicoquímicos del agua (pH, NH₃, NO₂⁻, salinidad).',
      );

  Widget _estatusNormativo() => const _PendienteDeModelar(
        titulo: 'Estatus normativo (CITES / SEMARNAT)',
        icono: VetIcons.certificate,
        queFaltaria:
            'Vigencia de registros y aprovechamientos, marcajes pendientes '
            '(microchip o anillo) y documentación de procedencia legal.',
      );

  Widget _incubadoras() => const _PendienteDeModelar(
        titulo: 'Incubadoras y nidadas activas',
        icono: VetIcons.egg,
        queFaltaria:
            'Temperatura de incubación por puesta —determinante del sexo en '
            'varias especies—, humedad, ovoscopia y cuenta regresiva a la '
            'eclosión.',
      );

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
                      s.recinto.isEmpty
                          ? '${s.diasDentro(ahora)} d'
                          : '${s.recinto} · ${s.diasDentro(ahora)} d',
                      style: const TextStyle(
                        fontSize: 12,
                        color: VetColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 4),
          const Text(
            'Los días de aislamiento previstos todavía no se guardan: se '
            'muestra el tiempo que lleva dentro.',
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

  Widget _alimentacion() => const _PendienteDeModelar(
        titulo: 'Monitor de alimentación y rechazos',
        icono: VetIcons.bowlPaw,
        queFaltaria:
            'Tomas aceptadas y rechazadas por ejemplar. En reptiles y aves '
            'dejar de comer suele ser el primer signo clínico, así que el '
            'registro necesita su propia tabla y no un campo de texto.',
      );

  /// Feed de eventos fisiológicos reales del expediente.
  Widget _eventos(ExoticSnapshot datos) {
    final delGrupo = datos.delTaxon(_taxon).map((e) => e.id).toSet();
    final recientes =
        datos.events.where((e) => delGrupo.contains(e.specimenId)).toList()
          ..sort((a, b) => b.fecha.compareTo(a.fecha));

    return VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Eventos recientes',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          if (recientes.isEmpty)
            const VetEmptyState(
              text: 'Sin eventos registrados para este grupo.',
              icon: VetIcons.history,
            )
          else
            for (final e in recientes.take(8))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(VetIcons.dot, size: 14, color: VetColors.muted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${_nombreDe(datos, e.specimenId)} · ${e.tipo}'
                        '${e.detalle.isEmpty ? '' : ' · ${e.detalle}'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 4),
          const Text(
            'Muda (ecdysis) con retención, postura, vocalizaciones anómalas y '
            'enriquecimiento todavía no son tipos de evento del expediente.',
            style: TextStyle(fontSize: 11, color: VetColors.muted),
          ),
        ],
      ),
    );
  }

  String _nombreDe(ExoticSnapshot datos, String id) {
    for (final e in datos.specimens) {
      if (e.id == id) return e.titulo;
    }
    return 'Ejemplar';
  }
}

/// Tarjeta para lo que el panel debe mostrar pero aún no tiene de dónde leer.
///
/// Es deliberadamente explícita: antes de esto el módulo de producción pintaba
/// cifras de ejemplo que parecían del usuario, y esa confusión es peor que un
/// hueco reconocido.
class _PendienteDeModelar extends StatelessWidget {
  const _PendienteDeModelar({
    required this.titulo,
    required this.icono,
    required this.queFaltaria,
  });

  final String titulo;
  final IconData icono;
  final String queFaltaria;

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
                label: 'Sin datos',
                kind: VetBadgeKind.unverified,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            queFaltaria,
            style: const TextStyle(fontSize: 12, color: VetColors.muted),
          ),
          const SizedBox(height: 6),
          const Text(
            'No hay tabla para esto todavía, así que no se muestra ningún '
            'valor: preferimos el hueco a un dato inventado.',
            style: TextStyle(fontSize: 11, color: VetColors.muted),
          ),
        ],
      ),
    );
  }
}

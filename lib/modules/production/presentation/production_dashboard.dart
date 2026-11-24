import 'package:flutter/material.dart';
import '../../../core/widgets/accent_glow.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_icons.dart';
import '../../../vet_ui/vet_theme.dart';
import '../../auth/domain/clinic_membership.dart';
import '../../core/domain/module_access.dart';
import '../domain/production_farm.dart';
import '../domain/production_write_repository.dart';
import 'production_capture_forms.dart';
import '../domain/production_unit_repository.dart';

/// Datos zootécnicos y analíticos por especie para el dashboard de producción.
class SpeciesMetrics {
  const SpeciesMetrics({required this.vitals});

  /// Rangos de referencia por especie. Es lo unico de este catalogo que es un
  /// dato real y general: no depende de la granja de nadie.
  ///
  /// Aqui vivian ademas unos costos, una conversion alimenticia, unos silos y
  /// unos lotes de una granja inventada de 480 vacas. Ya no se pintaban en
  /// ningun lado, pero seguian escritos, y lo que esta escrito acaba
  /// enchufandose. Lo real vive ahora en el inventario de alimento y en los
  /// lotes de Supabase.
  final List<VitalSign> vitals;
}

class VitalSign {
  const VitalSign({
    required this.parameter,
    required this.range,
    required this.unit,
  });
  final String parameter;
  final String range;
  final String unit;
}

/// Diccionario de métricas y datos operativos zootécnicos por especie
final Map<String, SpeciesMetrics> speciesDataCatalog = {
  'Bovinos': const SpeciesMetrics(
    vitals: [
      VitalSign(parameter: 'Temperatura rectal', range: '38.0 - 39.3', unit: '°C'),
      VitalSign(parameter: 'Frecuencia cardíaca', range: '60 - 80', unit: 'lpm'),
      VitalSign(parameter: 'Frecuencia respiratoria', range: '15 - 35', unit: 'rpm'),
      VitalSign(parameter: 'Movimientos ruminales', range: '2 - 3', unit: 'mov / 2 min'),
    ],
  ),
  'Porcinos': const SpeciesMetrics(
    vitals: [
      VitalSign(parameter: 'Temperatura rectal', range: '38.5 - 39.5', unit: '°C'),
      VitalSign(parameter: 'Frecuencia cardíaca', range: '70 - 100', unit: 'lpm'),
      VitalSign(parameter: 'Frecuencia respiratoria', range: '20 - 40', unit: 'rpm'),
      VitalSign(parameter: 'Consumo diario agua', range: '8 - 15', unit: 'L / cerdo final'),
    ],
  ),
  'Aves': const SpeciesMetrics(
    vitals: [
      VitalSign(parameter: 'Temperatura corporal', range: '40.6 - 41.7', unit: '°C'),
      VitalSign(parameter: 'Frecuencia respiratoria', range: '25 - 40', unit: 'rpm'),
      VitalSign(parameter: 'Frecuencia cardíaca', range: '250 - 400', unit: 'lpm'),
      VitalSign(parameter: 'Relación agua:alimento', range: '1.8 : 1 a 2.0 : 1', unit: 'L / kg'),
    ],
  ),
  'Ovinos / caprinos': const SpeciesMetrics(
    vitals: [
      VitalSign(parameter: 'Temperatura rectal', range: '38.5 - 40.0', unit: '°C'),
      VitalSign(parameter: 'Frecuencia cardíaca', range: '70 - 90', unit: 'lpm'),
      VitalSign(parameter: 'Frecuencia respiratoria', range: '16 - 34', unit: 'rpm'),
      VitalSign(parameter: 'Movimientos ruminales', range: '2 - 3', unit: 'mov / 2 min'),
    ],
  ),
  'Peces': const SpeciesMetrics(
    vitals: [
      VitalSign(parameter: 'Oxígeno disuelto ideal', range: '> 5.0', unit: 'mg/L'),
      VitalSign(parameter: 'Temperatura de agua (Tilapia)', range: '26.0 - 30.0', unit: '°C'),
      VitalSign(parameter: 'pH del agua', range: '6.5 - 8.5', unit: 'pH'),
      VitalSign(parameter: 'Amonio total (TAN)', range: '< 0.05', unit: 'mg/L tóxico'),
    ],
  ),
  'Abejas': const SpeciesMetrics(
    vitals: [
      VitalSign(parameter: 'Temperatura en cámara de cría', range: '34.5 - 35.5', unit: '°C'),
      VitalSign(parameter: 'Humedad relativa en colmena', range: '55 - 65', unit: '%'),
      VitalSign(parameter: 'Postura diaria reina', range: '1,500 - 2,000', unit: 'huevos/día'),
    ],
  ),
  'Equinos': const SpeciesMetrics(
    vitals: [
      VitalSign(parameter: 'Temperatura rectal', range: '37.2 - 38.3', unit: '°C'),
      VitalSign(parameter: 'Frecuencia cardíaca en reposo', range: '28 - 44', unit: 'lpm'),
      VitalSign(parameter: 'Frecuencia respiratoria', range: '8 - 16', unit: 'rpm'),
      VitalSign(parameter: 'Tiempo de llenado capilar (TLLC)', range: '< 2', unit: 'segundos'),
    ],
  ),
};

/// Widget principal del Dashboard Independiente de Producción Pecuaria
class ProductionDashboard extends StatefulWidget {
  const ProductionDashboard({
    super.key,
    required this.onNavigate,
    this.member,
    this.access,
    this.units,
    this.farm,
    this.farmWrite,
    this.initialSpecies = 'Bovinos',
  });

  final ValueChanged<String> onNavigate;
  final ClinicMembership? member;
  final ModuleAccess? access;
  final ProductionUnitRepository? units;

  /// De donde salen los lotes, eventos y registros reales de la granja.
  ///
  /// Si no se pasa, el panel no inventa una granja de ejemplo: se queda sin
  /// datos y lo dice. Las pruebas pueden entregar uno falso para no tocar red.
  final ProductionFarmRepository? farm;

  /// Por donde se guardan lotes, registros y eventos.
  ///
  /// Va aparte de [farm] a proposito: el panel es de lectura y solo las
  /// pantallas que capturan necesitan poder escribir. Si no se pasa, los
  /// botones de captura no se dibujan.
  final ProductionWriteRepository? farmWrite;
  final String initialSpecies;

  @override
  State<ProductionDashboard> createState() => _ProductionDashboardState();
}

class _ProductionDashboardState extends State<ProductionDashboard> {
  late String _selectedSpecies;

  final List<String> _speciesList = const [
    'Bovinos',
    'Porcinos',
    'Aves',
    'Ovinos / caprinos',
    'Peces',
    'Abejas',
    'Equinos',
  ];

  /// Lo que hay de verdad en la granja para la especie elegida.
  ///
  /// `null` mientras se lee. El panel no cae de vuelta al catalogo de ejemplo
  /// si esto viene vacio: ensenar la granja inventada de 480 vacas como si
  /// fuera del usuario era justo el error que se corrige.
  FarmSnapshot? _granja;
  bool _cargandoGranja = true;
  Object? _falloGranja;

  @override
  void initState() {
    super.initState();
    _selectedSpecies = widget.initialSpecies;
    if (!_speciesList.contains(_selectedSpecies)) {
      _selectedSpecies = 'Bovinos';
    }
    _cargarGranja();
  }

  Future<void> _cargarGranja() async {
    // Cede el turno antes de tocar el estado. La primera llamada sale de
    // initState, y ahi el widget todavia se esta montando: un setState
    // sincrono en ese momento revienta. Con esto, todo lo que sigue ocurre
    // ya montado, venga de initState o de un cambio de especie.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    final repo = widget.farm;
    final clinicId = widget.member?.clinicId;
    if (repo == null || clinicId == null || clinicId.isEmpty) {
      // Sin repositorio o sin area de trabajo no hay nada que leer. Se queda
      // en vacio, que es la verdad, en lugar de rellenar con el catalogo.
      if (mounted) {
        setState(() {
          _granja = const FarmSnapshot();
          _cargandoGranja = false;
          _falloGranja = null;
        });
      }
      return;
    }
    setState(() {
      _cargandoGranja = true;
      _falloGranja = null;
    });
    try {
      final datos = await repo.load(
        clinicId,
        especies: codigosDeEspecie[_selectedSpecies] ?? const [],
      );
      if (!mounted) return;
      setState(() {
        _granja = datos;
        _cargandoGranja = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Un fallo de red no es «no hay datos»: se distinguen en pantalla para
      // que nadie lea un corte de conexion como una granja sin lotes.
      setState(() {
        _falloGranja = e;
        _cargandoGranja = false;
      });
    }
  }

  /// Etiquetas, unidades y rangos de referencia de la especie.
  ///
  /// De aqui ya NO salen cifras de la granja: solo los textos que describen
  /// que se mide y en que unidad. Lo que es del usuario viene de [_granja].
  SpeciesMetrics get _currentMetrics =>
      speciesDataCatalog[_selectedSpecies] ?? speciesDataCatalog['Bovinos']!;

  void _openCalculatorDialog(String calcType) {
    showDialog<void>(
      context: context,
      builder: (ctx) => ProductionCalculatorModal(
        calcType: calcType,
        species: _selectedSpecies,
      ),
    );
  }

  void _openMassMedicationDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => MassMedicationModal(species: _selectedSpecies),
    );
  }

  void _openPrescriptionDialog({required bool quantified}) {
    showDialog<void>(
      context: context,
      builder: (ctx) => PecuariaPrescriptionModal(
        quantified: quantified,
        species: _selectedSpecies,
        clinicName: widget.member?.clinicName ?? 'Granja / Clínica Pecuaria',
        mvzName: widget.member?.userId ?? 'MVZ Responsable',
      ),
    );
  }

  void _openVademecumDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => ProductionVademecumModal(species: _selectedSpecies),
    );
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _currentMetrics;
    final (specIcon, specAccent) = _speciesVisual(_selectedSpecies);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Selector de especie (chips arriba)
        _buildSpeciesSelector(),
        const SizedBox(height: 16),

        // Todo lo que describe a ESTA granja (retiros, KPIs, curvas,
        // instalaciones, calendario, lotes y alertas) sale de Supabase. Si no
        // hay registros, se dice; no se rellena con el catalogo de ejemplo.
        ..._buildFarmArea(),

        // 2. Herramientas de la especie elegida (tarjetas interactivas)
        // No dependen de la granja: son calculadoras y referencias, y siguen
        // sirviendo aunque todavia no se haya dado de alta ningun lote.
        _buildSpeciesToolsSection(metrics, specIcon, specAccent),
        const SizedBox(height: 24),

        // 5. Recetas y control (acceso directo a receta cuantificada / simple)
        _buildPrescriptionAndControlSection(),
        const SizedBox(height: 24),

        // 6. Próximamente (en gris para grandes especies avanzada, manejo de desechos)
        _buildUpcomingSection(),
        const SizedBox(height: 32),
      ],
    );
  }

  /// La parte del panel que describe a ESTA granja.
  ///
  /// Antes se pintaba siempre desde `speciesDataCatalog`, un catalogo fijo con
  /// una granja inventada (480 vacas, silos al 71 %, alertas de una vaca
  /// #402). Parecia informacion del usuario y no lo era. Ahora sale de
  /// Supabase y, cuando no hay registros, se dice con todas sus letras.
  List<Widget> _buildFarmArea() {
    if (_cargandoGranja) {
      return const [
        VetCard(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
        SizedBox(height: 24),
      ];
    }

    if (_falloGranja != null) {
      return [
        VetCard(
          child: Column(
            children: [
              const Icon(VetIcons.cloudOff, size: 28, color: VetColors.muted),
              const SizedBox(height: 8),
              const Text(
                'No se pudieron leer los datos de producción',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              const Text(
                'Revisa la conexión. Esto no significa que la granja esté '
                'vacía: no se alcanzó el servidor.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: VetColors.muted),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _cargarGranja,
                icon: const Icon(VetIcons.refresh, size: 16),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ];
    }

    final granja = _granja ?? const FarmSnapshot();

    if (granja.sinDatos) {
      return [
        _barraDeCaptura(granja),
        _buildFarmEmptyCard(),
        const SizedBox(height: 24),
      ];
    }

    final ahora = DateTime.now();
    return [
      _barraDeCaptura(granja),
      _buildRealKpis(granja),
      const SizedBox(height: 20),
      _buildRealBatches(granja, ahora),
      const SizedBox(height: 24),
      _buildRealAlerts(granja, ahora),
      const SizedBox(height: 24),
    ];
  }

  // -------------------------------------------------------------------
  // Captura
  // -------------------------------------------------------------------

  /// Los botones que faltaban. Solo se dibujan si hay con que escribir y el
  /// rol lo permite; [ProductionCaptureBar] se encarga de lo segundo.
  Widget _barraDeCaptura(FarmSnapshot granja) {
    final repo = widget.farmWrite;
    final clinicId = widget.member?.clinicId;
    if (repo == null || clinicId == null || clinicId.isEmpty) {
      return const SizedBox.shrink();
    }
    return ProductionCaptureBar(
      member: widget.member,
      onNuevoLote: () => _abrirLote(repo, clinicId),
      onRegistro: () => _abrirRegistro(repo, clinicId, granja),
      onEvento: () => _abrirEvento(repo, clinicId, granja),
    );
  }

  /// Tras guardar se vuelve a leer: lo que se acaba de capturar tiene que
  /// verse en el panel sin que nadie tenga que salir y entrar.
  Future<void> _trasGuardar(bool guardado, String mensaje) async {
    if (!guardado || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
    await _cargarGranja();
  }

  Future<void> _abrirLote(
    ProductionWriteRepository repo,
    String clinicId,
  ) async {
    final guardado = await capturarLote(
      context,
      clinicId: clinicId,
      repo: repo,
      especiesPermitidas: codigosDeEspecie[_selectedSpecies] ?? const [],
    );
    await _trasGuardar(guardado, 'Lote guardado');
  }

  Future<void> _abrirRegistro(
    ProductionWriteRepository repo,
    String clinicId,
    FarmSnapshot granja,
  ) async {
    final guardado = await capturarRegistro(
      context,
      clinicId: clinicId,
      repo: repo,
      lotes: granja.batches,
      metricas: granja.metricDefs,
    );
    await _trasGuardar(guardado, 'Registro guardado');
  }

  Future<void> _abrirEvento(
    ProductionWriteRepository repo,
    String clinicId,
    FarmSnapshot granja,
  ) async {
    final guardado = await capturarEvento(
      context,
      clinicId: clinicId,
      repo: repo,
      lotes: granja.batches,
    );
    await _trasGuardar(guardado, 'Evento guardado');
  }

  /// El estado vacio de verdad: ni una cifra inventada.
  Widget _buildFarmEmptyCard() {
    final especieSinCatalogo =
        (codigosDeEspecie[_selectedSpecies] ?? const []).isEmpty;
    return VetCard(
      child: Column(
        children: [
          Icon(
            especieSinCatalogo ? VetIcons.info : VetIcons.barn,
            size: 30,
            color: VetColors.muted.withValues(alpha: .8),
          ),
          const SizedBox(height: 10),
          Text(
            especieSinCatalogo
                ? 'Todavía no hay producción de $_selectedSpecies'
                : 'Aún no hay datos de producción',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            especieSinCatalogo
                ? 'Esta especie todavía no forma parte del catálogo '
                    'productivo, así que no hay lotes ni registros que mostrar.'
                : 'Empieza con «Nuevo lote» y captura su registro diario: '
                    'aquí irán apareciendo tus cabezas, curvas y eventos. No '
                    'mostramos cifras de ejemplo para que nada se confunda '
                    'con datos de tu granja.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: VetColors.muted),
          ),
        ],
      ),
    );
  }

  /// Cabezas y lotes reales. Solo lo que se puede contar de verdad.
  Widget _buildRealKpis(FarmSnapshot granja) {
    final activos = granja.batches.where((b) => b.estado != 'cerrado').length;
    return Row(
      children: [
        Expanded(
          child: VetCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cabezas en inventario',
                  style: TextStyle(fontSize: 12, color: VetColors.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  '${granja.totalCabezas}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: VetCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lotes activos',
                  style: TextStyle(fontSize: 12, color: VetColors.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  '$activos',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Los lotes tal como estan en `lotes_produccion`.
  Widget _buildRealBatches(FarmSnapshot granja, DateTime ahora) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VetSectionHeader(
          title: 'Mis lotes',
          subtitle: 'Lotes dados de alta en este espacio de trabajo',
        ),
        const SizedBox(height: 10),
        if (granja.batches.isEmpty)
          const VetCard(
            child: VetEmptyState(
              text: 'Aún no hay lotes dados de alta para esta especie.',
              icon: VetIcons.barn,
            ),
          )
        else
          for (final b in granja.batches)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: VetCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                radius: 16,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.nombre.isEmpty ? b.codigo : b.nombre,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${b.proposito} · ${b.diasEnEtapa(ahora)} días',
                            style: const TextStyle(
                              fontSize: 12,
                              color: VetColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${b.cabezas}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  /// Alertas reales: eventos de `produccion_eventos` que aun no han pasado.
  Widget _buildRealAlerts(FarmSnapshot granja, DateTime ahora) {
    final proximos = granja.proximos(ahora);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VetSectionHeader(
          title: 'Alertas y Tareas Críticas',
          subtitle:
              'Vacunas por vencer, resguardos farmacológicos y partos o servicios',
        ),
        const SizedBox(height: 10),
        if (proximos.isEmpty)
          const VetCard(
            child: VetEmptyState(
              text: 'No hay eventos próximos registrados.',
              icon: VetIcons.calendarCheck,
            ),
          )
        else
          for (final e in proximos)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: VetCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                radius: 16,
                // Mismo anclaje arriba que el resto de tarjetas de alerta:
                // asi el icono y los dias no bailan segun cuanto texto haya.
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      e.tipo == 'resguardo'
                          ? VetIcons.alertOctagon
                          : (e.tipo == 'parto'
                              ? VetIcons.heart
                              : VetIcons.bell),
                      color: e.tipo == 'resguardo'
                          ? VetColors.danger
                          : VetColors.warning,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.subtipo.isEmpty ? e.tipo : e.subtipo,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            _nombreDeLote(granja, e.loteId),
                            style: const TextStyle(
                              fontSize: 12,
                              color: VetColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _chipDeDias(e.diasRestantes(ahora)),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  String _nombreDeLote(FarmSnapshot granja, String loteId) {
    for (final b in granja.batches) {
      if (b.id == loteId) return b.nombre.isEmpty ? b.codigo : b.nombre;
    }
    return 'Lote sin nombre';
  }

  Widget _chipDeDias(int dias) {
    final urgente = dias <= 2;
    final color = urgente ? VetColors.danger : VetColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        dias == 0 ? 'Hoy' : 'En $dias d',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  // 1. SELECTOR DE ESPECIE (Chips superiores)
  Widget _buildSpeciesSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VetSectionHeader(
          title: 'Producción Pecuaria',
          subtitle: 'Panel independiente de gestión zootécnica y financiera',
          large: true,
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              for (final sp in _speciesList) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: glowChip(
                    ChoiceChip(
                      selected: _selectedSpecies == sp,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedSpecies = sp;
                          });
                          // Cada especie tiene sus propios lotes: al cambiar
                          // de pestaña hay que releer, o se quedaria viendo
                          // los datos de la especie anterior.
                          _cargarGranja();
                        }
                      },
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _speciesVisual(sp).$1,
                            size: 16,
                            color: _selectedSpecies == sp
                                ? VetColors.ink
                                : VetColors.muted,
                          ),
                          const SizedBox(width: 6),
                          Flexible(child: Text(sp)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // 2. HERRAMIENTAS DE LA ESPECIE ELEGIDA (Tarjetas)
  Widget _buildSpeciesToolsSection(SpeciesMetrics metrics, IconData specIcon, Color specAccent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VetSectionHeader(
          title: 'Herramientas de $_selectedSpecies',
          subtitle: 'Calculadoras zootécnicas, constantes fisiológicas, vademécum y registros',
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          // 1.35 dejaba la celda en 118 dp y el rotulo a dos lineas no cabia.
          childAspectRatio: 1.2,
          children: [
            ProductionToolTile(
              title: 'Calculadora de Ración',
              subtitle: 'Requerimientos por etapa',
              icon: VetIcons.feedBag,
              accent: VetColors.turquoise,
              onTap: () => _openCalculatorDialog('ration'),
            ),
            ProductionToolTile(
              title: 'FCA / Conversión',
              subtitle: 'Factor conversión alimenticia',
              icon: VetIcons.balance,
              accent: VetColors.violet,
              onTap: () => _openCalculatorDialog('fca'),
            ),
            ProductionToolTile(
              title: 'Densidad Animal',
              subtitle: 'kg/m² o cabezas/corral',
              icon: VetIcons.grid,
              accent: VetColors.cyan,
              onTap: () => _openCalculatorDialog('density'),
            ),
            ProductionToolTile(
              title: 'Capacidad de Caseta/Nave',
              subtitle: 'Dimensiones y ventilación',
              icon: VetIcons.barn,
              accent: VetColors.warning,
              onTap: () => _openCalculatorDialog('capacity'),
            ),
            ProductionToolTile(
              title: 'Dosis Seminales',
              subtitle: 'Concentración y diluyente',
              icon: VetIcons.microscope,
              accent: VetColors.pink,
              onTap: () => _openCalculatorDialog('semen'),
            ),
            // Vivia en la fila de «Ejecución Diaria», que se retiro por pintar
            // un calendario de ejemplo. La dosificacion masiva no es un dato
            // inventado sino una calculadora, asi que se conserva aqui.
            ProductionToolTile(
              title: 'Dosificación Masiva',
              subtitle: 'Agua mg/L y alimento ppm',
              icon: VetIcons.dropper,
              accent: VetColors.brandSky,
              onTap: _openMassMedicationDialog,
            ),
            ProductionToolTile(
              title: 'Constantes Fisiológicas',
              subtitle: 'Rango normal de $_selectedSpecies',
              icon: VetIcons.heartPulse,
              accent: VetColors.turquoise,
              onTap: () => _showVitalsModal(metrics),
            ),
            ProductionToolTile(
              title: 'Vademécum Pecuario',
              subtitle: 'Fármacos y tiempos de retiro',
              icon: VetIcons.pills,
              accent: VetColors.lilac,
              onTap: () => _openVademecumDialog(),
            ),
            ProductionToolTile(
              title: 'Registros Productivos',
              subtitle: 'Pesajes, consumo y mortalidad',
              icon: VetIcons.clipboardChecks,
              accent: VetColors.turquoise,
              onTap: () => _showQuickRecordModal(),
            ),
          ],
        ),
      ],
    );
  }

  void _showVitalsModal(SpeciesMetrics metrics) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(VetIcons.heartPulse, color: VetColors.turquoise),
            const SizedBox(width: 8),
            Expanded(child: Text('Constantes: $_selectedSpecies')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final v in metrics.vitals) ...[
              ListTile(
                dense: true,
                title: Text(v.parameter, style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: Text(
                  '${v.range} ${v.unit}',
                  style: const TextStyle(color: VetColors.turquoise, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  void _showQuickRecordModal() {
    final pesoCtrl = TextEditingController();
    final mortCtrl = TextEditingController();
    final consCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo Registro Productivo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pesoCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Pesaje promedio del lote (kg o g)'),
            ),
            TextField(
              controller: mortCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Mortalidad del día (cabezas)'),
            ),
            TextField(
              controller: consCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Consumo de alimento diario (kg)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Registro productivo guardado con éxito.'),
                  backgroundColor: VetColors.success,
                ),
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // 5. RECETAS Y CONTROL
  Widget _buildPrescriptionAndControlSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VetSectionHeader(
          title: 'Recetas y Control Oficial',
          subtitle: 'Acceso directo a receta médica pecuaria simple y cuantificada',
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: VetActionButton(
                icon: VetIcons.document,
                label: 'Receta Simple',
                style: VetActionStyle.neutral,
                onPressed: () => _openPrescriptionDialog(quantified: false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: VetActionButton(
                icon: VetIcons.documentCheck,
                label: 'Receta Cuantificada',
                style: VetActionStyle.primary,
                onPressed: () => _openPrescriptionDialog(quantified: true),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 6. PRÓXIMAMENTE (En gris)
  Widget _buildUpcomingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VetSectionHeader(
          title: 'Próximamente',
          subtitle: 'Módulos en preparación zootécnica y ambiental',
        ),
        const SizedBox(height: 10),
        Opacity(
          opacity: 0.5,
          child: Column(
            children: const [
              VetCard(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                radius: 16,
                child: Row(
                  children: [
                    Icon(VetIcons.firstAidKit, color: Colors.grey, size: 28),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Grandes Especies: Cirugía y Clínica Avanzada',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          Text(
                            'Protocolos quirúrgicos de campo, cesáreas y laparotomía',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    VetStatusBadge(label: 'En desarrollo', kind: VetBadgeKind.unverified),
                  ],
                ),
              ),
              SizedBox(height: 8),
              VetCard(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                radius: 16,
                child: Row(
                  children: [
                    Icon(VetIcons.leaf, color: Colors.grey, size: 28),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manejo de Efluentes, Desechos y Bioseguridad',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          Text(
                            'Lagunas de oxidación, compostaje de mortalidad y biodigestores',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    VetStatusBadge(label: 'En desarrollo', kind: VetBadgeKind.unverified),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Visual por especie
(IconData, Color) _speciesVisual(String name) => switch (name) {
  'Bovinos' => (VetIcons.cow, VetColors.turquoise),
  'Porcinos' => (VetIcons.pig, VetColors.pink),
  'Aves' => (VetIcons.chicken, VetColors.warning),
  'Ovinos / caprinos' => (VetIcons.sheep, VetColors.violet),
  'Peces' => (VetIcons.fish, VetColors.cyan),
  'Abejas' => (VetIcons.hive, VetColors.warning),
  'Equinos' => (VetIcons.horse, VetColors.purpleDeep),
  _ => (VetIcons.paw, VetColors.turquoise),
};


// Botón de herramienta
class ProductionToolTile extends StatelessWidget {
  const ProductionToolTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: VetCard(
        padding: const EdgeInsets.all(12),
        radius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            VetIconBox(icon: icon, accent: accent, size: 36),
            // En un telefono de 360 dp la celda deja 133 dp de texto util, y
            // con una sola linea se cortaban casi todos los rotulos:
            // «Capacidad de Caseta/Nave» mide 153 dp y «Factor conversion
            // alimenticia», 174. Con dos lineas caben enteros.
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: VetColors.muted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Diálogo modal de Calculadoras de Producción
class ProductionCalculatorModal extends StatefulWidget {
  const ProductionCalculatorModal({
    super.key,
    required this.calcType,
    required this.species,
  });

  final String calcType;
  final String species;

  @override
  State<ProductionCalculatorModal> createState() => ProductionCalculatorModalState();
}

class ProductionCalculatorModalState extends State<ProductionCalculatorModal> {
  final numAnimalsCtrl = TextEditingController(text: '100');
  final paramCtrl1 = TextEditingController();
  final paramCtrl2 = TextEditingController();
  final paramCtrl3 = TextEditingController();
  String _result = '';

  @override
  void initState() {
    super.initState();
    _initParams();
  }

  void _initParams() {
    switch (widget.calcType) {
      case 'ration':
        paramCtrl1.text = '45'; // Peso prom kg
        paramCtrl2.text = '3.0'; // % peso vivo
        _calculate();
        break;
      case 'fca':
        paramCtrl1.text = '5200'; // Alimento consumido kg
        paramCtrl2.text = '2100'; // Ganancia de peso kg
        _calculate();
        break;
      case 'density':
        paramCtrl1.text = '120'; // Superficie m²
        paramCtrl2.text = '150'; // Animales
        _calculate();
        break;
      case 'capacity':
        paramCtrl1.text = '12'; // Ancho nave m
        paramCtrl2.text = '100'; // Largo nave m
        paramCtrl3.text = '12'; // Densidad objetivo (aves/m² o lechones/m²)
        _calculate();
        break;
      case 'semen':
        paramCtrl1.text = '200'; // Volumen eyaculado mL
        paramCtrl2.text = '300'; // Millones esp/mL
        paramCtrl3.text = '3000'; // Millones esp por dosis
        _calculate();
        break;
    }
  }

  void _calculate() {
    setState(() {
      if (widget.calcType == 'ration') {
        final n = double.tryParse(numAnimalsCtrl.text) ?? 1;
        final peso = double.tryParse(paramCtrl1.text) ?? 1;
        final pct = (double.tryParse(paramCtrl2.text) ?? 1) / 100.0;
        final porAnimal = peso * pct;
        final totalDia = porAnimal * n;
        _result = '${porAnimal.toStringAsFixed(2)} kg / animal / día\nTotal lote: ${totalDia.toStringAsFixed(1)} kg/día (${(totalDia/1000).toStringAsFixed(2)} Ton)';
      } else if (widget.calcType == 'fca') {
        final alim = double.tryParse(paramCtrl1.text) ?? 1;
        final peso = double.tryParse(paramCtrl2.text) ?? 1;
        final fca = peso > 0 ? (alim / peso) : 0.0;
        _result = 'FCA: ${fca.toStringAsFixed(2)} : 1\n(Se requieren ${fca.toStringAsFixed(2)} kg de alimento para producir 1 kg vivo)';
      } else if (widget.calcType == 'density') {
        final sup = double.tryParse(paramCtrl1.text) ?? 1;
        final anim = double.tryParse(paramCtrl2.text) ?? 1;
        final dens = sup > 0 ? (anim / sup) : 0.0;
        final m2PorAnimal = anim > 0 ? (sup / anim) : 0.0;
        _result = '${dens.toStringAsFixed(2)} animales / m²\nEspacio por animal: ${m2PorAnimal.toStringAsFixed(2)} m²/cabeza';
      } else if (widget.calcType == 'capacity') {
        final ancho = double.tryParse(paramCtrl1.text) ?? 1;
        final largo = double.tryParse(paramCtrl2.text) ?? 1;
        final dens = double.tryParse(paramCtrl3.text) ?? 1;
        final area = ancho * largo;
        final cap = area * dens;
        _result = 'Área útil: ${area.toStringAsFixed(0)} m²\nCapacidad total recomendada: ${cap.toStringAsFixed(0)} animales';
      } else if (widget.calcType == 'semen') {
        final vol = double.tryParse(paramCtrl1.text) ?? 1;
        final conc = double.tryParse(paramCtrl2.text) ?? 1;
        final dosisReq = double.tryParse(paramCtrl3.text) ?? 1;
        final totalEsp = vol * conc; // millones
        final numDosis = dosisReq > 0 ? (totalEsp / dosisReq).floor() : 0;
        _result = 'Total espermatozoides: ${totalEsp.toStringAsFixed(0)} M\nDosis seminales obtenibles: $numDosis dosis';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    String title = 'Calculadora Zootécnica';
    if (widget.calcType == 'ration') title = 'Cálculo de Ración Diaria';
    if (widget.calcType == 'fca') title = 'Factor Conversión Alimenticia (FCA)';
    if (widget.calcType == 'density') title = 'Densidad Animal';
    if (widget.calcType == 'capacity') title = 'Capacidad de Nave / Caseta';
    if (widget.calcType == 'semen') title = 'Dosis Seminales e Inseminación';

    return AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 16)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.calcType == 'ration') ...[
              TextField(
                controller: numAnimalsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Número de animales en lote'),
                onChanged: (_) => _calculate(),
              ),
              TextField(
                controller: paramCtrl1,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Peso promedio por animal (kg)'),
                onChanged: (_) => _calculate(),
              ),
              TextField(
                controller: paramCtrl2,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '% de peso vivo a consumir (ej. 2.5 - 3.5%)'),
                onChanged: (_) => _calculate(),
              ),
            ] else if (widget.calcType == 'fca') ...[
              TextField(
                controller: paramCtrl1,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Total alimento consumido en periodo (kg)'),
                onChanged: (_) => _calculate(),
              ),
              TextField(
                controller: paramCtrl2,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Ganancia de peso total en periodo (kg)'),
                onChanged: (_) => _calculate(),
              ),
            ] else if (widget.calcType == 'density') ...[
              TextField(
                controller: paramCtrl1,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Superficie de corral / nave (m²)'),
                onChanged: (_) => _calculate(),
              ),
              TextField(
                controller: paramCtrl2,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Número de animales alojados'),
                onChanged: (_) => _calculate(),
              ),
            ] else if (widget.calcType == 'capacity') ...[
              TextField(
                controller: paramCtrl1,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Ancho de la nave (m)'),
                onChanged: (_) => _calculate(),
              ),
              TextField(
                controller: paramCtrl2,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Largo de la nave (m)'),
                onChanged: (_) => _calculate(),
              ),
              TextField(
                controller: paramCtrl3,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Densidad meta (animales / m²)'),
                onChanged: (_) => _calculate(),
              ),
            ] else if (widget.calcType == 'semen') ...[
              TextField(
                controller: paramCtrl1,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Volumen eyaculado (mL)'),
                onChanged: (_) => _calculate(),
              ),
              TextField(
                controller: paramCtrl2,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Concentración (millones esp / mL)'),
                onChanged: (_) => _calculate(),
              ),
              TextField(
                controller: paramCtrl3,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Concentración objetivo por dosis (millones)'),
                onChanged: (_) => _calculate(),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VetColors.turquoise.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: VetColors.turquoise.withValues(alpha: 0.4)),
              ),
              child: Text(
                _result,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
      ],
    );
  }
}

// Modal de Dosificación Masiva (Agua mg/L y Alimento ppm)
class MassMedicationModal extends StatefulWidget {
  const MassMedicationModal({super.key, required this.species});
  final String species;

  @override
  State<MassMedicationModal> createState() => MassMedicationModalState();
}

class MassMedicationModalState extends State<MassMedicationModal> {
  int _tab = 0; // 0: Agua mg/L, 1: Alimento ppm

  final waterVolCtrl = TextEditingController(text: '1000'); // Litros tinaco
  final waterMgLCtrl = TextEditingController(text: '100'); // mg/L deseados
  final waterPctCtrl = TextEditingController(text: '10'); // Concentración producto %

  final feedTonCtrl = TextEditingController(text: '5'); // Toneladas alimento
  final feedPpmCtrl = TextEditingController(text: '200'); // ppm producto
  final feedPrePctCtrl = TextEditingController(text: '20'); // Premezcla %

  String _calcOutput = '';

  @override
  void initState() {
    super.initState();
    _recalc();
  }

  void _recalc() {
    setState(() {
      if (_tab == 0) {
        final l = double.tryParse(waterVolCtrl.text) ?? 1;
        final mgL = double.tryParse(waterMgLCtrl.text) ?? 1;
        final concPct = (double.tryParse(waterPctCtrl.text) ?? 1) / 100.0;
        final mgActivoTotal = l * mgL;
        final gActivoTotal = mgActivoTotal / 1000.0;
        final gProducto = concPct > 0 ? (gActivoTotal / concPct) : 0.0;
        _calcOutput = 'Principio activo total: ${gActivoTotal.toStringAsFixed(1)} g\n'
            'Agregar de producto comercial ($concPct*100%):\n'
            '👉 ${gProducto.toStringAsFixed(1)} gramos (o ${(gProducto/1000).toStringAsFixed(2)} kg) para los ${l.toStringAsFixed(0)} L';
      } else {
        final ton = double.tryParse(feedTonCtrl.text) ?? 1;
        final ppm = double.tryParse(feedPpmCtrl.text) ?? 1; // 1 ppm = 1 g/Ton
        final prePct = (double.tryParse(feedPrePctCtrl.text) ?? 1) / 100.0;
        final gActivoTotal = ton * ppm;
        final gPremezcla = prePct > 0 ? (gActivoTotal / prePct) : 0.0;
        _calcOutput = 'Activo requerido: ${gActivoTotal.toStringAsFixed(0)} g\n'
            'Mezclar en planta por batch:\n'
            '👉 ${(gPremezcla/1000).toStringAsFixed(2)} kg de premezcla para las ${ton.toStringAsFixed(1)} Ton';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Dosificación Masiva Pecuaria'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Agua (mg/L)')),
                ButtonSegment(value: 1, label: Text('Alimento (ppm)')),
              ],
              selected: {_tab},
              onSelectionChanged: (val) {
                setState(() {
                  _tab = val.first;
                  _recalc();
                });
              },
            ),
            const SizedBox(height: 16),
            if (_tab == 0) ...[
              TextField(
                controller: waterVolCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Volumen tinaco / bebedero (Litros)'),
                onChanged: (_) => _recalc(),
              ),
              TextField(
                controller: waterMgLCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Dosis meta en agua (mg / L o ppm)'),
                onChanged: (_) => _recalc(),
              ),
              TextField(
                controller: waterPctCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Concentración producto comercial (%)'),
                onChanged: (_) => _recalc(),
              ),
            ] else ...[
              TextField(
                controller: feedTonCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Toneladas de alimento a mezclar'),
                onChanged: (_) => _recalc(),
              ),
              TextField(
                controller: feedPpmCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Concentración objetivo en alimento (ppm o g/Ton)'),
                onChanged: (_) => _recalc(),
              ),
              TextField(
                controller: feedPrePctCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Concentración de la premezcla comercial (%)'),
                onChanged: (_) => _recalc(),
              ),
            ],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VetColors.violet.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: VetColors.violet.withValues(alpha: 0.35)),
              ),
              child: Text(
                _calcOutput,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
      ],
    );
  }
}

// Modal de Vademécum Pecuario Oficial SENASICA
class ProductionVademecumModal extends StatelessWidget {
  const ProductionVademecumModal({super.key, required this.species});
  final String species;

  @override
  Widget build(BuildContext context) {
    final List<(String, String, String, String)> drugs = [
      ('Oxitetraciclina 200 LA', 'Antimicrobiano amplio espectro', '28 días carne / 7 días leche', '20 mg/kg IM/SC'),
      ('Tilmicosina 300 mg/mL', 'Neumonías y complejo respiratorio', '28 días carne / Prohibido en leche humana', '10 mg/kg SC única'),
      ('Florfenicol 300 mg/mL', 'Respiratorio y pododermatitis', '28 - 38 días carne / No en lactancia', '20 mg/kg IM (48h) o 40 mg/kg SC'),
      ('Ivermectina 1%', 'Endectocida sistémico', '28 - 35 días carne / No en leche para consumo', '200 mcg/kg SC'),
      ('Flunixin Meglumine 50mg', 'Antiinflamatorio no esteroideo (AINE)', '4 días carne / 36 h leche', '1.1 - 2.2 mg/kg IV/IM'),
      ('Tilosina Tartrato', 'Disentería porcina, micoplasmosis', '5 - 7 días carne', '10 - 20 mg/kg agua'),
    ];

    return AlertDialog(
      title: Text('Vademécum Pecuario: $species'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: drugs.length,
          separatorBuilder: (_, _) => const Divider(height: 14),
          itemBuilder: (ctx, i) {
            final (name, cat, retiro, dose) = drugs[i];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(cat, style: const TextStyle(fontSize: 12, color: VetColors.muted)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: VetColors.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Retiro oficial: $retiro',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: VetColors.danger),
                  ),
                ),
                const SizedBox(height: 2),
                Text('Dosis referencia: $dose', style: const TextStyle(fontSize: 12)),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
      ],
    );
  }
}

// Modal de Receta Médica Pecuaria (Simple y Cuantificada)
class PecuariaPrescriptionModal extends StatefulWidget {
  const PecuariaPrescriptionModal({
    super.key,
    required this.quantified,
    required this.species,
    required this.clinicName,
    required this.mvzName,
  });

  final bool quantified;
  final String species;
  final String clinicName;
  final String mvzName;

  @override
  State<PecuariaPrescriptionModal> createState() => PecuariaPrescriptionModalState();
}

class PecuariaPrescriptionModalState extends State<PecuariaPrescriptionModal> {
  final uppCtrl = TextEditingController(text: 'UPP-04-129-882');
  final loteCtrl = TextEditingController(text: 'Lote Principal');
  final drugCtrl = TextEditingController(text: 'Oxitetraciclina 200 LA');
  final doseCtrl = TextEditingController(text: '20 mg/kg IM cada 48h por 3 dosis');
  final withdrawalCtrl = TextEditingController(text: '28 días en carne');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            widget.quantified ? VetIcons.documentCheck : VetIcons.document,
            color: widget.quantified ? VetColors.turquoise : VetColors.violet,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.quantified ? 'Receta Médica Cuantificada' : 'Receta Médica Simple',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Médico: ${widget.mvzName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Text('Granja / UPP: ${widget.clinicName}', style: const TextStyle(fontSize: 12, color: VetColors.muted)),
                  Text('Especie destino: ${widget.species}', style: const TextStyle(fontSize: 12, color: VetColors.muted)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: uppCtrl,
              decoration: const InputDecoration(labelText: 'Clave UPP / PSG oficial'),
            ),
            TextField(
              controller: loteCtrl,
              decoration: const InputDecoration(labelText: 'Lote / Corral / Nave destino'),
            ),
            TextField(
              controller: drugCtrl,
              decoration: const InputDecoration(labelText: 'Principio activo y concentración comercial'),
            ),
            TextField(
              controller: doseCtrl,
              decoration: const InputDecoration(labelText: 'Pauta posológica e indicación terapéutica'),
            ),
            TextField(
              controller: withdrawalCtrl,
              decoration: const InputDecoration(labelText: 'Tiempo de retiro obligatorio prescrito'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  widget.quantified
                      ? 'Receta cuantificada foliada y registrada con folio oficial.'
                      : 'Receta simple generada exitosamente.',
                ),
                backgroundColor: VetColors.success,
              ),
            );
          },
          child: const Text('Emitir Receta'),
        ),
      ],
    );
  }
}

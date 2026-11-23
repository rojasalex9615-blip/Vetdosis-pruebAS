import 'package:flutter/material.dart';

import '../../../core/widgets/accent_glow.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_icons.dart';
import '../../../vet_ui/vet_theme.dart';
import '../../auth/domain/clinic_membership.dart';
import '../../calculations/presentation/calculation_screen.dart';
import '../domain/exotic_dashboard.dart';
import '../domain/exotic_husbandry.dart';
import '../domain/exotic_reference.dart';
import '../domain/exotic_taxon.dart';
import 'allometric_calculator.dart';
import 'exotics_dashboard.dart';

/// Consulta de valores de referencia de mamíferos pequeños no convencionales.
///
/// Solo lectura: no guarda registros, no calcula dosis y no se liga a un
/// paciente. Cada valor cita su obra, página y tabla. Cuando dos obras dan
/// rangos distintos se muestran ambos, uno bajo otro: son criterios de
/// profesionales distintos y no se elige entre ellos.
class ExoticsMenu extends StatefulWidget {
  const ExoticsMenu({
    super.key,
    this.allowed = true,
    this.repository,
    this.member,
    this.initialViewDashboard = false,
    this.onNavigate,
    this.tambienPecuario = false,
  });

  /// Resultado del permiso de la pantalla; quien monta el menú lo calcula.
  final bool allowed;

  /// De donde salen los pacientes recientes. Sin el, ese bloque lo dice.
  final ExoticDashboardRepository? repository;

  final ClinicMembership? member;

  /// Si abre directo en el Dashboard en vez de en el panel de consulta.
  final bool initialViewDashboard;

  /// Para saltar a otra seccion. Sin el, el puente entre paneles no se pinta.
  final ValueChanged<String>? onNavigate;

  /// Si esta cuenta tambien trabaja produccion pecuaria.
  ///
  /// Quien lleva las dos areas —una clinica de exoticos que ademas atiende
  /// granja— tenia que volver al menu para cambiar de panel. Con esto salta
  /// de uno a otro directamente, y quien solo tiene un area no ve el enlace.
  final bool tambienPecuario;

  @override
  State<ExoticsMenu> createState() => _ExoticsMenuState();
}

class _ExoticsMenuState extends State<ExoticsMenu> {
  String? species;
  ExoticGroup? group;

  /// Grupo taxonomico elegido en el selector. `null` = todos.
  ExoticTaxon? _taxon;

  /// 0 = panel de consulta, 1 = dashboard. Se comparten el selector de grupo,
  /// asi que cambiar de pestana conserva el grupo elegido.
  late int _viewMode;

  @override
  void initState() {
    super.initState();
    _viewMode = widget.initialViewDashboard ? 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.allowed) {
      return const VetNotice(
        text:
            'Las referencias de exóticos no están habilitadas para tu acceso actual.',
        icon: VetIcons.lock,
        kind: VetBadgeKind.warning,
      );
    }
    // Con una especie abierta se muestra su ficha de referencia y nada mas:
    // la pestana estorbaria porque ya se esta dentro de un detalle.
    if (species != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _detail(context),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('Panel Exóticos'),
                icon: Icon(VetIcons.paw),
              ),
              ButtonSegment(
                value: 1,
                label: Text('Dashboard'),
                icon: Icon(VetIcons.dashboard),
              ),
            ],
            selected: {_viewMode},
            onSelectionChanged: (val) => setState(() => _viewMode = val.first),
          ),
        ),
        if (_viewMode == 1)
          ExoticsDashboard(
            member: widget.member,
            repository: widget.repository,
            initialTaxon: _taxon,
          )
        else
          ..._speciesList(context),
      ],
    );
  }

  /// El Panel Exóticos, en el orden en que se usa de verdad.
  ///
  /// 1) grupo, 2) calculadora de dosis, 3) constantes citadas, 4) manejo,
  /// 5) pacientes recientes, 6) emergencias. La calculadora va la primera y
  /// grande porque es lo que se abre en cada consulta; bajarla obligaria a
  /// desplazarse siempre.
  List<Widget> _speciesList(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final fichas = _taxon == null ? fichasDeManejo : fichasDe(_taxon!);
    // Las referencias citadas solo existen para mamiferos pequenos; en los
    // demas grupos se dice, en vez de ensenar una lista vacia sin explicar.
    final hayReferencias =
        _taxon == null || _taxon == ExoticTaxon.mamiferosPequenos;

    return [
      // ---- 1. Selector por grupo ----
      const VetSectionHeader(
        title: 'Grupo',
        subtitle: 'Filtra el panel por el tipo de paciente.',
      ),
      const SizedBox(height: 10),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            glowChip(
              ChoiceChip(
                label: const Text('Todos'),
                selected: _taxon == null,
                onSelected: (_) => setState(() => _taxon = null),
              ),
            ),
            for (final t in ExoticTaxon.values) ...[
              const SizedBox(width: 8),
              glowChip(
                ChoiceChip(
                  label: Text(t.label),
                  selected: _taxon == t,
                  onSelected: (_) => setState(() => _taxon = t),
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 20),

      // ---- 2. Calculadora de dosis: lo mas grande y arriba ----
      AllometricCalculatorCard(taxonInicial: _taxon),
      const SizedBox(height: 12),
      VetModuleTile(
        title: 'Peso metabólico',
        subtitle: 'Convierte el peso a escala metabólica para comparar especies.',
        icon: VetIcons.scale,
        accent: VetColors.violet,
        onTap: () => Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => const CalculationScreen(
              initialTool: 'metabolic',
              tools: exoticCalculationTools,
              title: 'Peso metabólico en exóticos',
            ),
          ),
        ),
      ),
      const SizedBox(height: 24),

      // ---- 3. Constantes y referencias ----
      const VetSectionHeader(
        title: 'Constantes y referencias',
        subtitle: 'FC, FR, temperatura y hematología, con su obra citada.',
      ),
      const SizedBox(height: 10),
      const VetNotice(
        text:
            'Cada valor cita su obra, página y tabla. Cuando dos obras difieren se muestran ambas; no se elige una.',
        icon: VetIcons.clipboardChecks,
      ),
      const SizedBox(height: 10),
      if (!hayReferencias)
        const VetEmptyState(
          text:
              'Todavía no se han cargado valores citados para este grupo. Los disponibles son de mamíferos pequeños.',
          icon: VetIcons.book,
        )
      else
        for (final name in exoticSpecies)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: VetCard(
              padding: EdgeInsets.zero,
              child: InkWell(
                onTap: () => setState(() {
                  species = name;
                  group = exoticGroupsFor(name).first;
                }),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const VetIconBox(
                        icon: VetIcons.paw,
                        accent: VetColors.turquoise,
                        size: 52,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Text(
                              exoticGroupsFor(
                                name,
                              ).map((g) => g.label).join(' · '),
                              style: textTheme.bodySmall,
                            ),
                            const SizedBox(height: 10),
                            VetStatusBadge(
                              label: exoticWorksFor(name) == 1
                                  ? '1 obra citada'
                                  : '${exoticWorksFor(name)} obras citadas',
                            ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 14),
                        child: Icon(
                          VetIcons.chevronRight,
                          color: VetColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      const SizedBox(height: 12),

      // ---- 4. Manejo ----
      const VetSectionHeader(
        title: 'Manejo',
        subtitle: 'Temperatura, humedad y dieta por especie.',
      ),
      const SizedBox(height: 10),
      const VetNotice(
        text:
            'Rangos orientativos de mantenimiento en cautiverio. Contrástalos con la obra de referencia de la especie antes de indicar un cambio.',
        icon: VetIcons.info,
        kind: VetBadgeKind.unverified,
      ),
      const SizedBox(height: 10),
      if (fichas.isEmpty)
        const VetEmptyState(
          text: 'Aún no hay ficha de manejo para este grupo.',
          icon: VetIcons.leaf,
        )
      else
        for (final f in fichas)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _FichaDeManejo(ficha: f),
          ),
      const SizedBox(height: 12),

      // ---- 5. Pacientes recientes ----
      const VetSectionHeader(
        title: 'Pacientes recientes',
        subtitle: 'Los últimos ejemplares atendidos.',
      ),
      const SizedBox(height: 10),
      _PacientesRecientes(repository: widget.repository, member: widget.member, taxon: _taxon),
      const SizedBox(height: 12),

      // ---- 6. Emergencias ----
      const VetSectionHeader(
        title: 'Emergencias',
        subtitle: 'Protocolos de urgencia por grupo taxonómico.',
      ),
      const SizedBox(height: 10),
      VetCard(
        padding: EdgeInsets.zero,
        radius: 18,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const VetIconBox(
                icon: VetIcons.firstAidKit,
                accent: VetColors.violet,
                size: 40,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Protocolos de urgencia', style: textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      'Estasis en conejo, golpe de calor, prolapso cloacal, retención de huevo.',
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: VetStatusBadge(
                        label: 'Próximamente',
                        kind: VetBadgeKind.unverified,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      if (widget.tambienPecuario && widget.onNavigate != null) ...[
        const SizedBox(height: 4),
        VetCard(
          padding: EdgeInsets.zero,
          radius: 18,
          child: InkWell(
            onTap: () => widget.onNavigate!('Dashboard Pecuario'),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const VetIconBox(
                    icon: VetIcons.barn,
                    accent: VetColors.turquoise,
                    size: 40,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ir al Dashboard Pecuario',
                          style: textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tu cuenta también lleva producción: los lotes y las alertas de granja están allí.',
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Icon(
                      VetIcons.chevronRight,
                      color: VetColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    ];
  }

  List<Widget> _detail(BuildContext context) {
    final name = species!;
    final groups = exoticGroupsFor(name);
    final current = group ?? groups.first;
    final rows = exoticRowsFor(name, current);
    final taxonNote = exoticTaxonNotes[name];
    final textTheme = Theme.of(context).textTheme;

    // Un bloque por parámetro; dentro, una línea por obra que lo da.
    final blocks = <String, List<ExoticReferenceRow>>{};
    for (final r in rows) {
      blocks.putIfAbsent(r.title, () => []).add(r);
    }
    final blockList = blocks.entries.toList();

    return [
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() {
            species = null;
            group = null;
          }),
          icon: const Icon(VetIcons.arrowBack),
          label: const Text('Volver a especies'),
        ),
      ),
      const SizedBox(height: 4),
      VetCard(
        child: Row(
          children: [
            const VetIconBox(
              icon: VetIcons.paw,
              accent: VetColors.turquoise,
              size: 56,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    exoticWorksFor(name) == 1
                        ? '1 obra citada'
                        : '${exoticWorksFor(name)} obras citadas',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      VetCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sección', style: textTheme.titleSmall),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (i, g) in groups.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    glowChip(
                      ChoiceChip(
                        label: Text(g.label),
                        selected: g == current,
                        onSelected: (_) => setState(() => group = g),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      const VetNotice(
        text:
            'Cada valor cita su obra, página y tabla. Cuando dos obras difieren se muestran ambas; no se elige una.',
        icon: VetIcons.clipboardChecks,
      ),
      if (taxonNote != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: VetNotice(text: taxonNote, icon: VetIcons.clipboardChecks),
        ),
      if (rows.any((r) => r.flagged))
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: VetNotice(
            text:
                'La transcripción marca algunos valores como altos: corrobora valor y unidad contra la página de la obra.',
            icon: VetIcons.clock,
            kind: VetBadgeKind.warning,
          ),
        ),
      const SizedBox(height: 16),
      VetCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < blockList.length; i++) ...[
              if (i > 0) const Divider(height: 24),
              _ReferenceBlock(
                title: blockList[i].key,
                entries: blockList[i].value,
              ),
            ],
          ],
        ),
      ),
      // Deja libre el botón flotante del escáner.
      const SizedBox(height: 96),
    ];
  }
}

class _ReferenceBlock extends StatelessWidget {
  const _ReferenceBlock({required this.title, required this.entries});
  final String title;
  final List<ExoticReferenceRow> entries;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.range, style: textTheme.bodyLarge),
                const SizedBox(height: 2),
                Text(e.caption, style: textTheme.bodySmall),
                if (e.note != null) ...[
                  const SizedBox(height: 2),
                  Text(e.note!, style: textTheme.bodySmall),
                ],
                if (e.flagged)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: VetStatusBadge(
                      label: 'Corroborar valor y unidad',
                      kind: VetBadgeKind.warning,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Ficha rápida de manejo de una especie, plegable.
///
/// Va plegada por omisión: con catorce especies abiertas el panel sería una
/// pared de texto y lo que se busca es la de un paciente concreto.
class _FichaDeManejo extends StatefulWidget {
  const _FichaDeManejo({required this.ficha});
  final HusbandrySheet ficha;

  @override
  State<_FichaDeManejo> createState() => _FichaDeManejoState();
}

class _FichaDeManejoState extends State<_FichaDeManejo> {
  bool abierta = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.ficha;
    final textTheme = Theme.of(context).textTheme;
    return VetCard(
      padding: EdgeInsets.zero,
      radius: 18,
      child: InkWell(
        onTap: () => setState(() => abierta = !abierta),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(f.especie, style: textTheme.titleSmall),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    abierta ? VetIcons.arrowUp : VetIcons.arrowDown,
                    size: 18,
                    color: VetColors.muted,
                  ),
                ],
              ),
              if (abierta) ...[
                const SizedBox(height: 10),
                _dato(context, VetIcons.thermometer, 'Temperatura', f.temperatura),
                _dato(context, VetIcons.drop, 'Humedad', f.humedad),
                if (f.uv.isNotEmpty) _dato(context, VetIcons.sun, 'UV', f.uv),
                if (f.agua.isNotEmpty)
                  _dato(context, VetIcons.waves, 'Agua', f.agua),
                _dato(context, VetIcons.bowlPaw, 'Dieta', f.dieta),
                if (f.advertencia.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        VetIcons.alertTriangle,
                        size: 15,
                        color: VetColors.warning,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          f.advertencia,
                          style: textTheme.bodySmall?.copyWith(
                            color: VetColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _dato(
    BuildContext context,
    IconData icono,
    String rotulo,
    String valor,
  ) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 15, color: VetColors.muted),
          const SizedBox(width: 8),
          // El rotulo y el valor van en columna, no en fila: a 360 dp un
          // "Temperatura" mas el gradiente completo no caben en una linea.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rotulo,
                  style: textTheme.labelSmall?.copyWith(
                    color: VetColors.muted,
                  ),
                ),
                Text(valor, style: textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Los últimos ejemplares atendidos, leídos del expediente real.
///
/// Si no hay repositorio o no hay pacientes, lo dice: no se rellena con una
/// lista de muestra que el usuario pueda confundir con los suyos.
class _PacientesRecientes extends StatefulWidget {
  const _PacientesRecientes({
    required this.repository,
    required this.member,
    required this.taxon,
  });

  final ExoticDashboardRepository? repository;
  final ClinicMembership? member;
  final ExoticTaxon? taxon;

  @override
  State<_PacientesRecientes> createState() => _PacientesRecientesState();
}

class _PacientesRecientesState extends State<_PacientesRecientes> {
  ExoticSnapshot? datos;
  bool cargando = true;
  Object? fallo;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    // Igual que en el dashboard: se cede el turno para no llamar a setState
    // mientras el widget todavia se monta.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    final repo = widget.repository;
    final clinicId = widget.member?.clinicId;
    if (repo == null || clinicId == null || clinicId.isEmpty) {
      setState(() {
        datos = const ExoticSnapshot();
        cargando = false;
      });
      return;
    }
    try {
      final leido = await repo.load(clinicId);
      if (!mounted) return;
      setState(() {
        datos = leido;
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        fallo = e;
        cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const VetCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (fallo != null) {
      return VetCard(
        child: Column(
          children: [
            const Text(
              'No se pudieron leer los pacientes. Revisa la conexión.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: VetColors.muted),
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: _cargar,
              icon: const Icon(VetIcons.refresh, size: 16),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    final lista = (datos ?? const ExoticSnapshot()).delTaxon(widget.taxon);
    if (lista.isEmpty) {
      return const VetCard(
        child: VetEmptyState(
          text: 'Todavía no hay ejemplares registrados para este grupo.',
          icon: VetIcons.paw,
        ),
      );
    }
    return VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in lista.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
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
      ),
    );
  }
}

/// El panel de reproducción.
///
/// Es una sola pantalla que sirve a los dos módulos, porque los datos son los
/// mismos. Lo único que cambia es desde dónde se abre y si viene acotada a un
/// lote de producción.
///
/// Lo que enseña primero es lo que de verdad hace falta decidir hoy: las
/// hembras que debieron parir y siguen abiertas. Una vaca que debió parir
/// hace cinco días y sigue «en curso» es o un parto sin registrar o un
/// problema, y en ambos casos es lo primero que alguien tiene que mirar.
library;

import 'package:flutter/material.dart';

import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_icons.dart';
import '../../../vet_ui/vet_theme.dart';
import '../../auth/domain/clinic_membership.dart';
import '../domain/gestation.dart';
import '../domain/gestation_write_repository.dart';
import 'gestation_capture_forms.dart';

class GestationPanel extends StatefulWidget {
  const GestationPanel({
    super.key,
    this.member,
    this.repository,
    this.writeRepository,
    this.loteId,
    this.nombreDelLote,
    this.titulo = 'Reproducción',
  });

  final ClinicMembership? member;
  final GestationRepository? repository;
  final GestationWriteRepository? writeRepository;

  /// Si viene, el panel solo muestra las gestaciones de ese lote y las altas
  /// quedan vinculadas a él.
  final String? loteId;
  final String? nombreDelLote;
  final String titulo;

  @override
  State<GestationPanel> createState() => _GestationPanelState();
}

class _GestationPanelState extends State<GestationPanel> {
  GestationSnapshot? _datos;
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
        _datos = const GestationSnapshot();
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

  bool get _puedeCapturar =>
      widget.writeRepository != null &&
      (widget.member?.clinicId.isNotEmpty ?? false) &&
      puedeCapturarGestacion(widget.member);

  /// Las gestaciones que este panel debe mostrar, acotadas al lote si lo hay.
  GestationSnapshot get _vista {
    final d = _datos ?? const GestationSnapshot();
    final lote = widget.loteId;
    if (lote == null) return d;
    return GestationSnapshot(
      gestaciones: d.deLote(lote),
      catalogo: d.catalogo,
      nombresDePaciente: d.nombresDePaciente,
    );
  }

  String _nombre(Gestation g) =>
      _vista.nombresDePaciente[g.patientId] ?? 'Hembra sin nombre';

  Future<void> _trasGuardar(bool guardado, String mensaje) async {
    if (!guardado || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
    await _cargar();
  }

  Future<void> _nueva() async {
    final repo = widget.writeRepository;
    final clinicId = widget.member?.clinicId;
    if (repo == null || clinicId == null) return;
    final ok = await capturarGestacion(
      context,
      clinicId: clinicId,
      repo: repo,
      catalogo: _vista.catalogo,
      loteId: widget.loteId,
      nombreDelLote: widget.nombreDelLote,
    );
    await _trasGuardar(ok, 'Gestación registrada');
  }

  Future<void> _editar(Gestation g) async {
    final repo = widget.writeRepository;
    final clinicId = widget.member?.clinicId;
    if (repo == null || clinicId == null) return;
    final ok = await capturarGestacion(
      context,
      clinicId: clinicId,
      repo: repo,
      catalogo: _vista.catalogo,
      inicial: g,
    );
    await _trasGuardar(ok, 'Gestación actualizada');
  }

  Future<void> _cerrar(Gestation g) async {
    final repo = widget.writeRepository;
    final clinicId = widget.member?.clinicId;
    if (repo == null || clinicId == null) return;
    final ok = await cerrarGestacion(
      context,
      clinicId: clinicId,
      repo: repo,
      gestacion: g,
      nombreDeLaHembra: _nombre(g),
    );
    await _trasGuardar(ok, 'Gestación cerrada');
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_fallo != null) {
      return VetCard(
        child: Column(
          children: [
            const Icon(VetIcons.cloudOff, size: 28, color: VetColors.muted),
            const SizedBox(height: 8),
            const Text(
              'No se pudieron leer las gestaciones',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              'Revisa la conexión. Esto no significa que no haya ninguna: no '
              'se alcanzó el servidor.',
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
      );
    }

    final ahora = DateTime.now();
    final vista = _vista;
    final abiertas = vista.abiertas();
    final vencidas = vista.vencidas(ahora);
    final proximas = vista.proximas(ahora);
    final cerradas = vista.gestaciones
        .where((g) => !g.estado.abierta)
        .toList()
      ..sort((a, b) => b.servicio.compareTo(a.servicio));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_puedeCapturar) ...[
          VetActionButton(
            label: 'Nueva gestación',
            icon: VetIcons.heart,
            onPressed: _nueva,
          ),
          const SizedBox(height: 16),
        ],

        if (vista.sinDatos)
          _vacio()
        else ...[
          _resumen(abiertas.length, vencidas.length, proximas.length),
          const SizedBox(height: 16),

          if (vencidas.isNotEmpty) ...[
            const VetSectionHeader(
              title: 'Ya debieron parir',
              subtitle:
                  'Pasó la fecha prevista y siguen abiertas. O falta '
                  'registrar el parto, o hay que revisarlas.',
            ),
            for (final g in vencidas) _tarjeta(g, ahora, urgente: true),
            const SizedBox(height: 16),
          ],

          if (proximas.isNotEmpty) ...[
            const VetSectionHeader(
              title: 'Paren en los próximos 30 días',
            ),
            for (final g in proximas) _tarjeta(g, ahora),
            const SizedBox(height: 16),
          ],

          if (abiertas.length > vencidas.length + proximas.length) ...[
            const VetSectionHeader(title: 'Resto de gestaciones abiertas'),
            for (final g in abiertas)
              if (!vencidas.contains(g) && !proximas.contains(g))
                _tarjeta(g, ahora),
            const SizedBox(height: 16),
          ],

          if (cerradas.isNotEmpty) ...[
            const VetSectionHeader(title: 'Cerradas'),
            for (final g in cerradas.take(20)) _tarjeta(g, ahora),
          ],
        ],
      ],
    );
  }

  Widget _vacio() => VetCard(
    child: Column(
      children: [
        const Icon(VetIcons.heart, size: 30, color: VetColors.muted),
        const SizedBox(height: 10),
        Text(
          widget.loteId == null
              ? 'Todavía no hay gestaciones registradas'
              : 'Este lote no tiene gestaciones registradas',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 6),
        Text(
          _puedeCapturar
              ? 'Registra el servicio de una hembra y aquí irá apareciendo su '
                    'fecha probable de parto y el aviso cuando se acerque.'
              : 'Tu rol no registra reproducción. Lo pueden hacer '
                    'administrador, MVZ y auxiliar.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: VetColors.muted),
        ),
      ],
    ),
  );

  Widget _resumen(int abiertas, int vencidas, int proximas) => Row(
    children: [
      Expanded(child: _kpi('Abiertas', '$abiertas', VetColors.turquoise)),
      const SizedBox(width: 10),
      Expanded(child: _kpi('Próximas', '$proximas', VetColors.violet)),
      const SizedBox(width: 10),
      Expanded(
        child: _kpi(
          'Vencidas',
          '$vencidas',
          vencidas > 0 ? VetColors.danger : VetColors.muted,
        ),
      ),
    ],
  );

  Widget _kpi(String titulo, String valor, Color color) => VetCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(fontSize: 11, color: VetColors.muted),
        ),
        const SizedBox(height: 4),
        Text(
          valor,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    ),
  );

  Widget _tarjeta(Gestation g, DateTime ahora, {bool urgente = false}) {
    final dias = g.diasParaParto(ahora);
    final abierta = g.estado.abierta;

    // La frase de la cuenta regresiva se arma aqui para que diga siempre algo
    // cierto: sin dias de gestacion no hay prevision, y se dice.
    final String cuenta;
    if (!abierta) {
      cuenta = g.estado.label;
    } else if (dias == null) {
      cuenta = 'Sin fecha prevista';
    } else if (dias < 0) {
      cuenta = 'Debió parir hace ${-dias} ${-dias == 1 ? "día" : "días"}';
    } else if (dias == 0) {
      cuenta = 'Pare hoy';
    } else {
      cuenta = 'Faltan $dias ${dias == 1 ? "día" : "días"}';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: VetCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                VetIconBox(
                  icon: abierta ? VetIcons.heart : VetIcons.checkCircle,
                  accent: urgente ? VetColors.danger : VetColors.turquoise,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nombre(g),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${g.especie} · ${g.metodo.label}',
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
            const SizedBox(height: 10),
            // Wrap y no Row: en un telefono de 360 dp tres insignias en linea
            // se desbordan.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                VetStatusBadge(
                  label: cuenta,
                  kind: !abierta
                      ? VetBadgeKind.unverified
                      : urgente
                      ? VetBadgeKind.danger
                      : VetBadgeKind.information,
                ),
                VetStatusBadge(
                  label: g.diagnostico.label,
                  kind: switch (g.diagnostico) {
                    PregnancyCheck.gestante => VetBadgeKind.success,
                    PregnancyCheck.vacia => VetBadgeKind.warning,
                    PregnancyCheck.dudosa => VetBadgeKind.warning,
                    PregnancyCheck.pendiente => VetBadgeKind.unverified,
                  },
                ),
                if (g.criasTotales != null)
                  VetStatusBadge(
                    label: '${g.criasVivas ?? 0} vivas'
                        '${(g.criasMuertas ?? 0) > 0 ? ", ${g.criasMuertas} muertas" : ""}',
                    kind: VetBadgeKind.information,
                  ),
              ],
            ),
            if (_puedeCapturar) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (abierta)
                    VetSecondaryButton(
                      label: 'Cerrar',
                      icon: VetIcons.checkCircle,
                      onPressed: () => _cerrar(g),
                    ),
                  VetSecondaryButton(
                    label: 'Editar',
                    icon: VetIcons.pencil,
                    onPressed: () => _editar(g),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

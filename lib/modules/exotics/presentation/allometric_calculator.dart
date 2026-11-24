import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_icons.dart';
import '../../../vet_ui/vet_theme.dart';
import '../domain/exotic_taxon.dart';

/// Calculadora alométrica y de fluidoterapia para exóticos.
///
/// Va grande y arriba porque es lo que más se usa. Hace tres cosas que en
/// exóticos no se pueden hacer de cabeza:
///
///   1. escalar una dosis conocida de una especie a otra por metabolismo,
///      no por regla de tres sobre el peso;
///   2. decir qué volumen hay que cargar y con qué jeringa, proponiendo una
///      dilución cuando el volumen es impracticable;
///   3. dar el mantenimiento hídrico diario del grupo taxonómico.
///
/// Todo lo que calcula se muestra con sus supuestos a la vista: el clínico
/// tiene que poder auditar el número antes de pinchar al ejemplar.
class AllometricCalculatorCard extends StatefulWidget {
  const AllometricCalculatorCard({super.key, this.taxonInicial});

  final ExoticTaxon? taxonInicial;

  @override
  State<AllometricCalculatorCard> createState() =>
      _AllometricCalculatorCardState();
}

class _AllometricCalculatorCardState extends State<AllometricCalculatorCard> {
  final _dosis = TextEditingController();
  final _pesoModelo = TextEditingController();
  final _pesoDestino = TextEditingController();
  final _concentracion = TextEditingController();

  ExoticTaxon _taxonModelo = ExoticTaxon.mamiferosPequenos;
  ExoticTaxon _taxonDestino = ExoticTaxon.aves;
  MetabolicConstant? _kModelo;
  MetabolicConstant? _kDestino;

  @override
  void initState() {
    super.initState();
    if (widget.taxonInicial != null) _taxonDestino = widget.taxonInicial!;
    _kModelo = constantesDe(_taxonModelo).first;
    _kDestino = constantesDe(_taxonDestino).first;
  }

  @override
  void dispose() {
    _dosis.dispose();
    _pesoModelo.dispose();
    _pesoDestino.dispose();
    _concentracion.dispose();
    super.dispose();
  }

  /// Los pesos se piden en gramos porque es como se pesa a un exótico, y se
  /// pasan a kilos solo para entrar en la fórmula.
  double? _kg(TextEditingController c) {
    final g = double.tryParse(c.text.trim().replaceAll(',', '.'));
    return (g == null || g <= 0) ? null : g / 1000;
  }

  @override
  Widget build(BuildContext context) {
    final dosis = double.tryParse(_dosis.text.trim().replaceAll(',', '.'));
    final pesoModeloKg = _kg(_pesoModelo);
    final pesoDestinoKg = _kg(_pesoDestino);
    final conc = double.tryParse(
      _concentracion.text.trim().replaceAll(',', '.'),
    );

    AllometricResult? resultado;
    if (dosis != null &&
        dosis > 0 &&
        pesoModeloKg != null &&
        pesoDestinoKg != null &&
        _kModelo != null &&
        _kDestino != null) {
      resultado = escalarDosis(
        dosisModeloMgKg: dosis,
        pesoModeloKg: pesoModeloKg,
        kModelo: _kModelo!.k,
        pesoDestinoKg: pesoDestinoKg,
        kDestino: _kDestino!.k,
      );
    }

    MicroVolume? volumen;
    if (resultado != null && conc != null && conc > 0) {
      volumen = calcularMicroVolumen(
        dosisMg: resultado.dosisDestinoMg,
        concentracionMgMl: conc,
      );
    }

    final mantenimiento = pesoDestinoKg == null
        ? null
        : mantenimientoDiario(taxon: _taxonDestino, pesoKg: pesoDestinoKg);

    return VetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                VetIcons.calculator,
                size: 22,
                color: VetColors.turquoise,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Calculadora alométrica y de fluidoterapia',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'Escala la dosis por energía metabólica, no por peso: la regla de '
            'tres sobredosifica a los pequeños.',
            style: TextStyle(fontSize: 12, color: VetColors.muted),
          ),
          const SizedBox(height: 14),

          _rotulo('Especie de la que se conoce la dosis'),
          const SizedBox(height: 6),
          _selectorTaxon(
            valor: _taxonModelo,
            alCambiar: (t) => setState(() {
              _taxonModelo = t;
              _kModelo = constantesDe(t).first;
            }),
          ),
          const SizedBox(height: 8),
          _selectorConstante(
            opciones: constantesDe(_taxonModelo),
            valor: _kModelo,
            alCambiar: (c) => setState(() => _kModelo = c),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _campo(_dosis, 'Dosis conocida', sufijo: 'mg/kg'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _campo(_pesoModelo, 'Peso del modelo', sufijo: 'g'),
              ),
            ],
          ),

          const SizedBox(height: 16),
          _rotulo('Ejemplar que se va a tratar'),
          const SizedBox(height: 6),
          _selectorTaxon(
            valor: _taxonDestino,
            alCambiar: (t) => setState(() {
              _taxonDestino = t;
              _kDestino = constantesDe(t).first;
            }),
          ),
          const SizedBox(height: 8),
          _selectorConstante(
            opciones: constantesDe(_taxonDestino),
            valor: _kDestino,
            alCambiar: (c) => setState(() => _kDestino = c),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _campo(_pesoDestino, 'Peso del ejemplar', sufijo: 'g'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _campo(_concentracion, 'Concentración', sufijo: 'mg/mL'),
              ),
            ],
          ),

          const SizedBox(height: 16),
          if (resultado == null)
            const VetEmptyState(
              text: 'Escribe la dosis y los dos pesos para ver el resultado.',
              icon: VetIcons.mathOps,
            )
          else
            _resultado(resultado, volumen, pesoDestinoKg!),

          if (mantenimiento != null) ...[
            const SizedBox(height: 12),
            _mantenimiento(mantenimiento),
          ],

          const SizedBox(height: 12),
          const Text(
            'El escalamiento metabólico orienta la dosis de partida; no '
            'sustituye la dosis publicada para la especie cuando existe.',
            style: TextStyle(fontSize: 12, color: VetColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _rotulo(String t) => Text(
    t,
    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
  );

  Widget _selectorTaxon({
    required ExoticTaxon valor,
    required ValueChanged<ExoticTaxon> alCambiar,
  }) {
    return DropdownButtonFormField<ExoticTaxon>(
      initialValue: valor,
      isExpanded: true,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
      ),
      items: [
        for (final t in ExoticTaxon.values)
          DropdownMenuItem(
            value: t,
            child: Text(t.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (t) {
        if (t != null) alCambiar(t);
      },
    );
  }

  Widget _selectorConstante({
    required List<MetabolicConstant> opciones,
    required MetabolicConstant? valor,
    required ValueChanged<MetabolicConstant> alCambiar,
  }) {
    // Con una sola opción el desplegable estorba: se muestra el dato y ya.
    if (opciones.length == 1) {
      final c = opciones.first;
      return Text(
        'K = ${c.k.toStringAsFixed(0)} kcal/día · ${c.detalle}',
        style: const TextStyle(fontSize: 12, color: VetColors.muted),
      );
    }
    return DropdownButtonFormField<MetabolicConstant>(
      initialValue: opciones.contains(valor) ? valor : opciones.first,
      isExpanded: true,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
      ),
      items: [
        for (final c in opciones)
          DropdownMenuItem(
            value: c,
            child: Text(
              'K ${c.k.toStringAsFixed(0)} · ${c.detalle}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (c) {
        if (c != null) alCambiar(c);
      },
    );
  }

  Widget _campo(
    TextEditingController c,
    String etiqueta, {
    required String sufijo,
  }) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: etiqueta,
        suffixText: sufijo,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _resultado(AllometricResult r, MicroVolume? v, double pesoDestinoKg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VetColors.turquoise.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(VetSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dosis para el ejemplar',
            style: TextStyle(fontSize: 12, color: VetColors.muted),
          ),
          const SizedBox(height: 2),
          Text(
            '${_mg(r.dosisDestinoMg)} mg',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
          ),
          Text(
            'equivale a ${r.dosisDestinoMgKg(pesoDestinoKg).toStringAsFixed(2)} '
            'mg/kg en esta especie',
            style: const TextStyle(fontSize: 12, color: VetColors.muted),
          ),
          const SizedBox(height: 10),
          _linea(
            'TMB del modelo',
            '${r.tmbModelo.toStringAsFixed(2)} kcal/día',
          ),
          _linea(
            'TMB del ejemplar',
            '${r.tmbDestino.toStringAsFixed(2)} kcal/día',
          ),
          _linea('Por kcal basal', '${_mg(r.mgPorKcal)} mg'),
          if (v != null) ...[
            const Divider(height: 18),
            const Text(
              'Volumen a cargar',
              style: TextStyle(fontSize: 12, color: VetColors.muted),
            ),
            const SizedBox(height: 2),
            Text(
              '${v.mlConDilucion.toStringAsFixed(2)} mL',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 2),
            Text(
              v.jeringaSugerida,
              style: const TextStyle(fontSize: 12, color: VetColors.muted),
            ),
            if (v.receta.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Para prepararlo, en pasos de 1 + 9:',
                style: TextStyle(fontSize: 12, color: VetColors.muted),
              ),
              const SizedBox(height: 2),
              for (var i = 0; i < v.receta.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    'Paso ${i + 1}: ${v.receta[i].producto.toStringAsFixed(1)} mL '
                    'de ${v.receta[i].esPrimero ? 'producto' : 'la mezcla anterior'}'
                    ' + ${v.receta[i].diluyente.toStringAsFixed(1)} mL de '
                    'diluyente → ${_mg(v.receta[i].concentracion)} mg/mL',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              Text(
                'De la última mezcla carga '
                '${v.mlConDilucion.toStringAsFixed(2)} mL, que son '
                '${_mg(v.concentracionFinal)} mg/mL.',
                style: const TextStyle(fontSize: 12),
              ),
            ],
            if (v.avisa != null) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    VetIcons.alertTriangle,
                    size: 14,
                    color: VetColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      v.avisa!,
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
        ],
      ),
    );
  }

  Widget _mantenimiento(({double min, double max}) m) {
    final tasa = tasaDe(_taxonDestino);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VetColors.brandSky.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(VetSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mantenimiento hídrico diario',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            '${m.min.toStringAsFixed(1)} - ${m.max.toStringAsFixed(1)} mL/día',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          if (tasa != null) ...[
            const SizedBox(height: 2),
            Text(
              '${tasa.rango} · ${tasa.nota}',
              style: const TextStyle(fontSize: 12, color: VetColors.muted),
            ),
          ],
          const SizedBox(height: 4),
          const Text(
            'Se muestra el rango completo a propósito: elegir el punto exacto '
            'es decisión clínica, no del cálculo.',
            style: TextStyle(fontSize: 12, color: VetColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _linea(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            k,
            style: const TextStyle(fontSize: 12, color: VetColors.muted),
          ),
        ),
        const SizedBox(width: 8),
        Text(v, style: const TextStyle(fontSize: 12)),
      ],
    ),
  );

  /// Los mg de un exótico son cifras diminutas: con dos decimales un 0.004 se
  /// vería como 0.00, así que se da más precisión cuando el número es pequeño.
  String _mg(double v) {
    if (v >= 100) return v.toStringAsFixed(1);
    if (v >= 1) return v.toStringAsFixed(2);
    if (v >= 0.01) return v.toStringAsFixed(3);
    return v.toStringAsFixed(5);
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../domain/manufacturer_pauta.dart';

/// Ficha de una pauta documentada por el fabricante.
///
/// El texto literal manda. La regla estructurada solo se usa para decidir si la
/// calculadora proporcional puede precargarse; nunca para reescribir la dosis.
class ManufacturerPautaCard extends StatelessWidget {
  const ManufacturerPautaCard({super.key, required this.pauta});
  final ManufacturerPauta pauta;

  String get _ruleNote => switch (pauta.rule) {
    PautaRule.proportionalToWeight => 'Proporcional al peso',
    PautaRule.fixedPerAnimal =>
      'Dosis fija por animal: no usar la calculadora proporcional.',
    PautaRule.weightBands =>
      'Bandas de peso: requiere su propia tabla, no es proporcional.',
    PautaRule.waterFeed =>
      'Va en agua o alimento: requiere la regla de consumo.',
    PautaRule.vaccination =>
      'Esquema vacunal: no es una dosis proporcional simple.',
    PautaRule.other => 'Regla especial: revisa el texto literal.',
    PautaRule.unspecified => 'La fuente no clasifica la regla.',
  };

  /// Indica a qué calculadora pertenece la pauta. El nombre comercial y la
  /// posología del empaque van a la calculadora de empaque; la dosis en masa
  /// por kg (mg/kg) va a la calculadora por agente farmacéutico.
  String get _calculatorNote {
    if (pauta.rule != PautaRule.proportionalToWeight) {
      return 'Calculadora: no aplica (la regla no es proporcional al peso).';
    }
    return switch (pauta.calculator) {
      PautaCalculator.package =>
        'Calculadora: dosis de empaque (volumen, tableta o sobre por kg).',
      PautaCalculator.agent =>
        'Calculadora: agente farmacéutico (dosis en mg/kg).',
      null =>
        'Calculadora: la unidad no permite una regla proporcional fiable.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ref = pauta.weightReference;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(pauta.presentation, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Especie: ${pauta.species}'),
            if (pauta.route.isNotEmpty) Text('Vía: ${pauta.route}'),
            if (pauta.ingredients.isNotEmpty)
              Text('Principios activos: ${pauta.ingredients}'),
            const SizedBox(height: 8),
            Text('Posología literal', style: theme.textTheme.labelLarge),
            SelectableText(pauta.literal),
            const SizedBox(height: 8),
            if (ref != null)
              Text('Referencia: ${ref.amount} ${ref.unit} ${ref.text}')
            else if (pauta.doseReference.isNotEmpty)
              Text('Referencia: ${pauta.doseReference}'),
            Text(_ruleNote, style: theme.textTheme.bodySmall),
            Text(_calculatorNote, style: theme.textTheme.bodySmall),
            if (pauta.interval.isNotEmpty) Text('Intervalo: ${pauta.interval}'),
            if (pauta.duration.isNotEmpty) Text('Duración: ${pauta.duration}'),
            if (pauta.withdrawal.isNotEmpty)
              Text('Retiro: ${pauta.withdrawal}'),
            if (pauta.contraindications.isNotEmpty)
              Text('Contraindicaciones: ${pauta.contraindications}'),
            if (pauta.discrepancies.isNotEmpty &&
                pauta.discrepancies.toLowerCase() != 'ninguna')
              Text('Discrepancias: ${pauta.discrepancies}'),
            const SizedBox(height: 6),
            Text(
              'Estado: ${pauta.state} · sin verificar en la clínica',
              style: theme.textTheme.bodySmall,
            ),
            if (pauta.warnings.isNotEmpty)
              Text(
                'Revisar integridad: ${pauta.warnings.join(' · ')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            if (pauta.evidenceUrl.isNotEmpty)
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(pauta.evidenceUrl),
                  mode: LaunchMode.externalApplication,
                ),
                child: const Text('Abrir fuente de la pauta'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Lista de pautas del producto. Si no hay ninguna, avisa sin inventar nada.
class ManufacturerPautaSection extends StatelessWidget {
  const ManufacturerPautaSection({super.key, required this.pautas});
  final List<ManufacturerPauta> pautas;

  @override
  Widget build(BuildContext context) {
    if (pautas.isEmpty) {
      return const Text(
        'Sin pauta estructurada para esta ficha. Usa la posología del empaque.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${pautas.length} pauta(s) documentada(s) por el fabricante',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Text(
          'Datos de investigación (Grok) aún sin validación clínica en la clínica. '
          'El texto literal es la fuente; la calculadora solo precarga reglas proporcionales al peso.',
        ),
        const SizedBox(height: 8),
        for (final pauta in pautas) ManufacturerPautaCard(pauta: pauta),
      ],
    );
  }
}

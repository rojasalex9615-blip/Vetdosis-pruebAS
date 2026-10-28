import '../../../core/widgets/workspace_panel.dart';
import '../../../core/widgets/neu_identity.dart';
import '../../../core/widgets/neu_header_card.dart';
import '../../../core/widgets/calculator_surface.dart';
import 'package:flutter/material.dart';
import '../domain/quantity.dart';

enum DoseMathMode {
  concentration('Volumen desde dosis y concentración'),
  ruleOfThree('Regla de tres por peso'),
  internationalUnits('Unidades internacionales tras reconstitución'),
  conversion('Conversión métrica');

  const DoseMathMode(this.label);
  final String label;
}

/// Arithmetic helpers only. All clinical inputs are supplied by the clinician.
class DoseMathTools extends StatefulWidget {
  const DoseMathTools({
    super.key,
    this.onChoosePatient,
    this.visualReference = false,
  });

  /// Shared cushioned family; enabled by the app when neumorphic style is selected.
  final bool visualReference;
  final Future<void> Function()? onChoosePatient;

  @override
  State<DoseMathTools> createState() => _DoseMathToolsState();
}

class _DoseMathToolsState extends State<DoseMathTools> {
  final _controllers = <String, TextEditingController>{
    for (final key in [
      'weight',
      'dose',
      'concentration',
      'baselineVolume',
      'baselineWeight',
      'totalUnits',
      'finalVolume',
      'unitsPerKg',
      'amount',
    ])
      key: TextEditingController(),
  };
  DoseMathMode mode = DoseMathMode.concentration;
  bool get referenceStyle => widget.visualReference;
  String fromUnit = 'kg';
  String toUnit = 'g';
  String? result;
  String? formula;
  String? concentrationDetail;
  String? error;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Quantity _positive(String key, String label) {
    final value = Quantity.parse(_controllers[key]!.text);
    if (!value.positive) {
      throw FormatException('$label debe ser mayor que cero.');
    }
    return value;
  }

  void calculate() {
    setState(() {
      result = null;
      formula = null;
      concentrationDetail = null;
      error = null;
    });
    try {
      late Quantity value;
      late String answer;
      late String equation;
      switch (mode) {
        case DoseMathMode.concentration:
          final weight = _positive('weight', 'Peso');
          final dose = _positive('dose', 'Dosis indicada');
          final concentration = _positive('concentration', 'Concentración');
          value = weight * dose / concentration;
          answer = '${value.display()} mL';
          equation =
              '${weight.display()} kg × ${dose.display()} mg/kg ÷ ${concentration.display()} mg/mL';
        case DoseMathMode.ruleOfThree:
          final targetWeight = _positive('weight', 'Peso del paciente');
          final baselineWeight = _positive(
            'baselineWeight',
            'Peso de referencia',
          );
          final baselineVolume = _positive(
            'baselineVolume',
            'Volumen de referencia',
          );
          value = baselineVolume * targetWeight / baselineWeight;
          answer = '${value.display()} mL';
          equation =
              '${baselineVolume.display()} mL ÷ ${baselineWeight.display()} kg × ${targetWeight.display()} kg';
        case DoseMathMode.internationalUnits:
          final weight = _positive('weight', 'Peso');
          final dose = _positive('unitsPerKg', 'Dosis indicada');
          final totalUnits = _positive('totalUnits', 'UI totales del frasco');
          final finalVolume = _positive(
            'finalVolume',
            'Volumen final reconstituido',
          );
          final concentration = totalUnits / finalVolume;
          value = weight * dose / concentration;
          answer = '${value.display()} mL';
          equation =
              '${weight.display()} kg × ${dose.display()} UI/kg ÷ (${totalUnits.display()} UI ÷ ${finalVolume.display()} mL)';
          concentrationDetail =
              'Concentración reconstituida: ${concentration.display()} UI/mL';
        case DoseMathMode.conversion:
          final amount = _positive('amount', 'Cantidad');
          final from = _unitFactor(fromUnit);
          final to = _unitFactor(toUnit);
          if (from.dimension != to.dimension) {
            throw const FormatException(
              'Elige unidades de la misma dimensión.',
            );
          }
          value = amount * from.factor / to.factor;
          answer = '${value.display()} $toUnit';
          equation = '${amount.display()} $fromUnit → $toUnit';
      }
      setState(() {
        result = answer;
        formula = equation;
      });
    } on FormatException catch (e) {
      setState(() => error = e.message);
    }
  }

  ({Quantity factor, String dimension}) _unitFactor(String unit) =>
      switch (unit) {
        'kg' => (factor: Quantity.parse('1000000'), dimension: 'masa'),
        'g' => (factor: Quantity.parse('1000'), dimension: 'masa'),
        'mg' => (factor: Quantity.parse('1'), dimension: 'masa'),
        'L' => (factor: Quantity.parse('1000'), dimension: 'volumen'),
        'mL' || 'cc' => (factor: Quantity.parse('1'), dimension: 'volumen'),
        _ => throw const FormatException('Unidad no disponible.'),
      };

  Widget _field(String key, String label) {
    void change(String _) => setState(() {
      result = null;
      formula = null;
      concentrationDetail = null;
      error = null;
    });
    if (!referenceStyle) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          key: ValueKey(key),
          controller: _controllers[key],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: label,
            helperText: calculatorUnitHint(label),
            helperMaxLines: 3,
            border: const OutlineInputBorder(),
          ),
          onChanged: change,
        ),
      );
    }
    final unit = RegExp(r'\(([^)]+)\)').firstMatch(label)?.group(1);
    return Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
              child: Text(
                label.replaceFirst(RegExp(r'\s*\([^)]+\)'), ''),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Semantics(
              label: label,
              child: TextField(
                key: ValueKey(key),
                controller: _controllers[key],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: '0,00',
                  suffixText: unit,
                  suffixStyle: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 12),
                ),
                onChanged: change,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _inputs() => switch (mode) {
    DoseMathMode.concentration => [
      _field('weight', 'Peso (kg)'),
      _field('dose', 'Dosis indicada por el MVZ (mg/kg)'),
      _field('concentration', 'Concentración (mg/mL)'),
    ],
    DoseMathMode.ruleOfThree => [
      _field('baselineVolume', 'Volumen indicado de referencia (mL)'),
      _field('baselineWeight', 'Peso de referencia (kg)'),
      _field('weight', 'Peso del paciente (kg)'),
    ],
    DoseMathMode.internationalUnits => [
      _field('totalUnits', 'UI totales declaradas en el frasco'),
      _field('finalVolume', 'Volumen final tras reconstituir (mL)'),
      _field('weight', 'Peso del paciente (kg)'),
      _field('unitsPerKg', 'Dosis indicada por el MVZ (UI/kg)'),
    ],
    DoseMathMode.conversion => [
      _field('amount', 'Cantidad'),
      Row(
        children: [
          Expanded(
            child: _unitPicker(
              fromUnit,
              (value) => setState(() => fromUnit = value),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward),
          ),
          Expanded(
            child: _unitPicker(
              toUnit,
              (value) => setState(() => toUnit = value),
            ),
          ),
        ],
      ),
    ],
  };

  Widget _unitPicker(String value, ValueChanged<String> changed) =>
      DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 18),
          border: OutlineInputBorder(),
        ),
        items: const ['kg', 'g', 'mg', 'L', 'mL', 'cc']
            .map((unit) => DropdownMenuItem(value: unit, child: Text(unit)))
            .toList(),
        onChanged: (next) {
          if (next != null) {
            changed(next);
            setState(() {
              result = null;
              formula = null;
              concentrationDetail = null;
            });
          }
        },
      );

  @override
  Widget build(BuildContext context) => CalculatorSurface(
    id: mode.name,
    referenceStyle: referenceStyle,
    child: referenceStyle ? Builder(builder: form) : form(context),
  );

  Widget resultPanel(Widget child) => referenceStyle
      ? WorkspacePanel(radius: 32, depth: 1.3, softLighting: true, child: child)
      : Card(child: child);

  Widget form(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      CalculatorHeading(id: mode.name, title: 'Operaciones de dosis'),
      const SizedBox(height: 8),
      const Text(
        'Operaciones matemáticas. Ingresa únicamente parámetros ya indicados y confirma las unidades y la presentación con el MVZ.',
      ),
      const SizedBox(height: 16),
      CalculatorSelectorCard(
        id: mode.name,
        title: 'Tipo de cálculo',
        referenceStyle: referenceStyle,
        child: DropdownButtonFormField<DoseMathMode>(
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14),
          isDense: false,
          itemHeight: referenceStyle ? null : kMinInteractiveDimension,
          isExpanded: true,
          initialValue: mode,
          decoration: InputDecoration(
            helperText: mode.label,
            helperMaxLines: 3,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            enabledBorder: referenceStyle
                ? NeuInputBorder(
                    depth: 1.8,
                    dark: Theme.of(context).brightness == Brightness.dark,
                  )
                : const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                    borderSide: BorderSide(color: Color(0xFFBCCBD3)),
                  ),
            border: const OutlineInputBorder(),
          ),
          items: DoseMathMode.values
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    item.label,
                    maxLines: referenceStyle ? null : 1,
                    softWrap: true,
                    overflow: referenceStyle
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() {
            mode = value ?? mode;
            result = null;
            formula = null;
            concentrationDetail = null;
            error = null;
          }),
        ),
      ),
      const SizedBox(height: 16),
      if (widget.onChoosePatient != null &&
          mode == DoseMathMode.concentration) ...[
        if (referenceStyle)
          NeuPrimaryButton(
            soft: true,
            color: calculatorPastel(mode.name),
            onPressed: widget.onChoosePatient,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_search_outlined, size: 20),
                SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Elegir paciente, peso y fármaco',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          )
        else
          OutlinedButton.icon(
            onPressed: widget.onChoosePatient,
            icon: const Icon(Icons.person_search_outlined),
            label: const Text('Elegir paciente, peso y fármaco'),
          ),
        if (referenceStyle) const SizedBox(height: 16),
      ],
      if (referenceStyle)
        NeuHeaderCard(
          title: 'Datos del cálculo',
          icon: Icons.tune_rounded,
          color: calculatorIdentity(mode.name).color,
          soft: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(children: _inputs()),
          ),
        ),
      if (!referenceStyle) ..._inputs(),
      if (referenceStyle) const SizedBox(height: 22),
      if (referenceStyle)
        NeuPrimaryButton(
          soft: true,
          color: calculatorPastel(mode.name),
          onPressed: calculate,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calculate_outlined, size: 21),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  mode == DoseMathMode.conversion
                      ? 'Convertir unidades'
                      : 'Calcular volumen',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        )
      else
        FilledButton.icon(
          onPressed: calculate,
          icon: const Icon(Icons.calculate_outlined),
          label: const Text('Calcular'),
        ),
      if (error case final message?)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      if (result case final value?) ...[
        const SizedBox(height: 16),
        resultPanel(
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Resultado matemático'),
                const SizedBox(height: 4),
                Text(value, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(formula ?? ''),
                if (concentrationDetail != null) Text(concentrationDetail!),
              ],
            ),
          ),
        ),
      ],
    ],
  );
}

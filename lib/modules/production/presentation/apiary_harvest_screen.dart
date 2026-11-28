import 'package:flutter/material.dart';
import '../../../vet_ui/vet_components.dart';
import '../domain/production_session_math.dart';

class ApiaryHarvestScreen extends StatefulWidget {
  const ApiaryHarvestScreen({super.key, required this.showCosts});
  final bool showCosts;
  @override
  State<ApiaryHarvestScreen> createState() => _ApiaryHarvestScreenState();
}

class _ApiaryHarvestScreenState extends State<ApiaryHarvestScreen> {
  final inputs = List.generate(5, (_) => TextEditingController());
  ApiaryHarvest? result;
  String error = '';
  @override
  void didUpdateWidget(covariant ApiaryHarvestScreen old) {
    super.didUpdateWidget(old);
    if (old.showCosts != widget.showCosts) {
      inputs[3].clear();
      inputs[4].clear();
      result = null;
      error = '';
    }
  }

  @override
  void dispose() {
    for (final c in inputs) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Apiario · rendimiento de cosecha')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const VetNotice(
          text:
              'Cálculo de sesión con tu cosecha capturada: kg por colmena productiva y por día. No propone rendimientos ni registra una cosecha automáticamente.',
        ),
        for (var i = 0; i < (widget.showCosts ? 5 : 3); i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextField(
              controller: inputs[i],
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: const [
                  'Miel cosechada (kg)',
                  'Colmenas productivas',
                  'Duración del periodo (días)',
                  'Precio capturado (MXN/kg) · opcional',
                  'Costos capturados (MXN) · opcional',
                ][i],
              ),
              onChanged: (_) => setState(() {
                result = null;
                error = '';
              }),
            ),
          ),
        FilledButton(
          onPressed: () {
            try {
              final r = ApiaryHarvest(
                kilograms: inputs[0].text,
                productiveHives: inputs[1].text,
                days: inputs[2].text,
                priceKg: widget.showCosts ? inputs[3].text : '',
                capturedCost: widget.showCosts ? inputs[4].text : '',
              );
              setState(() => result = r);
            } on FormatException catch (e) {
              setState(() {
                result = null;
                error = e.message;
              });
            }
          },
          child: const Text('Calcular cosecha'),
        ),
        if (error.isNotEmpty)
          VetNotice(text: error, kind: VetBadgeKind.warning),
        if (result case final r?) ...[
          Text('${r.perHive.display(places: 3)} kg/colmena productiva'),
          Text('${r.perDay.display(places: 3)} kg/día'),
          if (widget.showCosts) ...[
            Text(
              'Ingreso estimado: ${r.revenue?.display(places: 2) ?? 'Precio pendiente'} MXN',
            ),
            Text(
              'Saldo sobre costos capturados: ${(r.balance == null ? 'Datos pendientes' : signedSessionAmount(r.balance!))} MXN',
            ),
            const Text(
              'El saldo solo resta los costos que capturaste; no representa una utilidad completa.',
            ),
          ],
          const Text(
            'Procedimiento: miel ÷ colmenas productivas; miel ÷ días. Para guardar la cosecha usa Registros del apiario.',
          ),
        ],
      ],
    ),
  );
}

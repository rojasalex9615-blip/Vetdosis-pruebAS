import 'porcino_semen_panel.dart';
import 'package:flutter/material.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_icons.dart';
import 'aquaculture_panels.dart';
import 'porcino_panels.dart';
import 'growth_panel.dart';

/// Each independent calculator owns its route and its form state.
List<Widget> productionCalculatorEntries(
  BuildContext context,
  String scope,
  List<Widget> panels,
) => [
  for (final panel in panels)
    if (panel is SizedBox ||
        panel is VetNotice ||
        panel is AquacultureSpeciesPanel)
      panel
    else
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: OutlinedButton.icon(
          icon: const Icon(VetIcons.calculator),
          label: Text(productionPanelTitle(panel)),
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(
                  title: Text('$scope · ${productionPanelTitle(panel)}'),
                ),
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [panel],
                ),
              ),
            ),
          ),
        ),
      ),
];
String productionPanelTitle(Widget panel) => switch (panel) {
  PorcinoSiloPanel p => p.title,
  PorcinoSpacePanel p => p.title,
  PorcinoReferenceCard p => p.title,
  _ => _titles[panel.runtimeType] ?? 'Herramienta de producción',
};
const _titles = <Type, String>{
  AquacultureSeedPanel: 'Siembra y biomasa',
  AquacultureRationPanel: 'Ración diaria de peces',
  AquacultureIndicatorsPanel: 'Indicadores de cultivo',
  AquacultureFcrPanel: 'Conversión alimenticia y costo',
  AquacultureOxygenDemandPanel: 'Demanda de oxígeno',
  AquacultureAeratorPanel: 'Dimensionamiento de aireadores',
  AquacultureOxygenReservePanel: 'Reserva de oxígeno',
  AquacultureWaterExchangePanel: 'Recambio de agua',
  AquacultureNitriteSaltPanel: 'Nitritos y sal',
  AquacultureMedicatedFeedPanel: 'Alimento medicado',
  PorcinoBandFlowPanel: 'Flujo de bandas',
  PorcinoFlowPanel: 'Flujo reproductivo',
  PorcinoSemenPanel: 'Dosis y evaluación seminal',
  PorcinoInverseCapacityPanel: 'Capacidad inversa',
  PorcinoPenCapacityPanel: 'Capacidad de corrales',
  PorcinoVentilationPanel: 'Ventilación por etapa',
  PorcinoSiloPanel: 'Silos y alimento por fase',
  PorcinoReferenceCard: 'Referencias de la actividad',
  PorcinoProductiveModelsPanel: 'Modelos productivos',
  PorcinoBandPlanPanel: 'Planes de bandas guardados',
  PorcinoSpacePanel: 'Espacio por peso',
  PorcinoFacilitySizingPanel: 'Dimensionamiento de instalaciones',
  PorcinoInventoryPanel: 'Inventario por etapa',
  PorcinoAreaBalancePanel: 'Balance de superficies',
  PorcinoStageCapacityPanel: 'Capacidad por etapa',
  PorcinoGrowthProjectionPanel: 'Proyección de crecimiento',
  PorcinoFeedingSystemsPanel: 'Sistemas de alimentación',
  PorcinoStagePerformancePanel: 'Ganancia diaria y conversión',
  PorcinoYieldPanel: 'Rendimiento de canal',
  PorcinoInvestmentPanel: 'Inversión y costos',
  PorcinoBiosecurityPanel: 'Bioseguridad',
  PorcinoKpiImpactPanel: 'Impacto de indicadores',
  PorcinoUppPanel: 'Balance de la UPP de referencia',
  PorcinoNitrogenPanel: 'Nitrógeno y huella hídrica',
  PorcinoEnvironmentPanel: 'Ambiente y bienestar',
  PorcinoBiosecurityRefsPanel: 'Referencias de bioseguridad',
  GrowthPanel: 'Crecimiento y conversión del lote',
};

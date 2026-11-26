import '../../core/presentation/core_view_model.dart';

/// Una calculadora tal como se ofrece en el menu de su rama.
///
/// [tool] es el id que entiende `CalculationScreen`; las que abren su propia
/// pantalla llevan [route] en vez de `tool`.
class CalculationEntry {
  const CalculationEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    this.tool,
    this.route,
    this.available = true,
  });
  final String id, title, subtitle;
  final String? tool;
  final String? route;
  final bool available;
}

/// Agrupa las calculadoras por rama de trabajo, que es como las busca quien
/// las usa: primero «que soy» (pequenas especies, exoticos, produccion) y
/// despues «que quiero calcular». Antes estaban todas en un desplegable plano
/// mezclando areas, con las de aves sueltas como botones encima.
const calculationBranches = <ClinicalBranch, List<CalculationEntry>>{
  ClinicalBranch.small: [
    CalculationEntry(
      id: 'fluids',
      title: 'Fluidoterapia',
      subtitle: 'Plan de liquidos, mantenimiento y perdidas',
      tool: 'fluids',
    ),
    CalculationEntry(
      id: 'cri',
      title: 'Infusion continua (CRI)',
      subtitle: 'Dosis, concentracion y velocidad de bomba',
      tool: 'cri',
    ),
    CalculationEntry(
      id: 'dose',
      title: 'Dosis por paciente',
      subtitle: 'Peso, dosis y presentacion',
      route: 'Calculo rapido',
    ),
    CalculationEntry(
      id: 'doseActive',
      title: 'Dosis por principio activo',
      subtitle: 'Vademecum farmacologico: dosis por kg, peso y cita',
      route: 'Dosis por principio activo',
    ),
    CalculationEntry(
      id: 'doseBrand',
      title: 'Dosis por empaque comercial',
      subtitle: 'Vademecum de marcas: lo que dice el fabricante',
      route: 'Dosis por empaque comercial',
    ),
    CalculationEntry(
      id: 'doseTable',
      title: 'Tabla acumulativa de dosis',
      subtitle: 'Los dos vademecums en una tabla de 15 columnas',
      route: 'Tabla acumulativa de dosis',
    ),
    CalculationEntry(
      id: 'protocols',
      title: 'Protocolos por etapas',
      subtitle: 'Premedicacion, induccion, analgesia y recuperacion',
      tool: 'protocols',
    ),
    CalculationEntry(
      id: 'vitals',
      title: 'Constantes fisiologicas',
      subtitle: 'Comparar un valor medido con su rango',
      tool: 'vitals',
    ),
    CalculationEntry(
      id: 'withdrawals',
      title: 'Tiempos de retiro',
      subtitle: 'Producto, via y destino en Mexico',
      tool: 'withdrawals',
    ),
  ],
  ClinicalBranch.exotic: [
    CalculationEntry(
      id: 'metabolic',
      title: 'Peso metabolico',
      subtitle: 'Exoticos: peso metabolico a partir del peso',
      tool: 'metabolic',
    ),
    CalculationEntry(
      id: 'vitals',
      title: 'Constantes fisiologicas',
      subtitle: 'Comparar un valor medido con su rango',
      tool: 'vitals',
    ),
    CalculationEntry(
      id: 'fluids',
      title: 'Fluidoterapia',
      subtitle: 'Plan de liquidos en pacientes pequenos',
      tool: 'fluids',
    ),
    CalculationEntry(
      id: 'protocols',
      title: 'Protocolos por etapas',
      subtitle: 'Premedicacion, induccion, analgesia y recuperacion',
      tool: 'protocols',
    ),
    CalculationEntry(
      id: 'withdrawals',
      title: 'Tiempos de retiro',
      subtitle: 'Producto, via y destino en Mexico',
      tool: 'withdrawals',
    ),
  ],
  ClinicalBranch.production: [
    CalculationEntry(
      id: 'water',
      title: 'Agua de bebida',
      subtitle: 'Concentracion de un producto en el agua',
      tool: 'water',
    ),
    CalculationEntry(
      id: 'feed',
      title: 'Alimento o pienso',
      subtitle: 'Concentracion de un producto en el alimento',
      tool: 'feed',
    ),
    CalculationEntry(
      id: 'herd',
      title: 'Dosis por lote',
      subtitle: 'Peso promedio, numero de animales y dosis',
      tool: 'herd',
    ),
    CalculationEntry(
      id: 'aviculture',
      title: 'Aves · Capacidad e instalaciones',
      subtitle: 'Densidad, comederos y bebederos',
      route: 'Aves · Capacidad e instalaciones',
    ),
    CalculationEntry(
      id: 'incubation',
      title: 'Aves · Incubacion',
      subtitle: 'Huevos, nacimientos y etapas',
      route: 'Aves · Incubacion',
    ),
    CalculationEntry(
      id: 'broiler',
      title: 'Aves · Engorda',
      subtitle: 'Capacidad de pollo de engorda',
      route: 'Aves · Engorda',
    ),
    CalculationEntry(
      id: 'poultryIndex',
      title: 'Aves · Indices productivos',
      subtitle: 'Indices de engorda y postura',
      route: 'Aves · Indices productivos',
    ),
    CalculationEntry(
      id: 'withdrawals',
      title: 'Tiempos de retiro',
      subtitle: 'Producto, via y destino en Mexico',
      tool: 'withdrawals',
    ),
  ],
};

/// Etiqueta y descripcion de cada rama en el selector.
String calculationBranchLabel(ClinicalBranch branch) => switch (branch) {
  ClinicalBranch.small => 'Pequenas especies',
  ClinicalBranch.exotic => 'Exoticos y silvestres',
  ClinicalBranch.production => 'Produccion y grandes especies',
  ClinicalBranch.management => 'Gestion clinica',
};

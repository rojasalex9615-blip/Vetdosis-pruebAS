/// Capacidad e instalaciones porcinas: densidad, capacidad de corral,
/// dimensionamiento, déficit de superficie, capacidad productiva por etapa,
/// proyección de crecimiento y balance entre etapas.
///
/// Puras y sin estado: no guardan registros de granja. Las densidades de
/// referencia salen de [porcinoSpaceM2] (tabla Gonyou 2006 del material de
/// clase). No son metas de rendimiento ni dictamen normativo.
library;

import 'porcino_reference.dart';

FormatException _invalid(String message) => FormatException(message);

void _positive(double value, String label, {double max = 1e7}) {
  if (!value.isFinite || value <= 0 || value > max) {
    throw _invalid('$label: mayor que 0 y hasta ${_trim(max)}.');
  }
}

void _count(int value, String label, {bool allowZero = false}) {
  final min = allowZero ? 0 : 1;
  if (value < min || value > 1000000) {
    throw _invalid('$label: entero de $min a 1000000.');
  }
}

/// m² de referencia por animal para un peso y tipo de piso dados.
///
/// Devuelve null si el peso no está en la tabla: la app no interpola ni
/// inventa una densidad para un peso que la fuente no cubre.
double? swineDensityFor(int weightKg, PorcinoFloor floor) =>
    porcinoSpaceM2[weightKg]?[floor];

/// Pesos con densidad publicada en la tabla de origen, en orden ascendente.
List<int> get swineDensityWeights =>
    porcinoSpaceM2.keys.toList()..sort();

/// Capacidad de corral: cuántos animales caben en una superficie disponible.
///
/// La capacidad se redondea hacia abajo: una fracción de animal no cuenta. La
/// superficie requerida es la de los animales declarados, no la de la
/// capacidad, y la diferencia es disponible − requerida (positiva: sobra;
/// negativa: falta).
class PenCapacity {
  PenCapacity({
    required this.availableM2,
    required this.m2PerAnimal,
    required this.animals,
  }) {
    _positive(availableM2, 'Superficie disponible', max: 1e6);
    _positive(m2PerAnimal, 'Superficie de referencia por animal', max: 10);
    _count(animals, 'Número de animales', allowZero: true);
  }

  final double availableM2, m2PerAnimal;
  final int animals;

  /// Animales que caben: disponible ÷ referencia, redondeado hacia abajo.
  int get capacity => (availableM2 / m2PerAnimal + 1e-9).floor();

  /// Superficie que ocupan los animales declarados.
  double get requiredM2 => animals * m2PerAnimal;

  /// disponible − requerida. Positiva: sobra; negativa: falta.
  double get differenceM2 => availableM2 - requiredM2;

  bool get fits => requiredM2 <= availableM2 + 1e-9;
}

/// Dimensionamiento: superficie necesaria para alojar una cantidad de animales.
class FacilitySizing {
  FacilitySizing({required this.animals, required this.m2PerAnimal}) {
    _count(animals, 'Animales');
    _positive(m2PerAnimal, 'Superficie de referencia por animal', max: 10);
  }

  final int animals;
  final double m2PerAnimal;

  double get requiredM2 => animals * m2PerAnimal;
}

/// Balance de superficie: compara lo que existe contra lo requerido y separa
/// déficit de sobrante. Nunca devuelve los dos a la vez.
class AreaBalance {
  AreaBalance({required this.existingM2, required this.requiredM2}) {
    if (!existingM2.isFinite || existingM2 < 0 || existingM2 > 1e7) {
      throw _invalid('Superficie existente: de 0 a 10000000 m².');
    }
    if (!requiredM2.isFinite || requiredM2 < 0 || requiredM2 > 1e7) {
      throw _invalid('Superficie requerida: de 0 a 10000000 m².');
    }
  }

  final double existingM2, requiredM2;

  /// existing − required. Positiva: sobra; negativa: falta.
  double get differenceM2 => existingM2 - requiredM2;

  bool get hasDeficit => requiredM2 > existingM2 + 1e-9;

  /// Superficie que falta; 0 si no hay déficit.
  double get deficitM2 => hasDeficit ? requiredM2 - existingM2 : 0;

  /// Superficie que sobra; 0 si hay déficit.
  double get surplusM2 => hasDeficit ? 0 : existingM2 - requiredM2;
}

/// Una etapa productiva con su superficie y su densidad de referencia.
class StageArea {
  const StageArea({
    required this.stage,
    required this.areaM2,
    required this.m2PerAnimal,
  });
  final String stage;
  final double areaM2, m2PerAnimal;

  void validate() {
    if (stage.trim().isEmpty) throw _invalid('La etapa necesita nombre.');
    if (!areaM2.isFinite || areaM2 < 0 || areaM2 > 1e7) {
      throw _invalid('Superficie de $stage: de 0 a 10000000 m².');
    }
    _positive(m2PerAnimal, 'Superficie por animal de $stage', max: 10);
  }
}

/// Capacidad productiva: cuántos animales aloja cada etapa y el total.
class StageCapacityPlan {
  StageCapacityPlan(List<StageArea> stages) : stages = List.of(stages) {
    if (this.stages.isEmpty) {
      throw _invalid('Añade al menos una etapa.');
    }
    for (final stage in this.stages) {
      stage.validate();
    }
  }

  final List<StageArea> stages;

  /// Animales que aloja cada etapa, en el orden dado.
  List<int> get capacities => [
    for (final s in stages) (s.areaM2 / s.m2PerAnimal + 1e-9).floor(),
  ];

  int get totalCapacity => capacities.fold(0, (a, b) => a + b);

  /// La etapa que limita al conjunto: la de menor capacidad. Empate: la
  /// primera en el orden dado, para que el resultado sea reproducible.
  StageArea get bottleneckStage {
    var best = 0;
    final values = capacities;
    for (var i = 1; i < values.length; i++) {
      if (values[i] < values[best]) best = i;
    }
    return stages[best];
  }

  int get bottleneckCapacity => capacities.reduce((a, b) => a < b ? a : b);
}

/// Proyección de crecimiento: infraestructura necesaria para pasar del
/// inventario actual a uno mayor. Si la meta es menor, no falta superficie.
class GrowthProjection {
  GrowthProjection({
    required this.currentAnimals,
    required this.targetAnimals,
    required this.m2PerAnimal,
  }) {
    _count(currentAnimals, 'Inventario actual', allowZero: true);
    _count(targetAnimals, 'Meta de inventario', allowZero: true);
    _positive(m2PerAnimal, 'Superficie de referencia por animal', max: 10);
  }

  final int currentAnimals, targetAnimals;
  final double m2PerAnimal;

  double get currentM2 => currentAnimals * m2PerAnimal;
  double get targetM2 => targetAnimals * m2PerAnimal;

  /// Animales que se suman; 0 si la meta no supera al inventario.
  int get additionalAnimals =>
      targetAnimals > currentAnimals ? targetAnimals - currentAnimals : 0;

  /// Superficie adicional necesaria; 0 si no crece.
  double get additionalM2 => additionalAnimals * m2PerAnimal;
}

String _trim(double value) {
  final fixed = value.toStringAsFixed(0);
  return fixed;
}

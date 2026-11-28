/// Grupos taxonómicos de fauna exótica y las constantes que los distinguen.
///
/// En exóticos el grupo manda sobre la especie: un loro y un pinzón comparten
/// mucho más entre sí que con una iguana, y la tasa metabólica de un reptil es
/// un orden de magnitud menor que la de un ave del mismo peso. Por eso las
/// dosis no se extrapolan por regla de tres sobre el peso.
///
/// Aquí no se guarda nada ni se aplica a un paciente: son constantes de
/// consulta y el cálculo que se apoya en ellas.
library;

import 'dart:math' as math;

/// Los grupos con los que trabaja el módulo.
enum ExoticTaxon {
  aves('Aves', 'ave'),
  reptiles('Reptiles', 'reptil'),
  anfibios('Anfibios', 'anfibio'),
  mamiferosPequenos('Mamíferos pequeños', 'mamifero'),
  pecesOrnamentales('Peces ornamentales', 'pez'),
  faunaSilvestre('Fauna silvestre', 'silvestre');

  const ExoticTaxon(this.label, this.code);

  /// Como se lee en pantalla.
  final String label;

  /// Clave corta y estable, para guardar o filtrar sin depender del rótulo.
  final String code;

  static ExoticTaxon? porCodigo(String code) {
    for (final t in ExoticTaxon.values) {
      if (t.code == code) return t;
    }
    return null;
  }
}

/// Constante K de la ecuación metabólica basal, en kcal/día.
///
/// `TMB = K · P^0.75`, con el peso P en kilogramos. El exponente 0.75 es la
/// ley de Kleiber; K cambia con el grupo porque un homeotermo gasta mucho más
/// que un ectotermo del mismo tamaño.
///
/// Los valores son los que reproduce la literatura de escalamiento alométrico
/// para medicina de exóticos (método de Sedgwick). **No sustituyen a la obra
/// de referencia del clínico**: la pantalla muestra siempre de dónde sale cada
/// número para que pueda contrastarse antes de usarlo.
class MetabolicConstant {
  const MetabolicConstant({
    required this.taxon,
    required this.k,
    required this.detalle,
    required this.fuente,
  });

  final ExoticTaxon taxon;

  /// K en kcal/día para `TMB = K · P^0.75`.
  final double k;

  /// A que subgrupo corresponde exactamente, cuando la obra lo distingue.
  final String detalle;

  final String fuente;
}

/// Las constantes por grupo. Varias filas por grupo cuando la obra separa
/// subgrupos con metabolismos muy distintos (paseriformes vs. el resto).
const List<MetabolicConstant> constantesMetabolicas = [
  MetabolicConstant(
    taxon: ExoticTaxon.aves,
    k: 129,
    detalle: 'Paseriformes',
    fuente: 'Escalamiento alométrico (método de Sedgwick)',
  ),
  MetabolicConstant(
    taxon: ExoticTaxon.aves,
    k: 78,
    detalle: 'No paseriformes (psitácidas, rapaces)',
    fuente: 'Escalamiento alométrico (método de Sedgwick)',
  ),
  MetabolicConstant(
    taxon: ExoticTaxon.mamiferosPequenos,
    k: 70,
    detalle: 'Mamíferos placentarios',
    fuente: 'Escalamiento alométrico (método de Sedgwick)',
  ),
  MetabolicConstant(
    taxon: ExoticTaxon.mamiferosPequenos,
    k: 49,
    detalle: 'Marsupiales',
    fuente: 'Escalamiento alométrico (método de Sedgwick)',
  ),
  MetabolicConstant(
    taxon: ExoticTaxon.reptiles,
    k: 10,
    detalle: 'Reptiles (ectotermos)',
    fuente: 'Escalamiento alométrico (método de Sedgwick)',
  ),
  MetabolicConstant(
    taxon: ExoticTaxon.anfibios,
    k: 10,
    detalle: 'Anfibios (ectotermos)',
    fuente: 'Escalamiento alométrico (método de Sedgwick)',
  ),
  MetabolicConstant(
    taxon: ExoticTaxon.pecesOrnamentales,
    k: 10,
    detalle: 'Peces (ectotermos)',
    fuente: 'Escalamiento alométrico (método de Sedgwick)',
  ),
  MetabolicConstant(
    taxon: ExoticTaxon.faunaSilvestre,
    k: 70,
    detalle: 'Mamífero silvestre placentario (ajustar al grupo real)',
    fuente: 'Escalamiento alométrico (método de Sedgwick)',
  ),
];

List<MetabolicConstant> constantesDe(ExoticTaxon taxon) =>
    constantesMetabolicas.where((c) => c.taxon == taxon).toList();

/// Tasa de mantenimiento hídrico por grupo, en mL/kg/día.
///
/// Se guarda como rango, no como número único, porque las obras difieren y
/// porque la tasa real depende del estado del ejemplar. La pantalla muestra el
/// rango completo y su origen; no se promedia ni se elige por el clínico.
class FluidRate {
  const FluidRate({
    required this.taxon,
    required this.minMlKgDia,
    required this.maxMlKgDia,
    required this.nota,
    required this.fuente,
  });

  final ExoticTaxon taxon;
  final double minMlKgDia;
  final double maxMlKgDia;
  final String nota;
  final String fuente;

  String get rango => minMlKgDia == maxMlKgDia
      ? '${_num(minMlKgDia)} mL/kg/día'
      : '${_num(minMlKgDia)} - ${_num(maxMlKgDia)} mL/kg/día';
}

const List<FluidRate> tasasDeMantenimiento = [
  FluidRate(
    taxon: ExoticTaxon.aves,
    minMlKgDia: 40,
    maxMlKgDia: 60,
    nota: 'Repartir en varias tomas; vigilar sobrecarga en aves pequeñas.',
    fuente: 'Literatura de fluidoterapia en aves',
  ),
  FluidRate(
    taxon: ExoticTaxon.mamiferosPequenos,
    minMlKgDia: 50,
    maxMlKgDia: 100,
    nota: 'Los de menor talla tienden al extremo alto del rango.',
    fuente: 'Literatura de fluidoterapia en mamíferos no convencionales',
  ),
  FluidRate(
    taxon: ExoticTaxon.reptiles,
    minMlKgDia: 10,
    maxMlKgDia: 30,
    nota: 'Depende de la temperatura ambiente efectiva del ejemplar.',
    fuente: 'Literatura de fluidoterapia en reptiles',
  ),
  FluidRate(
    taxon: ExoticTaxon.anfibios,
    minMlKgDia: 20,
    maxMlKgDia: 30,
    nota: 'Preferir baños y vía cutánea sobre la parenteral.',
    fuente: 'Literatura de fluidoterapia en anfibios',
  ),
  FluidRate(
    taxon: ExoticTaxon.pecesOrnamentales,
    minMlKgDia: 0,
    maxMlKgDia: 0,
    nota:
        'No aplica por vía habitual: el manejo hídrico se hace sobre la calidad '
        'del agua del sistema, no por fluidoterapia.',
    fuente: '—',
  ),
  FluidRate(
    taxon: ExoticTaxon.faunaSilvestre,
    minMlKgDia: 50,
    maxMlKgDia: 100,
    nota: 'Ajustar al grupo real del ejemplar antes de aplicar.',
    fuente: 'Literatura de fluidoterapia en mamíferos',
  ),
];

FluidRate? tasaDe(ExoticTaxon taxon) {
  for (final t in tasasDeMantenimiento) {
    if (t.taxon == taxon) return t;
  }
  return null;
}

/// Resultado de escalar una dosis entre dos especies por energía metabólica.
class AllometricResult {
  const AllometricResult({
    required this.tmbModelo,
    required this.tmbDestino,
    required this.dosisModeloMg,
    required this.dosisDestinoMg,
    required this.mgPorKcal,
  });

  /// Tasa metabólica basal de la especie de la que se conoce la dosis.
  final double tmbModelo;

  /// Tasa metabólica basal del ejemplar que se va a tratar.
  final double tmbDestino;

  /// Dosis total que recibiria el modelo, en mg.
  final double dosisModeloMg;

  /// Dosis total para el ejemplar, en mg.
  final double dosisDestinoMg;

  /// Cuantos mg corresponden a cada kcal de metabolismo basal.
  final double mgPorKcal;

  /// La dosis del ejemplar expresada por kilo, para poder compararla.
  double dosisDestinoMgKg(double pesoDestinoKg) =>
      pesoDestinoKg <= 0 ? 0 : dosisDestinoMg / pesoDestinoKg;
}

/// Escala una dosis conocida de una especie a otra por energía metabólica.
///
/// No es una regla de tres sobre el peso: eso sobredosifica a los pequeños y
/// subdosifica a los grandes. El camino es
///
///   1. `TMB = K · P^0.75` para el modelo y para el destino;
///   2. la dosis del modelo se reparte entre sus kcal basales;
///   3. esos mg por kcal se aplican a las kcal del destino.
///
/// Lanza [ArgumentError] si algún dato no es positivo: con un peso de cero la
/// cuenta no tiene sentido y es preferible fallar que devolver un número.
AllometricResult escalarDosis({
  required double dosisModeloMgKg,
  required double pesoModeloKg,
  required double kModelo,
  required double pesoDestinoKg,
  required double kDestino,
}) {
  if (dosisModeloMgKg <= 0 ||
      pesoModeloKg <= 0 ||
      kModelo <= 0 ||
      pesoDestinoKg <= 0 ||
      kDestino <= 0) {
    throw ArgumentError(
      'Todos los datos del escalamiento deben ser mayores que cero.',
    );
  }
  final tmbModelo = kModelo * _pow075(pesoModeloKg);
  final tmbDestino = kDestino * _pow075(pesoDestinoKg);
  final dosisModeloMg = dosisModeloMgKg * pesoModeloKg;
  final mgPorKcal = dosisModeloMg / tmbModelo;
  return AllometricResult(
    tmbModelo: tmbModelo,
    tmbDestino: tmbDestino,
    dosisModeloMg: dosisModeloMg,
    dosisDestinoMg: mgPorKcal * tmbDestino,
    mgPorKcal: mgPorKcal,
  );
}

/// Un paso de dilución seriada 1 + 9 y la concentración con la que termina.
class PasoDilucion {
  const PasoDilucion({
    required this.producto,
    required this.diluyente,
    required this.concentracion,
    required this.esPrimero,
  });

  /// mL que se toman del frasco (primer paso) o de la mezcla anterior.
  final double producto;

  /// mL de diluyente que se añaden.
  final double diluyente;

  /// Concentración resultante del paso, en mg/mL.
  final double concentracion;

  final bool esPrimero;
}

/// Volumen a cargar para una dosis, con la jeringa que de verdad la mide.
class MicroVolume {
  const MicroVolume({
    required this.mlSinDiluir,
    required this.pasos,
    required this.mlConDilucion,
    required this.concentracionFinal,
    required this.receta,
    required this.jeringaSugerida,
    required this.avisa,
  });

  /// Volumen del producto tal cual sale del frasco.
  final double mlSinDiluir;

  /// Pasos seriados de 1 + 9. 0 = sin diluir.
  ///
  /// No se expresa como 1:N porque 1:100 y 1:1000 no se pueden preparar de una
  /// vez: habría que medir 0.01 mL o 0.001 mL del frasco, que es justo el
  /// volumen que no se puede medir. Se hacen pasos de 1 parte + 9 de diluyente.
  final int pasos;

  /// Volumen a cargar una vez diluido.
  final double mlConDilucion;

  /// Concentración de lo que se carga, en mg/mL.
  final double concentracionFinal;

  /// Preparación paso a paso. Vacía cuando no hace falta diluir.
  final List<PasoDilucion> receta;

  final String jeringaSugerida;

  /// Aviso cuando el volumen sigue siendo difícil de medir con fiabilidad.
  final String? avisa;
}

/// Calcula el volumen de una dosis y, si sale impracticable, propone diluir.
///
/// En exóticos el problema no suele ser la dosis sino poder medirla: 0.004 mL
/// no se cargan en ninguna jeringa. Se busca la dilución mínima, en pasos de
/// 1 + 9, que lleve el volumen a algo medible con margen en una jeringa de
/// insulina.
MicroVolume calcularMicroVolumen({
  required double dosisMg,
  required double concentracionMgMl,
}) {
  if (dosisMg <= 0 || concentracionMgMl <= 0) {
    throw ArgumentError('La dosis y la concentración deben ser positivas.');
  }
  final mlSinDiluir = dosisMg / concentracionMgMl;

  // 0.01 mL es una sola marca de la jeringa de insulina, con demasiado error
  // relativo. Se apunta a 0.05 mL.
  const minimoMedible = 0.05;
  const maximoPasos = 3;
  var pasos = 0;
  var factor = 1;
  var volumen = mlSinDiluir;
  while (volumen < minimoMedible && pasos < maximoPasos) {
    pasos++;
    factor *= 10;
    volumen = mlSinDiluir * factor;
  }

  final String jeringa;
  if (volumen <= 0.3) {
    jeringa = 'Insulina 0.3 mL (marca cada 0.01 mL)';
  } else if (volumen <= 0.5) {
    jeringa = 'Insulina 0.5 mL';
  } else if (volumen <= 1) {
    jeringa = 'Insulina o tuberculina 1 mL';
  } else if (volumen <= 3) {
    jeringa = 'Jeringa de 3 mL';
  } else {
    jeringa = 'Jeringa de ${volumen.ceil()} mL';
  }

  final receta = <PasoDilucion>[];
  var concentracion = concentracionMgMl;
  for (var i = 0; i < pasos; i++) {
    concentracion /= 10;
    receta.add(
      PasoDilucion(
        producto: 0.1,
        diluyente: 0.9,
        concentracion: concentracion,
        esPrimero: i == 0,
      ),
    );
  }

  String? avisa;
  if (volumen < minimoMedible) {
    avisa =
        'Ni con tres pasos de dilución se alcanza un volumen medible. '
        'Revisa la concentración del producto o busca una presentación más '
        'diluida.';
  } else if (pasos > 0) {
    avisa =
        'Sin diluir serían ${_num6(mlSinDiluir)} mL, que no se pueden '
        'medir.';
  }

  return MicroVolume(
    mlSinDiluir: mlSinDiluir,
    pasos: pasos,
    mlConDilucion: volumen,
    concentracionFinal: concentracion,
    receta: receta,
    jeringaSugerida: jeringa,
    avisa: avisa,
  );
}

/// Mantenimiento hídrico diario de un ejemplar, en mL/día.
///
/// Devuelve el rango, no un número: la tasa publicada es un rango y reducirlo
/// a un valor único esconde la decisión clínica.
({double min, double max})? mantenimientoDiario({
  required ExoticTaxon taxon,
  required double pesoKg,
}) {
  final tasa = tasaDe(taxon);
  if (tasa == null || pesoKg <= 0) return null;
  if (tasa.minMlKgDia == 0 && tasa.maxMlKgDia == 0) return null;
  return (min: tasa.minMlKgDia * pesoKg, max: tasa.maxMlKgDia * pesoKg);
}

/// `P^0.75`, el exponente de la ley de Kleiber.
double _pow075(double p) => math.pow(p, 0.75).toDouble();

String _num(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

String _num6(double v) => v.toStringAsFixed(6);

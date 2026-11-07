/// Catalogo de especies, actividades y apartados previstos de produccion.
///
/// Vive en el dominio y no en la pantalla porque lo usan los dos lados: el
/// menu para ofrecerlos y los registros para comprobar que una unidad no
/// quede colgada de una actividad que la app no ofrece.
library;

const productionSpecies = <String, List<String>>{
  'Bovinos': [
    'Leche',
    'Carne y engorda',
    'Doble propósito',
    'Atención individual',
  ],
  'Ovinos / caprinos': ['Ovinos', 'Caprinos'],
  'Aves': ['Postura', 'Engorda', 'Reproducción e incubación'],
  'Peces': ['Tilapia'],
  'Abejas': ['Apiarios y colmenas'],
  'Porcinos': [
    'Reproducción y gestación',
    'Maternidad y destete',
    'Crecimiento y engorda',
  ],
  'Equinos': ['Atención individual', 'Reproducción y crianza'],
};

const plannedProductionAreas = <String, List<String>>{
  'Bovinos': [
    'Animales y hatos/lotes',
    'Reproducción y alimentación',
    'Indicadores por unidad',
  ],
  'Ovinos / caprinos': [
    'Animales y rebaños',
    'Carne, leche y fibra según actividad',
    'Reproducción y alimentación',
  ],
  'Aves': [
    'Parvadas, casetas y ciclos',
    'Registros productivos',
    'Alimentación y seguimiento',
  ],
  'Peces': [
    'Lotes y unidades de cultivo',
    'Calidad del agua y alimentación',
    'Biomasa y ciclos',
  ],
  'Abejas': [
    'Apiarios y colmenas',
    'Revisiones y sanidad',
    'Cosechas y seguimiento',
  ],
  'Porcinos': [
    'Reproductores y servicios',
    'Camadas y alimentación',
    'Engorda e indicadores',
  ],
  'Equinos': ['Atención y seguimiento individual', 'Reproducción y crianza'],
};

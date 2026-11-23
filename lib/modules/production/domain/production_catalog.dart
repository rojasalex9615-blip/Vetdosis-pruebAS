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
  'Peces': ['Tilapia', 'Trucha', 'Cachama', 'Bagre'],
  'Abejas': ['Apiarios y colmenas'],
  'Porcinos': [
    'Reproducción y gestación',
    'Maternidad y destete',
    'Crecimiento y engorda',
    'Bioseguridad y ambiente',
    'Planeación financiera',
  ],
  'Equinos': ['Atención individual', 'Reproducción y crianza'],
};

/// Lo que todavia no tiene donde guardarse.
///
/// Esta lista encogio al entrar los lotes, los registros productivos y los
/// eventos de manejo: «animales y rebanos» son ahora los lotes, «cosechas y
/// seguimiento» son las metricas de miel, «revisiones y sanidad» son los
/// eventos sanitarios y los indicadores por unidad ya salen en el panel.
/// Solo queda fuera la reproduccion, que no tiene tabla ni metricas: no se
/// anuncia como disponible mientras no la tenga.
const plannedProductionAreas = <String, List<String>>{
  'Bovinos': ['Reproducción y genealogía'],
  'Ovinos / caprinos': ['Reproducción y genealogía'],
};

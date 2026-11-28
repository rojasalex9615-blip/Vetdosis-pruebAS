-- Dias de gestacion por especie.
--
-- Las claves de produccion (bovino, cerdo, ovino, caprino) son exactamente los
-- codigos de produccion_especies, para que el formulario del lote pueda
-- sugerir sin traducir. Las demas son nombres normalizados (minuscula, sin
-- acentos) contra los que la app compara el texto libre de vet_patients.species.
--
-- Las aves, los peces y las abejas de produccion_especies no aparecen aqui a
-- proposito: son oviparos y su reproduccion no es una gestacion. Lo suyo ya
-- tiene sitio en exotic_clutches.

insert into public.reproduccion_gestacion_dias (especie, nombre, grupo, dias_min, dias_prom, dias_max) values
  ('bovino',        'Bovino',          'produccion', 279, 283, 292),
  ('bufalo',        'Búfalo de agua',  'produccion', 300, 310, 320),
  ('cerdo',         'Cerdo',           'produccion', 112, 114, 117),
  ('ovino',         'Ovino',           'produccion', 144, 150, 157),
  ('caprino',       'Caprino',         'produccion', 145, 150, 155),
  ('llama',         'Llama',           'produccion', 335, 345, 360),
  ('alpaca',        'Alpaca',          'produccion', 335, 345, 355),
  ('equino',        'Equino',          'equino',     320, 340, 360),
  ('burro',         'Burro',           'equino',     360, 372, 390),
  ('perro',         'Perro',           'compania',    58,  63,  68),
  ('gato',          'Gato',            'compania',    58,  65,  70),
  ('conejo',        'Conejo',          'exotico',     28,  31,  34),
  ('cuyo',          'Cuyo',            'exotico',     59,  68,  72),
  ('chinchilla',    'Chinchilla',      'exotico',    105, 111, 118),
  ('huron',         'Hurón',           'exotico',     41,  42,  44),
  ('rata',          'Rata',            'exotico',     21,  22,  23),
  ('raton',         'Ratón',           'exotico',     19,  20,  21),
  ('jerbo',         'Jerbo',           'exotico',     23,  25,  26),
  ('hamster sirio', 'Hámster sirio',   'exotico',     15,  16,  18),
  ('hamster ruso',  'Hámster ruso',    'exotico',     18,  19,  21),
  ('hamster chino', 'Hámster chino',   'exotico',     20,  21,  22),
  ('hamster',       'Hámster',         'exotico',     15,  16,  18)
on conflict (especie) do nothing;

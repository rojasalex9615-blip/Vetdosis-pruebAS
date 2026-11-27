-- Aplicado el 2026-11-26 en wtrelwtztkddfktrfdpb.
-- Campos que la especificación de los dos vademécums exige por pauta y que la
-- tabla no tenía. Todo aditivo: no se altera ni se borra ninguna columna.

-- Campos que la especificación exige por pauta y que la tabla no tiene.
-- Todo aditivo: no se altera ni se borra ninguna columna existente.

alter table private.vetdosis_qwen_dosis_revision
  add column if not exists autor                 text,
  add column if not exists titulo                text,
  add column if not exists edicion               text,
  add column if not exists anio                  smallint,
  add column if not exists seccion               text,
  add column if not exists dosis_original        text,
  add column if not exists unidad_original       text,
  add column if not exists regla                 text,
  add column if not exists base_calculo          text,
  add column if not exists estado_normalizacion  text,
  add column if not exists motivo_no_normalizado text,
  add column if not exists especies              text[];

comment on column private.vetdosis_qwen_dosis_revision.autor is
  'Autor de la pauta. Cada pauta conserva su procedencia bibliográfica.';
comment on column private.vetdosis_qwen_dosis_revision.titulo is
  'Título de la obra o publicación de la que procede la pauta.';
comment on column private.vetdosis_qwen_dosis_revision.edicion is
  'Edición de la obra, tal como figura en la fuente.';
comment on column private.vetdosis_qwen_dosis_revision.anio is 'Año de publicación.';
comment on column private.vetdosis_qwen_dosis_revision.seccion is
  'Sección, apartado o tabla de la fuente, cuando la página no basta.';
comment on column private.vetdosis_qwen_dosis_revision.dosis_original is
  'Expresión literal de la dosis, sin normalizar. Es la única verdad de la pauta.';
comment on column private.vetdosis_qwen_dosis_revision.unidad_original is
  'Unidad tal como la escribe la fuente.';
comment on column private.vetdosis_qwen_dosis_revision.regla is
  'proporcional_al_peso | fija_por_animal | otra. Describe la unidad, no si el rango se pudo extraer.';
comment on column private.vetdosis_qwen_dosis_revision.base_calculo is
  'masa (mg/kg, UI/kg...) o volumen (ml/kg). Null cuando la pauta no es calculable por peso.';
comment on column private.vetdosis_qwen_dosis_revision.estado_normalizacion is
  'normalizada | no_normalizable | no_aplica.';
comment on column private.vetdosis_qwen_dosis_revision.motivo_no_normalizado is
  'Por qué no se pudo extraer un rango numérico fiable.';
comment on column private.vetdosis_qwen_dosis_revision.especies is
  'Especies de la pauta en forma de lista: una pauta para perro y gato sigue siendo una pauta.';

create index if not exists vetdosis_qwen_dosis_especies_idx
  on private.vetdosis_qwen_dosis_revision using gin (especies);
create index if not exists vetdosis_qwen_dosis_autor_idx
  on private.vetdosis_qwen_dosis_revision (autor);

-- 1) Bibliografía del bloque Ramsey, desde la copia de trabajo.
update private.vetdosis_qwen_dosis_revision d
   set autor                  = 'Ramsey, I. (ed.) / BSAVA',
       titulo                 = 'Vademécum farmacológico para perros y gatos',
       edicion                = '9.ª, Parte A',
       anio                   = 2017,
       dosis_original         = r.dosis_original,
       unidad_original        = r.unidad_original,
       estado_normalizacion   = r.estado_normalizacion,
       motivo_no_normalizado  = nullif(r.motivo_no_normalizado, '')
  from private.vetdosis_ramsey_pautas_revision r
 where d.bloque_origen = 'ramsey_9a_parte_a'
   and d.id_dosis_original = r.pauta_id
   and d.dosis_original is null;

-- 2) Especies como lista, en todos los bloques.
update private.vetdosis_qwen_dosis_revision
   set especies = case
     when especie is null then null
     when lower(especie) in ('general', 'no especificada', '') then '{}'::text[]
     when lower(especie) like '%perro%' and lower(especie) like '%gato%' then array['Perro','Gato']
     when lower(especie) like '%perro%' and lower(especie) like '%equino%' then array['Perro','Equino']
     when lower(especie) like '%conejo%' and lower(especie) like '%cuyo%' then array['Conejo','Cuyo']
     when lower(especie) like '%perro%' then array['Perro']
     when lower(especie) like '%gato%' then array['Gato']
     when lower(especie) like '%conejo%' then array['Conejo']
     when lower(especie) like '%cuyo%' then array['Cuyo']
     when lower(especie) like '%huron%' or lower(especie) like '%hurón%' then array['Hurón']
     when lower(especie) like '%reptil%' then array['Reptil']
     when lower(especie) like '%caballo%' then array['Caballo']
     when lower(especie) like '%equino%' then array['Equino']
     when lower(especie) like '%bovino%' then array['Bovino']
     else array[especie]
   end
 where especies is null;

-- 3) Regla y base de cálculo a partir de la unidad.
update private.vetdosis_qwen_dosis_revision
   set base_calculo = case
         when lower(unidad) ~ '^(mg|µg|ug|g|ng|ui|mmol)/kg$' then 'masa'
         when lower(unidad) = 'ml/kg' then 'volumen'
       end,
       regla = case
         when unidad is null then null
         when lower(unidad) ~ '^(mg|µg|ug|g|ng|ui|mmol)/kg$'
           or lower(unidad) = 'ml/kg' then 'proporcional_al_peso'
         when lower(unidad) ~ '(gato|perro|animal|articulaci|ojo|oreja|sitio|fosa)$' then 'fija_por_animal'
         when lower(unidad) in ('comprimido','comprimidos','cápsula','capsula','gota','gotas',
                                'pipeta','implante','collar','spot-on','pulverización',
                                'pulverizaciones','gel/crema','cucharaditas','cucharadas',
                                'cantidad') then 'fija_por_animal'
         else 'otra'
       end
 where regla is null;

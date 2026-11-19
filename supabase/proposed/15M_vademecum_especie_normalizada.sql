-- Separa la especie real de la dosis, para que cada especie reciba la suya.
--
-- POR QUE EXISTE. La vista vademecum_producto_comercial expone 553 etiquetas de
-- especie distintas para las mismas especies: 'Caninos y Felinos', 'Perros y
-- Gatos', 'Perros y gatos', 'Cánidos y felinos'... Con eso no se puede filtrar.
-- Peor: hay filas donde el campo especies no es una especie sino una prohibicion
-- ('No administrar a equinos destinados al consumo humano'). Si se filtra por
-- especie a ciegas se muestra una dosis justo donde la ficha la prohibe.
--
-- QUE HACE. Expone vademecum_producto_por_especie: una fila por producto,
-- especie canonica y categoria de animal, con la dosis que corresponde a esa
-- especie. La especie se deduce del texto de la ficha, no del orden de las
-- filas. Las dosis de Virbac ya vienen separadas por especie y categoria, y
-- entran sin tocarse.
--
-- LO QUE NO HACE. No inventa: si la ficha no nombra especie, la fila sale como
-- 'sin_especificar' en vez de asumir canino. Si la ficha prohibe la especie, la
-- fila sale con dosis_prohibida=true y sin dosis. No convierte la dosis en regla
-- clinica: todo sigue con habilitado_en_app=false.

begin;

create or replace function vetdosis_reference_staging.especies_canonicas(p_texto text)
returns text[] language sql immutable as $$
  select coalesce(array_agg(e order by e), '{}')
  from (
    select distinct e from (values
      ('canino',   'canin|perro|cánid|lobo'),
      ('felino',   'felino|gato|gata'),
      ('bovino',   'bovin|vacun|becerr|terner|vaquill|novill|cebú'),
      ('porcino',  'porcin|cerd|lechon|lechón|suino|marran'),
      ('equino',   'equin|caball|yegu|potr|mular|burro|asno'),
      ('ovino',    'ovin|ovej|cordero|borreg'),
      ('caprino',  'caprin|cabrit|cabra'),
      ('aviar',    'aviar|aves|ave|pollo|pollita|gallin|gallo|pavo|ponedor'),
      ('conejo',   'conejo|coneja|lagomorf'),
      ('camélido', 'camélid|camelid|alpaca|llama|vicuña'),
      ('acuícola', 'camarón|camaron|tilapia|pez|peces|acuícola'),
      ('roedor',   'ratón|raton|rata|roedor|hámster|hamster'),
      ('hurón',    'hurón|huron|furret')
    ) as t(e, patron)
    where p_texto ~* ('\m(' || patron || ')')
  ) x;
$$;

revoke all on function vetdosis_reference_staging.especies_canonicas(text) from public, anon, authenticated;

drop view if exists vetdosis_reference_staging.vademecum_producto_por_especie;

create view vetdosis_reference_staging.vademecum_producto_por_especie as
with texto as (
  select
    c.nombre_comercial, c.laboratorio, c.principios_activos, c.concentracion,
    c.presentacion, c.via_administracion, c.dosis_texto, c.dosis_cantidad,
    c.dosis_unidad, c.dosis_por_kg, c.intervalo,
    c.cantidad_fija, c.cantidad_fija_unidad, c.mezcla_valor, c.mezcla_unidad,
    c.frecuencia_horas, c.dosis_activos, c.tiempo_retiro,
    c.indicaciones, c.registro, c.documento_origen, c.pagina_origen, c.fuente,
    c.especies especies_originales,
    c.especies ~* '^(no administrar|prohibido|no aplicar|no se recomienda)' dosis_prohibida,
    null::text categoria_animal,
    vetdosis_reference_staging.especies_canonicas(c.especies) especies_detectadas,
    vetdosis_reference_staging.pauta_por_especie(c.dosis_texto) pautas
  from vetdosis_reference_staging.vademecum_producto_comercial c
  where c.fuente <> 'virbac_estructurada'
),
expandida as (
  select
    t.*,
    unnest(
      case
        when cardinality(t.especies_detectadas) = 0 then array['sin_especificar']
        else t.especies_detectadas
      end
    ) especie
  from texto t
),
texto_dedup as (
  -- Las pautas repiten la misma recomendacion en filas separadas; Virbac no.
  select distinct on (
    nombre_comercial, laboratorio, especie, coalesce(via_administracion,''),
    coalesce(dosis_texto,''), coalesce(dosis_por_kg, -1), coalesce(intervalo,''),
    coalesce(dosis_cantidad, -1), coalesce(dosis_unidad,''),
    coalesce(tiempo_retiro,''), dosis_prohibida, coalesce(cantidad_fija,-1),
    coalesce(mezcla_valor,-1), coalesce(pautas->especie, '{}'::jsonb)
  )
    nombre_comercial, laboratorio, principios_activos, concentracion,
    presentacion, especie, categoria_animal, especies_originales,
    via_administracion, dosis_texto, dosis_cantidad, dosis_unidad,
    dosis_por_kg, intervalo, cantidad_fija, cantidad_fija_unidad,
    mezcla_valor, mezcla_unidad, frecuencia_horas, dosis_activos, tiempo_retiro,
    indicaciones, registro, documento_origen, pagina_origen, fuente, dosis_prohibida,
    coalesce(pautas->especie, '{}'::jsonb) pauta_especie
  from expandida
  order by nombre_comercial, laboratorio, especie, coalesce(via_administracion,''),
           coalesce(dosis_texto,''), coalesce(dosis_por_kg, -1),
           coalesce(intervalo,''), coalesce(dosis_cantidad, -1),
           coalesce(dosis_unidad,''), coalesce(tiempo_retiro,''), dosis_prohibida
),
virbac as (
  select
    v.nombre_comercial, v.laboratorio, v.principios_activos, v.concentracion,
    v.presentacion,
    coalesce((vetdosis_reference_staging.especies_canonicas(v.especies))[1], 'sin_especificar') especie,
    v.categoria_animal,
    v.especies especies_originales,
    v.via_administracion, v.dosis_texto, v.dosis_cantidad, v.dosis_unidad,
    v.dosis_por_kg, v.intervalo, v.cantidad_fija, v.cantidad_fija_unidad,
    v.mezcla_valor, v.mezcla_unidad, v.frecuencia_horas, v.dosis_activos, v.tiempo_retiro,
    v.indicaciones, v.registro,
    v.documento_origen, v.pagina_origen, v.fuente,
    false dosis_prohibida,
    '{}'::jsonb pauta_especie
  from vetdosis_reference_staging.vademecum_producto_comercial v
  where v.fuente = 'virbac_estructurada'
)
select
  nombre_comercial, laboratorio, principios_activos, concentracion,
  presentacion, especie, categoria_animal, especies_originales, via_administracion,
  case when dosis_prohibida then null else dosis_texto end dosis_texto_original,
  case when dosis_prohibida then null
       else vetdosis_reference_staging.dosis_texto_limpio(dosis_texto) end dosis_texto,
  case when dosis_prohibida then null else pauta_especie->>'cantidad' end pauta_cantidad,
  case when dosis_prohibida then null else pauta_especie->>'unidad' end pauta_unidad,
  case when dosis_prohibida then null else pauta_especie->>'kg' end pauta_kg,
  case when dosis_prohibida then null else dosis_cantidad end dosis_cantidad,
  case when dosis_prohibida then null else dosis_unidad end dosis_unidad,
  case when dosis_prohibida then null else dosis_por_kg end dosis_por_kg,
  case when dosis_prohibida then null else intervalo end intervalo,
  case when dosis_prohibida then null else cantidad_fija end cantidad_fija,
  case when dosis_prohibida then null else cantidad_fija_unidad end cantidad_fija_unidad,
  case when dosis_prohibida then null else mezcla_valor end mezcla_valor,
  case when dosis_prohibida then null else mezcla_unidad end mezcla_unidad,
  case when dosis_prohibida then null else frecuencia_horas end frecuencia_horas,
  case when dosis_prohibida then null else dosis_activos end dosis_activos,
  tiempo_retiro, indicaciones, registro, documento_origen, pagina_origen,
  fuente, dosis_prohibida,
  'sin_verificar'::text estado_revision,
  false habilitado_en_app
from (
  select * from texto_dedup
  union all
  select * from virbac
) u;

revoke all on vetdosis_reference_staging.vademecum_producto_por_especie from public, anon, authenticated;

commit;

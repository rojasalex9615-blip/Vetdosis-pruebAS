-- Una sola tabla de fabricante, por nombre comercial, para el vademecum.
--
-- POR QUE EXISTE. Las dosis de fabricante estaban en tres fuentes que no se
-- hablaban y que la app exponia como catalogos paralelos:
--   1. private.vetdosis_inventario_comercial_revision (687 fichas, 12 labs,
--      dosis solo como texto). La lee review_catalog_list.
--   2. raw_intake_rows hoja 'Pautas' (1197 pautas, 693 nombres, 79 fabricantes,
--      con cantidad, unidad, referencia de peso, intervalo y tiempo de retiro).
--      La lee review_pauta_list.
--   3. Las cinco tablas de Virbac (34 productos, 64 dosis, 63 tiempos de espera),
--      que ninguna funcion leia.
-- Solo 81 nombres se solapan entre inventario y pautas, y Virbac no aparece en
-- pautas: son fuentes casi disjuntas, no duplicados.
--
-- QUE HACE. Expone una fila por pauta de fabricante, con el nombre comercial al
-- frente y la dosis ya normalizada: cantidad, unidad, dosis por kg, intervalo,
-- via, especie y tiempo de retiro. La columna `fuente` dice de donde viene cada
-- fila para poder rastrearla.
--
-- LO QUE NO HACE. No habilita nada para calculo: todo sale con
-- habilitado_en_app=false y estado 'sin_verificar'. No elige especie ni via
-- cuando el producto tiene varias. No valida la pauta ni la convierte en regla
-- clinica.

begin;

drop view if exists vetdosis_reference_staging.vademecum_producto_comercial cascade;
drop view if exists vetdosis_reference_staging.commercial_product_dose_unified;

create view vetdosis_reference_staging.vademecum_producto_comercial as
with inventario as (
  select
    i.nombre_comercial, i.laboratorio, i.principios_activos, i.concentracion,
    i.presentacion, i.especies, null::text categoria_animal, i.via_administracion,
    i.dosis_catalogo_texto dosis_texto,
    null::numeric dosis_cantidad, null::text dosis_unidad,
    null::numeric dosis_por_kg, null::text intervalo,
    null::numeric cantidad_fija, null::text cantidad_fija_unidad,
    null::numeric mezcla_valor, null::text mezcla_unidad,
    null::numeric frecuencia_horas, null::text dosis_activos,
    null::text tiempo_retiro,
    i.indicaciones, i.registro, i.documento_origen, i.pagina_origen,
    'inventario_comercial'::text fuente
  from private.vetdosis_inventario_comercial_revision i
  where i.laboratorio <> 'Virbac'
    -- Si la pauta trae el mismo nombre, manda la pauta: lleva especie, dosis
    -- por kg e intervalo, y el inventario solo trae texto libre.
    and not exists (
      select 1 from vetdosis_reference_staging.raw_intake_rows r
       where r.source_sheet = 'Pautas'
         and upper(btrim(r.original_payload->>'nombre_comercial')) = upper(btrim(i.nombre_comercial))
    )
),
pautas as (
  select
    btrim(r.original_payload->>'nombre_comercial') nombre_comercial,
    btrim(r.original_payload->>'fabricante') laboratorio,
    r.original_payload->>'principio_activo' principios_activos,
    (select i2.concentracion
       from private.vetdosis_inventario_comercial_revision i2
      where upper(btrim(i2.nombre_comercial)) = upper(btrim(r.original_payload->>'nombre_comercial'))
        and coalesce(i2.concentracion,'') <> ''
      limit 1) concentracion,
    r.original_payload->>'presentacion_exacta' presentacion,
    r.original_payload->>'especie' especies,
    null::text categoria_animal,
    r.original_payload->>'via' via_administracion,
    r.original_payload->>'posologia_literal' dosis_texto,
    case when r.original_payload->>'cantidad_admin' ~ '^[0-9]+(\.[0-9]+)?$'
         then (r.original_payload->>'cantidad_admin')::numeric end dosis_cantidad,
    r.original_payload->>'unidad_admin' dosis_unidad,
    case when r.original_payload->>'cantidad_admin' ~ '^[0-9]+(\.[0-9]+)?$'
          and substring(coalesce(r.original_payload->>'referencia','') from '([0-9]+(\.[0-9]+)?)\s*kg') is not null
         then (r.original_payload->>'cantidad_admin')::numeric
              / nullif((substring(coalesce(r.original_payload->>'referencia','') from '([0-9]+(\.[0-9]+)?)\s*kg'))::numeric, 0)
    end dosis_por_kg,
    nullif(r.original_payload->>'intervalo','') intervalo,
    null::numeric cantidad_fija, null::text cantidad_fija_unidad,
    null::numeric mezcla_valor, null::text mezcla_unidad,
    null::numeric frecuencia_horas, null::text dosis_activos,
    nullif(r.original_payload->>'tiempo_retiro','') tiempo_retiro,
    r.original_payload->>'indicacion' indicaciones,
    r.original_payload->>'registro_sanitario' registro,
    r.original_payload->>'url_plm' documento_origen,
    null::integer pagina_origen,
    'pauta_fabricante'::text fuente
  from vetdosis_reference_staging.raw_intake_rows r
  where r.source_sheet = 'Pautas'
    and coalesce(r.original_payload->>'nombre_comercial','') <> ''
),
virbac as (
  select
    p.nombre nombre_comercial, 'Virbac'::text laboratorio,
    (select string_agg(a.principio_activo, ' + ' order by a.principio_activo)
       from private.vetdosis_virbac_producto_activos a
      where a.producto_id = p.id) principios_activos,
    (select string_agg(a.principio_activo || ' ' || coalesce(a.cantidad::text,'') ||
                       coalesce(' ' || a.unidad,'') ||
                       coalesce(' por ' || a.por_cantidad::text || ' ' || coalesce(a.por_unidad,''),''),
                       '; ' order by a.principio_activo)
       from private.vetdosis_virbac_producto_activos a
      where a.producto_id = p.id) concentracion,
    p.presentaciones presentacion,
    d.especie especies, d.categoria_animal, d.via via_administracion,
    coalesce(d.nota, d.indicacion) dosis_texto,
    d.vol_cantidad dosis_cantidad, d.vol_unidad dosis_unidad,
    case when d.vol_peso_kg > 0 then d.vol_cantidad / d.vol_peso_kg end dosis_por_kg,
    case when d.frecuencia_horas is not null
         then 'cada ' || d.frecuencia_horas::text || ' h' end intervalo,
    d.cantidad_fija, d.cantidad_fija_unidad,
    d.mezcla_valor, d.mezcla_unidad,
    d.frecuencia_horas,
    (select string_agg(a.principio_activo || ' ' ||
                       coalesce(a.valor_min::text,'') ||
                       case when a.valor_max is not null and a.valor_max <> a.valor_min
                            then '-' || a.valor_max::text else '' end ||
                       ' ' || coalesce(a.unidad,''), '; ' order by a.principio_activo)
       from private.vetdosis_virbac_producto_dosis_activos a
      where a.dosis_id = d.id) dosis_activos,
    (select string_agg(t.especie || ' ' || t.matriz || ': ' ||
                       coalesce(t.valor::text || ' ' || t.unidad, 'no usar'), '; '
                       order by t.especie, t.matriz)
       from private.vetdosis_virbac_producto_tiempos_espera t
      where t.producto_id = p.id) tiempo_retiro,
    d.indicacion, p.registro, p.fuente, p.fuente_pagina,
    'virbac_estructurada'::text fuente
  from private.vetdosis_virbac_productos p
  join private.vetdosis_virbac_producto_dosis d on d.producto_id = p.id
)
select
  u.*,
  'sin_verificar'::text estado_revision,
  false habilitado_en_app
from (
  select * from inventario
  union all
  select * from pautas
  union all
  select * from virbac
) u;

revoke all on vetdosis_reference_staging.vademecum_producto_comercial from public, anon, authenticated;

commit;

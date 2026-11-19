-- Una sola tabla de fabricante, por nombre comercial, para el vademecum.
--
-- POR QUE EXISTE. Las dosis de fabricante estaban en sitios que no se hablaban:
-- el inventario comercial de 12 laboratorios (687 fichas, con la dosis solo
-- como texto) y las cinco tablas de Virbac (64 dosis y 63 tiempos de espera
-- estructurados, que ninguna funcion leia). Virbac era el unico con dosis por
-- kg, via e intervalo, y era justo el que la tabla unificada dejaba con
-- dosis_catalogo_texto vacio en sus 34 fichas.
--
-- QUE HACE. Expone una fila por ficha comercial con su dosis. El inventario
-- aporta sus 687 fichas tal cual; Virbac entra desde sus tablas estructuradas,
-- una fila por dosis, y sustituye a sus 34 fichas del inventario para no
-- duplicarlas. Marca seleccion_requerida cuando el mismo producto tiene varias
-- especies o vias, para que la calculadora no elija una en silencio.
--
-- LO QUE NO HACE. No habilita nada para calculo: todo sale con
-- habilitado_en_app=false y estado sin verificar. No valida la pauta ni la
-- convierte en regla clinica, y no rellena los tiempos de espera.

begin;

drop view if exists vetdosis_reference_staging.commercial_product_dose_unified;

create view vetdosis_reference_staging.commercial_product_dose_unified as
with inventario as (
  select
    i.laboratorio, i.nombre_comercial, i.principios_activos, i.concentracion,
    i.presentacion, i.especies, i.via_administracion, i.registro,
    i.dosis_catalogo_texto, i.indicaciones,
    i.documento_origen, i.pagina_origen,
    i.estado_revision, i.habilitado_en_app,
    null::text dosis_especie, null::text dosis_via,
    null::numeric dosis_por_kg, null::text dosis_unidad,
    null::numeric dosis_frecuencia_horas, null::text dosis_nota,
    false seleccion_requerida,
    'inventario_comercial'::text origen_dosis
  from private.vetdosis_inventario_comercial_revision i
  where i.laboratorio <> 'Virbac'
),
virbac_dosis as (
  select
    p.id producto_id, p.nombre nombre_comercial, p.presentaciones presentacion,
    array_to_string(p.especies_catalogo, ', ') especies, p.registro registro,
    p.fuente documento_origen, p.fuente_pagina pagina_origen,
    d.especie dosis_especie, d.via dosis_via,
    case when d.vol_peso_kg > 0 then d.vol_cantidad / d.vol_peso_kg end dosis_por_kg,
    d.vol_unidad dosis_unidad,
    d.frecuencia_horas dosis_frecuencia_horas,
    d.nota dosis_nota, d.nota dosis_catalogo_texto,
    d.requiere_revision
  from private.vetdosis_virbac_productos p
  join private.vetdosis_virbac_producto_dosis d on d.producto_id = p.id
),
virbac as (
  select
    'Virbac'::text laboratorio, v.nombre_comercial,
    (select string_agg(a.principio_activo, ' + ' order by a.principio_activo)
       from private.vetdosis_virbac_producto_activos a
      where a.producto_id = v.producto_id) principios_activos,
    (select string_agg(a.principio_activo || ' ' || coalesce(a.cantidad::text,'') ||
                       coalesce(' ' || a.unidad,'') ||
                       coalesce(' por ' || a.por_cantidad::text || ' ' || coalesce(a.por_unidad,''),''),
                       '; ' order by a.principio_activo)
       from private.vetdosis_virbac_producto_activos a
      where a.producto_id = v.producto_id) concentracion,
    v.presentacion, v.especies, v.dosis_via via_administracion, v.registro,
    v.dosis_catalogo_texto, null::text indicaciones,
    v.documento_origen, v.pagina_origen,
    'sin_verificar'::text estado_revision,
    false habilitado_en_app,
    v.dosis_especie, v.dosis_via,
    v.dosis_por_kg, v.dosis_unidad, v.dosis_frecuencia_horas, v.dosis_nota,
    (select count(distinct d2.especie || '|' || coalesce(d2.via,'')) > 1
       from private.vetdosis_virbac_producto_dosis d2
      where d2.producto_id = v.producto_id) seleccion_requerida,
    'virbac_estructurada'::text origen_dosis
  from virbac_dosis v
)
select * from inventario
union all
select * from virbac;

revoke all on vetdosis_reference_staging.commercial_product_dose_unified from public, anon, authenticated;

commit;

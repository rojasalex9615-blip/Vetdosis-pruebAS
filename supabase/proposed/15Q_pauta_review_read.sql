-- CANDIDATO LOCAL, NO APLICADO. Lectura de las pautas comerciales de Grok
-- (15P) para el modo revisión que ya existe en el servidor.
--
-- POR QUE EXISTE. Las 1197 pautas entran por 15P al staging con
-- review_state='pending'. Sin esta lectura, el modo revisión no las ve: hoy
-- review_catalog_list solo lee private.vetdosis_inventario_comercial_revision,
-- que son catálogos, no posología.
--
-- LO QUE NO HACE. No valida ninguna pauta, no activa reglas de cálculo y no
-- copia nada a las tablas que lee la app. Cada fila viaja con
-- review_status='sin_verificar' y enabled_in_app=false. Promover una pauta a
-- cálculo es decisión de un MVZ, no de una carga.
--
-- A QUIEN SIRVE. Al revisor de la clínica (rol admin o revisor) y al dueño de
-- plataforma. La función respeta el mismo permiso que review_catalog_list.
begin;

create or replace function public.review_pauta_list(
  p_clinic uuid, p_search text default null,
  p_limit integer default 100, p_offset integer default 0
) returns table(
  source_key text, product_name text, manufacturer text, product_url text,
  presentation text, registro text, ingredients text, species text, route text,
  rule text, literal text, dose_amount text, dose_unit text, dose_reference text,
  dose_interval text, duration text, withdrawal text, contraindications text,
  evidence_url text, state text, review_status text, enabled_in_app boolean,
  snapshot jsonb
) language plpgsql stable security definer set search_path = ''
as $$
begin
  if auth.uid() is null or not private.has_clinic_role(p_clinic,array['admin','revisor']) then
    raise exception 'review_access_denied' using errcode='42501';
  end if;
  -- La biblioteca de preparación puede no existir en un entorno limpio.
  if to_regclass('vetdosis_reference_staging.raw_intake_rows') is null then
    return;
  end if;
  return query execute $q$
    select ('grok_pautas:'||btrim(r.original_payload->>'id_pauta'))::text,
      btrim(coalesce(r.original_payload->>'nombre_comercial',''))::text,
      btrim(coalesce(r.original_payload->>'fabricante',''))::text,
      btrim(coalesce(r.original_payload->>'url_plm',''))::text,
      btrim(coalesce(r.original_payload->>'presentacion_exacta',''))::text,
      btrim(coalesce(r.original_payload->>'registro_sanitario',''))::text,
      btrim(coalesce(r.original_payload->>'principio_activo',''))::text,
      btrim(coalesce(r.original_payload->>'especie',''))::text,
      btrim(coalesce(r.original_payload->>'via',''))::text,
      btrim(coalesce(r.original_payload->>'tipo_regla',''))::text,
      btrim(coalesce(r.original_payload->>'posologia_literal',''))::text,
      btrim(coalesce(r.original_payload->>'cantidad_admin',''))::text,
      btrim(coalesce(r.original_payload->>'unidad_admin',''))::text,
      btrim(coalesce(r.original_payload->>'referencia',''))::text,
      btrim(coalesce(r.original_payload->>'intervalo',''))::text,
      btrim(coalesce(r.original_payload->>'duracion',''))::text,
      btrim(coalesce(r.original_payload->>'tiempo_retiro',''))::text,
      btrim(coalesce(r.original_payload->>'contraindicaciones',''))::text,
      btrim(coalesce(r.original_payload->>'url_evidencia',''))::text,
      btrim(coalesce(r.original_payload->>'estado_pauta',''))::text,
      'sin_verificar'::text, false,
      r.original_payload
    from vetdosis_reference_staging.raw_intake_rows r
    where r.source_filename = 'Pautas_VetDosis_MAESTRO.csv'
      and ($1 is null or btrim($1)='' or
        concat_ws(' ',r.original_payload->>'nombre_comercial',
          r.original_payload->>'fabricante',r.original_payload->>'principio_activo',
          r.original_payload->>'especie')
          ilike '%'||btrim($1)||'%')
    order by r.original_payload->>'fabricante',
      r.original_payload->>'nombre_comercial', r.original_payload->>'id_pauta'
    limit least(greatest(coalesce($2,100),1),200)
    offset greatest(coalesce($3,0),0)
  $q$ using p_search, p_limit, p_offset;
end;
$$;
revoke all on function public.review_pauta_list(uuid,text,integer,integer)
  from public, anon;
grant execute on function public.review_pauta_list(uuid,text,integer,integer)
  to authenticated;

commit;

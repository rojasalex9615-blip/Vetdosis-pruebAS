-- CANDIDATO LOCAL. Puente entre el modo revisión y las pautas comerciales de
-- Grok (15P/15Q). Hasta ahora review_pauta_list existía pero nadie lo llamaba:
-- la pantalla lee review_catalog_list (solo catálogo comercial) y las funciones
-- de escritura resolvían la clave contra vetdosis_inventario_comercial_revision.
--
-- QUÉ HACE. (1) Admite la fuente 'grok_pautas' en las tablas de estado.
-- (2) Reescribe review_pauta_list para devolver la MISMA forma que
-- review_catalog_list, con el estado real de cada ámbito, para que la pantalla
-- y su modelo no cambien. (3) Enseña a las tres funciones de escritura a
-- resolver y guardar una pauta. (4) Hace que review_catalog_progress cuente por
-- fuente. (5) Añade private.catalog_review_global_status: el catálogo comercial
-- guarda su estado global en una columna de su propia tabla, que las pautas no
-- tienen.
--
-- CLAVE. source_key = 'grok_pautas:'||row_key. NO se usa id_pauta: tiene dos
-- duplicados exactos en el lote (HEMOSTOPK-...), y row_key es único.
--
-- LO QUE NO HACE. No valida nada por sí sola, no activa reglas de cálculo y no
-- copia posología a las tablas que usa la calculadora.
begin;

-- (1) Las tablas de estado solo admitían el catálogo comercial.
alter table private.catalog_review_clinic_status
  drop constraint if exists catalog_review_clinic_status_source_catalog_check,
  add constraint catalog_review_clinic_status_source_catalog_check
    check (source_catalog in ('inventario_comercial','grok_pautas'));
alter table private.catalog_review_personal_status
  drop constraint if exists catalog_review_personal_status_source_catalog_check,
  add constraint catalog_review_personal_status_source_catalog_check
    check (source_catalog in ('inventario_comercial','grok_pautas'));
alter table private.catalog_review_scoped_history
  drop constraint if exists catalog_review_scoped_history_source_catalog_check,
  add constraint catalog_review_scoped_history_source_catalog_check
    check (source_catalog in ('inventario_comercial','grok_pautas'));
alter table public.catalog_review_reports
  drop constraint if exists catalog_review_reports_source_catalog_check,
  add constraint catalog_review_reports_source_catalog_check
    check (source_catalog in ('inventario_comercial','grok_pautas'));

-- (5) Estado global de una fuente que no tiene columna propia.
create table if not exists private.catalog_review_global_status (
  source_catalog text not null
    check (source_catalog in ('inventario_comercial','grok_pautas')),
  source_key text not null check (length(btrim(source_key)) between 1 and 300),
  catalog_version text not null,
  status text not null
    check (status in ('sin_verificar','revisar_conflicto','validado','descartado')),
  updated_by uuid not null references auth.users(id),
  updated_at timestamptz not null default now(),
  primary key (source_catalog, source_key)
);
alter table private.catalog_review_global_status enable row level security;
revoke all on private.catalog_review_global_status from public, anon, authenticated;

-- (2) Lectura. Se retira la versión de 15Q (otra forma de tabla) y se vuelve a
-- crear con la forma de review_catalog_list.
drop function if exists public.review_pauta_list(uuid,text,integer,integer);
create or replace function public.review_pauta_list(
  p_clinic uuid, p_search text default null,
  p_limit integer default 100, p_offset integer default 0
) returns table(
  source_key text, catalog_version text, title text, laboratory text,
  active_ingredients text, concentration text, presentation text, species text,
  route text, catalog_dose_text text, indications text, source_document text,
  source_page integer, review_status text, enabled_in_app boolean, snapshot jsonb,
  global_review_status text, clinic_review_status text, personal_review_status text
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
  return query
  with pauta as (
    select ('grok_pautas:'||r.row_key)::text as source_key,
      'pautas_grok_1197_20261115'::text as catalog_version,
      btrim(coalesce(r.original_payload->>'nombre_comercial',''))::text as title,
      btrim(coalesce(r.original_payload->>'fabricante',''))::text as laboratory,
      btrim(coalesce(r.original_payload->>'principio_activo',''))::text as active_ingredients,
      btrim(coalesce(r.original_payload->>'presentacion_exacta',''))::text as presentation,
      btrim(coalesce(r.original_payload->>'especie',''))::text as species,
      btrim(coalesce(r.original_payload->>'via',''))::text as route,
      btrim(coalesce(r.original_payload->>'posologia_literal',''))::text as catalog_dose_text,
      btrim(coalesce(r.original_payload->>'tipo_regla',''))::text as rule,
      btrim(coalesce(r.original_payload->>'contraindicaciones',''))::text as indications,
      btrim(coalesce(r.original_payload->>'url_evidencia',''))::text as source_document,
      r.original_payload as snapshot
    from vetdosis_reference_staging.raw_intake_rows r
    where r.source_filename = 'Pautas_VetDosis_MAESTRO.csv'
  )
  select p.source_key, p.catalog_version, p.title, p.laboratory,
    p.active_ingredients, null::text, p.presentation, p.species, p.route,
    p.catalog_dose_text, p.indications, p.source_document, null::integer,
    coalesce(cs.status,'sin_verificar')::text, false, p.snapshot,
    coalesce(gs.status,'sin_verificar')::text,
    coalesce(cs.status,'sin_verificar')::text,
    coalesce(ps.status,'sin_verificar')::text
  from pauta p
  left join private.catalog_review_global_status gs
    on gs.source_catalog='grok_pautas' and gs.source_key=p.source_key
  left join private.catalog_review_clinic_status cs
    on cs.clinic_id=p_clinic and cs.source_catalog='grok_pautas'
    and cs.source_key=p.source_key
  left join private.catalog_review_personal_status ps
    on ps.user_id=auth.uid() and ps.source_catalog='grok_pautas'
    and ps.source_key=p.source_key
  where (p_search is null or btrim(p_search)='' or
      concat_ws(' ',p.title,p.laboratory,p.active_ingredients,p.species)
        ilike '%'||btrim(p_search)||'%')
  order by p.laboratory, p.title, p.source_key
  limit least(greatest(coalesce(p_limit,100),1),200)
  offset greatest(coalesce(p_offset,0),0);
end;
$$;
revoke all on function public.review_pauta_list(uuid,text,integer,integer)
  from public, anon;
grant execute on function public.review_pauta_list(uuid,text,integer,integer)
  to authenticated;

-- (3a) Escritura de clínica.
create or replace function public.review_catalog_set_status(
  p_clinic uuid, p_source_key text, p_new_status text
) returns void language plpgsql security definer set search_path = ''
as $$
declare v_previous text; v_version text; v_catalog text;
begin
  if auth.uid() is null or not private.has_clinic_role(p_clinic, array['admin']) then
    raise exception 'review_admin_required' using errcode = '42501';
  end if;
  if p_new_status is null or p_new_status not in ('sin_verificar','en_revision','verificado','corregido','rechazado') then
    raise exception 'invalid_review_status' using errcode = '22023';
  end if;
  if p_source_key is null or length(btrim(p_source_key)) not between 1 and 300 then
    raise exception 'invalid_source_key' using errcode = '22023';
  end if;
  if p_source_key like 'grok_pautas:%' then
    v_catalog := 'grok_pautas';
    select 'pautas_grok_1197_20261115' into v_version
    from vetdosis_reference_staging.raw_intake_rows r
    where ('grok_pautas:'||r.row_key) = p_source_key;
  else
    v_catalog := 'inventario_comercial';
    select coalesce(r.documento_origen,'sin_version') into v_version
    from private.vetdosis_inventario_comercial_revision r
    where concat_ws(':',r.fuente_sistema,r.id_fuente) = p_source_key;
  end if;
  if v_version is null then
    raise exception 'review_item_not_found' using errcode = 'P0002';
  end if;

  select s.status into v_previous
  from private.catalog_review_clinic_status s
  where s.clinic_id = p_clinic and s.source_catalog = v_catalog
    and s.source_key = p_source_key for update;
  if v_previous is not distinct from p_new_status then return; end if;
  insert into private.catalog_review_clinic_status(
    clinic_id,source_catalog,source_key,catalog_version,status,updated_by,updated_at
  ) values (p_clinic,v_catalog,p_source_key,v_version,p_new_status,auth.uid(),now())
  on conflict (clinic_id,source_catalog,source_key) do update
    set catalog_version=excluded.catalog_version,status=excluded.status,
        updated_by=excluded.updated_by,updated_at=now();

  insert into private.catalog_review_scoped_history(
    scope,clinic_id,source_catalog,source_key,catalog_version,previous_status,new_status,actor_id
  ) values ('clinic',p_clinic,v_catalog,p_source_key,v_version,
    coalesce(v_previous,'sin_verificar'),p_new_status,auth.uid());
end;
$$;
revoke all on function public.review_catalog_set_status(uuid,text,text)
  from public, anon;
grant execute on function public.review_catalog_set_status(uuid,text,text)
  to authenticated;

-- (3b) Escritura personal.
create or replace function public.review_catalog_set_personal_status(
  p_source_key text, p_new_status text
) returns void language plpgsql security definer set search_path = ''
as $$
declare v_previous text; v_version text; v_catalog text;
begin
  if auth.uid() is null then raise exception 'authentication_required' using errcode='42501'; end if;
  if p_new_status is null or p_new_status not in ('sin_verificar','en_revision','verificado','corregido','rechazado') then
    raise exception 'invalid_review_status' using errcode='22023';
  end if;
  if p_source_key is null or length(btrim(p_source_key)) not between 1 and 300 then
    raise exception 'invalid_source_key' using errcode='22023';
  end if;
  if p_source_key like 'grok_pautas:%' then
    v_catalog := 'grok_pautas';
    select 'pautas_grok_1197_20261115' into v_version
    from vetdosis_reference_staging.raw_intake_rows r
    where ('grok_pautas:'||r.row_key) = p_source_key;
  else
    v_catalog := 'inventario_comercial';
    select coalesce(r.documento_origen,'sin_version') into v_version
    from private.vetdosis_inventario_comercial_revision r
    where concat_ws(':',r.fuente_sistema,r.id_fuente) = p_source_key;
  end if;
  if v_version is null then
    raise exception 'review_item_not_found' using errcode = 'P0002';
  end if;

  select s.status into v_previous from private.catalog_review_personal_status s
  where s.user_id=auth.uid() and s.source_catalog=v_catalog
    and s.source_key=p_source_key for update;
  if v_previous is not distinct from p_new_status then return; end if;
  insert into private.catalog_review_personal_status(
    user_id,source_catalog,source_key,catalog_version,status,updated_at
  ) values(auth.uid(),v_catalog,p_source_key,v_version,p_new_status,now())
  on conflict(user_id,source_catalog,source_key) do update
    set catalog_version=excluded.catalog_version,status=excluded.status,updated_at=now();
  insert into private.catalog_review_scoped_history(
    scope,user_id,source_catalog,source_key,catalog_version,previous_status,new_status,actor_id
  ) values('personal',auth.uid(),v_catalog,p_source_key,v_version,
    coalesce(v_previous,'sin_verificar'),p_new_status,auth.uid());
end;
$$;
revoke all on function public.review_catalog_set_personal_status(text,text)
  from public, anon;
grant execute on function public.review_catalog_set_personal_status(text,text)
  to authenticated;

-- (3c) Escritura global. Las pautas no tienen columna de estado en su tabla de
-- origen, así que usan private.catalog_review_global_status.
create or replace function public.review_catalog_set_global_status(
  p_source_key text, p_new_status text
) returns void language plpgsql security definer set search_path = ''
as $$
declare
  v_previous text; v_version text; v_source text; v_id text; v_rows integer;
begin
  if auth.uid() is null or not private.is_catalog_platform_owner() then
    raise exception 'platform_catalog_owner_required' using errcode='42501';
  end if;
  if p_new_status is null or p_new_status not in ('sin_verificar','revisar_conflicto','validado','descartado') then
    raise exception 'invalid_review_status' using errcode='22023';
  end if;
  if p_source_key is null or length(btrim(p_source_key)) not between 1 and 300
     or position(':' in p_source_key) < 2 then
    raise exception 'invalid_source_key' using errcode='22023';
  end if;
  v_source := split_part(p_source_key,':',1);
  v_id := substr(p_source_key,length(v_source)+2);

  if v_source = 'grok_pautas' then
    select 'pautas_grok_1197_20261115',
      coalesce(gs.status,'sin_verificar') into v_version,v_previous
    from vetdosis_reference_staging.raw_intake_rows r
    left join private.catalog_review_global_status gs
      on gs.source_catalog='grok_pautas' and gs.source_key=p_source_key
    where r.row_key = v_id;
    if not found then raise exception 'review_item_not_found' using errcode='P0002'; end if;
    if v_previous = p_new_status then return; end if;
    insert into private.catalog_review_global_status(
      source_catalog,source_key,catalog_version,status,updated_by,updated_at
    ) values('grok_pautas',p_source_key,v_version,p_new_status,auth.uid(),now())
    on conflict(source_catalog,source_key) do update
      set catalog_version=excluded.catalog_version,status=excluded.status,
          updated_by=excluded.updated_by,updated_at=now();
    insert into private.catalog_review_scoped_history(
      scope,source_catalog,source_key,catalog_version,previous_status,new_status,actor_id
    ) values('global','grok_pautas',p_source_key,v_version,v_previous,p_new_status,auth.uid());
    return;
  end if;

  select coalesce(r.estado_revision,'sin_verificar'),coalesce(r.documento_origen,'sin_version')
    into v_previous,v_version
  from private.vetdosis_inventario_comercial_revision r
  where r.fuente_sistema=v_source and r.id_fuente=v_id;
  if not found then raise exception 'review_item_not_found' using errcode='P0002'; end if;
  if v_previous=p_new_status then return; end if;

  if v_source = 'grok_catalogos' then
    update private.vetdosis_catalogos_laboratorios_revision
      set estado_revision=p_new_status where id=v_id::bigint;
  elsif v_source = 'grok_mederilab' then
    update private.vetdosis_mederilab_catalogo_revision
      set estado_revision=p_new_status where id=v_id::bigint;
  elsif v_source = 'grok_zoetis_holland' then
    update private.vetdosis_zoetis_holland_catalogo_revision
      set estado_revision=p_new_status where id=v_id::bigint;
  elsif v_source = 'claude_virbac' then
    update private.vetdosis_virbac_productos
      set estado=case when p_new_status='sin_verificar' then 'sin verificar' else p_new_status end
      where id=v_id;
  else
    raise exception 'unsupported_catalog_source' using errcode='22023';
  end if;
  get diagnostics v_rows = row_count;
  if v_rows <> 1 then raise exception 'review_item_not_found' using errcode='P0002'; end if;

  insert into private.catalog_review_scoped_history(
    scope,source_catalog,source_key,catalog_version,previous_status,new_status,actor_id
  ) values('global','inventario_comercial',p_source_key,v_version,v_previous,p_new_status,auth.uid());
end;
$$;
revoke all on function public.review_catalog_set_global_status(text,text)
  from public, anon;
grant execute on function public.review_catalog_set_global_status(text,text)
  to authenticated;

-- (4) Progreso por fuente.
create or replace function public.review_catalog_progress(
  p_clinic uuid, p_source text
) returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare v_global jsonb; v_clinic jsonb; v_personal jsonb;
begin
  if auth.uid() is null or not private.has_clinic_role(p_clinic,array['admin','revisor']) then
    raise exception 'review_access_denied' using errcode='42501';
  end if;
  if p_source is null or p_source not in ('inventario_comercial','grok_pautas') then
    raise exception 'invalid_review_source' using errcode='22023';
  end if;

  if p_source = 'grok_pautas' then
    if to_regclass('vetdosis_reference_staging.raw_intake_rows') is null then
      return jsonb_build_object('total',0,'sin_verificar',0,'en_revision',0,
        'verificado',0,'corregido',0,'rechazado',0,
        'clinic',jsonb_build_object('total',0,'sin_verificar',0,'en_revision',0,
          'verificado',0,'corregido',0,'rechazado',0),
        'global',jsonb_build_object('total',0,'sin_verificar',0,'revisar_conflicto',0,
          'validado',0,'descartado',0),
        'personal',jsonb_build_object('total',0,'sin_verificar',0,'en_revision',0,
          'verificado',0,'corregido',0,'rechazado',0));
    end if;
    select jsonb_build_object(
      'total',count(*),
      'sin_verificar',count(*) filter(where coalesce(s.status,'sin_verificar')='sin_verificar'),
      'en_revision',count(*) filter(where s.status='en_revision'),
      'verificado',count(*) filter(where s.status='verificado'),
      'corregido',count(*) filter(where s.status='corregido'),
      'rechazado',count(*) filter(where s.status='rechazado')
    ) into v_clinic
    from vetdosis_reference_staging.raw_intake_rows r
    left join private.catalog_review_clinic_status s
      on s.clinic_id=p_clinic and s.source_catalog='grok_pautas'
      and s.source_key=('grok_pautas:'||r.row_key)
    where r.source_filename='Pautas_VetDosis_MAESTRO.csv';
    select jsonb_build_object(
      'total',count(*),
      'sin_verificar',count(*) filter(where coalesce(g.status,'sin_verificar')='sin_verificar'),
      'revisar_conflicto',count(*) filter(where g.status='revisar_conflicto'),
      'validado',count(*) filter(where g.status='validado'),
      'descartado',count(*) filter(where g.status='descartado')
    ) into v_global
    from vetdosis_reference_staging.raw_intake_rows r
    left join private.catalog_review_global_status g
      on g.source_catalog='grok_pautas' and g.source_key=('grok_pautas:'||r.row_key)
    where r.source_filename='Pautas_VetDosis_MAESTRO.csv';
    select jsonb_build_object(
      'total',count(*),
      'sin_verificar',count(*) filter(where coalesce(s.status,'sin_verificar')='sin_verificar'),
      'en_revision',count(*) filter(where s.status='en_revision'),
      'verificado',count(*) filter(where s.status='verificado'),
      'corregido',count(*) filter(where s.status='corregido'),
      'rechazado',count(*) filter(where s.status='rechazado')
    ) into v_personal
    from vetdosis_reference_staging.raw_intake_rows r
    left join private.catalog_review_personal_status s
      on s.user_id=auth.uid() and s.source_catalog='grok_pautas'
      and s.source_key=('grok_pautas:'||r.row_key)
    where r.source_filename='Pautas_VetDosis_MAESTRO.csv';
  else
    select jsonb_build_object(
      'total',count(*),
      'sin_verificar',count(*) filter(where coalesce(s.status,'sin_verificar')='sin_verificar'),
      'en_revision',count(*) filter(where s.status='en_revision'),
      'verificado',count(*) filter(where s.status='verificado'),
      'corregido',count(*) filter(where s.status='corregido'),
      'rechazado',count(*) filter(where s.status='rechazado')
    ) into v_clinic
    from private.vetdosis_inventario_comercial_revision r
    left join private.catalog_review_clinic_status s
      on s.clinic_id=p_clinic and s.source_key=concat_ws(':',r.fuente_sistema,r.id_fuente);
    select jsonb_build_object(
      'total',count(*),
      'sin_verificar',count(*) filter(where coalesce(r.estado_revision,'sin_verificar')='sin_verificar'),
      'revisar_conflicto',count(*) filter(where r.estado_revision='revisar_conflicto'),
      'validado',count(*) filter(where r.estado_revision='validado'),
      'descartado',count(*) filter(where r.estado_revision='descartado')
    ) into v_global from private.vetdosis_inventario_comercial_revision r;
    select jsonb_build_object(
      'total',count(*),
      'sin_verificar',count(*) filter(where status='sin_verificar'),
      'en_revision',count(*) filter(where status='en_revision'),
      'verificado',count(*) filter(where status='verificado'),
      'corregido',count(*) filter(where status='corregido'),
      'rechazado',count(*) filter(where status='rechazado')
    ) into v_personal from private.catalog_review_personal_status
    where user_id=auth.uid() and source_catalog='inventario_comercial';
  end if;

  return jsonb_build_object(
    'total',v_clinic->'total',
    'sin_verificar',v_clinic->'sin_verificar',
    'en_revision',v_clinic->'en_revision',
    'verificado',v_clinic->'verificado',
    'corregido',v_clinic->'corregido',
    'rechazado',v_clinic->'rechazado',
    'clinic',v_clinic,'global',v_global,'personal',v_personal
  );
end;
$$;
revoke all on function public.review_catalog_progress(uuid,text)
  from public, anon;
grant execute on function public.review_catalog_progress(uuid,text)
  to authenticated;
-- La firma anterior (solo clinic) queda como envoltorio para no romper clientes.
create or replace function public.review_catalog_progress(p_clinic uuid)
returns jsonb language sql stable security definer set search_path = ''
as $$ select public.review_catalog_progress(p_clinic,'inventario_comercial'); $$;
revoke all on function public.review_catalog_progress(uuid) from public, anon;
grant execute on function public.review_catalog_progress(uuid) to authenticated;

commit;

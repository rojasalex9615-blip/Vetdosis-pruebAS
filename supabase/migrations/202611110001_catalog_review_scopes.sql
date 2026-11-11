-- Catalog review scopes: platform, clinic and personal are independent.
-- Bootstrap the confirmed platform owner; do not grant client-side table writes.
begin;

create table if not exists private.catalog_platform_owners (
  user_id uuid primary key references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);
revoke all on private.catalog_platform_owners from public, anon, authenticated;
-- Platform owners are provisioned as an explicit, project-specific ops step.
-- Do not grant global catalog authority from a versioned schema migration.

create or replace function private.is_catalog_platform_owner()
returns boolean language sql stable security definer set search_path = ''
as $$
  select auth.uid() is not null and exists (
    select 1 from private.catalog_platform_owners o where o.user_id = auth.uid()
  );
$$;
revoke all on function private.is_catalog_platform_owner() from public, anon;
grant execute on function private.is_catalog_platform_owner() to authenticated;

create table if not exists private.catalog_review_clinic_status (
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  source_catalog text not null default 'inventario_comercial'
    check (source_catalog = 'inventario_comercial'),
  source_key text not null check (length(btrim(source_key)) between 1 and 300),
  catalog_version text not null,
  status text not null check (status in ('sin_verificar','en_revision','verificado','corregido','rechazado')),
  updated_by uuid not null references auth.users(id),
  updated_at timestamptz not null default now(),
  primary key (clinic_id, source_catalog, source_key)
);

create table if not exists private.catalog_review_personal_status (
  user_id uuid not null references auth.users(id) on delete cascade,
  source_catalog text not null default 'inventario_comercial'
    check (source_catalog = 'inventario_comercial'),
  source_key text not null check (length(btrim(source_key)) between 1 and 300),
  catalog_version text not null,
  status text not null check (status in ('sin_verificar','en_revision','verificado','corregido','rechazado')),
  updated_at timestamptz not null default now(),
  primary key (user_id, source_catalog, source_key)
);

create table if not exists private.catalog_review_scoped_history (
  id uuid primary key default gen_random_uuid(),
  scope text not null check (scope in ('global','clinic','personal')),
  clinic_id uuid references public.clinics(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  source_catalog text not null default 'inventario_comercial'
    check (source_catalog = 'inventario_comercial'),
  source_key text not null check (length(btrim(source_key)) between 1 and 300),
  catalog_version text not null,
  previous_status text,
  new_status text not null,
  actor_id uuid not null references auth.users(id),
  changed_at timestamptz not null default now(),
  constraint catalog_review_scoped_history_target check (
    (scope = 'global' and clinic_id is null and user_id is null) or
    (scope = 'clinic' and clinic_id is not null and user_id is null) or
    (scope = 'personal' and clinic_id is null and user_id is not null)
  ),
  constraint catalog_review_scoped_history_status check (
    new_status in ('sin_verificar','en_revision','verificado','corregido','rechazado')
  )
);
create index if not exists catalog_review_scoped_history_clinic_idx
  on private.catalog_review_scoped_history(clinic_id, changed_at desc)
  where scope = 'clinic';
create index if not exists catalog_review_scoped_history_user_idx
  on private.catalog_review_scoped_history(user_id, changed_at desc)
  where scope = 'personal';
create index if not exists catalog_review_scoped_history_global_idx
  on private.catalog_review_scoped_history(changed_at desc)
  where scope = 'global';

alter table private.catalog_review_clinic_status enable row level security;
alter table private.catalog_review_personal_status enable row level security;
alter table private.catalog_review_scoped_history enable row level security;
revoke all on private.catalog_review_clinic_status,
  private.catalog_review_personal_status,
  private.catalog_review_scoped_history from public, anon, authenticated;
revoke all on private.vetdosis_inventario_comercial_revision from anon, authenticated;

create or replace function public.review_catalog_set_status(
  p_clinic uuid, p_source_key text, p_new_status text
) returns void language plpgsql security definer set search_path = ''
as $$
declare
  v_previous text;
  v_version text;
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
  select coalesce(r.documento_origen,'sin_version')
    into v_version
  from private.vetdosis_inventario_comercial_revision r
  where concat_ws(':',r.fuente_sistema,r.id_fuente) = p_source_key;
  if not found then raise exception 'review_item_not_found' using errcode = 'P0002'; end if;

  select s.status into v_previous
  from private.catalog_review_clinic_status s
  where s.clinic_id = p_clinic and s.source_catalog = 'inventario_comercial'
    and s.source_key = p_source_key for update;

  if v_previous is not distinct from p_new_status then return; end if;
  insert into private.catalog_review_clinic_status(
    clinic_id,source_catalog,source_key,catalog_version,status,updated_by,updated_at
  ) values (p_clinic,'inventario_comercial',p_source_key,v_version,p_new_status,auth.uid(),now())
  on conflict (clinic_id,source_catalog,source_key) do update
    set catalog_version=excluded.catalog_version,status=excluded.status,
        updated_by=excluded.updated_by,updated_at=now();

  insert into private.catalog_review_scoped_history(
    scope,clinic_id,source_catalog,source_key,catalog_version,previous_status,new_status,actor_id
  ) values ('clinic',p_clinic,'inventario_comercial',p_source_key,v_version,
    coalesce(v_previous,'sin_verificar'),p_new_status,auth.uid());
end;
$$;

create or replace function public.review_catalog_set_personal_status(
  p_source_key text, p_new_status text
) returns void language plpgsql security definer set search_path = ''
as $$
declare v_previous text; v_version text;
begin
  if auth.uid() is null then raise exception 'authentication_required' using errcode='42501'; end if;
  if p_new_status is null or p_new_status not in ('sin_verificar','en_revision','verificado','corregido','rechazado') then
    raise exception 'invalid_review_status' using errcode='22023';
  end if;
  if p_source_key is null or length(btrim(p_source_key)) not between 1 and 300 then
    raise exception 'invalid_source_key' using errcode='22023';
  end if;
  select coalesce(r.documento_origen,'sin_version') into v_version
  from private.vetdosis_inventario_comercial_revision r
  where concat_ws(':',r.fuente_sistema,r.id_fuente)=p_source_key;
  if not found then raise exception 'review_item_not_found' using errcode='P0002'; end if;
  select s.status into v_previous from private.catalog_review_personal_status s
  where s.user_id=auth.uid() and s.source_catalog='inventario_comercial'
    and s.source_key=p_source_key for update;
  if v_previous is not distinct from p_new_status then return; end if;
  insert into private.catalog_review_personal_status(
    user_id,source_catalog,source_key,catalog_version,status,updated_at
  ) values(auth.uid(),'inventario_comercial',p_source_key,v_version,p_new_status,now())
  on conflict(user_id,source_catalog,source_key) do update
    set catalog_version=excluded.catalog_version,status=excluded.status,updated_at=now();
  insert into private.catalog_review_scoped_history(
    scope,user_id,source_catalog,source_key,catalog_version,previous_status,new_status,actor_id
  ) values('personal',auth.uid(),'inventario_comercial',p_source_key,v_version,
    coalesce(v_previous,'sin_verificar'),p_new_status,auth.uid());
end;
$$;

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
  if p_new_status is null or p_new_status not in ('sin_verificar','en_revision','verificado','corregido','rechazado') then
    raise exception 'invalid_review_status' using errcode='22023';
  end if;
  if p_source_key is null or length(btrim(p_source_key)) not between 1 and 300
     or position(':' in p_source_key) < 2 then
    raise exception 'invalid_source_key' using errcode='22023';
  end if;
  v_source := split_part(p_source_key,':',1);
  v_id := substr(p_source_key,length(v_source)+2);
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
      set estado=p_new_status where id=v_id;
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
revoke all on function public.review_catalog_set_global_status(text,text) from public, anon;
grant execute on function public.review_catalog_set_global_status(text,text) to authenticated;

drop function if exists public.review_catalog_list(uuid,text,text,integer,integer);
create function public.review_catalog_list(
  p_clinic uuid, p_status text default null, p_search text default null,
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
  if p_status is not null and p_status not in ('sin_verificar','en_revision','verificado','corregido','rechazado') then
    raise exception 'invalid_review_status' using errcode='22023';
  end if;
  return query
  select concat_ws(':',r.fuente_sistema,r.id_fuente)::text,
    coalesce(r.documento_origen,'sin_version')::text,r.nombre_comercial::text,
    r.laboratorio::text,r.principios_activos::text,r.concentracion::text,
    r.presentacion::text,r.especies::text,r.via_administracion::text,
    r.dosis_catalogo_texto::text,r.indicaciones::text,r.documento_origen::text,
    r.pagina_origen,
    coalesce(cs.status,'sin_verificar')::text,
    coalesce(r.habilitado_en_app,false),
    jsonb_build_object(
      'fuente_sistema',r.fuente_sistema,'id_fuente',r.id_fuente,
      'laboratorio',r.laboratorio,'nombre_comercial',r.nombre_comercial,
      'principios_activos',r.principios_activos,'concentracion',r.concentracion,
      'presentacion',r.presentacion,'especies',r.especies,'registro',r.registro,
      'jurisdiccion_registro',r.jurisdiccion_registro,'via_administracion',r.via_administracion,
      'dosis_catalogo_texto',r.dosis_catalogo_texto,'indicaciones',r.indicaciones,
      'documento_origen',r.documento_origen,'pagina_origen',r.pagina_origen,
      'habilitado_en_app',r.habilitado_en_app,'alerta_formato',r.alerta_formato
    ),
    coalesce(r.estado_revision,'sin_verificar')::text,
    coalesce(cs.status,'sin_verificar')::text,
    coalesce(ps.status,'sin_verificar')::text
  from private.vetdosis_inventario_comercial_revision r
  left join private.catalog_review_clinic_status cs
    on cs.clinic_id=p_clinic and cs.source_catalog='inventario_comercial'
    and cs.source_key=concat_ws(':',r.fuente_sistema,r.id_fuente)
  left join private.catalog_review_personal_status ps
    on ps.user_id=auth.uid() and ps.source_catalog='inventario_comercial'
    and ps.source_key=concat_ws(':',r.fuente_sistema,r.id_fuente)
  where (p_status is null or coalesce(cs.status,'sin_verificar')=p_status)
    and (p_search is null or btrim(p_search)='' or
      concat_ws(' ',r.nombre_comercial,r.laboratorio,r.principios_activos,r.especies)
        ilike '%'||btrim(p_search)||'%')
  order by r.laboratorio,r.nombre_comercial,r.fuente_sistema,r.id_fuente
  limit least(greatest(coalesce(p_limit,100),1),200)
  offset greatest(coalesce(p_offset,0),0);
end;
$$;

create or replace function public.review_catalog_progress(p_clinic uuid)
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare v_global jsonb; v_clinic jsonb; v_personal jsonb;
begin
  if auth.uid() is null or not private.has_clinic_role(p_clinic,array['admin','revisor']) then
    raise exception 'review_access_denied' using errcode='42501';
  end if;
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
    'en_revision',count(*) filter(where r.estado_revision='en_revision'),
    'verificado',count(*) filter(where r.estado_revision='verificado'),
    'corregido',count(*) filter(where r.estado_revision='corregido'),
    'rechazado',count(*) filter(where r.estado_revision='rechazado'),
    'revisar_conflicto',count(*) filter(where r.estado_revision='revisar_conflicto')
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

create or replace function public.review_report_export(
  p_clinic uuid, p_reviewer uuid default null, p_module text default null, p_status text default null
) returns table(
  report_id uuid, reviewer_id uuid, module text, source_key text, title text,
  laboratory text, review_status text, catalog_version text, observed_value text,
  expected_value text, source_reference text, comment text, created_at timestamptz
) language plpgsql stable security definer set search_path = ''
as $$
declare v_admin boolean;
begin
  v_admin := private.has_clinic_role(p_clinic,array['admin']);
  if auth.uid() is null or not private.has_clinic_role(p_clinic,array['admin','revisor']) then
    raise exception 'review_access_denied' using errcode='42501';
  end if;
  if p_module is not null and p_module not in
    ('vademecum','fisiologia','laboratorio','produccion','aves','incubacion','capacidad') then
    raise exception 'invalid_review_module' using errcode='22023';
  end if;
  if p_status is not null and p_status not in
    ('sin_verificar','en_revision','verificado','corregido','rechazado') then
    raise exception 'invalid_review_status' using errcode='22023';
  end if;
  return query
  select report.id,report.reviewer_id,report.module,report.source_key,
    raw.nombre_comercial,raw.laboratorio,coalesce(cs.status,'sin_verificar'),
    report.catalog_version,
    concat_ws(' · ',raw.principios_activos,raw.concentracion,raw.presentacion,
      raw.especies,raw.via_administracion,raw.dosis_catalogo_texto),
    report.expected_value,report.source_reference,report.comment,report.created_at
  from public.catalog_review_reports report
  left join private.vetdosis_inventario_comercial_revision raw
    on report.source_key=concat_ws(':',raw.fuente_sistema,raw.id_fuente)
  left join private.catalog_review_clinic_status cs
    on cs.clinic_id=report.clinic_id and cs.source_catalog=report.source_catalog
    and cs.source_key=report.source_key
  where report.clinic_id=p_clinic and (v_admin or report.reviewer_id=auth.uid())
    and (p_reviewer is null or (v_admin and report.reviewer_id=p_reviewer))
    and (p_module is null or report.module=p_module)
    and (p_status is null or coalesce(cs.status,'sin_verificar')=p_status)
  order by report.created_at desc;
end;
$$;

revoke all on function public.review_catalog_set_status(uuid,text,text) from public, anon;
revoke all on function public.review_catalog_set_personal_status(text,text) from public, anon;
revoke all on function public.review_catalog_set_global_status(text,text) from public, anon;
revoke all on function public.review_catalog_list(uuid,text,text,integer,integer) from public, anon;
revoke all on function public.review_catalog_progress(uuid) from public, anon;
revoke all on function public.review_report_export(uuid,uuid,text,text) from public, anon;
grant execute on function public.review_catalog_set_status(uuid,text,text) to authenticated;
grant execute on function public.review_catalog_set_personal_status(text,text) to authenticated;
grant execute on function public.review_catalog_set_global_status(text,text) to authenticated;
grant execute on function public.review_catalog_list(uuid,text,text,integer,integer) to authenticated;
grant execute on function public.review_catalog_progress(uuid) to authenticated;
grant execute on function public.review_report_export(uuid,uuid,text,text) to authenticated;

commit;

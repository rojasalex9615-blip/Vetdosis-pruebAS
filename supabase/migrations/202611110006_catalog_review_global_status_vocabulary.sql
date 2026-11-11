-- Align global catalog state with the source tables' real vocabulary.
-- Clinic and personal review states retain their separate workflow vocabulary.
begin;
alter table private.catalog_review_scoped_history
  drop constraint if exists catalog_review_scoped_history_status;
alter table private.catalog_review_scoped_history
  add constraint catalog_review_scoped_history_status check (
    (scope = 'global' and new_status in ('sin_verificar','revisar_conflicto','validado','descartado')) or
    (scope in ('clinic','personal') and new_status in ('sin_verificar','en_revision','verificado','corregido','rechazado'))
  );

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
revoke all on function public.review_catalog_set_global_status(text,text) from public, anon;
grant execute on function public.review_catalog_set_global_status(text,text) to authenticated;

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

create or replace function public.review_catalog_is_platform_owner()
returns boolean language sql stable security definer set search_path = ''
as $$
  select private.is_catalog_platform_owner();
$$;
revoke all on function public.review_catalog_set_global_status(text,text) from public, anon;
revoke all on function public.review_catalog_progress(uuid) from public, anon;
revoke all on function public.review_catalog_is_platform_owner() from public, anon;
grant execute on function public.review_catalog_set_global_status(text,text) to authenticated;
grant execute on function public.review_catalog_progress(uuid) to authenticated;
grant execute on function public.review_catalog_is_platform_owner() to authenticated;
commit;

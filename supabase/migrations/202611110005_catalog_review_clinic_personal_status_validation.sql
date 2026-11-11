-- Reject null and malformed status writes in clinic and personal scopes.
-- This forward migration updates projects where 202611110001 was already applied.
begin;

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

revoke all on function public.review_catalog_set_status(uuid,text,text) from public, anon;
revoke all on function public.review_catalog_set_personal_status(text,text) from public, anon;
grant execute on function public.review_catalog_set_status(uuid,text,text) to authenticated;
grant execute on function public.review_catalog_set_personal_status(text,text) to authenticated;

commit;

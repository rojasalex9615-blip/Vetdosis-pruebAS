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
  if p_new_status not in ('sin_verificar','en_revision','verificado','corregido','rechazado') then
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

-- Isolated-scope contract; run in the dedicated Pruebas project or disposable local fixture.
begin;
do $$
declare
  v_item text;
  v_virbac_item text;
  v_virbac_state text;
  v_before_global text;
  v_after_global text;
  v_clinic_status text;
  v_personal_status text;
  v_owner_clinic_status text;
  v_owner_personal_status text;
  v_global_target text;
  v_history_count integer;
  v_actor uuid := 'ae270fa9-5d73-4ca4-b2ab-35d46d30c28a'::uuid;
  v_clinic uuid := '2d61242b-d2aa-4624-8c7d-6cf420aad49c'::uuid;
  v_other_clinic uuid := 'e68a35d4-82ef-4a9a-819b-05c23df64bba'::uuid;
  v_owner uuid;
begin
  select concat_ws(':', r.fuente_sistema, r.id_fuente),
         coalesce(r.estado_revision, 'sin_verificar')
    into v_item, v_before_global
  from private.vetdosis_inventario_comercial_revision r
  where r.fuente_sistema = 'grok_catalogos'
  order by r.laboratorio, r.nombre_comercial, r.id_fuente
  limit 1;
  if v_item is null then raise exception 'fixture_catalog_empty'; end if;

  select concat_ws(':', r.fuente_sistema, r.id_fuente)
    into v_virbac_item
  from private.vetdosis_inventario_comercial_revision r
  where r.fuente_sistema = 'claude_virbac'
  order by r.laboratorio, r.nombre_comercial, r.id_fuente
  limit 1;
  if v_virbac_item is null then raise exception 'virbac_fixture_catalog_empty'; end if;

  select o.user_id into v_owner
  from private.catalog_platform_owners o
  join public.clinic_members m
    on m.user_id = o.user_id and m.clinic_id = v_other_clinic and m.role = 'admin'
  order by o.created_at
  limit 1;
  if v_owner is null then raise exception 'platform_owner_fixture_missing'; end if;

  perform set_config('request.jwt.claim.sub', v_actor::text, true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_actor, 'role', 'authenticated')::text, true);
  if public.review_catalog_is_platform_owner() then
    raise exception 'non_owner_reported_as_platform_owner';
  end if;

  begin
    perform public.review_catalog_set_global_status(v_item, 'validado');
    raise exception 'expected_global_owner_denial';
  exception when sqlstate '42501' then null;
  end;
  begin
    perform public.review_catalog_set_status(v_other_clinic, v_item, 'en_revision');
    raise exception 'expected_cross_clinic_denial';
  exception when sqlstate '42501' then null;
  end;
  begin
    perform public.review_catalog_set_status(v_clinic, v_item, null);
    raise exception 'expected_null_clinic_status_denial';
  exception when sqlstate '22023' then null;
  end;
  begin
    perform public.review_catalog_set_personal_status(v_item, null);
    raise exception 'expected_null_personal_status_denial';
  exception when sqlstate '22023' then null;
  end;
  begin
    perform public.review_catalog_set_personal_status(null, 'verificado');
    raise exception 'expected_null_personal_source_denial';
  exception when sqlstate '22023' then null;
  end;

  perform public.review_catalog_set_status(v_clinic, v_item, 'en_revision');
  select status into v_clinic_status
  from private.catalog_review_clinic_status
  where clinic_id = v_clinic and source_key = v_item;
  if v_clinic_status <> 'en_revision' then
    raise exception 'clinic_scope_write_failed';
  end if;

  select coalesce(estado_revision, 'sin_verificar') into v_after_global
  from private.vetdosis_inventario_comercial_revision
  where concat_ws(':', fuente_sistema, id_fuente) = v_item;
  if v_after_global is distinct from v_before_global then
    raise exception 'clinic_write_changed_global';
  end if;

  perform public.review_catalog_set_personal_status(v_item, 'rechazado');
  select status into v_personal_status
  from private.catalog_review_personal_status
  where user_id = v_actor and source_key = v_item;
  if v_personal_status <> 'rechazado' then
    raise exception 'personal_scope_write_failed';
  end if;
  if not exists (
    select 1 from private.catalog_review_clinic_status
    where clinic_id = v_clinic and source_key = v_item and status = 'en_revision'
  ) then
    raise exception 'personal_write_changed_clinic';
  end if;
  select coalesce(estado_revision, 'sin_verificar') into v_after_global
  from private.vetdosis_inventario_comercial_revision
  where concat_ws(':', fuente_sistema, id_fuente) = v_item;
  if v_after_global is distinct from v_before_global then
    raise exception 'personal_write_changed_global';
  end if;

  select count(*) into v_history_count
  from public.review_catalog_history('personal', null, v_item, 100);
  if v_history_count <> 1 then raise exception 'personal_history_not_scoped_to_actor'; end if;
  select count(*) into v_history_count
  from public.review_catalog_history('clinic', v_clinic, v_item, 100);
  if v_history_count <> 1 then raise exception 'clinic_history_not_scoped_to_clinic'; end if;
  begin
    perform count(*) from public.review_catalog_history('global', null, v_item, 100);
    raise exception 'expected_global_history_denial';
  exception when sqlstate '42501' then null;
  end;
  begin
    perform count(*) from public.review_catalog_history('clinic', v_other_clinic, v_item, 100);
    raise exception 'expected_other_clinic_history_denial';
  exception when sqlstate '42501' then null;
  end;

  -- Switch to the second clinic admin: personal and clinic scopes must not leak.
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_owner, 'role', 'authenticated')::text, true);
  if not public.review_catalog_is_platform_owner() then
    raise exception 'platform_owner_capability_missing';
  end if;

  select clinic_review_status, personal_review_status
    into v_owner_clinic_status, v_owner_personal_status
  from public.review_catalog_list(v_other_clinic, null, null, 200, 0)
  where source_key = v_item;
  if v_owner_clinic_status <> 'sin_verificar' then
    raise exception 'clinic_scope_leaked_between_clinics';
  end if;
  if v_owner_personal_status <> 'sin_verificar' then
    raise exception 'personal_scope_leaked_between_users';
  end if;

  select count(*) into v_history_count
  from public.review_catalog_history('personal', null, v_item, 100);
  if v_history_count <> 0 then
    raise exception 'personal_history_leaked_between_users';
  end if;
  begin
    perform count(*) from public.review_catalog_history('clinic', v_clinic, v_item, 100);
    raise exception 'expected_other_clinic_history_denial_for_owner';
  exception when sqlstate '42501' then null;
  end;
  begin
    perform public.review_catalog_set_status(v_clinic, v_item, 'verificado');
    raise exception 'expected_cross_clinic_owner_write_denial';
  exception when sqlstate '42501' then null;
  end;
  begin
    perform public.review_catalog_set_global_status(v_item, null);
    raise exception 'expected_null_global_status_denial';
  exception when sqlstate '22023' then null;
  end;

  perform public.review_catalog_set_personal_status(v_item, 'verificado');
  select count(*) into v_history_count
  from public.review_catalog_history('personal', null, v_item, 100);
  if v_history_count <> 1 then raise exception 'owner_personal_history_missing'; end if;

  v_global_target := case
    when v_before_global = 'validado' then 'descartado'
    else 'validado'
  end;
  perform public.review_catalog_set_global_status(v_item, v_global_target);

  -- Virbac stores the default with a space; the RPC accepts the canonical key.
  perform public.review_catalog_set_global_status(v_virbac_item, 'validado');
  perform public.review_catalog_set_global_status(v_virbac_item, 'sin_verificar');
  select estado into v_virbac_state
  from private.vetdosis_virbac_productos
  where id = split_part(v_virbac_item, ':', 2);
  if v_virbac_state <> 'sin verificar' then
    raise exception 'virbac_status_storage_normalization_failed';
  end if;
  select count(*) into v_history_count
  from public.review_catalog_history('global', null, v_item, 100);
  if v_history_count < 1 then raise exception 'owner_global_history_missing'; end if;

  -- The original clinic user still sees only their clinic and personal states.
  perform set_config('request.jwt.claim.sub', v_actor::text, true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_actor, 'role', 'authenticated')::text, true);
  select clinic_review_status, personal_review_status, global_review_status
    into v_clinic_status, v_personal_status, v_after_global
  from public.review_catalog_list(v_clinic, null, null, 200, 0)
  where source_key = v_item;
  if v_clinic_status <> 'en_revision' then raise exception 'global_write_changed_clinic'; end if;
  if v_personal_status <> 'rechazado' then raise exception 'personal_scope_leaked_owner_status'; end if;
  if v_after_global <> v_global_target then raise exception 'global_status_not_visible_read_only'; end if;

  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_owner, 'role', 'authenticated')::text, true);
  select clinic_review_status, personal_review_status, global_review_status
    into v_owner_clinic_status, v_owner_personal_status, v_after_global
  from public.review_catalog_list(v_other_clinic, null, null, 200, 0)
  where source_key = v_item;
  if v_owner_clinic_status <> 'sin_verificar' then raise exception 'owner_clinic_scope_changed'; end if;
  if v_owner_personal_status <> 'verificado' then raise exception 'owner_personal_scope_write_failed'; end if;
  if v_after_global <> v_global_target then raise exception 'owner_global_scope_write_failed'; end if;
end $$;
rollback;

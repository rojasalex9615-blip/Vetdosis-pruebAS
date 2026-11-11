-- Isolated-scope contract; run only in the dedicated test project.
begin;
do $$
declare
  v_item text; v_before_global text; v_after_global text; v_clinic_status text;
  v_actor uuid := 'ae270fa9-5d73-4ca4-b2ab-35d46d30c28a'::uuid;
  v_clinic uuid := '2d61242b-d2aa-4624-8c7d-6cf420aad49c'::uuid;
  v_other_clinic uuid := 'e68a35d4-82ef-4a9a-819b-05c23df64bba'::uuid;
  v_owner uuid := 'd57f1634-9416-4757-8897-58965c10bba8'::uuid;
begin
  select concat_ws(':',fuente_sistema,id_fuente),coalesce(estado_revision,'sin_verificar') into v_item,v_before_global from private.vetdosis_inventario_comercial_revision order by fuente_sistema,id_fuente limit 1;
  if v_item is null then raise exception 'fixture_catalog_empty'; end if;
  perform set_config('request.jwt.claim.sub',v_actor::text,true);
  perform set_config('request.jwt.claims',json_build_object('sub',v_actor,'role','authenticated')::text,true);
  begin perform public.review_catalog_set_global_status(v_item,'verificado'); raise exception 'expected_global_owner_denial'; exception when insufficient_privilege then null; end;
  begin
    perform public.review_catalog_set_status(v_other_clinic,v_item,'en_revision');
    raise exception 'expected_cross_clinic_denial';
  exception when insufficient_privilege then null;
  end;
  perform public.review_catalog_set_status(v_clinic,v_item,'en_revision');
  select status into v_clinic_status from private.catalog_review_clinic_status where clinic_id=v_clinic and source_key=v_item;
  if v_clinic_status <> 'en_revision' then raise exception 'clinic_scope_write_failed'; end if;
  select coalesce(estado_revision,'sin_verificar') into v_after_global from private.vetdosis_inventario_comercial_revision where concat_ws(':',fuente_sistema,id_fuente)=v_item;
  if v_after_global is distinct from v_before_global then raise exception 'clinic_write_changed_global'; end if;
  perform public.review_catalog_set_personal_status(v_item,'rechazado');
  if not exists(select 1 from private.catalog_review_personal_status where user_id=v_actor and source_key=v_item and status='rechazado') then raise exception 'personal_scope_write_failed'; end if;
  if not exists(select 1 from private.catalog_review_clinic_status where clinic_id=v_clinic and source_key=v_item and status='en_revision') then raise exception 'personal_write_changed_clinic'; end if;
  select coalesce(estado_revision,'sin_verificar') into v_after_global from private.vetdosis_inventario_comercial_revision where concat_ws(':',fuente_sistema,id_fuente)=v_item;
  if v_after_global is distinct from v_before_global then raise exception 'personal_write_changed_global'; end if;
  -- The second user cannot edit the first user's personal row.
  perform set_config('request.jwt.claim.sub',v_owner::text,true);
  perform set_config('request.jwt.claims',json_build_object('sub',v_owner,'role','authenticated')::text,true);
  if exists(select 1 from private.catalog_review_personal_status where user_id=v_owner and source_key=v_item) then
    raise exception 'personal_scope_leaked_between_users';
  end if;
  perform set_config('request.jwt.claim.sub',v_owner::text,true);
  perform set_config('request.jwt.claims',json_build_object('sub',v_owner,'role','authenticated')::text,true);
  perform public.review_catalog_set_global_status(v_item,'corregido');
  if not exists(select 1 from private.vetdosis_inventario_comercial_revision where concat_ws(':',fuente_sistema,id_fuente)=v_item and estado_revision='corregido') then raise exception 'global_owner_write_failed'; end if;
end $$;
rollback;

create or replace function public.produccion_alimento_guardar(p_clinic uuid, p_data jsonb, p_operation text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_fp jsonb; v_version integer; v_nombre text;
begin
 if auth.uid() is null then raise exception 'authentication_required'; end if;
 if not private.has_clinic_role(p_clinic, array['admin','mvz']::text[]) then raise exception 'admin_or_mvz_required'; end if;
 if jsonb_typeof(p_data) is distinct from 'object' or octet_length(p_data::text) > 8000 then raise exception 'invalid_data'; end if;
 if exists(select 1 from jsonb_object_keys(p_data) k where k not in ('id','nombre','tipo','unidad','kg_por_unidad','materia_seca_pct','proteina_pct','activo','notas','version')) then raise exception 'invalid_fields'; end if;
 v_nombre = btrim(coalesce(p_data->>'nombre',''));
 if v_nombre = '' or char_length(v_nombre) > 120 then raise exception 'nombre_required'; end if;
 if coalesce(p_data->>'tipo','concentrado') not in ('concentrado','forraje','ensilado','mineral','aditivo','leche','medicado','otro') then raise exception 'invalid_tipo'; end if;
 if coalesce(p_data->>'unidad','kg') not in ('kg','ton','saco','costal','paca','l') then raise exception 'invalid_unidad'; end if;
 if coalesce(p_data->>'kg_por_unidad','1') !~ '^[0-9]+(\.[0-9]+)?$' then raise exception 'invalid_kg_por_unidad'; end if;
 if coalesce(p_data->>'kg_por_unidad','1')::numeric <= 0 or coalesce(p_data->>'kg_por_unidad','1')::numeric > 100000 then raise exception 'invalid_kg_por_unidad'; end if;
 if coalesce(p_data->>'materia_seca_pct','') <> '' and (p_data->>'materia_seca_pct' !~ '^[0-9]+(\.[0-9]+)?$' or (p_data->>'materia_seca_pct')::numeric <= 0 or (p_data->>'materia_seca_pct')::numeric > 100) then raise exception 'invalid_materia_seca'; end if;
 if coalesce(p_data->>'proteina_pct','') <> '' and (p_data->>'proteina_pct' !~ '^[0-9]+(\.[0-9]+)?$' or (p_data->>'proteina_pct')::numeric > 100) then raise exception 'invalid_proteina'; end if;
 if char_length(coalesce(p_data->>'notas','')) > 2000 then raise exception 'notas_too_long'; end if;
 v_fp = jsonb_build_object('kind','produccion_alimento','data',p_data);
 v_id = private.vet_receipt(p_clinic,p_operation,v_fp); if v_id is not null then return v_id; end if;
 perform 1 from public.clinics where id=p_clinic for update;
 v_id = nullif(p_data->>'id','')::uuid;
 if exists(select 1 from public.produccion_alimentos a where a.clinic_id=p_clinic and lower(btrim(a.nombre))=lower(v_nombre) and (v_id is null or a.id<>v_id)) then raise exception 'alimento_duplicado'; end if;
 if v_id is null then
  insert into public.produccion_alimentos(clinic_id,nombre,tipo,unidad,kg_por_unidad,materia_seca_pct,proteina_pct,activo,notas,created_by)
  values(p_clinic,v_nombre,coalesce(nullif(p_data->>'tipo',''),'concentrado'),coalesce(nullif(p_data->>'unidad',''),'kg'),coalesce(nullif(p_data->>'kg_por_unidad','')::numeric,1),nullif(p_data->>'materia_seca_pct','')::numeric,nullif(p_data->>'proteina_pct','')::numeric,coalesce((p_data->>'activo')::boolean,true),btrim(coalesce(p_data->>'notas','')),auth.uid())
  returning id into v_id;
 else
  if coalesce(p_data->>'version','') !~ '^[0-9]{1,9}$' then raise exception 'version_required'; end if;
  v_version = (p_data->>'version')::integer;
  update public.produccion_alimentos set nombre=v_nombre, tipo=coalesce(nullif(p_data->>'tipo',''),tipo), unidad=coalesce(nullif(p_data->>'unidad',''),unidad), kg_por_unidad=coalesce(nullif(p_data->>'kg_por_unidad','')::numeric,kg_por_unidad), materia_seca_pct=nullif(p_data->>'materia_seca_pct','')::numeric, proteina_pct=nullif(p_data->>'proteina_pct','')::numeric, activo=coalesce((p_data->>'activo')::boolean,activo), notas=btrim(coalesce(p_data->>'notas',notas)), version=version+1, updated_at=clock_timestamp()
  where id=v_id and clinic_id=p_clinic and version=v_version;
  if not found then raise exception 'version_conflict_or_not_found'; end if;
 end if;
 insert into public.audit_log(clinic_id,actor_id,action,entity_id,details) values(p_clinic,auth.uid(),'produccion_alimento_saved',v_id::text,jsonb_build_object('nombre',v_nombre,'tipo',p_data->>'tipo'));
 insert into private.vet_operation_receipts values(auth.uid(),p_clinic,p_operation,v_fp,v_id);
 return v_id;
end$$;

create or replace function public.produccion_silo_guardar(p_clinic uuid, p_data jsonb, p_operation text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_fp jsonb; v_version integer; v_nombre text; v_alimento uuid;
begin
 if auth.uid() is null then raise exception 'authentication_required'; end if;
 if not private.has_clinic_role(p_clinic, array['admin','mvz']::text[]) then raise exception 'admin_or_mvz_required'; end if;
 if jsonb_typeof(p_data) is distinct from 'object' or octet_length(p_data::text) > 8000 then raise exception 'invalid_data'; end if;
 if exists(select 1 from jsonb_object_keys(p_data) k where k not in ('id','nombre','tipo','capacidad_kg','alimento_id','activo','notas','version')) then raise exception 'invalid_fields'; end if;
 v_nombre = btrim(coalesce(p_data->>'nombre',''));
 if v_nombre = '' or char_length(v_nombre) > 80 then raise exception 'nombre_required'; end if;
 if coalesce(p_data->>'tipo','silo') not in ('silo','bodega','tolva','trinchera','otro') then raise exception 'invalid_tipo'; end if;
 if coalesce(p_data->>'capacidad_kg','') <> '' and (p_data->>'capacidad_kg' !~ '^[0-9]+(\.[0-9]+)?$' or (p_data->>'capacidad_kg')::numeric <= 0 or (p_data->>'capacidad_kg')::numeric > 100000000) then raise exception 'invalid_capacidad'; end if;
 if char_length(coalesce(p_data->>'notas','')) > 2000 then raise exception 'notas_too_long'; end if;
 v_alimento = nullif(p_data->>'alimento_id','')::uuid;
 if v_alimento is not null and not exists(select 1 from public.produccion_alimentos where id=v_alimento and clinic_id=p_clinic) then raise exception 'alimento_not_found'; end if;
 v_fp = jsonb_build_object('kind','produccion_silo','data',p_data);
 v_id = private.vet_receipt(p_clinic,p_operation,v_fp); if v_id is not null then return v_id; end if;
 perform 1 from public.clinics where id=p_clinic for update;
 v_id = nullif(p_data->>'id','')::uuid;
 if exists(select 1 from public.produccion_silos s where s.clinic_id=p_clinic and lower(btrim(s.nombre))=lower(v_nombre) and (v_id is null or s.id<>v_id)) then raise exception 'silo_duplicado'; end if;
 if v_id is null then
  insert into public.produccion_silos(clinic_id,nombre,tipo,capacidad_kg,alimento_id,activo,notas,created_by)
  values(p_clinic,v_nombre,coalesce(nullif(p_data->>'tipo',''),'silo'),nullif(p_data->>'capacidad_kg','')::numeric,v_alimento,coalesce((p_data->>'activo')::boolean,true),btrim(coalesce(p_data->>'notas','')),auth.uid())
  returning id into v_id;
 else
  if coalesce(p_data->>'version','') !~ '^[0-9]{1,9}$' then raise exception 'version_required'; end if;
  v_version = (p_data->>'version')::integer;
  update public.produccion_silos set nombre=v_nombre, tipo=coalesce(nullif(p_data->>'tipo',''),tipo), capacidad_kg=nullif(p_data->>'capacidad_kg','')::numeric, alimento_id=v_alimento, activo=coalesce((p_data->>'activo')::boolean,activo), notas=btrim(coalesce(p_data->>'notas',notas)), version=version+1, updated_at=clock_timestamp()
  where id=v_id and clinic_id=p_clinic and version=v_version;
  if not found then raise exception 'version_conflict_or_not_found'; end if;
 end if;
 insert into public.audit_log(clinic_id,actor_id,action,entity_id,details) values(p_clinic,auth.uid(),'produccion_silo_saved',v_id::text,jsonb_build_object('nombre',v_nombre,'tipo',p_data->>'tipo'));
 insert into private.vet_operation_receipts values(auth.uid(),p_clinic,p_operation,v_fp,v_id);
 return v_id;
end$$;

create or replace function public.produccion_alimento_movimiento(p_clinic uuid, p_alimento uuid, p_silo uuid, p_lote uuid, p_fecha date, p_tipo text, p_kg numeric, p_costo numeric, p_proveedor text, p_referencia text, p_nota text, p_operation text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_fp jsonb; v_kg numeric; v_costo numeric; v_stock numeric; v_valor numeric; v_ultima numeric; v_estado text;
begin
 if auth.uid() is null then raise exception 'authentication_required'; end if;
 if not private.has_clinic_role(p_clinic, array['admin','mvz','auxiliar']::text[]) then raise exception 'produccion_write_required'; end if;
 if p_fecha is null or p_fecha > current_date then raise exception 'invalid_fecha'; end if;
 if p_tipo is null or p_tipo not in ('compra','consumo','merma','ajuste') then raise exception 'invalid_tipo'; end if;
 if p_kg is null or p_kg = 0 or abs(p_kg) > 10000000 then raise exception 'invalid_kg'; end if;
 if char_length(coalesce(p_proveedor,'')) > 120 then raise exception 'proveedor_too_long'; end if;
 if char_length(coalesce(p_referencia,'')) > 60 then raise exception 'referencia_too_long'; end if;
 if char_length(coalesce(p_nota,'')) > 2000 then raise exception 'nota_too_long'; end if;
 if not exists(select 1 from public.produccion_alimentos where id=p_alimento and clinic_id=p_clinic) then raise exception 'alimento_not_found'; end if;
 if p_silo is not null and not exists(select 1 from public.produccion_silos where id=p_silo and clinic_id=p_clinic) then raise exception 'silo_not_found'; end if;
 -- El signo lo pone el servidor segun el tipo: quien captura escribe cuanto, no el signo.
 -- El ajuste es la unica excepcion, porque ahi la direccion es justo lo que se decide.
 v_kg = case when p_tipo='compra' then abs(p_kg) when p_tipo in ('consumo','merma') then -abs(p_kg) else p_kg end;
 if p_tipo='consumo' then
  if p_lote is null then raise exception 'lote_required'; end if;
  select estado into v_estado from public.lotes_produccion where id=p_lote and clinic_id=p_clinic;
  if v_estado is null then raise exception 'lote_not_found'; end if;
  if v_estado <> 'activo' then raise exception 'lote_closed'; end if;
 elsif p_lote is not null then
  if not exists(select 1 from public.lotes_produccion where id=p_lote and clinic_id=p_clinic) then raise exception 'lote_not_found'; end if;
 end if;
 if p_tipo='compra' then
  if p_costo is null then raise exception 'costo_required'; end if;
  if p_costo < 0 or p_costo > 1000000 then raise exception 'invalid_costo'; end if;
  v_costo = p_costo;
 else
  select coalesce(sum(kg),0), coalesce(sum(kg*costo_kg),0) into v_stock, v_valor
   from public.produccion_alimento_movimientos where clinic_id=p_clinic and alimento_id=p_alimento;
  select costo_kg into v_ultima from public.produccion_alimento_movimientos
   where clinic_id=p_clinic and alimento_id=p_alimento and tipo='compra' order by fecha desc, created_at desc limit 1;
  v_costo = case when v_stock > 0 and v_valor > 0 then v_valor / v_stock else coalesce(v_ultima,0) end;
 end if;
 v_fp = jsonb_build_object('kind','produccion_alimento_mov','alimento',p_alimento,'silo',p_silo,'lote',p_lote,'fecha',p_fecha,'tipo',p_tipo,'kg',v_kg,'costo',case when p_tipo='compra' then p_costo else null end,'proveedor',btrim(coalesce(p_proveedor,'')),'referencia',btrim(coalesce(p_referencia,'')),'nota',btrim(coalesce(p_nota,'')));
 v_id = private.vet_receipt(p_clinic,p_operation,v_fp); if v_id is not null then return v_id; end if;
 perform 1 from public.clinics where id=p_clinic for update;
 insert into public.produccion_alimento_movimientos(clinic_id,alimento_id,silo_id,lote_id,fecha,tipo,kg,costo_kg,proveedor,referencia,nota,registrado_por)
 values(p_clinic,p_alimento,p_silo,p_lote,p_fecha,p_tipo,v_kg,v_costo,btrim(coalesce(p_proveedor,'')),btrim(coalesce(p_referencia,'')),btrim(coalesce(p_nota,'')),auth.uid())
 returning id into v_id;
 insert into public.audit_log(clinic_id,actor_id,action,entity_id,details) values(p_clinic,auth.uid(),'produccion_alimento_movimiento',v_id::text,jsonb_build_object('alimento_id',p_alimento,'tipo',p_tipo,'kg',v_kg,'lote_id',p_lote,'costo_kg',v_costo));
 insert into private.vet_operation_receipts values(auth.uid(),p_clinic,p_operation,v_fp,v_id);
 return v_id;
end$$;

revoke all on function public.produccion_alimento_guardar(uuid,jsonb,text), public.produccion_silo_guardar(uuid,jsonb,text), public.produccion_alimento_movimiento(uuid,uuid,uuid,uuid,date,text,numeric,numeric,text,text,text,text) from public, anon;
grant execute on function public.produccion_alimento_guardar(uuid,jsonb,text), public.produccion_silo_guardar(uuid,jsonb,text), public.produccion_alimento_movimiento(uuid,uuid,uuid,uuid,date,text,numeric,numeric,text,text,text,text) to authenticated;

notify pgrst,'reload schema';

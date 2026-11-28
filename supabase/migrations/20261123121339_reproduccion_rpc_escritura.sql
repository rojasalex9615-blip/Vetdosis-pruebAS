-- Escrituras de gestacion. Mismo molde que exotic_clutch_save: comprobar
-- sesion, comprobar rol, validar entrada, recibo de idempotencia, bloquear la
-- clinica, escribir y dejar rastro en audit_log.
--
-- `p_operation` debe ser 48 caracteres hexadecimales en minuscula, que es lo
-- que exige private.vet_receipt (^[a-f0-9]{48}$).

create or replace function public.reproduccion_gestacion_guardar(
  p_clinic uuid, p_id uuid, p_patient uuid, p_lote uuid, p_especie text,
  p_servicio date, p_metodo text, p_semental text, p_dias integer,
  p_diagnostico text, p_diagnostico_el date, p_notas text, p_operation text
) returns uuid language plpgsql security definer set search_path to '' as $function$
declare v_id uuid; v_fp jsonb; v_estimado date;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if not private.has_clinic_role(p_clinic, array['admin','mvz','auxiliar']::text[]) then raise exception 'reproduccion_write_required'; end if;

  if p_patient is null or not exists (select 1 from public.vet_patients where id=p_patient and clinic_id=p_clinic) then raise exception 'patient_not_found'; end if;
  if p_lote is not null and not exists (select 1 from public.lotes_produccion where id=p_lote and clinic_id=p_clinic) then raise exception 'lote_not_found'; end if;
  if char_length(btrim(coalesce(p_especie,''))) < 1 then raise exception 'invalid_especie'; end if;
  if p_servicio is null or p_servicio > current_date then raise exception 'invalid_servicio'; end if;
  if coalesce(p_metodo,'monta_natural') not in ('monta_natural','inseminacion_artificial','transferencia_embrion','desconocido') then raise exception 'invalid_metodo'; end if;
  if p_semental is not null and char_length(btrim(p_semental)) > 80 then raise exception 'semental_too_long'; end if;
  if p_dias is not null and (p_dias < 1 or p_dias > 400) then raise exception 'invalid_dias'; end if;
  if coalesce(p_diagnostico,'pendiente') not in ('pendiente','gestante','vacia','dudosa') then raise exception 'invalid_diagnostico'; end if;
  if p_diagnostico_el is not null and p_diagnostico_el < p_servicio then raise exception 'diagnostico_antes_del_servicio'; end if;
  if p_diagnostico_el is not null and p_diagnostico_el > current_date then raise exception 'invalid_diagnostico_fecha'; end if;
  if p_notas is not null and char_length(p_notas) > 2000 then raise exception 'notas_too_long'; end if;

  -- La fecha probable de parto se deriva aqui, no en el movil: asi no depende
  -- del reloj ni de la zona horaria del telefono que capture.
  v_estimado = case when p_dias is null then null else p_servicio + p_dias end;

  v_fp = jsonb_build_object('kind','reproduccion_gestacion','id',p_id,'patient',p_patient,'servicio',p_servicio,'especie',btrim(p_especie));
  v_id = private.vet_receipt(p_clinic, p_operation, v_fp);
  if v_id is not null then return v_id; end if;
  perform 1 from public.clinics where id = p_clinic for update;

  if p_id is null then
    insert into public.reproduccion_gestaciones(
      clinic_id,patient_id,lote_id,especie,servicio_el,metodo,semental,
      dias_gestacion,parto_estimado,diagnostico,diagnostico_el,notas,created_by)
    values (p_clinic,p_patient,p_lote,btrim(p_especie),p_servicio,
      coalesce(p_metodo,'monta_natural'),nullif(btrim(coalesce(p_semental,'')),''),
      p_dias,v_estimado,coalesce(p_diagnostico,'pendiente'),p_diagnostico_el,
      nullif(btrim(coalesce(p_notas,'')),''),auth.uid())
    returning id into v_id;
  else
    update public.reproduccion_gestaciones set
      patient_id=p_patient, lote_id=p_lote, especie=btrim(p_especie),
      servicio_el=p_servicio, metodo=coalesce(p_metodo,'monta_natural'),
      semental=nullif(btrim(coalesce(p_semental,'')),''),
      dias_gestacion=p_dias, parto_estimado=v_estimado,
      diagnostico=coalesce(p_diagnostico,'pendiente'), diagnostico_el=p_diagnostico_el,
      notas=nullif(btrim(coalesce(p_notas,'')),''),
      version=version+1, updated_at=clock_timestamp()
    where id=p_id and clinic_id=p_clinic returning id into v_id;
    if v_id is null then raise exception 'gestacion_not_found'; end if;
  end if;

  insert into public.audit_log(clinic_id,actor_id,action,entity_id,details)
  values (p_clinic, auth.uid(), 'reproduccion_gestacion_saved', v_id::text,
          jsonb_build_object('especie',btrim(p_especie),'diagnostico',coalesce(p_diagnostico,'pendiente')));
  insert into private.vet_operation_receipts values (auth.uid(), p_clinic, p_operation, v_fp, v_id);
  return v_id;
end$function$;


-- Cerrar la gestacion es una operacion aparte y no un campo mas del
-- formulario: es el momento en que el dato deja de ser una prevision y pasa a
-- ser un hecho, y conviene que quede en el rastro como tal.
create or replace function public.reproduccion_gestacion_cerrar(
  p_clinic uuid, p_id uuid, p_estado text, p_parto date,
  p_vivas integer, p_muertas integer, p_notas text, p_operation text
) returns uuid language plpgsql security definer set search_path to '' as $function$
declare v_id uuid; v_fp jsonb; v_servicio date;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if not private.has_clinic_role(p_clinic, array['admin','mvz','auxiliar']::text[]) then raise exception 'reproduccion_write_required'; end if;
  if p_estado not in ('parida','aborto','vacia','cancelada') then raise exception 'invalid_estado'; end if;

  select servicio_el into v_servicio from public.reproduccion_gestaciones where id=p_id and clinic_id=p_clinic;
  if v_servicio is null then raise exception 'gestacion_not_found'; end if;

  -- Solo el parto exige fecha y crias. Un aborto o un vacio puede no tener
  -- numero de crias, y obligar a inventarlo seria peor que no pedirlo.
  if p_estado = 'parida' then
    if p_parto is null then raise exception 'parto_requerido'; end if;
    if p_vivas is null then raise exception 'crias_requeridas'; end if;
  end if;
  if p_parto is not null and p_parto < v_servicio then raise exception 'parto_antes_del_servicio'; end if;
  if p_parto is not null and p_parto > current_date then raise exception 'invalid_parto'; end if;
  if p_vivas is not null and (p_vivas < 0 or p_vivas > 10000) then raise exception 'invalid_crias'; end if;
  if p_muertas is not null and (p_muertas < 0 or p_muertas > 10000) then raise exception 'invalid_crias'; end if;
  if p_notas is not null and char_length(p_notas) > 2000 then raise exception 'notas_too_long'; end if;

  v_fp = jsonb_build_object('kind','reproduccion_cierre','id',p_id,'estado',p_estado,'parto',p_parto);
  v_id = private.vet_receipt(p_clinic, p_operation, v_fp);
  if v_id is not null then return v_id; end if;
  perform 1 from public.clinics where id = p_clinic for update;

  update public.reproduccion_gestaciones set
    estado=p_estado, parto_el=p_parto, crias_vivas=p_vivas, crias_muertas=p_muertas,
    diagnostico = case when p_estado='vacia' then 'vacia' else diagnostico end,
    notas = coalesce(nullif(btrim(coalesce(p_notas,'')),''), notas),
    version=version+1, updated_at=clock_timestamp()
  where id=p_id and clinic_id=p_clinic returning id into v_id;

  insert into public.audit_log(clinic_id,actor_id,action,entity_id,details)
  values (p_clinic, auth.uid(), 'reproduccion_gestacion_cerrada', v_id::text,
          jsonb_build_object('estado',p_estado,'vivas',p_vivas,'muertas',p_muertas));
  insert into private.vet_operation_receipts values (auth.uid(), p_clinic, p_operation, v_fp, v_id);
  return v_id;
end$function$;

revoke all on function public.reproduccion_gestacion_guardar(uuid,uuid,uuid,uuid,text,date,text,text,integer,text,date,text,text) from public, anon;
revoke all on function public.reproduccion_gestacion_cerrar(uuid,uuid,text,date,integer,integer,text,text) from public, anon;
grant execute on function public.reproduccion_gestacion_guardar(uuid,uuid,uuid,uuid,text,date,text,text,integer,text,date,text,text) to authenticated;
grant execute on function public.reproduccion_gestacion_cerrar(uuid,uuid,text,date,integer,integer,text,text) to authenticated;

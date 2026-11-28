-- Escrituras del modulo de exoticos.
-- Mismo molde que produccion_evento_guardar: comprobar sesion, comprobar rol,
-- validar entrada, recibo de idempotencia, bloquear la clinica, insertar y
-- dejar rastro en audit_log.
--
-- Nota para quien llame desde el cliente: `p_operation` debe ser un
-- identificador de 48 caracteres hexadecimales en minuscula; es lo que exige
-- private.vet_receipt para garantizar la idempotencia (^[a-f0-9]{48}$).

create or replace function public.exotic_enclosure_save(
  p_clinic uuid, p_id uuid, p_nombre text, p_tipo text, p_especie text,
  p_rangos jsonb, p_notas text, p_operation text
) returns uuid language plpgsql security definer set search_path to '' as $function$
declare v_id uuid; v_fp jsonb;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if not private.has_clinic_role(p_clinic, array['admin','mvz','auxiliar']::text[]) then raise exception 'exotic_write_required'; end if;
  if char_length(btrim(coalesce(p_nombre,''))) < 1 or char_length(btrim(p_nombre)) > 80 then raise exception 'invalid_nombre'; end if;
  if p_tipo not in ('terrario','aviario','acuaterrario','acuario','encierro','incubadora') then raise exception 'invalid_tipo'; end if;
  if jsonb_typeof(coalesce(p_rangos,'{}'::jsonb)) is distinct from 'object' then raise exception 'invalid_rangos'; end if;

  v_fp = jsonb_build_object('kind','exotic_enclosure','id',p_id,'nombre',btrim(p_nombre),'tipo',p_tipo,'rangos',coalesce(p_rangos,'{}'::jsonb));
  v_id = private.vet_receipt(p_clinic, p_operation, v_fp);
  if v_id is not null then return v_id; end if;
  perform 1 from public.clinics where id = p_clinic for update;

  if p_id is null then
    insert into public.exotic_enclosures(
      clinic_id,nombre,tipo,especie,
      temp_caliente_min,temp_caliente_max,temp_fria_min,temp_fria_max,
      humedad_min,humedad_max,uv_min,uv_max,ph_min,ph_max,
      amoniaco_max,nitrito_max,salinidad_min,salinidad_max,notas,created_by)
    values (p_clinic, btrim(p_nombre), p_tipo, nullif(btrim(coalesce(p_especie,'')),''),
      (p_rangos->>'temp_caliente_min')::numeric,(p_rangos->>'temp_caliente_max')::numeric,
      (p_rangos->>'temp_fria_min')::numeric,(p_rangos->>'temp_fria_max')::numeric,
      (p_rangos->>'humedad_min')::numeric,(p_rangos->>'humedad_max')::numeric,
      (p_rangos->>'uv_min')::numeric,(p_rangos->>'uv_max')::numeric,
      (p_rangos->>'ph_min')::numeric,(p_rangos->>'ph_max')::numeric,
      (p_rangos->>'amoniaco_max')::numeric,(p_rangos->>'nitrito_max')::numeric,
      (p_rangos->>'salinidad_min')::numeric,(p_rangos->>'salinidad_max')::numeric,
      nullif(btrim(coalesce(p_notas,'')),''), auth.uid())
    returning id into v_id;
  else
    update public.exotic_enclosures set
      nombre = btrim(p_nombre), tipo = p_tipo,
      especie = nullif(btrim(coalesce(p_especie,'')),''),
      temp_caliente_min=(p_rangos->>'temp_caliente_min')::numeric,
      temp_caliente_max=(p_rangos->>'temp_caliente_max')::numeric,
      temp_fria_min=(p_rangos->>'temp_fria_min')::numeric,
      temp_fria_max=(p_rangos->>'temp_fria_max')::numeric,
      humedad_min=(p_rangos->>'humedad_min')::numeric,
      humedad_max=(p_rangos->>'humedad_max')::numeric,
      uv_min=(p_rangos->>'uv_min')::numeric, uv_max=(p_rangos->>'uv_max')::numeric,
      ph_min=(p_rangos->>'ph_min')::numeric, ph_max=(p_rangos->>'ph_max')::numeric,
      amoniaco_max=(p_rangos->>'amoniaco_max')::numeric,
      nitrito_max=(p_rangos->>'nitrito_max')::numeric,
      salinidad_min=(p_rangos->>'salinidad_min')::numeric,
      salinidad_max=(p_rangos->>'salinidad_max')::numeric,
      notas = nullif(btrim(coalesce(p_notas,'')),''),
      version = version + 1, updated_at = clock_timestamp()
    where id = p_id and clinic_id = p_clinic
    returning id into v_id;
    if v_id is null then raise exception 'enclosure_not_found'; end if;
  end if;

  insert into public.audit_log(clinic_id,actor_id,action,entity_id,details)
  values (p_clinic, auth.uid(), 'exotic_enclosure_saved', v_id::text, jsonb_build_object('tipo',p_tipo));
  insert into private.vet_operation_receipts values (auth.uid(), p_clinic, p_operation, v_fp, v_id);
  return v_id;
end$function$;

create or replace function public.exotic_reading_log(
  p_clinic uuid, p_enclosure uuid, p_medido_en timestamptz, p_valores jsonb,
  p_nota text, p_operation text
) returns uuid language plpgsql security definer set search_path to '' as $function$
declare v_id uuid; v_fp jsonb; v_cuando timestamptz = coalesce(p_medido_en, clock_timestamp());
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if not private.has_clinic_role(p_clinic, array['admin','mvz','auxiliar']::text[]) then raise exception 'exotic_write_required'; end if;
  if v_cuando > clock_timestamp() + interval '1 hour' then raise exception 'invalid_medido_en'; end if;
  if jsonb_typeof(coalesce(p_valores,'{}'::jsonb)) is distinct from 'object' then raise exception 'invalid_valores'; end if;
  if not exists (select 1 from public.exotic_enclosures where id = p_enclosure and clinic_id = p_clinic) then raise exception 'enclosure_not_found'; end if;

  v_fp = jsonb_build_object('kind','exotic_reading','recinto',p_enclosure,'cuando',v_cuando,'valores',coalesce(p_valores,'{}'::jsonb));
  v_id = private.vet_receipt(p_clinic, p_operation, v_fp);
  if v_id is not null then return v_id; end if;
  perform 1 from public.clinics where id = p_clinic for update;

  insert into public.exotic_enclosure_readings(
    clinic_id,enclosure_id,medido_en,temp_caliente,temp_fria,humedad,uv_index,
    ph,amoniaco,nitrito,salinidad,nota,registrado_por)
  values (p_clinic, p_enclosure, v_cuando,
    (p_valores->>'temp_caliente')::numeric,(p_valores->>'temp_fria')::numeric,
    (p_valores->>'humedad')::numeric,(p_valores->>'uv_index')::numeric,
    (p_valores->>'ph')::numeric,(p_valores->>'amoniaco')::numeric,
    (p_valores->>'nitrito')::numeric,(p_valores->>'salinidad')::numeric,
    nullif(btrim(coalesce(p_nota,'')),''), auth.uid())
  returning id into v_id;

  insert into public.audit_log(clinic_id,actor_id,action,entity_id,details)
  values (p_clinic, auth.uid(), 'exotic_reading_logged', v_id::text, jsonb_build_object('recinto',p_enclosure));
  insert into private.vet_operation_receipts values (auth.uid(), p_clinic, p_operation, v_fp, v_id);
  return v_id;
end$function$;

create or replace function public.exotic_feeding_log(
  p_clinic uuid, p_patient uuid, p_ofrecido_en timestamptz, p_alimento text,
  p_aceptado boolean, p_cantidad numeric, p_nota text, p_operation text
) returns uuid language plpgsql security definer set search_path to '' as $function$
declare v_id uuid; v_fp jsonb; v_cuando timestamptz = coalesce(p_ofrecido_en, clock_timestamp());
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if not private.has_clinic_role(p_clinic, array['admin','mvz','auxiliar']::text[]) then raise exception 'exotic_write_required'; end if;
  if p_aceptado is null then raise exception 'invalid_aceptado'; end if;
  if char_length(btrim(coalesce(p_alimento,''))) < 1 or char_length(btrim(p_alimento)) > 120 then raise exception 'invalid_alimento'; end if;
  if p_cantidad is not null and (p_cantidad < 0 or p_cantidad > 100000) then raise exception 'invalid_cantidad'; end if;
  if v_cuando > clock_timestamp() + interval '1 hour' then raise exception 'invalid_ofrecido_en'; end if;
  if not exists (select 1 from public.vet_patients where id = p_patient and clinic_id = p_clinic) then raise exception 'patient_wrong_clinic'; end if;

  v_fp = jsonb_build_object('kind','exotic_feeding','paciente',p_patient,'cuando',v_cuando,'alimento',btrim(p_alimento),'aceptado',p_aceptado);
  v_id = private.vet_receipt(p_clinic, p_operation, v_fp);
  if v_id is not null then return v_id; end if;
  perform 1 from public.clinics where id = p_clinic for update;

  insert into public.exotic_feedings(clinic_id,patient_id,ofrecido_en,alimento,aceptado,cantidad_g,nota,registrado_por)
  values (p_clinic, p_patient, v_cuando, btrim(p_alimento), p_aceptado, p_cantidad, nullif(btrim(coalesce(p_nota,'')),''), auth.uid())
  returning id into v_id;

  insert into public.audit_log(clinic_id,actor_id,action,entity_id,details)
  values (p_clinic, auth.uid(), 'exotic_feeding_logged', v_id::text, jsonb_build_object('paciente',p_patient,'aceptado',p_aceptado));
  insert into private.vet_operation_receipts values (auth.uid(), p_clinic, p_operation, v_fp, v_id);
  return v_id;
end$function$;

create or replace function public.exotic_event_log(
  p_clinic uuid, p_patient uuid, p_tipo text, p_ocurrio_en timestamptz,
  p_detalle text, p_operation text
) returns uuid language plpgsql security definer set search_path to '' as $function$
declare v_id uuid; v_fp jsonb; v_cuando timestamptz = coalesce(p_ocurrio_en, clock_timestamp());
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if not private.has_clinic_role(p_clinic, array['admin','mvz','auxiliar']::text[]) then raise exception 'exotic_write_required'; end if;
  if p_tipo not in ('ecdisis','ecdisis_retenida','postura','vocalizacion','actividad_anormal','enriquecimiento','otro') then raise exception 'invalid_tipo'; end if;
  if char_length(coalesce(p_detalle,'')) > 2000 then raise exception 'detalle_too_long'; end if;
  if v_cuando > clock_timestamp() + interval '1 hour' then raise exception 'invalid_ocurrio_en'; end if;
  if not exists (select 1 from public.vet_patients where id = p_patient and clinic_id = p_clinic) then raise exception 'patient_wrong_clinic'; end if;

  v_fp = jsonb_build_object('kind','exotic_event','paciente',p_patient,'tipo',p_tipo,'cuando',v_cuando);
  v_id = private.vet_receipt(p_clinic, p_operation, v_fp);
  if v_id is not null then return v_id; end if;
  perform 1 from public.clinics where id = p_clinic for update;

  insert into public.exotic_events(clinic_id,patient_id,tipo,ocurrio_en,detalle,registrado_por)
  values (p_clinic, p_patient, p_tipo, v_cuando, nullif(btrim(coalesce(p_detalle,'')),''), auth.uid())
  returning id into v_id;

  insert into public.audit_log(clinic_id,actor_id,action,entity_id,details)
  values (p_clinic, auth.uid(), 'exotic_event_logged', v_id::text, jsonb_build_object('paciente',p_patient,'tipo',p_tipo));
  insert into private.vet_operation_receipts values (auth.uid(), p_clinic, p_operation, v_fp, v_id);
  return v_id;
end$function$;

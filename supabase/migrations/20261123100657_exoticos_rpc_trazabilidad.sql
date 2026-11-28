-- Marcaje, estatus legal, nidadas y plan de cuarentena.
-- `p_operation` debe ser 48 caracteres hexadecimales (^[a-f0-9]{48}$).

create or replace function public.exotic_identifier_save(
  p_clinic uuid, p_patient uuid, p_tipo text, p_codigo text,
  p_colocado_el date, p_ubicacion text, p_operation text
) returns uuid language plpgsql security definer set search_path to '' as $function$
declare v_id uuid; v_fp jsonb; v_codigo text = btrim(coalesce(p_codigo,''));
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if not private.has_clinic_role(p_clinic, array['admin','mvz','auxiliar']::text[]) then raise exception 'exotic_write_required'; end if;
  if p_tipo not in ('microchip','anillo','muesca','tatuaje','foto') then raise exception 'invalid_tipo'; end if;
  if char_length(v_codigo) < 1 or char_length(v_codigo) > 60 then raise exception 'invalid_codigo'; end if;
  if p_colocado_el is not null and p_colocado_el > current_date then raise exception 'invalid_colocado_el'; end if;
  if not exists (select 1 from public.vet_patients where id = p_patient and clinic_id = p_clinic) then raise exception 'patient_wrong_clinic'; end if;
  -- Un mismo codigo activo en dos ejemplares haria inutil el buscador.
  if exists (select 1 from public.exotic_identifiers i where i.clinic_id = p_clinic and i.tipo = p_tipo and lower(i.codigo) = lower(v_codigo) and i.activo and i.patient_id <> p_patient) then
    raise exception 'codigo_duplicado';
  end if;

  v_fp = jsonb_build_object('kind','exotic_identifier','paciente',p_patient,'tipo',p_tipo,'codigo',lower(v_codigo));
  v_id = private.vet_receipt(p_clinic, p_operation, v_fp);
  if v_id is not null then return v_id; end if;
  perform 1 from public.clinics where id = p_clinic for update;

  insert into public.exotic_identifiers(clinic_id,patient_id,tipo,codigo,colocado_el,ubicacion,created_by)
  values (p_clinic, p_patient, p_tipo, v_codigo, p_colocado_el, nullif(btrim(coalesce(p_ubicacion,'')),''), auth.uid())
  returning id into v_id;

  insert into public.audit_log(clinic_id,actor_id,action,entity_id,details)
  values (p_clinic, auth.uid(), 'exotic_identifier_saved', v_id::text, jsonb_build_object('paciente',p_patient,'tipo',p_tipo));
  insert into private.vet_operation_receipts values (auth.uid(), p_clinic, p_operation, v_fp, v_id);
  return v_id;
end$function$;

-- El estatus legal lo firma quien responde por el: por eso aqui, y solo aqui,
-- la escritura se cierra a admin y MVZ; un auxiliar no puede tocarlo.
create or replace function public.exotic_legal_save(
  p_clinic uuid, p_id uuid, p_patient uuid, p_regimen text, p_apendice text,
  p_numero text, p_desde date, p_hasta date, p_procedencia text,
  p_documentada boolean, p_notas text, p_operation text
) returns uuid language plpgsql security definer set search_path to '' as $function$
declare v_id uuid; v_fp jsonb;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if not private.has_clinic_role(p_clinic, array['admin','mvz']::text[]) then raise exception 'exotic_legal_write_required'; end if;
  if p_regimen not in ('cites','semarnat','uma','pimvs','otro') then raise exception 'invalid_regimen'; end if;
  if p_desde is not null and p_hasta is not null and p_desde > p_hasta then raise exception 'invalid_vigencia'; end if;
  if char_length(coalesce(p_numero,'')) > 80 then raise exception 'numero_too_long'; end if;
  if not exists (select 1 from public.vet_patients where id = p_patient and clinic_id = p_clinic) then raise exception 'patient_wrong_clinic'; end if;

  v_fp = jsonb_build_object('kind','exotic_legal','id',p_id,'paciente',p_patient,'regimen',p_regimen,'numero',coalesce(p_numero,''),'hasta',p_hasta);
  v_id = private.vet_receipt(p_clinic, p_operation, v_fp);
  if v_id is not null then return v_id; end if;
  perform 1 from public.clinics where id = p_clinic for update;

  if p_id is null then
    insert into public.exotic_legal_status(clinic_id,patient_id,regimen,apendice,numero_registro,vigencia_desde,vigencia_hasta,procedencia,documentada,notas,created_by)
    values (p_clinic,p_patient,p_regimen,nullif(btrim(coalesce(p_apendice,'')),''),nullif(btrim(coalesce(p_numero,'')),''),p_desde,p_hasta,nullif(btrim(coalesce(p_procedencia,'')),''),coalesce(p_documentada,false),nullif(btrim(coalesce(p_notas,'')),''),auth.uid())
    returning id into v_id;
  else
    update public.exotic_legal_status set
      regimen=p_regimen, apendice=nullif(btrim(coalesce(p_apendice,'')),''),
      numero_registro=nullif(btrim(coalesce(p_numero,'')),''),
      vigencia_desde=p_desde, vigencia_hasta=p_hasta,
      procedencia=nullif(btrim(coalesce(p_procedencia,'')),''),
      documentada=coalesce(p_documentada,false),
      notas=nullif(btrim(coalesce(p_notas,'')),''),
      version=version+1, updated_at=clock_timestamp()
    where id=p_id and clinic_id=p_clinic returning id into v_id;
    if v_id is null then raise exception 'legal_status_not_found'; end if;
  end if;

  insert into public.audit_log(clinic_id,actor_id,action,entity_id,details)
  values (p_clinic, auth.uid(), 'exotic_legal_saved', v_id::text, jsonb_build_object('paciente',p_patient,'regimen',p_regimen));
  insert into private.vet_operation_receipts values (auth.uid(), p_clinic, p_operation, v_fp, v_id);
  return v_id;
end$function$;

create or replace function public.exotic_clutch_save(
  p_clinic uuid, p_id uuid, p_enclosure uuid, p_patient uuid, p_especie text,
  p_puesta date, p_huevos integer, p_fertiles integer, p_temp numeric,
  p_humedad numeric, p_dias integer, p_estado text, p_notas text, p_operation text
) returns uuid language plpgsql security definer set search_path to '' as $function$
declare v_id uuid; v_fp jsonb; v_eclosion date;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if not private.has_clinic_role(p_clinic, array['admin','mvz','auxiliar']::text[]) then raise exception 'exotic_write_required'; end if;
  if char_length(btrim(coalesce(p_especie,''))) < 1 then raise exception 'invalid_especie'; end if;
  if p_puesta is null or p_puesta > current_date then raise exception 'invalid_puesta'; end if;
  if p_huevos is null or p_huevos < 1 or p_huevos > 10000 then raise exception 'invalid_huevos'; end if;
  if p_fertiles is not null and (p_fertiles < 0 or p_fertiles > p_huevos) then raise exception 'invalid_fertiles'; end if;
  if p_dias is not null and (p_dias < 1 or p_dias > 400) then raise exception 'invalid_dias'; end if;
  if coalesce(p_estado,'incubando') not in ('incubando','eclosionada','perdida','cancelada') then raise exception 'invalid_estado'; end if;
  if p_enclosure is not null and not exists (select 1 from public.exotic_enclosures where id=p_enclosure and clinic_id=p_clinic) then raise exception 'enclosure_not_found'; end if;
  if p_patient is not null and not exists (select 1 from public.vet_patients where id=p_patient and clinic_id=p_clinic) then raise exception 'patient_wrong_clinic'; end if;

  -- La cuenta regresiva se deriva aqui para que no dependa del reloj del movil.
  v_eclosion = case when p_dias is null then null else p_puesta + p_dias end;

  v_fp = jsonb_build_object('kind','exotic_clutch','id',p_id,'especie',btrim(p_especie),'puesta',p_puesta,'huevos',p_huevos);
  v_id = private.vet_receipt(p_clinic, p_operation, v_fp);
  if v_id is not null then return v_id; end if;
  perform 1 from public.clinics where id = p_clinic for update;

  if p_id is null then
    insert into public.exotic_clutches(clinic_id,enclosure_id,patient_id,especie,puesta_el,huevos,fertiles,temp_objetivo,humedad_objetivo,dias_incubacion,eclosion_estimada,estado,notas,created_by)
    values (p_clinic,p_enclosure,p_patient,btrim(p_especie),p_puesta,p_huevos,p_fertiles,p_temp,p_humedad,p_dias,v_eclosion,coalesce(p_estado,'incubando'),nullif(btrim(coalesce(p_notas,'')),''),auth.uid())
    returning id into v_id;
  else
    update public.exotic_clutches set
      enclosure_id=p_enclosure, patient_id=p_patient, especie=btrim(p_especie),
      puesta_el=p_puesta, huevos=p_huevos, fertiles=p_fertiles,
      temp_objetivo=p_temp, humedad_objetivo=p_humedad, dias_incubacion=p_dias,
      eclosion_estimada=v_eclosion, estado=coalesce(p_estado,'incubando'),
      notas=nullif(btrim(coalesce(p_notas,'')),''),
      version=version+1, updated_at=clock_timestamp()
    where id=p_id and clinic_id=p_clinic returning id into v_id;
    if v_id is null then raise exception 'clutch_not_found'; end if;
  end if;

  insert into public.audit_log(clinic_id,actor_id,action,entity_id,details)
  values (p_clinic, auth.uid(), 'exotic_clutch_saved', v_id::text, jsonb_build_object('especie',btrim(p_especie),'huevos',p_huevos));
  insert into private.vet_operation_receipts values (auth.uid(), p_clinic, p_operation, v_fp, v_id);
  return v_id;
end$function$;

create or replace function public.exotic_quarantine_set(
  p_clinic uuid, p_stay uuid, p_dias integer, p_motivo text, p_operation text
) returns uuid language plpgsql security definer set search_path to '' as $function$
declare v_id uuid; v_fp jsonb;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if not private.has_clinic_role(p_clinic, array['admin','mvz','auxiliar']::text[]) then raise exception 'exotic_write_required'; end if;
  if p_dias is null or p_dias < 1 or p_dias > 365 then raise exception 'invalid_dias'; end if;
  if not exists (select 1 from public.hospital_stays where id=p_stay and clinic_id=p_clinic) then raise exception 'stay_not_found'; end if;

  v_fp = jsonb_build_object('kind','exotic_quarantine','estancia',p_stay,'dias',p_dias);
  v_id = private.vet_receipt(p_clinic, p_operation, v_fp);
  if v_id is not null then return v_id; end if;
  perform 1 from public.clinics where id = p_clinic for update;

  insert into public.exotic_quarantine_plans(clinic_id,stay_id,dias,motivo,created_by)
  values (p_clinic,p_stay,p_dias,nullif(btrim(coalesce(p_motivo,'')),''),auth.uid())
  on conflict (clinic_id, stay_id) do update set dias=excluded.dias, motivo=excluded.motivo
  returning id into v_id;

  insert into public.audit_log(clinic_id,actor_id,action,entity_id,details)
  values (p_clinic, auth.uid(), 'exotic_quarantine_set', v_id::text, jsonb_build_object('estancia',p_stay,'dias',p_dias));
  insert into private.vet_operation_receipts values (auth.uid(), p_clinic, p_operation, v_fp, v_id);
  return v_id;
end$function$;

-- Candidate for coordinated integration only. Do not apply directly to production.
-- Cálculos de dosis farmacológica que quedan en la ficha del paciente.
-- Sin acceso directo a la tabla: se escribe y se lee por RPC, con validación
-- de la carga y recibo idempotente por operación. Append-only: no hay update
-- ni delete, porque un cálculo hecho no se reescribe.
begin;

create table if not exists public.vet_dose_calculations (
 id uuid primary key default gen_random_uuid(),
 clinic_id uuid not null references public.clinics(id) on delete cascade,
 patient_id uuid not null references public.vet_patients(id) on delete cascade,
 peso_kg numeric not null check (peso_kg > 0 and peso_kg <= 100000),
 principio text not null check (char_length(btrim(principio)) between 1 and 300),
 pauta_id text not null default '' check (char_length(pauta_id) <= 200),
 indicacion text not null default '' check (char_length(indicacion) <= 500),
 especie text not null default '' check (char_length(especie) <= 120),
 via text not null default '' check (char_length(via) <= 120),
 intervalo text not null default '' check (char_length(intervalo) <= 120),
 dosis_literal text not null check (char_length(btrim(dosis_literal)) between 1 and 300),
 cita text not null check (char_length(btrim(cita)) between 1 and 300),
 resultado_mg text not null check (char_length(btrim(resultado_mg)) between 1 and 120),
 concentracion_mg_ml numeric check (concentracion_mg_ml > 0 and concentracion_mg_ml <= 1000000),
 resultado_ml text check (char_length(btrim(resultado_ml)) between 1 and 120),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default clock_timestamp(),
 constraint vet_dose_calculations_volumen_con_concentracion
   check (resultado_ml is null or concentracion_mg_ml is not null)
);

create index if not exists vet_dose_calculations_patient
 on public.vet_dose_calculations(clinic_id, patient_id, created_at desc);

alter table public.vet_dose_calculations enable row level security;
revoke all on public.vet_dose_calculations from public, anon, authenticated;

-- Quien calcula la dosis es quien la indica: solo MVZ y admin escriben.
-- Auxiliar lee, porque es quien administra y necesita ver qué se calculó;
-- recepción y estilista no ven cálculos clínicos.
create or replace function public.record_vet_dose_calculation(
 p_clinic_id uuid, p_patient_id uuid, p_calculation jsonb, p_operation_id text
) returns uuid language plpgsql volatile security definer set search_path='' as $$
declare v_id uuid; fingerprint jsonb; campo text; peso numeric; concentracion numeric;
begin
 if auth.uid() is null then raise exception 'dose_calculation_sign_in_required'; end if;
 if not private.has_clinic_role(p_clinic_id, array['admin','mvz']::public.clinic_role[]) then
  raise exception 'dose_calculation_role_required';
 end if;
 if not exists(select 1 from public.vet_patients where vet_patients.clinic_id=p_clinic_id and vet_patients.id=p_patient_id) then
  raise exception 'patient_wrong_clinic';
 end if;
 if jsonb_typeof(p_calculation) is distinct from 'object'
    or pg_catalog.octet_length(p_calculation::text) > 20000 then
  raise exception 'invalid_dose_calculation';
 end if;
 fingerprint=jsonb_build_object('kind','dose_calculation','patient',p_patient_id,'payload',p_calculation);
 v_id=private.vet_receipt(p_clinic_id,p_operation_id,fingerprint);
 if v_id is not null then return v_id; end if;
 foreach campo in array array['principio','dosis_literal','cita','resultado_mg'] loop
  if jsonb_typeof(p_calculation->campo) is distinct from 'string'
     or char_length(btrim(p_calculation->>campo)) not between 1 and 300 then
   raise exception 'invalid_dose_calculation';
  end if;
 end loop;
 if jsonb_typeof(p_calculation->'peso_kg') is distinct from 'string'
    or p_calculation->>'peso_kg' !~ '^\d{1,7}([.,]\d{1,6})?$' then
  raise exception 'invalid_weight';
 end if;
 peso=replace(p_calculation->>'peso_kg',',','.')::numeric;
 if peso <= 0 or peso > 100000 then raise exception 'invalid_weight'; end if;
 if p_calculation->'concentracion_mg_ml' is not null and p_calculation->'concentracion_mg_ml' <> 'null'::jsonb then
  if jsonb_typeof(p_calculation->'concentracion_mg_ml') is distinct from 'string'
     or p_calculation->>'concentracion_mg_ml' !~ '^\d{1,7}([.,]\d{1,6})?$' then
   raise exception 'invalid_concentration';
  end if;
  concentracion=replace(p_calculation->>'concentracion_mg_ml',',','.')::numeric;
  if concentracion <= 0 or concentracion > 1000000 then raise exception 'invalid_concentration'; end if;
 end if;
 if p_calculation->'resultado_ml' is not null and p_calculation->'resultado_ml' <> 'null'::jsonb then
  if jsonb_typeof(p_calculation->'resultado_ml') is distinct from 'string'
     or char_length(btrim(p_calculation->>'resultado_ml')) not between 1 and 120 then
   raise exception 'invalid_volume';
  end if;
 end if;
 insert into public.vet_dose_calculations(
  clinic_id,patient_id,peso_kg,principio,pauta_id,indicacion,especie,via,intervalo,
  dosis_literal,cita,resultado_mg,concentracion_mg_ml,resultado_ml,created_by)
 values(
  p_clinic_id,p_patient_id,peso,btrim(p_calculation->>'principio'),
  coalesce(p_calculation->>'pauta_id',''),coalesce(p_calculation->>'indicacion',''),
  coalesce(p_calculation->>'especie',''),coalesce(p_calculation->>'via',''),
  coalesce(p_calculation->>'intervalo',''),btrim(p_calculation->>'dosis_literal'),
  btrim(p_calculation->>'cita'),btrim(p_calculation->>'resultado_mg'),
  concentracion,nullif(btrim(coalesce(p_calculation->>'resultado_ml','')),''),auth.uid())
 returning vet_dose_calculations.id into v_id;
 insert into private.vet_operation_receipts
  values(auth.uid(),p_clinic_id,p_operation_id,fingerprint,v_id);
 insert into public.audit_log(clinic_id,actor_id,action,entity_id,details)
  values(p_clinic_id,auth.uid(),'dose_calculation_recorded',v_id,
   jsonb_build_object('patient_id',p_patient_id,'principio',btrim(p_calculation->>'principio')));
 return v_id;
end $$;
revoke all on function public.record_vet_dose_calculation(uuid,uuid,jsonb,text) from public,anon;
grant execute on function public.record_vet_dose_calculation(uuid,uuid,jsonb,text) to authenticated;

-- La lectura pasa por RLS del dueño de la función, así que el filtro por
-- clínica y rol se repite aquí a propósito.
create or replace function public.vet_dose_calculations_for_patient(
 p_clinic_id uuid, p_patient_id uuid, p_limit integer default 50
) returns setof public.vet_dose_calculations
language sql stable security definer set search_path='' as $$
 select c.* from public.vet_dose_calculations c
 where c.clinic_id=p_clinic_id and c.patient_id=p_patient_id
   and private.has_clinic_role(p_clinic_id, array['admin','mvz','auxiliar']::public.clinic_role[])
 order by c.created_at desc
 limit least(greatest(coalesce(p_limit,50),1),200);
$$;
revoke all on function public.vet_dose_calculations_for_patient(uuid,uuid,integer) from public,anon;
grant execute on function public.vet_dose_calculations_for_patient(uuid,uuid,integer) to authenticated;

notify pgrst,'reload schema';
commit;

-- Isolated fixture for migration 22 (cálculos de dosis en la ficha).
-- No prueba el recorte remoto completo de RLS: crea el andamio mínimo
-- (clínicas, pacientes, recibo de operación, auditoría) y aplica la migración.
create schema if not exists private;
create schema if not exists auth;
do $$begin
 if not exists(select 1 from pg_roles where rolname='anon') then create role anon;end if;
 if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated;end if;
end$$;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$
 select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
create type public.clinic_role as enum ('admin','mvz','auxiliar','recepcion','estilista');
create table public.clinics(id uuid primary key, name text not null default '');
create table public.clinic_memberships(
 id uuid primary key default gen_random_uuid(), clinic_id uuid, user_id uuid, role public.clinic_role not null);
create table public.vet_patients(id uuid primary key, clinic_id uuid, name text, species text, created_by uuid);
create table public.audit_log(id uuid primary key default gen_random_uuid(),
 clinic_id uuid, actor_id uuid, action text, entity_id uuid, details jsonb, created_at timestamptz default now());
create table private.vet_operation_receipts(user_id uuid, clinic_id uuid, operation_id text,
 fingerprint jsonb, entity_id uuid, primary key(user_id,clinic_id,operation_id));
create function private.has_clinic_role(target uuid, allowed public.clinic_role[] default null)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.clinic_memberships m
  where m.clinic_id=target and m.user_id=auth.uid() and (allowed is null or m.role=any(allowed)))$$;
create function private.vet_receipt(c uuid, op text, fp jsonb) returns uuid
language plpgsql security definer set search_path='' as $$
declare r private.vet_operation_receipts;begin
 if op !~ '^[a-f0-9]{48}$' then raise exception 'invalid_operation';end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||c::text||op,0));
 select * into r from private.vet_operation_receipts where user_id=auth.uid() and clinic_id=c and operation_id=op;
 if found then if r.fingerprint<>fp then raise exception 'operation_payload_changed';end if;return r.entity_id;end if;
 return null;end$$;

\ir ../proposed/22_dose_calculations.sql

grant usage on schema public, private, auth to authenticated;
grant execute on function auth.uid(), private.has_clinic_role(uuid, public.clinic_role[]) to authenticated;

insert into auth.users(id) values
 ('11111111-1111-1111-1111-111111111111'),('22222222-2222-2222-2222-222222222222');
insert into public.clinics(id,name) values
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','Clínica ficticia'),
 ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','Otra clínica');
insert into public.clinic_memberships(clinic_id,user_id,role) values
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','11111111-1111-1111-1111-111111111111','mvz'),
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','22222222-2222-2222-2222-222222222222','auxiliar');
insert into public.vet_patients(id,clinic_id,name,species,created_by) values
 ('cccccccc-cccc-cccc-cccc-cccccccccccc','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','Paciente ficticio','Especie ficticia','11111111-1111-1111-1111-111111111111');

begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',true);

do $$
declare a uuid; b uuid; fila public.vet_dose_calculations; n int; carga jsonb;
begin
 carga:=jsonb_build_object('principio','Principio ficticio','pauta_id','F1','indicacion','Indicación ficticia',
  'especie','Especie ficticia','via','oral','intervalo','cada 24 h','dosis_literal','25–50 mg/kg',
  'cita','Fuente ficticia, p. 275','peso_kg','10,5','resultado_mg','250–500 mg',
  'concentracion_mg_ml','50','resultado_ml','5–10 mL');
 a:=public.record_vet_dose_calculation('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'cccccccc-cccc-cccc-cccc-cccccccccccc',carga,repeat('a',48));
 b:=public.record_vet_dose_calculation('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'cccccccc-cccc-cccc-cccc-cccccccccccc',carga,repeat('a',48));
 if a is distinct from b then raise exception 'idempotencia: % vs %',a,b; end if;
 select count(*) into n from public.vet_dose_calculations_for_patient(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','cccccccc-cccc-cccc-cccc-cccccccccccc');
 if n<>1 then raise exception 'conteo: %',n; end if;
 select c.* into fila from public.vet_dose_calculations_for_patient(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','cccccccc-cccc-cccc-cccc-cccccccccccc') c;
 if fila.peso_kg<>10.5 then raise exception 'peso: %',fila.peso_kg; end if;
 if fila.concentracion_mg_ml<>50 then raise exception 'concentracion: %',fila.concentracion_mg_ml; end if;
 if fila.resultado_ml<>'5–10 mL' then raise exception 'volumen: %',fila.resultado_ml; end if;
 if fila.created_by is distinct from auth.uid() then raise exception 'autor'; end if;
end $$;

do $$
begin
 begin
  perform public.record_vet_dose_calculation('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','cccccccc-cccc-cccc-cccc-cccccccccccc',
   jsonb_build_object('principio','A','dosis_literal','b','cita','c','resultado_mg','d','peso_kg','9'),repeat('a',48));
  raise exception 'otro contenido con la misma operación no falló';
 exception when others then
  if sqlerrm not like '%operation_payload_changed%' then raise; end if;
 end;
 begin
  perform public.record_vet_dose_calculation('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','cccccccc-cccc-cccc-cccc-cccccccccccc',
   jsonb_build_object('principio','A','dosis_literal','b','cita','c','resultado_mg','d','peso_kg','mucho'),repeat('b',48));
  raise exception 'peso no numérico aceptado';
 exception when others then
  if sqlerrm not like '%invalid_weight%' then raise; end if;
 end;
 begin
  perform public.record_vet_dose_calculation('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','cccccccc-cccc-cccc-cccc-cccccccccccc',
   jsonb_build_object('principio','A','dosis_literal','b','cita','c','resultado_mg','d','peso_kg','0'),repeat('c',48));
  raise exception 'peso cero aceptado';
 exception when others then
  if sqlerrm not like '%invalid_weight%' then raise; end if;
 end;
 begin
  perform public.record_vet_dose_calculation('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','cccccccc-cccc-cccc-cccc-cccccccccccc',
   jsonb_build_object('principio','A','dosis_literal','b','cita','c','resultado_mg','d','peso_kg','10','concentracion_mg_ml','0'),repeat('d',48));
  raise exception 'concentración cero aceptada';
 exception when others then
  if sqlerrm not like '%invalid_concentration%' then raise; end if;
 end;
 begin
  perform public.record_vet_dose_calculation('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','cccccccc-cccc-cccc-cccc-cccccccccccc',
   jsonb_build_object('principio','A','dosis_literal','b','cita','c','resultado_mg','d','peso_kg','10','resultado_ml','5 mL'),repeat('e',48));
  raise exception 'volumen sin concentración aceptado';
 exception when others then
  if sqlerrm not like '%vet_dose_calculations_volumen_con_concentracion%' then raise; end if;
 end;
 begin
  perform public.record_vet_dose_calculation('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','cccccccc-cccc-cccc-cccc-cccccccccccc',
   jsonb_build_object('principio','A','dosis_literal','b','cita','c','resultado_mg','d','peso_kg','10'),repeat('f',48));
  raise exception 'clínica ajena aceptada';
 exception when others then
  if sqlerrm not like '%dose_calculation_role_required%' then raise; end if;
 end;
 begin
  perform 1 from public.vet_dose_calculations limit 1;
  raise exception 'lectura directa de la tabla permitida';
 exception when insufficient_privilege then null;
 end;
end $$;

-- Auxiliar: no escribe el cálculo, pero sí lo lee para administrarlo.
select set_config('request.jwt.claim.sub','22222222-2222-2222-2222-222222222222',true);
do $$
declare n int;
begin
 begin
  perform public.record_vet_dose_calculation('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','cccccccc-cccc-cccc-cccc-cccccccccccc',
   jsonb_build_object('principio','A','dosis_literal','b','cita','c','resultado_mg','d','peso_kg','10'),repeat('9',48));
  raise exception 'auxiliar escribió un cálculo';
 exception when others then
  if sqlerrm not like '%dose_calculation_role_required%' then raise; end if;
 end;
 select count(*) into n from public.vet_dose_calculations_for_patient(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','cccccccc-cccc-cccc-cccc-cccccccccccc');
 if n<>1 then raise exception 'auxiliar debería leer 1, leyó %',n; end if;
end $$;

-- Quien no es de la clínica no lee nada.
select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333333',true);
do $$
declare n int;
begin
 select count(*) into n from public.vet_dose_calculations_for_patient(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','cccccccc-cccc-cccc-cccc-cccccccccccc');
 if n<>0 then raise exception 'ajeno leyó % filas',n; end if;
end $$;
rollback;

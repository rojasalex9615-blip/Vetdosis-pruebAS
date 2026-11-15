-- Regresión aislada del módulo M15 (aves de postura).
-- Usa dependencias sintéticas mínimas; no acredita el corte RLS remoto completo.
create schema if not exists private;create schema if not exists auth;
do $$begin
 if not exists(select 1 from pg_roles where rolname='anon') then create role anon;end if;
 if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated;end if;
end$$;
create table if not exists auth.users(id uuid primary key);
create or replace function auth.uid() returns uuid language sql stable as
 $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
create table if not exists public.clinics(id uuid primary key);
create table if not exists public.clinic_members(
 clinic_id uuid,user_id uuid,role text default 'admin',
 created_at timestamptz default now(),primary key(clinic_id,user_id));
create table if not exists public.audit_log(clinic_id uuid,actor_id uuid,action text,entity_id text);
create table if not exists public.inventory_clinic_settings(clinic_id uuid,timezone text);
create table if not exists private.vet_operation_receipts(
 user_id uuid,clinic_id uuid,operation_id text,fingerprint jsonb,entity_id uuid,
 primary key(user_id,clinic_id,operation_id));
create or replace function private.vet_receipt(c uuid,op text,fp jsonb)
returns uuid language plpgsql as $$
declare r private.vet_operation_receipts;begin
 if op !~ '^[a-f0-9]{48}$' then raise exception 'invalid_operation';end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||c::text||op,0));
 select * into r from private.vet_operation_receipts
  where user_id=auth.uid() and clinic_id=c and operation_id=op;
 if found then
  if r.fingerprint<>fp then raise exception 'operation_payload_changed';end if;
  return r.entity_id;
 end if;
 return null;
end$$;

\ir ../adaptations/existing_aviculture_m15.sql

insert into auth.users values
 ('00000000-0000-0000-0000-000000000001'),
 ('00000000-0000-0000-0000-000000000002'),
 ('00000000-0000-0000-0000-000000000003');
insert into public.clinics values
 ('10000000-0000-0000-0000-000000000001'),
 ('10000000-0000-0000-0000-000000000002');
insert into public.clinic_members(clinic_id,user_id,role) values
 ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','admin'),
 ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','auxiliar'),
 ('10000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000003','admin');
insert into public.inventory_clinic_settings values
 ('10000000-0000-0000-0000-000000000001','America/Mexico_City');

create or replace function public.test_avi_denied(sql text,expected text)
returns void language plpgsql as $$begin
 begin execute sql;raise exception 'expected_denial';
 exception when others then
  if sqlerrm<>expected then raise exception 'Expected %, got %',expected,sqlerrm;end if;
 end;
end$$;

select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',false);
-- Catálogo instalado con los datos declarados.
do $$declare r jsonb;begin
 r=public.avi_workspace('10000000-0000-0000-0000-000000000001');
 if r->>'schema_version'<>'1' then raise exception 'schema_version';end if;
 if jsonb_array_length(r->'references')<>15 then raise exception 'references';end if;
 if jsonb_array_length(r->'equipment')<>7 then raise exception 'equipment';end if;
 if (select count(*) from public.aviculture_references where estado='pendiente')<>3 then
  raise exception 'pending_references';
 end if;
 if (select min(minimo) from public.aviculture_references
  where etapa='postura' and sistema='jaula_bateria')<>450 then
  raise exception 'postura_jaula_range';
 end if;
end$$;

-- Aislamiento: otra clínica y usuarios sin membresía.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',false);
select public.test_avi_denied(
 $q$select public.avi_workspace('10000000-0000-0000-0000-000000000001')$q$,'access_denied');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',false);
select public.test_avi_denied(
 $q$select public.avi_workspace('10000000-0000-0000-0000-000000000002')$q$,'access_denied');

do $$declare c uuid='10000000-0000-0000-0000-000000000001';
 h uuid;f uuid;p uuid;e uuid;r jsonb;x uuid;y uuid;begin
 -- Caseta: alta idempotente y control de versión.
 x=public.avi_house_save(c,null,null,
  '{"name":"Caseta 1","system":"jaula_bateria","capacity":1200,"notes":"Sintética"}',repeat('a',48));
 y=public.avi_house_save(c,null,null,
  '{"name":"Caseta 1","system":"jaula_bateria","capacity":1200,"notes":"Sintética"}',repeat('a',48));
 if x<>y then raise exception 'house_retry';end if;
 h=x;
 x=public.avi_house_save(c,h,1,'{"name":"Caseta 1","system":"piso","capacity":900}',repeat('c',48));
 if x<>h or (select version from public.aviculture_houses where id=h)<>2 then
  raise exception 'house_update';
 end if;
 perform public.test_avi_denied(format(
  'select public.avi_house_save(%L,%L,1,%L,%L)',c,h,
  '{"name":"Caseta 1","system":"piso","capacity":900}',repeat('b',48)),'version_conflict');
 -- Nombre duplicado en la misma clínica.
 perform public.test_avi_denied(format(
  'select public.avi_house_save(%L,null,null,%L,%L)',c,
  '{"name":"Caseta 1","system":"piso","capacity":10}',repeat('d',48)),'duplicate key value violates unique constraint "aviculture_houses_name_key"');
 -- Parvada.
 f=public.avi_flock_save(c,null,null,jsonb_build_object(
  'code','P-2026-01','house_id',h,'genetic_line','Lohmann Brown',
  'start_date',(current_date-70)::text,'initial_birds',1000),repeat('e',48));
 perform public.test_avi_denied(format(
  'select public.avi_flock_save(%L,null,null,%L,%L)',c,
  '{"code":"P-2026-01","start_date":"2026-01-01","initial_birds":10}',repeat('f',48)),
  'flock_code_exists');
 perform public.test_avi_denied(format(
  'select public.avi_flock_save(%L,null,null,%L,%L)',c,
  jsonb_build_object('code','P-2027-01','start_date',(current_date+7)::text,
   'initial_birds',10),repeat('1',48)),'invalid_date');
 -- Registro diario.
 p=public.avi_production_save(c,null,null,jsonb_build_object(
  'flock_id',f,'date',(current_date-1)::text,'eggs',800,'eggs_discarded',12,
  'mortality',2,'feed_kg','112.500','avg_weight_g','1850','notes','Sintético'),repeat('2',48));
 perform public.test_avi_denied(format(
  'select public.avi_production_save(%L,null,null,%L,%L)',c,
  jsonb_build_object('flock_id',f,'date',(current_date-1)::text,'eggs',1),repeat('3',48)),
  'record_exists');
 perform public.test_avi_denied(format(
  'select public.avi_production_save(%L,null,null,%L,%L)',c,
  jsonb_build_object('flock_id',f,'date',(current_date-2)::text,'mortality',1000),repeat('4',48)),
  'mortality_exceeds_birds');
 r=public.avi_workspace(c);
 if (r->'flocks'->0->>'birds')::int<>998 then raise exception 'birds';end if;
 if (r->'flocks'->0->>'mortality_pct')::numeric<>0.20 then raise exception 'mortality_pct';end if;
 if (r->'flocks'->0->>'laying_pct')::numeric<>80.16 then raise exception 'laying_pct';end if;
 if (r->'flocks'->0->>'feed_g_bird_day')::numeric<>112.7 then raise exception 'feed_g';end if;
 if jsonb_array_length(r->'records')<>1 then raise exception 'records';end if;
 -- Edición concurrente del registro.
 perform public.test_avi_denied(format(
  'select public.avi_production_save(%L,%L,99,%L,%L)',c,p,
  jsonb_build_object('flock_id',f,'date',(current_date-1)::text,'eggs',1),repeat('5',48)),
  'version_conflict');
 x=public.avi_production_save(c,p,1,jsonb_build_object(
  'flock_id',f,'date',(current_date-1)::text,'eggs',810,'mortality',2,'feed_kg','112.500'),
  repeat('6',48));
 if x<>p or (select version from public.aviculture_production_records where id=p)<>2 then
  raise exception 'production_update';
 end if;
 -- Fecha anterior al inicio de la parvada.
 perform public.test_avi_denied(format(
  'select public.avi_production_save(%L,null,null,%L,%L)',c,
  jsonb_build_object('flock_id',f,'date',(current_date-90)::text,'eggs',1),repeat('7',48)),
  'invalid_date');
 -- Evento con retiro de huevo.
 e=public.avi_event_save(c,null,null,jsonb_build_object(
  'flock_id',f,'date',(current_date-2)::text,'kind','tratamiento',
  'title','Antibiótico sintético','details','Retiro de huevo',
  'withdrawal_until',(current_date+8)::text),repeat('8',48));
 perform public.test_avi_denied(format(
  'select public.avi_event_save(%L,null,null,%L,%L)',c,
  jsonb_build_object('flock_id',f,'date',(current_date-2)::text,'kind','otro',
   'title','X','withdrawal_until',(current_date-30)::text),repeat('9',48)),
  'invalid_date');
 r=public.avi_workspace(c);
 if jsonb_array_length(r->'events')<>1 then raise exception 'events';end if;
 -- Cierre del ciclo: no admite más registros.
 perform public.avi_flock_save(c,f,1,jsonb_build_object(
  'code','P-2026-01','start_date',(current_date-70)::text,'initial_birds',1000,
  'status','cerrada'),repeat('a1',24));
 perform public.test_avi_denied(format(
  'select public.avi_production_save(%L,null,null,%L,%L)',c,
  jsonb_build_object('flock_id',f,'date',current_date::text,'eggs',1),repeat('b1',24)),
  'flock_closed');
 -- Cambiar aves iniciales con registros existentes tampoco se permite.
 perform public.test_avi_denied(format(
  'select public.avi_flock_save(%L,%L,2,%L,%L)',c,f,
  jsonb_build_object('code','P-2026-01','start_date',(current_date-70)::text,
   'initial_birds',1200,'status','cerrada'),repeat('c1',24)),'flock_has_records');
 if (select initial_birds from public.aviculture_flocks where id=f)<>1000 then
  raise exception 'initial_birds_changed';
 end if;
 if (select count(*) from public.audit_log where clinic_id=c and action like 'avi_%')<5 then
  raise exception 'audit';
 end if;
end$$;

-- Auxiliar: registra producción, pero no crea ni cierra parvadas.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',false);
do $$declare c uuid='10000000-0000-0000-0000-000000000001';f uuid;begin
 select id into f from public.aviculture_flocks where clinic_id=c;
 perform public.test_avi_denied(format(
  'select public.avi_flock_save(%L,null,null,%L,%L)',c,
  jsonb_build_object('code','P-2026-02','start_date',current_date::text,
   'initial_birds',50),repeat('d1',24)),'lead_role_required');
 update public.aviculture_flocks set status='activa' where id=f;
 perform public.avi_production_save(c,null,null,jsonb_build_object(
  'flock_id',f,'date',current_date::text,'eggs',795,'mortality',1),repeat('e1',24));
end$$;

-- Sin privilegios directos ni ejecución anónima.
do $$begin
 if has_table_privilege('authenticated','public.aviculture_flocks','select') or
  has_table_privilege('authenticated','public.aviculture_production_records','insert') or
  has_function_privilege('anon','public.avi_workspace(uuid)','execute') or
  has_function_privilege('authenticated','private.avi_guard(uuid,boolean,boolean)','execute')
 then raise exception 'privileges_leak';end if;
end$$;
set role authenticated;
select public.avi_workspace('10000000-0000-0000-0000-000000000001');
reset role;

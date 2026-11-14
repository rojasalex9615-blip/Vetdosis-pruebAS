-- 15P: planes guardados del flujo de produccion porcino por bandas.
-- Origen: hoja de clase Flujo_produccion_bandas.xlsx (550 vientres, banda de 14 dias).
-- Multi-clinica, RLS por rol, escritura solo por RPC con recibo idempotente.
--
-- ESTADO: CANDIDATO. No aplicado todavia en Supabase Pruebas; aplicar con DB URL
-- (psql) o desde el editor SQL. Mismo patron que 20261112000100_produccion_lotes.sql.
begin;

create table if not exists public.produccion_bandas_planes (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  nombre text not null check (char_length(btrim(nombre)) between 1 and 120),
  especie text not null default 'cerdo' check (char_length(btrim(especie)) between 1 and 40),
  entradas jsonb not null check (jsonb_typeof(entradas)='object' and octet_length(entradas::text)<=8000),
  resultados jsonb not null default '{}'::jsonb check (jsonb_typeof(resultados)='object' and octet_length(resultados::text)<=8000),
  version integer not null default 1 check (version>0),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  unique (clinic_id, nombre),
  unique (id, clinic_id)
);

create index if not exists produccion_bandas_planes_clinic on public.produccion_bandas_planes(clinic_id, updated_at desc);

alter table public.produccion_bandas_planes enable row level security;
revoke all on public.produccion_bandas_planes from public,anon,authenticated;
grant select on public.produccion_bandas_planes to authenticated;

drop policy if exists produccion_bandas_planes_read on public.produccion_bandas_planes;
create policy produccion_bandas_planes_read on public.produccion_bandas_planes
  for select to authenticated using (private.has_clinic_role(clinic_id));

create or replace function public.produccion_banda_guardar(p_clinic uuid,p_data jsonb,p_operation text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;v_fp jsonb;v_version integer;
begin
 if auth.uid() is null then raise exception 'authentication_required';end if;
 if not private.has_clinic_role(p_clinic,array['admin','mvz','auxiliar']::text[]) then raise exception 'produccion_write_required';end if;
 if jsonb_typeof(p_data) is distinct from 'object' or octet_length(p_data::text)>20000 then raise exception 'invalid_data';end if;
 if exists(select 1 from jsonb_object_keys(p_data) k where k not in ('id','nombre','especie','entradas','resultados','version')) then raise exception 'invalid_fields';end if;
 if coalesce(btrim(p_data->>'nombre'),'')='' then raise exception 'nombre_required';end if;
 if jsonb_typeof(p_data->'entradas') is distinct from 'object' then raise exception 'entradas_required';end if;
 if p_data?'resultados' and jsonb_typeof(p_data->'resultados') is distinct from 'object' then raise exception 'invalid_resultados';end if;
 v_fp=jsonb_build_object('kind','produccion_banda','data',p_data);
 v_id=private.vet_receipt(p_clinic,p_operation,v_fp);if v_id is not null then return v_id;end if;
 perform 1 from public.clinics where id=p_clinic for update;
 v_id=nullif(p_data->>'id','')::uuid;
 if v_id is null then
  insert into public.produccion_bandas_planes(clinic_id,nombre,especie,entradas,resultados,created_by)
  values(p_clinic,btrim(p_data->>'nombre'),coalesce(nullif(btrim(p_data->>'especie'),''),'cerdo'),p_data->'entradas',coalesce(p_data->'resultados','{}'::jsonb),auth.uid())
  returning id into v_id;
 else
  if coalesce(p_data->>'version','')!~'^[0-9]{1,9}$' then raise exception 'version_required';end if;
  v_version=(p_data->>'version')::integer;
  update public.produccion_bandas_planes set
   nombre=btrim(p_data->>'nombre'),
   especie=coalesce(nullif(btrim(p_data->>'especie'),''),especie),
   entradas=p_data->'entradas',
   resultados=coalesce(p_data->'resultados',resultados),
   version=version+1,
   updated_at=clock_timestamp()
  where id=v_id and clinic_id=p_clinic and version=v_version;
  if not found then raise exception 'version_conflict_or_not_found';end if;
 end if;
 insert into public.audit_log(clinic_id,actor_id,action,entity_id,details) values(p_clinic,auth.uid(),'produccion_banda_saved',v_id::text,jsonb_build_object('nombre',p_data->>'nombre'));
 insert into private.vet_operation_receipts values(auth.uid(),p_clinic,p_operation,v_fp,v_id);
 return v_id;
end$$;

create or replace function public.produccion_banda_eliminar(p_clinic uuid,p_id uuid,p_operation text)
returns boolean language plpgsql security definer set search_path='' as $$
declare v_fp jsonb;v_receipt uuid;
begin
 if auth.uid() is null then raise exception 'authentication_required';end if;
 if not private.has_clinic_role(p_clinic,array['admin','mvz']::text[]) then raise exception 'admin_or_mvz_required';end if;
 if p_id is null then raise exception 'id_required';end if;
 v_fp=jsonb_build_object('kind','produccion_banda_delete','id',p_id);
 v_receipt=private.vet_receipt(p_clinic,p_operation,v_fp);if v_receipt is not null then return true;end if;
 perform 1 from public.clinics where id=p_clinic for update;
 delete from public.produccion_bandas_planes where id=p_id and clinic_id=p_clinic;
 if not found then raise exception 'not_found';end if;
 insert into public.audit_log(clinic_id,actor_id,action,entity_id,details) values(p_clinic,auth.uid(),'produccion_banda_deleted',p_id::text,'{}'::jsonb);
 insert into private.vet_operation_receipts values(auth.uid(),p_clinic,p_operation,v_fp,p_id);
 return true;
end$$;

revoke all on function public.produccion_banda_guardar(uuid,jsonb,text),public.produccion_banda_eliminar(uuid,uuid,text) from public,anon;
grant execute on function public.produccion_banda_guardar(uuid,jsonb,text),public.produccion_banda_eliminar(uuid,uuid,text) to authenticated;

notify pgrst,'reload schema';
commit;

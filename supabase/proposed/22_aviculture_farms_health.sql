-- Candidata: granjas, casetas y bitácora sanitaria compartidas por clínica.
-- Requiere M15; no activa pautas ni recomendaciones de medicamentos.
begin;
create table if not exists public.aviculture_farms(
 id uuid primary key default gen_random_uuid(),clinic_id uuid not null references public.clinics(id),
 name text not null check(btrim(name)<>'' and length(name)<=80),
 identifier text not null default '' check(length(identifier)<=80),
 location text not null default '' check(length(location)<=200),
 notes text not null default '' check(length(notes)<=1000),
 archived boolean not null default false,version integer not null default 1 check(version>0),
 created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 updated_at timestamptz not null default clock_timestamp(),unique(clinic_id,id));
create unique index if not exists avi_farms_name_key on public.aviculture_farms(clinic_id,lower(btrim(name)));
alter table public.aviculture_houses add column if not exists farm_id uuid;
do $$begin
 if not exists(select 1 from pg_constraint where conname='avi_house_farm_fk' and conrelid='public.aviculture_houses'::regclass) then
  alter table public.aviculture_houses add constraint avi_house_farm_fk foreign key(clinic_id,farm_id)
   references public.aviculture_farms(clinic_id,id);
 end if;
end$$;
-- Caseta 1 puede existir en cada granja; las casetas históricas siguen sin granja.
drop index if exists public.aviculture_houses_name_key;
create unique index if not exists aviculture_houses_name_key on public.aviculture_houses(clinic_id,lower(btrim(name))) where farm_id is null;
create unique index if not exists avi_houses_farm_name_key on public.aviculture_houses(clinic_id,farm_id,lower(btrim(name))) where farm_id is not null;
create unique index if not exists avi_house_scope_key on public.aviculture_houses(clinic_id,farm_id,id);
create table if not exists public.aviculture_health_events(
 id uuid primary key default gen_random_uuid(),clinic_id uuid not null,farm_id uuid not null,house_id uuid not null,
 flock_id uuid,occurred_on date not null,kind text not null check(kind in('vacunacion','medicacion','enfermedad')),
 product text not null default '' check(length(product)<=160),dose text not null default '' check(length(dose)<=200),
 route text not null default '' check(length(route)<=80),diagnosis text not null default '' check(length(diagnosis)<=300),
 status text not null default 'observada' check(status in('observada','confirmada','resuelta')),
 details text not null default '' check(length(details)<=2000),ended_on date,withdrawal_until date,
 created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 unique(clinic_id,id),foreign key(clinic_id,farm_id,house_id) references public.aviculture_houses(clinic_id,farm_id,id),
 foreign key(clinic_id,flock_id) references public.aviculture_flocks(clinic_id,id),
 check((kind='enfermedad' and btrim(diagnosis)<>'') or(kind<>'enfermedad' and btrim(product)<>'')),
 check(ended_on is null or ended_on>=occurred_on),check(withdrawal_until is null or withdrawal_until>=occurred_on));
create index if not exists avi_health_history on public.aviculture_health_events(clinic_id,farm_id,house_id,occurred_on desc);
alter table public.aviculture_farms enable row level security;
alter table public.aviculture_health_events enable row level security;
revoke all on public.aviculture_farms,public.aviculture_health_events from public,anon,authenticated;

create or replace function public.avi_farms_workspace(p_clinic uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare base jsonb;r text;
begin
 r=private.avi_guard(p_clinic,false,false);
 base=public.avi_workspace(p_clinic);
 return jsonb_build_object('schema_version',1,'clinic_id',p_clinic,'can_manage',r in('admin','mvz'),'records',base,
  'farms',(select coalesce(jsonb_agg(to_jsonb(f) order by f.name),'[]'::jsonb) from public.aviculture_farms f where f.clinic_id=p_clinic),
  'house_farms',(select coalesce(jsonb_agg(jsonb_build_object('house_id',h.id,'farm_id',h.farm_id)),'[]'::jsonb)
   from public.aviculture_houses h where h.clinic_id=p_clinic),
  'health',(select coalesce(jsonb_agg(to_jsonb(e) order by e.occurred_on desc,e.created_at desc),'[]'::jsonb)
   from public.aviculture_health_events e where e.clinic_id=p_clinic));
end$$;

create or replace function public.avi_farm_save(p_clinic uuid,p_id uuid,p_version integer,p_data jsonb,p_operation text)
returns uuid language plpgsql security definer set search_path='' as $$
declare r uuid;v public.aviculture_farms;fp jsonb;v_name text;v_identifier text;v_location text;v_notes text;v_archived boolean;
begin
 perform private.avi_guard(p_clinic,true,true);
 if p_data is null or jsonb_typeof(p_data)<>'object' or octet_length(p_data::text)>6000
  or p_data - array['name','identifier','location','notes','archived'] <> '{}'::jsonb then raise exception 'invalid_data';end if;
 v_name=private.avi_text(p_data,'name',80,true);v_identifier=private.avi_text(p_data,'identifier',80,false);
 v_location=private.avi_text(p_data,'location',200,false);v_notes=private.avi_text(p_data,'notes',1000,false);
 if coalesce(p_data->>'archived','false') not in('true','false') then raise exception 'invalid_data';end if;
 v_archived=coalesce((p_data->>'archived')::boolean,false);
 fp=jsonb_build_object('kind','avi_farm','id',p_id,'version',p_version,'data',p_data);
 r=private.vet_receipt(p_clinic,p_operation,fp);if r is not null then return r;end if;
 if p_id is null then
  insert into public.aviculture_farms(clinic_id,name,identifier,location,notes,archived,created_by)
   values(p_clinic,v_name,v_identifier,v_location,v_notes,v_archived,auth.uid()) returning id into r;
 else
  select * into v from public.aviculture_farms where clinic_id=p_clinic and id=p_id for update;
  if not found then raise exception 'not_found';end if;
  if v.version is distinct from p_version then raise exception 'version_conflict';end if;
  if v_archived and exists(select 1 from public.aviculture_houses where clinic_id=p_clinic and farm_id=p_id and not archived)
   then raise exception 'farm_has_active_houses';end if;
  update public.aviculture_farms set name=v_name,identifier=v_identifier,location=v_location,notes=v_notes,
   archived=v_archived,version=version+1,updated_at=clock_timestamp() where id=p_id and clinic_id=p_clinic returning id into r;
 end if;
 insert into public.audit_log(clinic_id,actor_id,action,entity_id) values(p_clinic,auth.uid(),'avi_farm_saved',r::text);
 insert into private.vet_operation_receipts values(auth.uid(),p_clinic,p_operation,fp,r);return r;
end$$;

create or replace function public.avi_farm_house_save(p_clinic uuid,p_farm uuid,p_id uuid,p_version integer,p_data jsonb,p_operation text)
returns uuid language plpgsql security definer set search_path='' as $$
declare r uuid;v public.aviculture_houses;fp jsonb;v_name text;v_system text;v_notes text;v_capacity bigint;v_archived boolean;
begin
 perform private.avi_guard(p_clinic,true,true);
 if p_data is null or jsonb_typeof(p_data)<>'object' or octet_length(p_data::text)>4000
  or p_data - array['name','system','capacity','notes','archived'] <> '{}'::jsonb then raise exception 'invalid_data';end if;
 v_name=private.avi_text(p_data,'name',80,true);v_notes=private.avi_text(p_data,'notes',1000,false);
 v_system=coalesce(p_data->>'system','');if v_system not in('piso','jaula_bateria') then raise exception 'invalid_system';end if;
 v_capacity=private.avi_int(p_data,'capacity',0,1000000,0);
 if coalesce(p_data->>'archived','false') not in('true','false') then raise exception 'invalid_data';end if;
 v_archived=coalesce((p_data->>'archived')::boolean,false);
 fp=jsonb_build_object('kind','avi_farm_house','farm',p_farm,'id',p_id,'version',p_version,'data',p_data);
 r=private.vet_receipt(p_clinic,p_operation,fp);if r is not null then return r;end if;
 perform 1 from public.aviculture_farms where clinic_id=p_clinic and id=p_farm and not archived for update;
 if not found then raise exception 'farm_not_available';end if;
 if p_id is null then
  insert into public.aviculture_houses(clinic_id,farm_id,name,system,capacity_birds,notes,archived,created_by)
   values(p_clinic,p_farm,v_name,v_system,v_capacity::int,v_notes,v_archived,auth.uid()) returning id into r;
 else
  select * into v from public.aviculture_houses where clinic_id=p_clinic and id=p_id for update;
  if not found then raise exception 'not_found';end if;
  if v.version is distinct from p_version then raise exception 'version_conflict';end if;
  if v.farm_id is not null and v.farm_id<>p_farm and
   (exists(select 1 from public.aviculture_flocks where clinic_id=p_clinic and house_id=p_id)
    or exists(select 1 from public.aviculture_health_events where clinic_id=p_clinic and house_id=p_id))
   then raise exception 'house_has_history';end if;
  update public.aviculture_houses set farm_id=p_farm,name=v_name,system=v_system,capacity_birds=v_capacity::int,
   notes=v_notes,archived=v_archived,version=version+1,updated_at=clock_timestamp() where clinic_id=p_clinic and id=p_id returning id into r;
 end if;
 insert into public.audit_log(clinic_id,actor_id,action,entity_id) values(p_clinic,auth.uid(),'avi_farm_house_saved',r::text);
 insert into private.vet_operation_receipts values(auth.uid(),p_clinic,p_operation,fp,r);return r;
end$$;

create or replace function public.avi_health_event_save(p_clinic uuid,p_data jsonb,p_operation text)
returns uuid language plpgsql security definer set search_path='' as $$
declare r uuid;fp jsonb;v_house public.aviculture_houses;v_house_id uuid;v_flock uuid;v_day date;v_ended date;v_withdrawal date;
 v_kind text;v_product text;v_dose text;v_route text;v_diagnosis text;v_details text;v_status text;tz text;
begin
 perform private.avi_guard(p_clinic,true,false);
 if p_data is null or jsonb_typeof(p_data)<>'object' or octet_length(p_data::text)>14000 or
  p_data-array['house_id','flock_id','date','kind','product','dose','route','diagnosis','status','details','ended_on','withdrawal_until']<>'{}'::jsonb
  then raise exception 'invalid_data';end if;
 begin v_house_id=(p_data->>'house_id')::uuid;v_flock=nullif(p_data->>'flock_id','')::uuid;v_day=(p_data->>'date')::date;
  v_ended=nullif(p_data->>'ended_on','')::date;v_withdrawal=nullif(p_data->>'withdrawal_until','')::date;
 exception when others then raise exception 'invalid_date';end;
 v_kind=coalesce(p_data->>'kind','');if v_kind not in('vacunacion','medicacion','enfermedad') then raise exception 'invalid_kind';end if;
 v_product=private.avi_text(p_data,'product',160,v_kind<>'enfermedad');v_dose=private.avi_text(p_data,'dose',200,false);
 v_route=private.avi_text(p_data,'route',80,false);v_diagnosis=private.avi_text(p_data,'diagnosis',300,v_kind='enfermedad');
 v_details=private.avi_text(p_data,'details',2000,false);v_status=coalesce(p_data->>'status','observada');
 if v_status not in('observada','confirmada','resuelta') then raise exception 'invalid_data';end if;
 select coalesce(timezone,'America/Mexico_City') into tz from public.inventory_clinic_settings where clinic_id=p_clinic;
 tz=coalesce(tz,'America/Mexico_City');
 if v_day is null or v_day>(statement_timestamp() at time zone tz)::date or v_ended<v_day or v_withdrawal<v_day then raise exception 'invalid_date';end if;
 fp=jsonb_build_object('kind','avi_health','data',p_data);r=private.vet_receipt(p_clinic,p_operation,fp);if r is not null then return r;end if;
 select * into v_house from public.aviculture_houses where clinic_id=p_clinic and id=v_house_id and not archived for update;
 if not found or v_house.farm_id is null then raise exception 'house_not_available';end if;
 if v_flock is not null and not exists(select 1 from public.aviculture_flocks f where f.clinic_id=p_clinic
   and f.id=v_flock and f.house_id=v_house_id and f.start_date<=v_day) then raise exception 'flock_not_in_house';end if;
 insert into public.aviculture_health_events(clinic_id,farm_id,house_id,flock_id,occurred_on,kind,product,dose,route,diagnosis,status,details,ended_on,withdrawal_until,created_by)
 values(p_clinic,v_house.farm_id,v_house_id,v_flock,v_day,v_kind,v_product,v_dose,v_route,v_diagnosis,v_status,v_details,v_ended,v_withdrawal,auth.uid()) returning id into r;
 insert into public.audit_log(clinic_id,actor_id,action,entity_id) values(p_clinic,auth.uid(),'avi_health_recorded',r::text);
 insert into private.vet_operation_receipts values(auth.uid(),p_clinic,p_operation,fp,r);return r;
end$$;
revoke all on function public.avi_farms_workspace(uuid),public.avi_farm_save(uuid,uuid,integer,jsonb,text),
 public.avi_farm_house_save(uuid,uuid,uuid,integer,jsonb,text),public.avi_health_event_save(uuid,jsonb,text) from public,anon;
grant execute on function public.avi_farms_workspace(uuid),public.avi_farm_save(uuid,uuid,integer,jsonb,text),
 public.avi_farm_house_save(uuid,uuid,uuid,integer,jsonb,text),public.avi_health_event_save(uuid,jsonb,text) to authenticated;

-- Preserva exactamente el snapshot vigente y añade el módulo avícola al respaldo
-- de clínica. Los controles de autorización de clinic_export siguen vigentes.
do $$begin
 if to_regprocedure('private.clinic_snapshot(uuid)') is not null and
    to_regprocedure('private.clinic_snapshot_before_avi_farms(uuid)') is null then
  execute replace(pg_get_functiondef('private.clinic_snapshot(uuid)'::regprocedure),
   'FUNCTION private.clinic_snapshot(', 'FUNCTION private.clinic_snapshot_before_avi_farms(');
 end if;
end$$;
do $$begin
 if to_regprocedure('private.clinic_snapshot_before_avi_farms(uuid)') is not null then
  revoke all on function private.clinic_snapshot_before_avi_farms(uuid) from public,anon,authenticated;
  execute $body$create or replace function private.clinic_snapshot(p_clinic uuid) returns text
  language plpgsql security definer set search_path='' as $fn$
  declare result jsonb;t text;rows jsonb;
  begin
   result=private.clinic_snapshot_before_avi_farms(p_clinic)::jsonb;
   foreach t in array array['aviculture_farms','aviculture_houses','aviculture_flocks','aviculture_production_records','aviculture_flock_events','aviculture_health_events'] loop
    execute format('select coalesce(jsonb_agg(to_jsonb(x)),''[]''::jsonb) from public.%I x where clinic_id=$1',t) into rows using p_clinic;
    result=jsonb_set(result,array['tables',t],rows,true);
   end loop;
   return result::text;
  end;$fn$
  $body$;
  revoke all on function private.clinic_snapshot(uuid) from public,anon,authenticated;
 end if;
end$$;
notify pgrst,'reload schema';
commit;

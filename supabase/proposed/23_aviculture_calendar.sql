-- Candidata. Requiere M15 y 22_aviculture_farms_health.sql. No aplicada remotamente.
begin;
create table if not exists public.aviculture_schedule(
 id uuid primary key default gen_random_uuid(),clinic_id uuid not null,farm_id uuid not null,house_id uuid not null,
 flock_id uuid,due_on date not null,kind text not null check(kind in('vacunacion','medicacion','seguimiento')),
 title text not null check(btrim(title)<>'' and length(title)<=160),notes text not null default '' check(length(notes)<=2000),
 days_before integer not null default 0 check(days_before between 0 and 90),
 status text not null default 'pendiente' check(status in('pendiente','completada','cancelada')),
 version integer not null default 1,created_by uuid not null references auth.users(id),
 created_at timestamptz not null default clock_timestamp(),updated_at timestamptz not null default clock_timestamp(),
 foreign key(clinic_id,farm_id,house_id) references public.aviculture_houses(clinic_id,farm_id,id),
 foreign key(clinic_id,flock_id) references public.aviculture_flocks(clinic_id,id));
create index if not exists avi_schedule_due on public.aviculture_schedule(clinic_id,status,due_on,house_id);
alter table public.aviculture_schedule enable row level security;
revoke all on public.aviculture_schedule from public,anon,authenticated;
create or replace function public.avi_calendar_workspace(p_clinic uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$begin
 perform private.avi_guard(p_clinic,false,false);
 return jsonb_build_object('schema_version',1,'clinic_id',p_clinic,'items',(
  select coalesce(jsonb_agg(to_jsonb(s) order by s.due_on,s.created_at),'[]'::jsonb)
  from public.aviculture_schedule s where s.clinic_id=p_clinic));
end$$;
create or replace function public.avi_calendar_save(p_clinic uuid,p_id uuid,p_version integer,p_data jsonb,p_operation text)
returns uuid language plpgsql security definer set search_path='' as $$
declare r uuid;fp jsonb;v public.aviculture_schedule;h public.aviculture_houses;f uuid;d date;
 v_title text;v_notes text;v_kind text;v_status text;days integer;house uuid;
begin
 perform private.avi_guard(p_clinic,true,false);
 if p_data is null or jsonb_typeof(p_data)<>'object' or octet_length(p_data::text)>14000 or
  p_data-array['house_id','flock_id','date','kind','title','notes','days_before','status']<>'{}'::jsonb then raise exception 'invalid_data';end if;
 begin
  house=(p_data->>'house_id')::uuid;f=nullif(p_data->>'flock_id','')::uuid;d=(p_data->>'date')::date;
 exception when others then raise exception 'invalid_date';end;
 if d is null then raise exception 'invalid_date';end if;
 v_title=private.avi_text(p_data,'title',160,true);v_notes=private.avi_text(p_data,'notes',2000,false);
 days=private.avi_int(p_data,'days_before',0,90,0)::integer;
 v_kind=coalesce(p_data->>'kind','');v_status=coalesce(p_data->>'status','pendiente');
 if v_kind not in('vacunacion','medicacion','seguimiento') or v_status not in('pendiente','completada','cancelada') then raise exception 'invalid_data';end if;
 if p_id is null and v_status<>'pendiente' then raise exception 'invalid_data';end if;
 fp=jsonb_build_object('kind','avi_calendar','id',p_id,'version',p_version,'data',p_data);
 r=private.vet_receipt(p_clinic,p_operation,fp);if r is not null then return r;end if;
 select * into h from public.aviculture_houses where clinic_id=p_clinic and id=house for update;
 if not found or h.farm_id is null then raise exception 'house_not_available';end if;
 if h.archived and (p_id is null or v_status='pendiente') then raise exception 'house_not_available';end if;
 if f is not null and not exists(select 1 from public.aviculture_flocks x where x.clinic_id=p_clinic and x.id=f and x.house_id=house and x.start_date<=d) then raise exception 'flock_not_in_house';end if;
 if p_id is null then
  insert into public.aviculture_schedule(clinic_id,farm_id,house_id,flock_id,due_on,kind,title,notes,days_before,status,created_by)
  values(p_clinic,h.farm_id,house,f,d,v_kind,v_title,v_notes,days,v_status,auth.uid()) returning id into r;
 else
  select * into v from public.aviculture_schedule where clinic_id=p_clinic and id=p_id for update;
  if not found then raise exception 'not_found';end if;
  if v.version is distinct from p_version then raise exception 'version_conflict';end if;
  if v.house_id<>house or v.flock_id is distinct from f then raise exception 'schedule_scope_changed';end if;
  update public.aviculture_schedule set due_on=d,kind=v_kind,title=v_title,notes=v_notes,days_before=days,status=v_status,
   version=v.version+1,updated_at=clock_timestamp() where id=p_id and clinic_id=p_clinic returning id into r;
 end if;
 insert into public.audit_log(clinic_id,actor_id,action,entity_id) values(p_clinic,auth.uid(),'avi_calendar_saved',r::text);
 insert into private.vet_operation_receipts values(auth.uid(),p_clinic,p_operation,fp,r);return r;
end$$;
revoke all on function public.avi_calendar_workspace(uuid),public.avi_calendar_save(uuid,uuid,integer,jsonb,text) from public,anon;
grant execute on function public.avi_calendar_workspace(uuid),public.avi_calendar_save(uuid,uuid,integer,jsonb,text) to authenticated;
-- Añade calendario a respaldos de clínica; mantiene el guard anterior.
do $$begin
 if to_regprocedure('private.clinic_snapshot(uuid)') is not null and to_regprocedure('private.clinic_snapshot_before_avi_calendar(uuid)') is null then
  execute replace(pg_get_functiondef('private.clinic_snapshot(uuid)'::regprocedure),'FUNCTION private.clinic_snapshot(','FUNCTION private.clinic_snapshot_before_avi_calendar(');
 end if;
 if to_regprocedure('private.clinic_snapshot_before_avi_calendar(uuid)') is not null then
  revoke all on function private.clinic_snapshot_before_avi_calendar(uuid) from public,anon,authenticated;
  execute $body$create or replace function private.clinic_snapshot(p_clinic uuid) returns text
  language plpgsql security definer set search_path='' as $fn$
  declare result jsonb;rows jsonb;
  begin
   result=private.clinic_snapshot_before_avi_calendar(p_clinic)::jsonb;
   select coalesce(jsonb_agg(to_jsonb(s)),'[]'::jsonb) into rows from public.aviculture_schedule s where s.clinic_id=p_clinic;
   return jsonb_set(result,array['tables','aviculture_schedule'],rows,true)::text;
  end;$fn$
  $body$;
  revoke all on function private.clinic_snapshot(uuid) from public,anon,authenticated;
 end if;
end$$;
notify pgrst,'reload schema';
commit;

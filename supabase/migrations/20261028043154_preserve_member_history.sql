-- Candidate only. Requires clinic operations, payroll, contacts, and messages.
-- Retiring a clinic membership must revoke access without deleting its history.
begin;
do $prerequisites$
begin
 if to_regclass('public.clinic_commission_payments') is null
 or to_regclass('public.clinic_staff_contacts') is null
 or to_regclass('public.clinic_private_messages') is null then
  raise exception 'member_history_prerequisite_missing';
 end if;
end
$prerequisites$;

-- Stable identity FKs preserve rows after membership removal. This trigger
-- retains the former FK's active-membership requirement for NEW assignments.
-- Locking the membership serializes assignments against concurrent removal.
create or replace function private.member_history_active_assignment()
returns trigger language plpgsql security definer set search_path='' as $guard$
declare actor uuid; clinic uuid;
begin
 actor=(to_jsonb(new)->>tg_argv[0])::uuid;
 clinic=(to_jsonb(new)->>'clinic_id')::uuid;
 if tg_op='UPDATE' then
  if to_jsonb(new)->>tg_argv[0] is not distinct from to_jsonb(old)->>tg_argv[0]
     and new.clinic_id is not distinct from old.clinic_id then return new;end if;
 end if;
 if actor is null then return new;end if;
 -- Match remove_clinic_member: clinic first, member second. The FK's AFTER
 -- check would otherwise acquire clinic last and could deadlock the remover.
 perform 1 from public.clinics where id=clinic for key share;
 if not found then raise exception 'clinic_not_found';end if;
 perform 1 from public.clinic_members where clinic_id=clinic and user_id=actor for key share;
 if not found then raise exception 'current_member_required';end if;
 return new;
end
$guard$;
revoke all on function private.member_history_active_assignment() from public,anon,authenticated,service_role;

-- Fail closed for unknown future membership references; never add CASCADE to
-- medical, payroll, message, appointment or attendance records.
do $references$
declare link record; user_column text;
begin
 for link in
  select c.conname,c.conrelid,ns.nspname,rel.relname,
   array(select a.attname from unnest(c.conkey) with ordinality k(attnum,pos)
    join pg_attribute a on a.attrelid=c.conrelid and a.attnum=k.attnum order by k.pos) as columns
  from pg_constraint c join pg_class rel on rel.oid=c.conrelid
  join pg_namespace ns on ns.oid=rel.relnamespace
  where c.contype='f' and c.confrelid='public.clinic_members'::regclass
 loop
  if (link.nspname||'.'||link.relname) not in (
   'private.member_job_labels','public.attendance_consents','public.attendance_events',
   'public.clinic_appointments','public.clinic_tasks','public.staff_medical_profiles',
   'public.clinic_service_acts','public.clinic_commission_payments',
   'public.clinic_staff_contacts','public.clinic_private_messages')
   or cardinality(link.columns)<>2 or link.columns[1]<>'clinic_id'
   or link.columns[2] not in ('user_id','professional_id','assigned_to','author_id','recipient_id') then
   raise exception 'unreviewed_membership_reference: %.%',link.nspname,link.relname;
  end if;
  user_column=link.columns[2];
  execute format('alter table %I.%I drop constraint %I',link.nspname,link.relname,link.conname);
  execute format('alter table %I.%I add constraint %I foreign key (%I) references auth.users(id)',
   link.nspname,link.relname,link.conname,user_column);
  if not exists(select 1 from pg_constraint where conrelid=link.conrelid and conname='member_history_clinic_fk') then
   execute format('alter table %I.%I add constraint member_history_clinic_fk foreign key(clinic_id) references public.clinics(id)',link.nspname,link.relname);
  end if;

 end loop;
end
$references$;

-- The six core operation/attendance tables were already detached by
-- existing_membership_history.sql. Protect new assignments in those tables too.
-- Commission payment INSERTs intentionally permit settling former staff.
do $assignments$
declare assignment record;
begin
 for assignment in select * from (values
  ('private','member_job_labels','user_id'),
  ('public','attendance_consents','user_id'),('public','attendance_events','user_id'),
  ('public','clinic_appointments','professional_id'),('public','clinic_tasks','assigned_to'),
  ('public','staff_medical_profiles','user_id'),('public','clinic_service_acts','professional_id'),
  ('public','clinic_staff_contacts','user_id'),('public','clinic_private_messages','author_id'),
  ('public','clinic_private_messages','recipient_id')
 ) fields(schema_name,table_name,user_column) loop
  execute format('drop trigger if exists %I on %I.%I','member_history_guard_'||assignment.user_column,assignment.schema_name,assignment.table_name);
  execute format('create trigger %I before insert or update on %I.%I for each row execute function private.member_history_active_assignment(%L)',
   'member_history_guard_'||assignment.user_column,assignment.schema_name,assignment.table_name,assignment.user_column);
 end loop;
end
$assignments$;

-- Current memberships are access control, not an inventory of historical payees.
create or replace function private.commission_historical_subjects(p_clinic uuid)
returns table(clinic_id uuid,user_id uuid) language sql stable set search_path='' as $subjects$
 select l.clinic_id,l.professional_id from public.inventory_sale_lines l
 where l.clinic_id=p_clinic and l.professional_id is not null
 union
 select p.clinic_id,p.professional_id from public.clinic_commission_payments p where p.clinic_id=p_clinic;
$subjects$;
revoke all on function private.commission_historical_subjects(uuid) from public,anon,authenticated,service_role;

create or replace function public.commission_account(p_clinic uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare cfg public.clinic_commission_schedule;is_admin boolean;begin
 if not private.has_clinic_role(p_clinic) then raise exception 'access_denied';end if;
 is_admin=private.has_clinic_role(p_clinic,array['admin']);
 select * into cfg from public.clinic_commission_schedule where clinic_id=p_clinic;
 return jsonb_build_object(
  'schedule',case when cfg.clinic_id is null then null else jsonb_build_object('cadence',cfg.cadence,'pay_day',cfg.pay_day,'period_start',cfg.period_start,'next_pay_on',cfg.next_pay_on) end,
  'accrued',coalesce((select jsonb_agg(jsonb_build_object('professional_id',m.user_id,'professional_name',coalesce(n.name,'Sin nombre'),'amount',(coalesce(e.amount,0)-coalesce(p.amount,0))::text))
    from private.commission_historical_subjects(p_clinic) m
    left join public.staff_display_names n on n.clinic_id=m.clinic_id and n.user_id=m.user_id
    left join lateral (
      select sum(l.commission) amount from public.inventory_sale_lines l
      join public.inventory_sales s on s.id=l.sale_id and s.clinic_id=l.clinic_id
      where l.clinic_id=p_clinic and l.professional_id=m.user_id and l.commission>0
        and not exists(select 1 from public.inventory_sale_reversals r where r.sale_id=s.id)
    ) e on true
    left join lateral (
      select sum(x.amount) amount from public.clinic_commission_payments x
      where x.clinic_id=p_clinic and x.professional_id=m.user_id
    ) p on true
    where m.clinic_id=p_clinic and (is_admin or m.user_id=auth.uid())
      and (coalesce(e.amount,0)-coalesce(p.amount,0))<>0),'[]'::jsonb),
  'payments',coalesce((select jsonb_agg(jsonb_build_object('professional_id',p.professional_id,'professional_name',coalesce(n.name,'Sin nombre'),'amount',p.amount::text,'scheduled_on',p.scheduled_on,'recorded_at',p.recorded_at,'period_start',p.period_start,'period_end',p.period_end) order by p.recorded_at desc)
    from public.clinic_commission_payments p left join public.staff_display_names n on n.clinic_id=p.clinic_id and n.user_id=p.professional_id where p.clinic_id=p_clinic and (is_admin or p.professional_id=auth.uid())),'[]'::jsonb)
 );
end$$;

create or replace function public.commission_period_pay(p_clinic uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare cfg public.clinic_commission_schedule;v_batch uuid=gen_random_uuid();v_end timestamptz;v_next date;begin
 if not private.has_clinic_role(p_clinic,array['admin']) then raise exception 'admin_required';end if;
 select * into cfg from public.clinic_commission_schedule where clinic_id=p_clinic for update;
 if not found then raise exception 'schedule_required';end if;
 if (clock_timestamp() at time zone private.inv_timezone(p_clinic))::date<cfg.next_pay_on then raise exception 'payment_day_not_reached';end if;
 v_end=cfg.next_pay_on::timestamp at time zone private.inv_timezone(p_clinic);
 if v_end<=cfg.period_start then raise exception 'invalid_period';end if;
 insert into public.clinic_commission_payments(clinic_id,professional_id,period_start,period_end,scheduled_on,amount,recorded_by)
 select p_clinic,m.user_id,cfg.period_start,v_end,cfg.next_pay_on,
        greatest(0,coalesce(e.amount,0)-coalesce(p.amount,0)),auth.uid()
 from private.commission_historical_subjects(p_clinic) m
 left join lateral (
   select sum(l.commission) amount from public.inventory_sale_lines l
   join public.inventory_sales s on s.id=l.sale_id and s.clinic_id=l.clinic_id
   where l.clinic_id=p_clinic and l.professional_id=m.user_id and l.commission>0
     and s.created_at<v_end
     and not exists(select 1 from public.inventory_sale_reversals r where r.sale_id=s.id)
 ) e on true
 left join lateral (
   select sum(x.amount) amount from public.clinic_commission_payments x
   where x.clinic_id=p_clinic and x.professional_id=m.user_id
 ) p on true
 where m.clinic_id=p_clinic and coalesce(e.amount,0)>coalesce(p.amount,0);
 v_next=case cfg.cadence
  when 'diario' then cfg.next_pay_on+1
  when 'semanal' then cfg.next_pay_on+7
  when 'quincenal' then cfg.next_pay_on+15
  else make_date(
   extract(year from cfg.next_pay_on+interval '1 month')::integer,
   extract(month from cfg.next_pay_on+interval '1 month')::integer,
   least(cfg.pay_day,extract(day from date_trunc('month',cfg.next_pay_on+interval '2 months')-interval '1 day')::integer)
  ) end;
 update public.clinic_commission_schedule set period_start=v_end,next_pay_on=v_next,updated_by=auth.uid(),updated_at=clock_timestamp() where clinic_id=p_clinic;
 insert into public.audit_log(clinic_id,actor_id,action,entity_id,details)
 values(p_clinic,auth.uid(),'commission_period_paid',v_batch::text,jsonb_build_object('period_start',cfg.period_start,'period_end',v_end,'scheduled_on',cfg.next_pay_on));
 return v_batch;
end$$;
revoke all on function public.commission_schedule_save(uuid,text,date),public.commission_account(uuid),public.commission_period_pay(uuid) from public,anon;
grant execute on function public.commission_schedule_save(uuid,text,date),public.commission_account(uuid),public.commission_period_pay(uuid) to authenticated;
notify pgrst,'reload schema';
commit;

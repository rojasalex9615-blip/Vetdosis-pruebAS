-- Apply after 14G. Creates a dormant, consent-based outbound delivery queue.
-- No provider credentials, schedules, or clinical details are stored here.
begin;
alter table private.hospital_automation_runtime
 add column external_delivery_enabled boolean not null default false;
alter table private.hospital_automation_runtime
 add column external_delivery_started_at timestamptz;
create function private.hospital_delivery_activation() returns trigger
language plpgsql set search_path='' as $$
begin
 if new.external_delivery_enabled and not old.external_delivery_enabled then
  new.external_delivery_started_at=clock_timestamp();
 end if;
 return new;
end$$;
create trigger hospital_delivery_activation before update on private.hospital_automation_runtime
 for each row execute function private.hospital_delivery_activation();

create table private.hospital_delivery_targets (
 id uuid primary key default gen_random_uuid(),
 clinic_id uuid not null references public.clinics(id),
 user_id uuid not null references auth.users(id),
 member_since timestamptz not null,
 channel text not null check (channel in ('fcm','whatsapp')),
 destination text not null check (length(destination) between 8 and 4096),
 consent_at timestamptz not null default clock_timestamp(),
 revoked_at timestamptz,
 created_at timestamptz not null default clock_timestamp(),
 unique (clinic_id,user_id,channel,destination)
);
create index hospital_delivery_targets_active
 on private.hospital_delivery_targets(clinic_id,user_id,member_since)
 where revoked_at is null;

create table private.hospital_notice_deliveries (
 id uuid primary key default gen_random_uuid(),
 notice_id uuid not null references private.hospital_notices(id),
 target_id uuid not null references private.hospital_delivery_targets(id),
 status text not null default 'pending' check (status in ('pending','leased','sent','dead')),
 attempts integer not null default 0 check (attempts between 0 and 8),
 next_attempt_at timestamptz not null default clock_timestamp(),
 lease_until timestamptz,
 sent_at timestamptz,
 provider_ref text,
 error_code text,
 created_at timestamptz not null default clock_timestamp(),
 unique (notice_id,target_id),
 check (provider_ref is null or length(provider_ref)<=200),
 check (error_code is null or error_code ~ '^[a-z_]{1,60}$')
);
create index hospital_notice_deliveries_ready
 on private.hospital_notice_deliveries(next_attempt_at,id)
 where status in ('pending','leased');

alter table private.hospital_delivery_targets enable row level security;
alter table private.hospital_notice_deliveries enable row level security;
revoke all on private.hospital_delivery_targets,private.hospital_notice_deliveries
 from public,anon,authenticated,service_role;

create function private.hospital_notice_enqueue() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 insert into private.hospital_notice_deliveries(notice_id,target_id)
 select new.id,t.id from private.hospital_delivery_targets t
 where t.clinic_id=new.clinic_id and t.user_id=new.recipient_id
   and t.member_since=new.member_since and t.revoked_at is null;
 return new;
end$$;
create trigger hospital_notice_enqueue after insert on private.hospital_notices
 for each row execute function private.hospital_notice_enqueue();

create function public.hospital_delivery_target_set(
 p_clinic uuid,p_channel text,p_destination text,p_consent boolean
) returns uuid language plpgsql security definer set search_path='' as $$
declare since timestamptz;target uuid;begin
 if auth.uid() is null or p_consent is distinct from true then
  raise exception 'explicit_delivery_consent_required';
 end if;
 select created_at into since from public.clinic_members
 where clinic_id=p_clinic and user_id=auth.uid();
 if since is null or not private.hospital_notice_recipient(p_clinic,auth.uid(),since,false) then
  raise exception 'current_hospital_recipient_required';
 end if;
 if (p_channel='whatsapp' and p_destination ~ '^\+[1-9][0-9]{7,14}$')
    or (p_channel='fcm' and length(p_destination) between 20 and 4096
        and p_destination ~ '^[A-Za-z0-9:_-]+$') then null;
 else raise exception 'invalid_delivery_destination';end if;
 insert into private.hospital_delivery_targets
 (clinic_id,user_id,member_since,channel,destination)
 values(p_clinic,auth.uid(),since,p_channel,p_destination)
 on conflict(clinic_id,user_id,channel,destination)
 do update set member_since=excluded.member_since,revoked_at=null,
               consent_at=clock_timestamp()
 returning id into target;
 return target;
end$$;

create function public.hospital_delivery_target_revoke(p_clinic uuid,p_target uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'authentication_required';end if;
 update private.hospital_delivery_targets set revoked_at=clock_timestamp()
 where id=p_target and clinic_id=p_clinic and user_id=auth.uid()
 and revoked_at is null;
 if not found then raise exception 'own_delivery_target_required';end if;
end$$;

-- Service-role-only RPC. Rechecks clinical state, membership and consent when claimed.
create function public.hospital_delivery_claim(p_limit integer default 20)
returns jsonb language plpgsql security definer set search_path='' as $$
declare d record;result jsonb:='[]'::jsonb;begin
 if not (select external_delivery_enabled and external_delivery_started_at is not null
         from private.hospital_automation_runtime) then
  return result;
 end if;
 if p_limit is null or p_limit not between 1 and 50 then raise exception 'invalid_claim_limit';end if;
 for d in
  select x.id,x.attempts,t.channel,t.destination,n.clinic_id,n.recipient_id
  from private.hospital_notice_deliveries x
  join private.hospital_notices n on n.id=x.notice_id
  join private.hospital_delivery_targets t on t.id=x.target_id
  join public.hospital_tasks h on h.id=n.task_id and h.clinic_id=n.clinic_id
  join public.hospital_stays s on s.id=h.stay_id and s.clinic_id=n.clinic_id
  where x.status in ('pending','leased') and x.next_attempt_at<=clock_timestamp()
    and (x.status='pending' or x.lease_until<clock_timestamp())
    and x.attempts<8 and t.revoked_at is null and x.created_at>=t.consent_at
    and n.created_at >= (select external_delivery_started_at from private.hospital_automation_runtime)
    and t.clinic_id=n.clinic_id and t.user_id=n.recipient_id
    and t.member_since=n.member_since
    and private.hospital_notice_recipient(n.clinic_id,n.recipient_id,n.member_since,n.stage='mvz')
    and h.state='pending' and s.discharged_at is null
    and not exists(select 1 from private.hospital_notice_responses a
      join private.hospital_notices responded on responded.id=a.notice_id
      where responded.task_id=n.task_id)
  order by x.next_attempt_at,x.id
  for update of x skip locked limit p_limit
 loop
  update private.hospital_notice_deliveries
  set status='leased',attempts=d.attempts+1,lease_until=clock_timestamp()+interval '2 minutes'
  where id=d.id;
  result=result||jsonb_build_array(jsonb_build_object(
   'id',d.id,'channel',d.channel,'destination',d.destination));
 end loop;
 return result;
end$$;

create function public.hospital_delivery_finish(
 p_id uuid,p_sent boolean,p_provider_ref text default null,p_error_code text default null
) returns void language plpgsql security definer set search_path='' as $$
declare tries integer;begin
 if p_sent is null or (p_sent and p_error_code is not null)
    or (not p_sent and (p_error_code is null or p_error_code !~ '^[a-z_]{1,60}$'))
    or length(coalesce(p_provider_ref,''))>200 then raise exception 'invalid_delivery_result';end if;
 select attempts into tries from private.hospital_notice_deliveries
 where id=p_id and status='leased' and lease_until>=clock_timestamp()
 for update;
 if tries is null then raise exception 'active_delivery_lease_required';end if;
 update private.hospital_notice_deliveries set
  status=case when p_sent then 'sent' when tries>=8 then 'dead' else 'pending' end,
  sent_at=case when p_sent then clock_timestamp() else null end,
  provider_ref=case when p_sent then p_provider_ref else null end,
  error_code=case when p_sent then null else p_error_code end,
  lease_until=null,
  next_attempt_at=case when p_sent then next_attempt_at
    else clock_timestamp()+make_interval(secs=>least(3600,30*(2^tries)::integer)) end
 where id=p_id;
end$$;

revoke all on function private.hospital_notice_enqueue(),private.hospital_delivery_activation(),
 public.hospital_delivery_target_set(uuid,text,text,boolean),
 public.hospital_delivery_target_revoke(uuid,uuid),
 public.hospital_delivery_claim(integer),
 public.hospital_delivery_finish(uuid,boolean,text,text)
 from public,anon,authenticated,service_role;
grant execute on function public.hospital_delivery_target_set(uuid,text,text,boolean),
 public.hospital_delivery_target_revoke(uuid,uuid) to authenticated;
grant execute on function public.hospital_delivery_claim(integer),
 public.hospital_delivery_finish(uuid,boolean,text,text) to service_role;
commit;

-- Candidate after explicit permission foundation, M9 and operational export contract.
begin;
insert into private.permission_catalog(code,label,procedure_scoped,requires_professional)
values('staff.medical.read','Consultar fichas de emergencia consentidas del personal',false,false)
on conflict(code) do update set label=excluded.label;
create table private.staff_medical_events (
 id uuid primary key default gen_random_uuid(),clinic_id uuid not null references public.clinics(id),user_id uuid not null references auth.users(id),
 member_since timestamptz not null,revision bigint not null check(revision>0),
 action text not null check(action in ('accepted','withdrawn')),notice_version integer,notice_hash text,
 created_at timestamptz not null default clock_timestamp(),unique(clinic_id,user_id,id)
);
create index staff_medical_events_owner on private.staff_medical_events(clinic_id,user_id,created_at);
create table private.staff_medical_state (
 clinic_id uuid not null references public.clinics(id),user_id uuid not null references auth.users(id),
 revision bigint not null check(revision>=0),primary key(clinic_id,user_id)
);
create table private.staff_medical_accesses (
 id uuid primary key default gen_random_uuid(),clinic_id uuid not null references public.clinics(id),
 subject_id uuid not null references auth.users(id),actor_id uuid not null references auth.users(id),
 consent_event_id uuid not null,purpose text not null check(purpose in ('emergency','emergency_preparation')),
 created_at timestamptz not null default clock_timestamp(),
 foreign key(clinic_id,subject_id,consent_event_id) references private.staff_medical_events(clinic_id,user_id,id)
);
create index staff_medical_access_subject on private.staff_medical_accesses(clinic_id,subject_id,created_at);
create index staff_medical_access_actor on private.staff_medical_accesses(actor_id);
alter table private.staff_medical_events enable row level security;
alter table private.staff_medical_state enable row level security;
alter table private.staff_medical_accesses enable row level security;
revoke all on private.staff_medical_events,private.staff_medical_state,private.staff_medical_accesses from public,anon,authenticated,service_role;
create trigger staff_medical_event_immutable before update or delete on private.staff_medical_events for each row execute function private.inv_history_guard();
create trigger staff_medical_access_immutable before update or delete on private.staff_medical_accesses for each row execute function private.inv_history_guard();
alter table public.staff_medical_profiles add column consent_event_id uuid;
alter table public.staff_medical_profiles add constraint staff_medical_consent_identity foreign key(clinic_id,user_id,consent_event_id) references private.staff_medical_events(clinic_id,user_id,id);

create function private.staff_medical_notice() returns jsonb language sql immutable set search_path='' as $$
 select jsonb_build_object('version',1,'text',t,'hash',encode(sha256(convert_to(t,'UTF8')),'hex'))
 from (values('Ficha de emergencia del personal. Los datos son opcionales y se guardan para contacto y atención de emergencias en esta clínica. Puedes consultar, actualizar o retirar tu propia ficha. Solo administradores de esta clínica con permiso específico pueden consultar fichas con este consentimiento vigente, confirmando una finalidad de emergencia o preparación para emergencias. Se registra quién consulta y cuándo, sin copiar el contenido médico al registro de acceso. Retirar elimina la ficha activa; se conserva un historial mínimo de aceptación, retirada y accesos sin su contenido médico. No elimina tu cuenta.')) x(t);
$$;
create function private.staff_medical_gate(p_clinic uuid,p_actor uuid,p_write boolean,p_team boolean default false) returns timestamptz
language plpgsql security definer set search_path='' as $$
declare since timestamptz;begin
 if auth.uid() is null or auth.uid() is distinct from p_actor then raise exception 'session_changed';end if;
 if not exists(select 1 from public.clinic_members where clinic_id=p_clinic and user_id=auth.uid()) then raise exception 'clinic_membership_required';end if;
 -- Match permission grant/revocation lock order; recheck after a concurrent change.
 perform 1 from public.clinics where id=p_clinic for update;
 perform public.beta_access_check(p_write,p_clinic);
 select created_at into since from public.clinic_members where clinic_id=p_clinic and user_id=auth.uid() for share;
 if not found then raise exception 'clinic_membership_required';end if;
 if p_team and (not private.has_clinic_role(p_clinic,array['admin']) or not exists(
  select 1 from private.member_permission_grants g where g.id=private.permission_effective(p_clinic,auth.uid(),'staff.medical.read') and g.valid_until>clock_timestamp()
 )) then raise exception 'staff_medical_read_required';end if;
 return since;
end$$;
revoke all on function private.staff_medical_notice(),private.staff_medical_gate(uuid,uuid,boolean,boolean) from public,anon,authenticated,service_role;

create function public.ops_staff_medical_workspace(p_clinic uuid,p_actor uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare since timestamptz;notice jsonb;profile jsonb;begin
 since=private.staff_medical_gate(p_clinic,p_actor,false);
 notice=private.staff_medical_notice();
 select to_jsonb(p)||jsonb_build_object('consent_current',exists(select 1 from private.staff_medical_events e where e.id=p.consent_event_id and e.clinic_id=p.clinic_id and e.user_id=p.user_id and e.member_since=since and e.action='accepted' and e.notice_version=(notice->>'version')::integer and e.notice_hash=notice->>'hash'))
 into profile from public.staff_medical_profiles p where p.clinic_id=p_clinic and p.user_id=auth.uid();
 return jsonb_build_object('schema_version',1,'clinic_id',p_clinic,'actor_id',auth.uid(),'member_since',since,
 'revision',coalesce((select revision from private.staff_medical_state where clinic_id=p_clinic and user_id=auth.uid()),0),
 'notice',notice,'profile',profile,
 'can_team_read',private.has_clinic_role(p_clinic,array['admin']) and exists(select 1 from private.member_permission_grants g where g.id=private.permission_effective(p_clinic,auth.uid(),'staff.medical.read') and g.valid_until>clock_timestamp()),
 'events',(select coalesce(jsonb_agg(to_jsonb(q) order by q.created_at desc,q.id),'[]') from (select id,revision,action,notice_version,created_at from private.staff_medical_events where clinic_id=p_clinic and user_id=auth.uid() order by created_at desc,id limit 20) q),
 'accesses',(select coalesce(jsonb_agg(to_jsonb(q) order by q.created_at desc,q.id),'[]') from (select id,actor_id,purpose,created_at from private.staff_medical_accesses where clinic_id=p_clinic and subject_id=auth.uid() order by created_at desc,id limit 20) q));
end$$;

create function public.ops_staff_medical_write(p_clinic uuid,p_action text,p_details jsonb,p_consent boolean,
 p_notice_version integer,p_notice_hash text,p_expected_revision bigint,p_member_since timestamptz,p_actor uuid,p_operation text) returns uuid
language plpgsql security definer set search_path='' as $$
declare since timestamptz;notice jsonb;clean jsonb='{}';k text;v jsonb;revision bigint;receipt uuid;fp jsonb;previous public.staff_medical_profiles;
begin
 since=private.staff_medical_gate(p_clinic,p_actor,true);
 if p_member_since is distinct from since then raise exception 'staff_medical_refresh_required';end if;
 if p_action is null or p_action not in ('save','withdraw') then raise exception 'staff_medical_action_required';end if;
 if p_action='save' then
  if jsonb_typeof(p_details) is distinct from 'object' or octet_length(p_details::text)>16000 then raise exception 'staff_medical_details_required';end if;
  for k,v in select * from jsonb_each(p_details) loop
   if k not in ('blood','allergies','conditions','vaccines','emergency') or jsonb_typeof(v)<>'string' or length(v#>>'{}')>2000 then raise exception 'staff_medical_fields_invalid';end if;
   if length(btrim(v#>>'{}'))>0 then clean=clean||jsonb_build_object(k,btrim(v#>>'{}'));end if;
  end loop;
  if clean='{}'::jsonb then raise exception 'staff_medical_details_required';end if;
 else
  if p_consent is distinct from false or (p_details is not null and p_details<>'{}'::jsonb) then raise exception 'withdraw_without_acceptance_required';end if;
 end if;
 select coalesce((select s.revision from private.staff_medical_state s where s.clinic_id=p_clinic and s.user_id=auth.uid()),0) into revision;
 -- Receipts contain only a hash of the canonical content, never medical text.
 fp=jsonb_build_object('kind','staff_medical','action',p_action,'details_hash',encode(sha256(convert_to(clean::text,'UTF8')),'hex'),
 'consent',p_consent,'notice_version',p_notice_version,'notice_hash',p_notice_hash,'expected_revision',p_expected_revision,'member_since',since);
 receipt=private.vet_receipt(p_clinic,p_operation,fp);if receipt is not null then return receipt;end if;
 if p_expected_revision is distinct from revision then raise exception 'staff_medical_revision_changed';end if;
 notice=private.staff_medical_notice();
 if p_action='save' and (p_consent is distinct from true or p_notice_version is distinct from (notice->>'version')::integer or p_notice_hash is distinct from notice->>'hash') then raise exception 'staff_medical_consent_required';end if;
 select * into previous from public.staff_medical_profiles where clinic_id=p_clinic and user_id=auth.uid();
 if p_action='withdraw' and not found then raise exception 'staff_medical_profile_unavailable';end if;
 insert into private.staff_medical_events(clinic_id,user_id,member_since,revision,action,notice_version,notice_hash)
 values(p_clinic,auth.uid(),since,revision+1,case when p_action='save' then 'accepted' else 'withdrawn' end,
 case when p_action='save' then p_notice_version else (select notice_version from private.staff_medical_events where id=previous.consent_event_id) end,
 case when p_action='save' then p_notice_hash else (select notice_hash from private.staff_medical_events where id=previous.consent_event_id) end) returning id into receipt;
 if p_action='save' then
  insert into public.staff_medical_profiles(clinic_id,user_id,details,consent_at,consent_event_id)
  values(p_clinic,auth.uid(),clean,clock_timestamp(),receipt)
  on conflict(clinic_id,user_id) do update set details=excluded.details,consent_at=excluded.consent_at,consent_event_id=excluded.consent_event_id,updated_at=clock_timestamp();
 else
  delete from public.staff_medical_profiles where clinic_id=p_clinic and user_id=auth.uid();
 end if;
 insert into private.staff_medical_state(clinic_id,user_id,revision) values(p_clinic,auth.uid(),revision+1)
 on conflict(clinic_id,user_id) do update set revision=excluded.revision;
 insert into public.audit_log(clinic_id,actor_id,action,entity_id,details) values(p_clinic,auth.uid(),case when p_action='save' then 'staff_medical_consent_saved' else 'staff_medical_withdrawn' end,receipt::text,jsonb_build_object('revision',revision+1));
 insert into private.vet_operation_receipts values(auth.uid(),p_clinic,p_operation,fp,receipt);
 return receipt;
end$$;

create function public.ops_staff_medical_directory(p_clinic uuid,p_actor uuid,p_offset integer default 0) returns jsonb
language plpgsql security definer set search_path='' as $$
declare notice jsonb;begin
 perform private.staff_medical_gate(p_clinic,p_actor,false,true);
 if p_offset is null or p_offset<0 or p_offset>100000 then raise exception 'invalid_offset';end if;
 notice=private.staff_medical_notice();
 return jsonb_build_object('schema_version',1,'clinic_id',p_clinic,'actor_id',auth.uid(),'items',
 (select coalesce(jsonb_agg(to_jsonb(q) order by q.user_id),'[]') from (
 select p.user_id,coalesce(n.name,p.user_id::text) display_name from public.staff_medical_profiles p
 join public.clinic_members m on m.clinic_id=p.clinic_id and m.user_id=p.user_id
 join private.staff_medical_events e on e.id=p.consent_event_id and e.clinic_id=p.clinic_id and e.user_id=p.user_id
 left join public.staff_display_names n on n.clinic_id=p.clinic_id and n.user_id=p.user_id
 where p.clinic_id=p_clinic and e.action='accepted' and e.member_since=m.created_at and e.notice_version=(notice->>'version')::integer and e.notice_hash=notice->>'hash'
 order by p.user_id limit 100 offset p_offset) q));
end$$;
create function public.ops_staff_medical_view(p_clinic uuid,p_subject uuid,p_purpose text,p_actor uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare notice jsonb;profile public.staff_medical_profiles;access_id uuid;begin
 -- An audited read needs the write capability required to persist the access event.
 perform private.staff_medical_gate(p_clinic,p_actor,true,true);
 if p_purpose is null or p_purpose not in ('emergency','emergency_preparation') then raise exception 'staff_medical_purpose_required';end if;
 notice=private.staff_medical_notice();
 select p.* into profile from public.staff_medical_profiles p
 join public.clinic_members m on m.clinic_id=p.clinic_id and m.user_id=p.user_id
 join private.staff_medical_events e on e.id=p.consent_event_id and e.clinic_id=p.clinic_id and e.user_id=p.user_id
 where p.clinic_id=p_clinic and p.user_id=p_subject and e.action='accepted' and e.member_since=m.created_at and e.notice_version=(notice->>'version')::integer and e.notice_hash=notice->>'hash';
 if not found then raise exception 'staff_medical_profile_unavailable';end if;
 insert into private.staff_medical_accesses(clinic_id,subject_id,actor_id,consent_event_id,purpose)
 values(p_clinic,p_subject,auth.uid(),profile.consent_event_id,p_purpose) returning id into access_id;
 insert into public.audit_log(clinic_id,actor_id,action,entity_id,details)
 values(p_clinic,auth.uid(),'staff_medical_accessed',access_id::text,jsonb_build_object('subject',p_subject,'purpose',p_purpose));
 return jsonb_build_object('schema_version',1,'clinic_id',p_clinic,'actor_id',auth.uid(),'subject_id',p_subject,'details',profile.details,'access_id',access_id,'consent_at',profile.consent_at);
end$$;

-- Close the legacy implicit-admin read and unversioned-save paths.
create or replace function public.ops_medical(p_clinic uuid,p_details jsonb default null,p_consent boolean default false) returns jsonb
language plpgsql security definer set search_path='' as $$
declare since timestamptz;rev bigint;begin
 since=private.staff_medical_gate(p_clinic,auth.uid(),p_details is not null);
 if p_details is not null then
  if p_details<>'{}'::jsonb then raise exception 'staff_medical_client_upgrade_required';end if;
  if exists(select 1 from public.staff_medical_profiles where clinic_id=p_clinic and user_id=auth.uid()) then
   select coalesce((select revision from private.staff_medical_state where clinic_id=p_clinic and user_id=auth.uid()),0) into rev;
   perform public.ops_staff_medical_write(p_clinic,'withdraw',null,false,null,null,rev,since,auth.uid(),replace(gen_random_uuid()::text,'-','')||substr(replace(gen_random_uuid()::text,'-',''),1,16));
  end if;
 end if;
 return (select coalesce(jsonb_agg(to_jsonb(p)),'[]') from public.staff_medical_profiles p where clinic_id=p_clinic and user_id=auth.uid());
end$$;
-- Existing role-based table reads must not bypass the audited endpoints.
drop policy if exists ops_read on public.staff_medical_profiles;
revoke all on public.staff_medical_profiles from public,anon,authenticated,service_role;
revoke all on function public.ops_staff_medical_workspace(uuid,uuid),public.ops_staff_medical_write(uuid,text,jsonb,boolean,integer,text,bigint,timestamptz,uuid,text),public.ops_staff_medical_directory(uuid,uuid,integer),public.ops_staff_medical_view(uuid,uuid,text,uuid),public.ops_medical(uuid,jsonb,boolean) from public,anon,authenticated,service_role;
grant execute on function public.ops_staff_medical_workspace(uuid,uuid),public.ops_staff_medical_write(uuid,text,jsonb,boolean,integer,text,bigint,timestamptz,uuid,text),public.ops_staff_medical_directory(uuid,uuid,integer),public.ops_staff_medical_view(uuid,uuid,text,uuid),public.ops_medical(uuid,jsonb,boolean) to authenticated;

-- Retain the operational export's existing authorization; include only the actor's metadata.
alter function public.clinic_export(uuid) set schema private;
alter function private.clinic_export(uuid) rename to clinic_export_before_staff_medical_privacy;
revoke all on function private.clinic_export_before_staff_medical_privacy(uuid) from public,anon,authenticated,service_role;
create function public.clinic_export(p_clinic uuid) returns text language plpgsql security definer set search_path='' as $$
declare snapshot jsonb;begin
 snapshot=private.clinic_export_before_staff_medical_privacy(p_clinic)::jsonb;
 snapshot=jsonb_set(snapshot,'{tables,my_staff_medical_profile}',(select coalesce(jsonb_agg(to_jsonb(p)-'details'),'[]') from public.staff_medical_profiles p where p.clinic_id=p_clinic and p.user_id=auth.uid()));
 snapshot=jsonb_set(snapshot,'{tables,my_staff_medical_events}',(select coalesce(jsonb_agg(to_jsonb(e)),'[]') from private.staff_medical_events e where e.clinic_id=p_clinic and e.user_id=auth.uid()));
 snapshot=jsonb_set(snapshot,'{tables,my_staff_medical_accesses}',(select coalesce(jsonb_agg(to_jsonb(a)),'[]') from private.staff_medical_accesses a where a.clinic_id=p_clinic and a.subject_id=auth.uid()));
 return jsonb_set(snapshot,'{tables,my_staff_medical_state}',(select coalesce(jsonb_agg(to_jsonb(s)),'[]') from private.staff_medical_state s where s.clinic_id=p_clinic and s.user_id=auth.uid()))::text;
end$$;
revoke all on function public.clinic_export(uuid) from public,anon,authenticated,service_role;
grant execute on function public.clinic_export(uuid) to authenticated;
-- No automatic retention period: a reviewed decision is required for each purge.
-- Owner-only maintenance, unavailable to app roles and service_role.
create table private.staff_medical_retention_decisions(
 clinic_id uuid not null,user_id uuid not null,purge_after timestamptz not null,
 legal_hold boolean not null default true,policy_ref text not null check(length(btrim(policy_ref)) between 8 and 1000),
 approved_at timestamptz not null default clock_timestamp(),primary key(clinic_id,user_id)
);
create table private.staff_medical_purge_permits(
 backend integer not null,transaction_id bigint not null,clinic_id uuid not null,user_id uuid not null,
 primary key(backend,transaction_id)
);
alter table private.staff_medical_retention_decisions enable row level security;
alter table private.staff_medical_purge_permits enable row level security;
revoke all on private.staff_medical_retention_decisions,private.staff_medical_purge_permits from public,anon,authenticated,service_role;
create function private.staff_medical_history_guard() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op='DELETE' and current_user=(select pg_get_userbyid(relowner) from pg_class where oid='private.staff_medical_events'::regclass)
 and exists(select 1 from private.staff_medical_purge_permits p where p.backend=pg_backend_pid() and p.transaction_id=txid_current()
  and p.clinic_id=old.clinic_id and (case when tg_table_name='staff_medical_events' then to_jsonb(old)->>'user_id'=p.user_id::text
   else to_jsonb(old)->>'subject_id'=p.user_id::text or to_jsonb(old)->>'actor_id'=p.user_id::text end)) then return old;end if;
 raise exception 'staff_medical_history_is_immutable';
end$$;
revoke all on function private.staff_medical_history_guard() from public,anon,authenticated,service_role;
drop trigger staff_medical_event_immutable on private.staff_medical_events;
drop trigger staff_medical_access_immutable on private.staff_medical_accesses;
create trigger staff_medical_event_immutable before update or delete on private.staff_medical_events for each row execute function private.staff_medical_history_guard();
create trigger staff_medical_access_immutable before update or delete on private.staff_medical_accesses for each row execute function private.staff_medical_history_guard();
create function private.staff_medical_purge(p_clinic uuid,p_user uuid) returns void
language plpgsql security invoker set search_path='' as $$
declare decision private.staff_medical_retention_decisions;
begin
 if current_user<>(select pg_get_userbyid(relowner) from pg_class where oid='private.staff_medical_events'::regclass) then raise exception 'maintenance_owner_required';end if;
 perform 1 from public.clinics where id=p_clinic for update;
 select * into decision from private.staff_medical_retention_decisions where clinic_id=p_clinic and user_id=p_user for update;
 if not found or decision.legal_hold or decision.purge_after>clock_timestamp() then raise exception 'staff_medical_retention_not_released';end if;
 if exists(select 1 from public.staff_medical_profiles where clinic_id=p_clinic and user_id=p_user) then raise exception 'staff_medical_withdrawal_required';end if;
 insert into private.staff_medical_purge_permits values(pg_backend_pid(),txid_current(),p_clinic,p_user);
 delete from private.staff_medical_accesses where clinic_id=p_clinic and (subject_id=p_user or actor_id=p_user);
 delete from private.staff_medical_events where clinic_id=p_clinic and user_id=p_user;
 delete from private.staff_medical_state where clinic_id=p_clinic and user_id=p_user;
 delete from private.vet_operation_receipts where clinic_id=p_clinic and user_id=p_user and fingerprint->>'kind'='staff_medical';
 delete from private.staff_medical_purge_permits where backend=pg_backend_pid() and transaction_id=txid_current();
 delete from private.staff_medical_retention_decisions where clinic_id=p_clinic and user_id=p_user;
 -- Operator policy/ticket is retained without subject or medical content.
 raise log 'staff_medical_purge policy_ref=%',decision.policy_ref;
end$$;
revoke all on function private.staff_medical_purge(uuid,uuid) from public,anon,authenticated,service_role;

select private.beta_install_guards();
notify pgrst,'reload schema';
commit;

-- 16A · Mi espacio personal.
-- Apply after 20261027142748_staff_medical_consent_access.sql and 20261028043154_preserve_member_history.sql.
--
-- 1. Notas y recordatorios personales: solo la persona dueña los ve (RLS por auth.uid()).
-- 2. Horarios de trabajo en una o más clínicas: solo la persona dueña los ve.
-- 3. Ficha de emergencia (staff_medical, ya existente por clínica):
--    - nuevo campo opcional «drug_allergies» (fármacos a los que es alérgica la persona);
--    - la persona elige compañeros de la clínica que pueden consultar su ficha en una emergencia;
--    - cada consulta (administración o compañero) queda en private.staff_medical_accesses,
--      visible para la persona y para la administración (encargado) de la clínica, sin contenido médico.
--    El aviso pasa a la versión 2 porque cambia quién puede consultar: las fichas guardadas con el
--    aviso 1 dejan de mostrarse al equipo hasta que su dueño acepte el aviso nuevo.
begin;

-- 1. Notas y recordatorios ---------------------------------------------------------------
create table public.personal_notes (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 kind text not null default 'note' check (kind in ('note','reminder')),
 title text not null check (length(btrim(title)) between 1 and 200),
 body text not null default '' check (length(body) <= 4000),
 remind_at timestamptz,
 done boolean not null default false,
 created_at timestamptz not null default clock_timestamp(),
 updated_at timestamptz not null default clock_timestamp(),
 check (kind = 'reminder' or remind_at is null)
);
create index personal_notes_owner on public.personal_notes(user_id, kind, done, remind_at);
alter table public.personal_notes enable row level security;
revoke all on public.personal_notes from public, anon, authenticated;
grant select, insert, update, delete on public.personal_notes to authenticated;
create policy personal_notes_owner on public.personal_notes for all to authenticated
 using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- 2. Horarios en una o más clínicas --------------------------------------------------------
create table public.personal_work_schedules (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 -- Nombre libre: también sirve para lugares fuera de VetDosis.
 place text not null check (length(btrim(place)) between 1 and 120),
 -- Enlace opcional a una clínica de la que la persona es miembro.
 linked_clinic_id uuid references public.clinics(id) on delete set null,
 weekday smallint not null check (weekday between 1 and 7),
 starts_at time not null,
 ends_at time not null,
 note text not null default '' check (length(note) <= 500),
 created_at timestamptz not null default clock_timestamp(),
 check (ends_at <> starts_at)
);
create index personal_work_schedules_owner on public.personal_work_schedules(user_id, weekday, starts_at);
alter table public.personal_work_schedules enable row level security;
revoke all on public.personal_work_schedules from public, anon, authenticated;
grant select, insert, update, delete on public.personal_work_schedules to authenticated;
create policy personal_work_schedules_owner on public.personal_work_schedules for all to authenticated
 using (user_id = (select auth.uid()))
 with check (user_id = (select auth.uid()) and (linked_clinic_id is null or exists(
  select 1 from public.clinic_members m where m.clinic_id = linked_clinic_id and m.user_id = (select auth.uid()))));

-- 3. Ficha de emergencia: aviso 2, fármacos y compañeros elegidos --------------------------
create or replace function private.staff_medical_notice() returns jsonb language sql immutable set search_path='' as $$
 select jsonb_build_object('version',2,'text',t,'hash',encode(sha256(convert_to(t,'UTF8')),'hex'))
 from (values('Ficha de emergencia del personal. Los datos son opcionales y se guardan para contacto y atención de emergencias en esta clínica. Tú decides qué datos incluir, como antecedentes o padecimientos. Puedes consultar, actualizar o retirar tu propia ficha. Pueden consultarla, confirmando una finalidad de emergencia o preparación para emergencias, los administradores de esta clínica con permiso específico y los compañeros de esta clínica que tú elijas; puedes quitar a un compañero en cualquier momento. Cada consulta queda registrada con quién, cuándo y para qué, sin copiar el contenido médico, y ese registro lo ven tú y la administración de la clínica. Retirar elimina la ficha activa; se conserva un historial mínimo de aceptación, retirada y accesos sin su contenido médico. No elimina tu cuenta.')) x(t);
$$;
revoke all on function private.staff_medical_notice() from public,anon,authenticated,service_role;

-- Same body as 20261027142748, with 'drug_allergies' added to the allowed fields.
create or replace function public.ops_staff_medical_write(p_clinic uuid,p_action text,p_details jsonb,p_consent boolean,
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
   if k not in ('blood','allergies','drug_allergies','conditions','vaccines','emergency') or jsonb_typeof(v)<>'string' or length(v#>>'{}')>2000 then raise exception 'staff_medical_fields_invalid';end if;
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

-- Who read the profile: administration (existing endpoint) or a colleague chosen by the owner.
alter table private.staff_medical_accesses add column via text not null default 'admin' check (via in ('admin','delegate'));

create table private.staff_medical_delegates (
 clinic_id uuid not null references public.clinics(id),
 subject_id uuid not null references auth.users(id),
 delegate_id uuid not null references auth.users(id),
 granted_at timestamptz not null default clock_timestamp(),
 revoked_at timestamptz,
 primary key (clinic_id, subject_id, delegate_id),
 check (subject_id <> delegate_id)
);
create index staff_medical_delegates_delegate on private.staff_medical_delegates(clinic_id, delegate_id) where revoked_at is null;
alter table private.staff_medical_delegates enable row level security;
revoke all on private.staff_medical_delegates from public,anon,authenticated,service_role;

-- Profile with consent current for the CURRENT notice and the current membership.
create function private.staff_medical_current_profile(p_clinic uuid,p_subject uuid) returns public.staff_medical_profiles
language sql stable security definer set search_path='' as $$
 select p.* from public.staff_medical_profiles p
 join public.clinic_members m on m.clinic_id=p.clinic_id and m.user_id=p.user_id
 join private.staff_medical_events e on e.id=p.consent_event_id and e.clinic_id=p.clinic_id and e.user_id=p.user_id
 where p.clinic_id=p_clinic and p.user_id=p_subject and e.action='accepted' and e.member_since=m.created_at
  and e.notice_version=(private.staff_medical_notice()->>'version')::integer and e.notice_hash=private.staff_medical_notice()->>'hash';
$$;
revoke all on function private.staff_medical_current_profile(uuid,uuid) from public,anon,authenticated,service_role;

create function private.staff_medical_name(p_clinic uuid,p_user uuid) returns text
language sql stable security definer set search_path='' as $$
 select coalesce((select n.name from public.staff_display_names n where n.clinic_id=p_clinic and n.user_id=p_user),'Integrante del equipo');
$$;
revoke all on function private.staff_medical_name(uuid,uuid) from public,anon,authenticated,service_role;

-- My chosen colleagues plus the clinic members I can choose from (names only).
create function public.ops_staff_medical_delegates(p_clinic uuid,p_actor uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
 perform private.staff_medical_gate(p_clinic,p_actor,false);
 if private.personal_clinic(p_clinic) then raise exception 'staff_medical_team_required';end if;
 return jsonb_build_object('schema_version',1,'clinic_id',p_clinic,'actor_id',auth.uid(),
 'colleagues',(select coalesce(jsonb_agg(jsonb_build_object('user_id',m.user_id,'display_name',private.staff_medical_name(p_clinic,m.user_id),
   'delegated',exists(select 1 from private.staff_medical_delegates d where d.clinic_id=p_clinic and d.subject_id=auth.uid() and d.delegate_id=m.user_id and d.revoked_at is null))
   order by private.staff_medical_name(p_clinic,m.user_id),m.user_id),'[]')
  from public.clinic_members m where m.clinic_id=p_clinic and m.user_id<>auth.uid()),
 'shared_with_me',(select coalesce(jsonb_agg(jsonb_build_object('user_id',d.subject_id,'display_name',private.staff_medical_name(p_clinic,d.subject_id),
   'available',(private.staff_medical_current_profile(p_clinic,d.subject_id)).user_id is not null)
   order by private.staff_medical_name(p_clinic,d.subject_id),d.subject_id),'[]')
  from private.staff_medical_delegates d join public.clinic_members m on m.clinic_id=d.clinic_id and m.user_id=d.subject_id
  join public.clinic_members me on me.clinic_id=d.clinic_id and me.user_id=d.delegate_id
  where d.clinic_id=p_clinic and d.delegate_id=auth.uid() and d.revoked_at is null
   and d.granted_at>=m.created_at and d.granted_at>=me.created_at));
end$$;

create function public.ops_staff_medical_delegate_set(p_clinic uuid,p_actor uuid,p_delegate uuid,p_enabled boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform private.staff_medical_gate(p_clinic,p_actor,true);
 if private.personal_clinic(p_clinic) then raise exception 'staff_medical_team_required';end if;
 if p_delegate is null or p_enabled is null or p_delegate=auth.uid() then raise exception 'staff_medical_delegate_invalid';end if;
 if p_enabled then
  if not exists(select 1 from public.clinic_members where clinic_id=p_clinic and user_id=p_delegate) then raise exception 'staff_medical_delegate_invalid';end if;
  insert into private.staff_medical_delegates(clinic_id,subject_id,delegate_id) values(p_clinic,auth.uid(),p_delegate)
  on conflict(clinic_id,subject_id,delegate_id) do update set granted_at=clock_timestamp(),revoked_at=null
   where private.staff_medical_delegates.revoked_at is not null;
 else
  update private.staff_medical_delegates set revoked_at=clock_timestamp()
   where clinic_id=p_clinic and subject_id=auth.uid() and delegate_id=p_delegate and revoked_at is null;
 end if;
 if found then
  insert into public.audit_log(clinic_id,actor_id,action,entity_id,details)
  values(p_clinic,auth.uid(),case when p_enabled then 'staff_medical_delegate_granted' else 'staff_medical_delegate_revoked' end,p_delegate::text,'{}'::jsonb);
 end if;
end$$;

-- A chosen colleague reads the profile. Requires an active choice, both still members and current consent.
create function public.ops_staff_medical_delegate_view(p_clinic uuid,p_subject uuid,p_purpose text,p_actor uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare profile public.staff_medical_profiles;access_id uuid;begin
 perform private.staff_medical_gate(p_clinic,p_actor,true);
 if p_purpose is null or p_purpose not in ('emergency','emergency_preparation') then raise exception 'staff_medical_purpose_required';end if;
 -- A choice made before either person left and rejoined the clinic does not carry over.
 if not exists(select 1 from private.staff_medical_delegates d
  join public.clinic_members s on s.clinic_id=d.clinic_id and s.user_id=d.subject_id
  join public.clinic_members a on a.clinic_id=d.clinic_id and a.user_id=d.delegate_id
  where d.clinic_id=p_clinic and d.subject_id=p_subject and d.delegate_id=auth.uid() and d.revoked_at is null
   and d.granted_at>=s.created_at and d.granted_at>=a.created_at)
  then raise exception 'staff_medical_delegate_required';end if;
 profile=private.staff_medical_current_profile(p_clinic,p_subject);
 if profile.user_id is null then raise exception 'staff_medical_profile_unavailable';end if;
 insert into private.staff_medical_accesses(clinic_id,subject_id,actor_id,consent_event_id,purpose,via)
 values(p_clinic,p_subject,auth.uid(),profile.consent_event_id,p_purpose,'delegate') returning id into access_id;
 insert into public.audit_log(clinic_id,actor_id,action,entity_id,details)
 values(p_clinic,auth.uid(),'staff_medical_accessed',access_id::text,jsonb_build_object('subject',p_subject,'purpose',p_purpose,'via','delegate'));
 return jsonb_build_object('schema_version',1,'clinic_id',p_clinic,'actor_id',auth.uid(),'subject_id',p_subject,'details',profile.details,'access_id',access_id,'consent_at',profile.consent_at);
end$$;

-- Access log without medical content. The owner sees reads of their own profile;
-- administration of the clinic (encargado) sees every read in the clinic.
create function public.ops_staff_medical_access_log(p_clinic uuid,p_actor uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare admin boolean;begin
 perform private.staff_medical_gate(p_clinic,p_actor,false);
 admin=private.has_clinic_role(p_clinic,array['admin']);
 return jsonb_build_object('schema_version',1,'clinic_id',p_clinic,'actor_id',auth.uid(),'scope',case when admin then 'clinic' else 'own' end,
 'items',(select coalesce(jsonb_agg(to_jsonb(q) order by q.created_at desc,q.id),'[]') from (
  select a.id,a.created_at,a.purpose,a.via,a.subject_id,a.actor_id,
   private.staff_medical_name(p_clinic,a.subject_id) subject_name,private.staff_medical_name(p_clinic,a.actor_id) actor_name
  from private.staff_medical_accesses a where a.clinic_id=p_clinic and (admin or a.subject_id=auth.uid())
  order by a.created_at desc,a.id limit 100) q));
end$$;

revoke all on function public.ops_staff_medical_delegates(uuid,uuid),public.ops_staff_medical_delegate_set(uuid,uuid,uuid,boolean),
 public.ops_staff_medical_delegate_view(uuid,uuid,text,uuid),public.ops_staff_medical_access_log(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.ops_staff_medical_delegates(uuid,uuid),public.ops_staff_medical_delegate_set(uuid,uuid,uuid,boolean),
 public.ops_staff_medical_delegate_view(uuid,uuid,text,uuid),public.ops_staff_medical_access_log(uuid,uuid) to authenticated;

-- Same body as 20261027142748, also removing the person's colleague choices (as owner or as colleague).
create or replace function private.staff_medical_purge(p_clinic uuid,p_user uuid) returns void
language plpgsql security invoker set search_path='' as $$
declare decision private.staff_medical_retention_decisions;
begin
 if current_user<>(select pg_get_userbyid(relowner) from pg_class where oid='private.staff_medical_events'::regclass) then raise exception 'maintenance_owner_required';end if;
 perform 1 from public.clinics where id=p_clinic for update;
 select * into decision from private.staff_medical_retention_decisions where clinic_id=p_clinic and user_id=p_user for update;
 if not found or decision.legal_hold or decision.purge_after>clock_timestamp() then raise exception 'staff_medical_retention_not_released';end if;
 if exists(select 1 from public.staff_medical_profiles where clinic_id=p_clinic and user_id=p_user) then raise exception 'staff_medical_withdrawal_required';end if;
 if exists(select 1 from public.clinic_members where clinic_id=p_clinic and user_id=p_user) then raise exception 'staff_medical_membership_removal_required';end if;
 insert into private.staff_medical_purge_permits values(pg_backend_pid(),txid_current(),p_clinic,p_user);
 delete from private.staff_medical_accesses where clinic_id=p_clinic and (subject_id=p_user or actor_id=p_user);
 delete from private.staff_medical_events where clinic_id=p_clinic and user_id=p_user;
 delete from private.staff_medical_state where clinic_id=p_clinic and user_id=p_user;
 delete from private.staff_medical_delegates where clinic_id=p_clinic and (subject_id=p_user or delegate_id=p_user);
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

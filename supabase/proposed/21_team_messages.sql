-- Candidate for coordinated integration only. Do not apply directly to production.
-- Mensajes internos del equipo. Sin acceso directo a la tabla: solo RPCs.
begin;

create table if not exists public.team_messages (
 id uuid primary key default gen_random_uuid(),
 clinic_id uuid not null references public.clinics(id) on delete cascade,
 sender_id uuid not null references auth.users(id) on delete cascade,
 recipient_id uuid references auth.users(id) on delete cascade,
 body text not null check (char_length(body) between 1 and 2000),
 created_at timestamptz not null default clock_timestamp(),
 read_at timestamptz
);
alter table public.team_messages enable row level security;
revoke all on public.team_messages from public, anon, authenticated;
create index if not exists team_messages_inbox
 on public.team_messages(clinic_id, recipient_id, created_at desc);

create or replace function public.team_message_send(
 p_clinic uuid, p_recipients uuid[], p_body text
) returns integer language plpgsql volatile security definer set search_path='' as $$
declare target uuid; sent integer := 0; body_trim text := btrim(coalesce(p_body,''));
begin
 if auth.uid() is null or not exists(
   select 1 from public.clinic_members m
   where m.clinic_id=p_clinic and m.user_id=auth.uid()
 ) then raise exception 'team_message_membership_required'; end if;
 if char_length(body_trim) < 1 or char_length(body_trim) > 2000 then
   raise exception 'team_message_invalid_body';
 end if;
 if p_recipients is null or cardinality(p_recipients)=0 then
   insert into public.team_messages(clinic_id, sender_id, recipient_id, body)
   values (p_clinic, auth.uid(), null, body_trim);
   return 1;
 end if;
 if cardinality(p_recipients) > 50 then raise exception 'team_message_too_many'; end if;
 foreach target in array p_recipients loop
   if target = auth.uid() then continue; end if;
   if not exists(select 1 from public.clinic_members m
     where m.clinic_id=p_clinic and m.user_id=target) then
     raise exception 'team_message_recipient_not_member';
   end if;
   insert into public.team_messages(clinic_id, sender_id, recipient_id, body)
   values (p_clinic, auth.uid(), target, body_trim);
   sent := sent + 1;
 end loop;
 if sent = 0 then raise exception 'team_message_no_recipients'; end if;
 return sent;
end$$;

create or replace function public.team_message_inbox(p_clinic uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not exists(
   select 1 from public.clinic_members m
   where m.clinic_id=p_clinic and m.user_id=auth.uid()
 ) then raise exception 'team_message_membership_required'; end if;
 return coalesce((
   select jsonb_agg(jsonb_build_object(
     'id', t.id,
     'clinic_id', t.clinic_id,
     'sender_id', t.sender_id,
     'recipient_id', t.recipient_id,
     'sender_name', coalesce(p.display_name,''),
     'sender_photo', case when p.show_photo then p.photo_url else null end,
     'body', t.body,
     'created_at', t.created_at,
     'read_at', t.read_at) order by t.created_at desc)
   from public.team_messages t
   left join public.personal_profiles p on p.user_id=t.sender_id
   where t.clinic_id=p_clinic
     and t.sender_id <> auth.uid()
     and (t.recipient_id is null or t.recipient_id = auth.uid())
 ), '[]'::jsonb);
end$$;

create or replace function public.team_message_mark_read(p_message uuid)
returns void language plpgsql volatile security definer set search_path='' as $$
declare msg public.team_messages;
begin
 if auth.uid() is null then raise exception 'team_message_membership_required'; end if;
 select * into msg from public.team_messages t where t.id=p_message;
 if not found then raise exception 'team_message_not_found'; end if;
 if msg.recipient_id is not null and msg.recipient_id <> auth.uid() then
   raise exception 'team_message_not_recipient';
 end if;
 if msg.recipient_id is null and not exists(
   select 1 from public.clinic_members m
   where m.clinic_id=msg.clinic_id and m.user_id=auth.uid()
 ) then raise exception 'team_message_membership_required'; end if;
 update public.team_messages set read_at=coalesce(read_at, clock_timestamp())
 where id=p_message;
end$$;

grant execute on function public.team_message_send(uuid, uuid[], text) to authenticated;
grant execute on function public.team_message_inbox(uuid) to authenticated;
grant execute on function public.team_message_mark_read(uuid) to authenticated;
commit;

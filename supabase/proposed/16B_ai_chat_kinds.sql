-- Apply after 16A. The app assistant chat and the AI help/support chats are
-- different products that were sharing one history: every chat landed in
-- ai_chats and ai_dashboard listed them all, so a usage-help answer or a support
-- draft showed up among the user's assistant conversations. This marks the kind
-- at creation and keeps the assistant history to assistant chats only.
begin;

alter table public.ai_chats
  add column if not exists kind text not null default 'assistant'
  check (kind in ('assistant','help','support'));

-- Chats already stored from the included help can be recognised by their title;
-- support drafts and assistant chats keep the safe default.
update public.ai_chats set kind='help' where kind='assistant' and title like 'Ayuda incluida · %';

-- The old 3-argument signature must go: a 4-argument function with a default
-- would otherwise make the 3-argument call ambiguous.
drop function if exists public.ai_chat_create(uuid,text,text);

create function public.ai_chat_create(
  p_clinic uuid, p_title text, p_operation text, p_kind text default 'assistant'
) returns uuid language plpgsql security definer set search_path='' as $$
declare fp jsonb; v_id uuid;
begin
 if not private.has_clinic_role(p_clinic) then raise exception 'access_denied';end if;
 if p_kind not in ('assistant','support') then raise exception 'invalid_chat_kind';end if;
 fp=jsonb_build_object('kind','ai_chat','chat_kind',p_kind,'title',p_title);
 v_id=private.vet_receipt(p_clinic,p_operation,fp);
 if v_id is not null then return v_id;end if;
 insert into public.ai_chats(clinic_id,owner_id,title,kind) values(p_clinic,auth.uid(),p_title,p_kind) returning id into v_id;
 insert into private.vet_operation_receipts values(auth.uid(),p_clinic,p_operation,fp,v_id);return v_id;
end$$;

-- The included help creates its own chat; it must not read as an assistant chat.
create or replace function public.starter_ai_prepare(
  p_clinic uuid, p_topic text, p_operation text
) returns jsonb language plpgsql security definer set search_path='' as $$
declare cfg private.starter_ai_config; r private.starter_ai_requests; v_chat uuid;
 day_utc date=(clock_timestamp() at time zone 'UTC')::date;
begin
 if not private.has_clinic_role(p_clinic) or not exists(select 1 from auth.users where id=auth.uid() and email_confirmed_at is not null) then raise exception 'verified_member_required';end if;
 if p_topic is null or p_topic not in('getting_started','permissions','payments','notifications','report_problem','privacy') or p_operation is null or length(p_operation) not between 16 and 100 then raise exception 'invalid_help_topic';end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,715));
 select * into r from private.starter_ai_requests where user_id=auth.uid() and operation=p_operation;
 if found then if r.clinic_id<>p_clinic or r.topic<>p_topic then raise exception 'operation_content_changed';end if;
 if r.state in('queued','processing') and r.created_at<clock_timestamp()-interval '2 minutes' then update private.starter_ai_requests set state='failed' where id=r.id returning * into r;end if;
 return jsonb_build_object('id',r.id,'state',r.state,'chat',r.chat_id);end if;
 select * into cfg from private.starter_ai_config where id=true;if not cfg.enabled then raise exception 'starter_ai_disabled';end if;
 insert into private.starter_ai_global_usage(day)values(day_utc)on conflict do nothing;perform 1 from private.starter_ai_global_usage where day=day_utc for update;
 insert into private.starter_ai_user_usage(user_id,day)values(auth.uid(),day_utc)on conflict do nothing;
 if(select attempts from private.starter_ai_global_usage where day=day_utc)>=cfg.global_daily or(select attempts from private.starter_ai_user_usage where user_id=auth.uid() and day=day_utc)>=cfg.per_user_daily then raise exception 'starter_ai_daily_limit';end if;
 update private.starter_ai_global_usage set attempts=attempts+1 where day=day_utc;update private.starter_ai_user_usage set attempts=attempts+1 where user_id=auth.uid() and day=day_utc;
 insert into public.ai_chats(clinic_id,owner_id,title,kind)values(p_clinic,auth.uid(),'Ayuda incluida · '||(case p_topic when 'getting_started' then 'Primeros pasos' when 'permissions' then 'Roles y permisos' when 'payments' then 'Planes, ventas y caja' when 'notifications' then 'Avisos y notificaciones' when 'report_problem' then 'Reportar un problema' when 'privacy' then 'Privacidad y contexto' end),'help')returning id into v_chat;
 insert into public.ai_messages(clinic_id,chat_id,role,body,created_by)values(p_clinic,v_chat,'user','Ayuda de uso de la app: '||(case p_topic when 'getting_started' then 'Primeros pasos' when 'permissions' then 'Roles y permisos' when 'payments' then 'Planes, ventas y caja' when 'notifications' then 'Avisos y notificaciones' when 'report_problem' then 'Reportar un problema' when 'privacy' then 'Privacidad y contexto' end),auth.uid());
 insert into private.starter_ai_requests(user_id,clinic_id,chat_id,topic,provider,model,operation)values(auth.uid(),p_clinic,v_chat,p_topic,cfg.provider,cfg.model,p_operation)returning * into r;
 return jsonb_build_object('id',r.id,'state',r.state,'chat',v_chat);end $$;

-- `ai_dashboard` already returns every chat as `to_jsonb(c)`, so `kind` travels
-- with each row and the screen keeps the assistant history to assistant chats.
-- It is not redefined here on purpose: 13P also recreates it to add `can_manage`,
-- and a redefinition in this file would drop that field if it ran later.

revoke all on function public.ai_chat_create(uuid,text,text,text),public.starter_ai_prepare(uuid,text,text) from public,anon,authenticated;
grant execute on function public.ai_chat_create(uuid,text,text,text),public.starter_ai_prepare(uuid,text,text) to authenticated;

commit;

-- Free-text help chat for the included assistant. Apply after 16B.
--
-- The old `starter_ai_prepare` path stays for compatibility (fixed topics).
-- This one stores the user's question in a `kind='help'` chat, so the answer
-- keeps its conversation and stays out of the assistant history. The daily and
-- global quotas are the same, and the beta gate remains in the edge function.
begin;

create function public.starter_ai_prepare_chat(
  p_clinic uuid, p_chat uuid, p_message text, p_operation text
) returns jsonb language plpgsql security definer set search_path='' as $$
declare cfg private.starter_ai_config; r private.starter_ai_requests; v_chat uuid;
  day_utc date=(clock_timestamp() at time zone 'UTC')::date;
begin
  if not private.has_clinic_role(p_clinic) or not exists(
    select 1 from auth.users
    where id=auth.uid() and email_confirmed_at is not null
  ) then raise exception 'verified_member_required'; end if;
  if p_message is null or length(btrim(p_message)) not between 1 and 1000
     or p_operation is null or length(p_operation) not between 16 and 100
  then raise exception 'invalid_help_message'; end if;
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,715));
  select * into r from private.starter_ai_requests
    where user_id=auth.uid() and operation=p_operation;
  if found then
    -- A retry may arrive without the chat id if the first response was lost;
    -- only an explicitly different chat is a content change.
    if r.clinic_id<>p_clinic or r.topic<>'chat'
       or (p_chat is not null and r.chat_id<>p_chat)
    then raise exception 'operation_content_changed'; end if;
    if r.state in('queued','processing')
       and r.created_at<clock_timestamp()-interval '2 minutes' then
      update private.starter_ai_requests set state='failed'
        where id=r.id returning * into r;
    end if;
    return jsonb_build_object('id',r.id,'state',r.state,'chat',r.chat_id);
  end if;
  select * into cfg from private.starter_ai_config where id=true;
  if not cfg.enabled then raise exception 'starter_ai_disabled'; end if;
  if p_chat is not null then
    if not exists(
      select 1 from public.ai_chats
      where id=p_chat and clinic_id=p_clinic and owner_id=auth.uid()
        and kind='help'
    ) then raise exception 'invalid_help_chat'; end if;
    v_chat=p_chat;
  else
    insert into public.ai_chats(clinic_id,owner_id,title,kind)
      values(
        p_clinic,auth.uid(),'Ayuda incluida · '||left(btrim(p_message),60),
        'help'
      ) returning id into v_chat;
  end if;
  insert into private.starter_ai_global_usage(day) values(day_utc)
    on conflict do nothing;
  perform 1 from private.starter_ai_global_usage where day=day_utc for update;
  insert into private.starter_ai_user_usage(user_id,day) values(auth.uid(),day_utc)
    on conflict do nothing;
  if (select attempts from private.starter_ai_global_usage where day=day_utc)
       >=cfg.global_daily
     or (select attempts from private.starter_ai_user_usage
         where user_id=auth.uid() and day=day_utc)>=cfg.per_user_daily
  then raise exception 'starter_ai_daily_limit'; end if;
  update private.starter_ai_global_usage set attempts=attempts+1
    where day=day_utc;
  update private.starter_ai_user_usage set attempts=attempts+1
    where user_id=auth.uid() and day=day_utc;
  insert into public.ai_messages(clinic_id,chat_id,role,body,created_by)
    values(p_clinic,v_chat,'user',btrim(p_message),auth.uid());
  insert into private.starter_ai_requests(
    user_id,clinic_id,chat_id,topic,provider,model,operation
  ) values(
    auth.uid(),p_clinic,v_chat,'chat',cfg.provider,cfg.model,p_operation
  ) returning * into r;
  return jsonb_build_object('id',r.id,'state',r.state,'chat',v_chat);
end $$;

revoke all on function public.starter_ai_prepare_chat(uuid,uuid,text,text)
  from public,anon,authenticated;
grant execute on function public.starter_ai_prepare_chat(uuid,uuid,text,text)
  to authenticated;

-- Deployment (run by the owner, not by this migration):
--   update private.starter_ai_config
--      set enabled=true, provider='zai', model='glm-4.7-flash';
-- and set the function secrets STARTER_AI_PROVIDER=zai,
-- STARTER_AI_MODEL=glm-4.7-flash, STARTER_AI_API_KEY and
-- STARTER_AI_FREE_TIER_REVIEWED=true.

commit;

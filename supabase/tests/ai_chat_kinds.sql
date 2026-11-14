\set ON_ERROR_STOP on
-- The assistant history must not mix in the included help or support drafts.
begin;
insert into auth.users values('00000000-0000-0000-0000-0000000000B1','kindsb1@example.test',now());
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-0000000000B1',true);
select public.personal_workspace_create() as clinic \gset
select set_config('test.kind_clinic',:'clinic',true);
-- An assistant chat created without kind stays an assistant chat.
select public.ai_chat_create(:'clinic','Chat del asistente',repeat('a1',24)) as assistant \gset
select set_config('test.kind_assistant',:'assistant',true);
-- A support draft is created with its own kind.
select public.ai_chat_create(:'clinic','Ayuda de soporte',repeat('a2',24),'support') as support \gset
select set_config('test.kind_support',:'support',true);
do $$begin
 begin perform public.ai_chat_create(current_setting('test.kind_clinic')::uuid,'Tipo inválido',repeat('a3',24),'otro');raise exception 'invalid_kind_allowed';exception when raise_exception then if sqlerrm<>'invalid_chat_kind' then raise;end if;end;
end$$;
-- The included help marks its own chat as help.
reset role;
insert into public.ai_messages(clinic_id,chat_id,role,body,created_by)
 values(:'clinic',:'support','user','Borrador de soporte ficticio','00000000-0000-0000-0000-0000000000B1');
update private.starter_ai_config set enabled=true;
set local role authenticated;
select public.starter_ai_prepare(:'clinic','getting_started',repeat('b1',24)) as prepared \gset
select set_config('test.kind_help',(:'prepared'::jsonb->>'chat'),true);
do $$
declare chats jsonb;
begin
 chats := public.ai_dashboard(current_setting('test.kind_clinic')::uuid)->'chats';
 -- Every chat carries its kind, so the client can keep the assistant history
 -- apart without a second query.
 if exists(select 1 from jsonb_array_elements(chats) c where c->>'id'=current_setting('test.kind_assistant') and c->>'kind'<>'assistant') then raise exception 'assistant_kind_missing';end if;
 if exists(select 1 from jsonb_array_elements(chats) c where c->>'id'=current_setting('test.kind_support') and c->>'kind'<>'support') then raise exception 'support_kind_missing';end if;
 if exists(select 1 from jsonb_array_elements(chats) c where c->>'id'=current_setting('test.kind_help') and c->>'kind'<>'help') then raise exception 'help_kind_missing';end if;
 -- The assistant history is exactly the assistant chats; the client filter
 -- reproduces the same rule it applies in the app.
 if (select count(*) from jsonb_array_elements(chats) c where coalesce(c->>'kind','assistant')='assistant')<>1 then raise exception 'assistant_history_count_wrong';end if;
 -- A support draft stays readable by id even though it is not assistant.
 if jsonb_array_length(public.ai_messages_read(current_setting('test.kind_support')::uuid))<1 then raise exception 'support_chat_unreadable';end if;
 if jsonb_array_length(public.ai_messages_read(current_setting('test.kind_help')::uuid))<1 then raise exception 'help_chat_unreadable';end if;
end$$;
rollback;

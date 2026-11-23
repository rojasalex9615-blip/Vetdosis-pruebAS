-- Deshace la migración 21 (mensajes del equipo). Solo elimina objetos que creó ella.
begin;
drop function if exists public.team_message_mark_read(uuid);
drop function if exists public.team_message_inbox(uuid);
drop function if exists public.team_message_send(uuid, uuid[], text);
drop table if exists public.team_messages;
commit;

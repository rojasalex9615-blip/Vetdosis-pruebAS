-- Deshace la migración 20 (perfil personal). Solo elimina objetos que creó ella.
begin;
drop function if exists public.personal_profile_team(uuid);
drop function if exists public.personal_profile_save(jsonb, integer);
drop function if exists public.personal_profile_get(uuid);
drop table if exists public.personal_profiles;
commit;

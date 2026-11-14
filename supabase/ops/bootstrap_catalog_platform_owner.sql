-- Manual, project-specific owner bootstrap.
-- Run only after verifying the intended user in this Supabase project's auth.users:
-- psql "$DATABASE_URL" -v owner_user_id="<verified-auth-user-uuid>" -f supabase/ops/bootstrap_catalog_platform_owner.sql
\set ON_ERROR_STOP on
\if :{?owner_user_id}
\else
  \echo 'Required: pass -v owner_user_id=<verified-auth-user-uuid>'
  \quit 2
\endif

select set_config('app.catalog_platform_owner_id', :'owner_user_id', false);

do $$
declare
  v_owner uuid := current_setting('app.catalog_platform_owner_id')::uuid;
begin
  if not exists (select 1 from auth.users where id = v_owner) then
    raise exception 'catalog_platform_owner_user_not_found';
  end if;
  insert into private.catalog_platform_owners(user_id)
  values (v_owner)
  on conflict (user_id) do nothing;
end
$$;

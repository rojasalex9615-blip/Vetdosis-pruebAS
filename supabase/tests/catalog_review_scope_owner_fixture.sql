-- Local-only synthetic platform owner for the catalog scope test.
-- This file is run only by the disposable PostgreSQL integration harness.
insert into private.catalog_platform_owners(user_id)
values ('f13a9b24-5c7d-4e61-9b31-2a4d8e6f701c'::uuid)
on conflict (user_id) do nothing;

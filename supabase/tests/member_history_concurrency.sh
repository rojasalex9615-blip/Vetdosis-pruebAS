#!/usr/bin/env bash
set -euo pipefail
container_name="$1"
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT
wait_query() {
 local query="$1"
 for attempt in {1..50};do
  if [ "$(docker exec "$container_name" psql -U postgres -Atc "$query")" = t ];then return;fi
  sleep .05
 done
 echo 'Membership race coordination failed';exit 1
}
docker exec -i "$container_name" psql -U postgres -v ON_ERROR_STOP=1 >/dev/null <<'SQL'
insert into auth.users(id,email,email_confirmed_at) values
 ('00000000-0000-0000-0000-000000000292','p0-race-remove@example.test',now()),
 ('00000000-0000-0000-0000-000000000293','p0-race-assign@example.test',now());
insert into public.clinic_members(clinic_id,user_id,role)
 select id,u,'auxiliar' from public.clinics cross join unnest(array[
 '00000000-0000-0000-0000-000000000292'::uuid,'00000000-0000-0000-0000-000000000293'::uuid]) u
 where name='Synthetic medication permissions';
SQL
# Removal wins: the waiting assignment must recheck and deny after commit.
docker exec -e PGAPPNAME=p0_remove_first -i "$container_name" psql -U postgres -v ON_ERROR_STOP=1 > "$work_dir/remove.log" 2>&1 <<'SQL' &
begin;
select id as clinic from public.clinics where name='Synthetic medication permissions' \gset
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000150',true);
set local role authenticated;
select public.remove_clinic_member(:'clinic','00000000-0000-0000-0000-000000000292');
select pg_advisory_xact_lock(774292);
select pg_sleep(4);
commit;
SQL
remover=$!
wait_query "select not pg_try_advisory_lock(774292)"
docker exec -e PGAPPNAME=p0_assign_waiting -i "$container_name" psql -U postgres -v ON_ERROR_STOP=1 > "$work_dir/assignment.log" 2>&1 <<'SQL' &
insert into public.clinic_tasks(clinic_id,title,assigned_to,priority,created_by)
 select id,'P0 forbidden waiting assignment','00000000-0000-0000-0000-000000000292','media','00000000-0000-0000-0000-000000000150'
 from public.clinics where name='Synthetic medication permissions';
SQL
writer=$!
wait_query "select exists(select 1 from pg_stat_activity where application_name='p0_assign_waiting' and cardinality(pg_blocking_pids(pid))>0)"
wait "$remover" || { cat "$work_dir/remove.log";exit 1; }
if wait "$writer";then echo 'Removed member received a new assignment';exit 1;fi
grep -Fq current_member_required "$work_dir/assignment.log" || { cat "$work_dir/assignment.log";exit 1; }
# Assignment wins: removal waits, then succeeds without deleting the task.
docker exec -e PGAPPNAME=p0_assign_first -i "$container_name" psql -U postgres -v ON_ERROR_STOP=1 > "$work_dir/first.log" 2>&1 <<'SQL' &
begin;
insert into public.clinic_tasks(clinic_id,title,assigned_to,priority,created_by)
 select id,'P0 retained concurrent assignment','00000000-0000-0000-0000-000000000293','media','00000000-0000-0000-0000-000000000150'
 from public.clinics where name='Synthetic medication permissions';
select pg_advisory_xact_lock(774293);
select pg_sleep(4);
commit;
SQL
writer=$!
wait_query "select not pg_try_advisory_lock(774293)"
docker exec -e PGAPPNAME=p0_remove_waiting -i "$container_name" psql -U postgres -v ON_ERROR_STOP=1 > "$work_dir/second.log" 2>&1 <<'SQL' &
select id as clinic from public.clinics where name='Synthetic medication permissions' \gset
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000150',false);
set role authenticated;
select public.remove_clinic_member(:'clinic','00000000-0000-0000-0000-000000000293');
SQL
remover=$!
wait_query "select exists(select 1 from pg_stat_activity where application_name='p0_remove_waiting' and cardinality(pg_blocking_pids(pid))>0)"
wait "$writer" || { cat "$work_dir/first.log";exit 1; }
wait "$remover" || { cat "$work_dir/second.log";exit 1; }
docker exec -i "$container_name" psql -U postgres -v ON_ERROR_STOP=1 <<'SQL'
do $$begin
 if exists(select 1 from public.clinic_tasks where title='P0 forbidden waiting assignment')
 or not exists(select 1 from public.clinic_tasks where title='P0 retained concurrent assignment'
  and assigned_to='00000000-0000-0000-0000-000000000293')
 or exists(select 1 from public.clinic_members where user_id in
 ('00000000-0000-0000-0000-000000000292','00000000-0000-0000-0000-000000000293')) then
  raise exception 'membership_race_failed';
 end if;
end$$;
SQL
echo 'Membership races passed: removed-before-assign denies; assigned-before-remove retains history.'

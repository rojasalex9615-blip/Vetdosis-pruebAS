#!/usr/bin/env bash
set -euo pipefail
container_name="$1"
test_database="staff_medical_races"
work_dir=$(mktemp -d)
docker exec "$container_name" createdb -U postgres -T postgres "$test_database"
trap 'docker exec "$container_name" dropdb -U postgres --force "$test_database" >/dev/null; rm -rf "$work_dir"' EXIT
pids=()
for operation in aa bb;do
 docker exec -i "$container_name" psql -U postgres -d "$test_database" -v ON_ERROR_STOP=1 > "$work_dir/$operation.log" 2>&1 <<SQL &
select id as clinic from public.clinics where name='Synthetic medication permissions' \\gset
select created_at as member_since from public.clinic_members where clinic_id=:'clinic' and user_id='00000000-0000-0000-0000-000000000181' \\gset
select private.staff_medical_notice()->>'hash' as hash \\gset
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000181',false);
set role authenticated;
select public.ops_staff_medical_write(:'clinic','save','{"blood":"Synthetic $operation"}',true,1,:'hash',3,:'member_since',auth.uid(),repeat('ed$operation',12));
SQL
 pids+=("$!")
done
success=0
for pid in "${pids[@]}";do if wait "$pid";then success=$((success+1));fi;done
if [ "$success" -ne 1 ] || ! grep -q 'staff_medical_revision_changed' "$work_dir/"*.log;then cat "$work_dir/"*.log;exit 1;fi
# The administrative view begins before withdrawal commits; it must read fresh consent after waiting.
docker exec -i "$container_name" psql -U postgres -d "$test_database" -v ON_ERROR_STOP=1 > "$work_dir/setup.log" <<'SQL'
select id as clinic from public.clinics where name='Synthetic medication permissions' \gset
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000150',false);
set role authenticated;
select public.permission_grant(:'clinic',auth.uid(),'staff.medical.read',null,clock_timestamp()+interval '1 day','Synthetic concurrent medical read');
SQL
# A separate connection owns the release barrier until the reader is visibly blocked.
docker exec -e PGAPPNAME=staff-medical-barrier -i "$container_name" psql -U postgres -d "$test_database" -v ON_ERROR_STOP=1 > "$work_dir/barrier.log" 2>&1 <<'SQL' &
select pg_advisory_lock(771158);
select pg_sleep(30);
SQL
barrier_pid=$!
for attempt in {1..40};do
 if [ "$(docker exec "$container_name" psql -U postgres -d "$test_database" -Atc 'select pg_try_advisory_lock(771158)')" = f ];then break;fi
 sleep 0.05
done
docker exec -i "$container_name" psql -U postgres -d "$test_database" -v ON_ERROR_STOP=1 > "$work_dir/withdraw.log" 2>&1 <<'SQL' &
begin;
select id as clinic from public.clinics where name='Synthetic medication permissions' \gset
select created_at as member_since from public.clinic_members where clinic_id=:'clinic' and user_id='00000000-0000-0000-0000-000000000181' \gset
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000181',false);
set role authenticated;
select public.ops_staff_medical_write(:'clinic','withdraw',null,false,null,null,4,:'member_since',auth.uid(),repeat('edcc',12));
select pg_advisory_xact_lock(771156);
select pg_advisory_xact_lock(771158);
commit;
SQL
writer_pid=$!
ready=false
for attempt in {1..40};do
 if [ "$(docker exec "$container_name" psql -U postgres -d "$test_database" -Atc 'select pg_try_advisory_lock(771156)')" = f ];then ready=true;break;fi
 sleep 0.1
done
if [ "$ready" != true ];then cat "$work_dir/withdraw.log";exit 1;fi
docker exec -e PGAPPNAME=staff-medical-reader -i "$container_name" psql -U postgres -d "$test_database" -v ON_ERROR_STOP=1 > "$work_dir/read.log" 2>&1 <<'SQL' &
select id as clinic from public.clinics where name='Synthetic medication permissions' \gset
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000150',false);
set role authenticated;
select public.ops_staff_medical_view(:'clinic','00000000-0000-0000-0000-000000000181','emergency',auth.uid());
SQL
reader_pid=$!
blocked=false
for attempt in {1..60};do
 if [ "$(docker exec "$container_name" psql -U postgres -d "$test_database" -Atc "select count(*) from pg_stat_activity where datname='$test_database' and application_name='staff-medical-reader' and wait_event_type='Lock'")" -ge 1 ];then blocked=true;break;fi
 sleep 0.05
done
if [ "$blocked" != true ];then echo 'Reader did not wait for withdrawal';cat "$work_dir/read.log";exit 1;fi
docker exec "$container_name" psql -U postgres -d "$test_database" -Atc "select pg_terminate_backend(pid) from pg_stat_activity where datname='$test_database' and application_name='staff-medical-barrier'" >/dev/null
wait "$barrier_pid" || true
if wait "$reader_pid";then echo 'Read returned withdrawn health information';exit 1;fi
wait "$writer_pid" || { cat "$work_dir/withdraw.log";exit 1; }
grep -q 'staff_medical_profile_unavailable' "$work_dir/read.log" || { cat "$work_dir/read.log";exit 1; }
docker exec -i "$container_name" psql -U postgres -d "$test_database" -v ON_ERROR_STOP=1 <<'SQL'
do $$begin
 if (select count(*) from private.staff_medical_accesses where subject_id='00000000-0000-0000-0000-000000000181')<>1 then raise exception 'Withdrawn read added an access event';end if;
 if exists(select 1 from public.staff_medical_profiles where user_id='00000000-0000-0000-0000-000000000181') then raise exception 'Withdrawn profile survived';end if;
end$$;
SQL
echo 'Medical updates cannot overwrite a newer revision; a waiting reader cannot access a withdrawn profile.'

#!/usr/bin/env bash
set -euo pipefail
container_name="$1"
test_database="hospital_target_transfer_race"
work_dir=$(mktemp -d)
docker exec "$container_name" createdb -U postgres -T postgres "$test_database"
trap 'docker exec "$container_name" dropdb -U postgres --force "$test_database" >/dev/null; rm -rf "$work_dir"' EXIT

# Reuse only the synthetic permission setup, in a separate cloned database.
{ sed -n '1,/^reset role;/p' supabase/tests/hospital_target_transfer.sql; echo 'commit;'; } |
 docker exec -i "$container_name" psql -U postgres -d "$test_database" -v ON_ERROR_STOP=1 > "$work_dir/setup.log" 2>&1 || { cat "$work_dir/setup.log"; exit 1; }

pids=()
for user_suffix in 151 160;do
 docker exec -i "$container_name" psql -U postgres -d "$test_database" -v ON_ERROR_STOP=1 > "$work_dir/$user_suffix.log" 2>&1 <<SQL &
begin;
select id as clinic from public.clinics where name='Synthetic medication permissions' \gset
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000$user_suffix',false);
set role authenticated;
select public.hospital_delivery_target_set(:'clinic','fcm','synthetic_concurrent_device_123456',true);
select pg_sleep(1);
commit;
SQL
 pids+=("$!")
done
for pid in "${pids[@]}";do
 wait "$pid" || { cat "$work_dir/151.log" "$work_dir/160.log"; exit 1; }
done
docker exec -i "$container_name" psql -U postgres -d "$test_database" -v ON_ERROR_STOP=1 <<'SQL'
do $$begin
 if (select count(*) from private.hospital_delivery_targets
     where channel='fcm' and destination='synthetic_concurrent_device_123456'
       and revoked_at is null)<>1 then
  raise exception 'Concurrent device registration left multiple active users';
 end if;
end$$;
SQL
echo 'Concurrent device registration preserves exactly one active user.'

#!/usr/bin/env bash
set -euo pipefail
container_name="$1"
test_database="vial_index_write_compatibility"
work_dir=$(mktemp -d)
docker exec "$container_name" createdb -U postgres -T postgres "$test_database"
trap 'docker exec "$container_name" dropdb -U postgres --force "$test_database" >/dev/null; rm -rf "$work_dir"' EXIT
docker exec -i "$container_name" psql -U postgres -d "$test_database" -v ON_ERROR_STOP=1 > "$work_dir/setup.log" <<'SQL'
drop index public.vial_movement_chronology;
drop index public.vial_record_incidents;
insert into public.medication_vials(id,clinic_id,product_version_id,lot,initial_volume,unit,responsible_id,opened_at)
select '00000000-0000-0000-0000-000000000405',c.id,p.id,'SYNTHETIC-INDEX-WRITE',10,'ml','00000000-0000-0000-0000-000000000151',clock_timestamp()-interval '1 minute'
from public.clinics c cross join public.medication_product_versions p where c.name='Synthetic medication permissions' and p.product_key='synthetic-permission-liquid';
-- Pause the real RPC after it writes medication_records and before its movement.
-- The former inverted ordinary-index lock order could deadlock at this boundary.
create function public.synthetic_index_write_pause() returns trigger language plpgsql as $$begin
 perform pg_advisory_xact_lock(771155);
 perform pg_sleep(2);
 return new;
end$$;
create trigger synthetic_index_write_pause after insert on public.medication_records for each row
when(new.vial_id='00000000-0000-0000-0000-000000000405') execute function public.synthetic_index_write_pause();
SQL
docker exec -i "$container_name" psql -U postgres -d "$test_database" -v ON_ERROR_STOP=1 > "$work_dir/write.log" 2>&1 <<'SQL' &
set statement_timeout='15s';
select id as case_id from public.clinical_cases where title='Synthetic medication case' \gset
select id as product from public.medication_product_versions where product_key='synthetic-permission-liquid' \gset
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000152',false);
set role authenticated;
select public.rx_medication_report(:'case_id',jsonb_build_object('product_version_id',:'product','quantity','1','unit','ml','route','synthetic route','procedure','cuidados','performed_by',auth.uid(),'observed_at',to_char(clock_timestamp(),'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),'vial_id','00000000-0000-0000-0000-000000000405'),repeat('fa05',12));
SQL
writer_pid=$!
ready=false
for attempt in {1..40};do
 if [ "$(docker exec "$container_name" psql -U postgres -d "$test_database" -Atc 'select pg_try_advisory_lock(771155)')" = f ];then ready=true;break;fi
 sleep 0.1
done
if [ "$ready" != true ];then cat "$work_dir/write.log";echo 'Writer did not reach the index-test boundary';exit 1;fi
for migration in supabase/migrations/20261027141227_vial_movement_index_concurrent.sql supabase/migrations/20261027141229_vial_incident_index_concurrent.sql;do
 # Each file is sent on its own connection outside any explicit transaction.
 if ! docker exec -e PGOPTIONS='-c statement_timeout=15000' -i "$container_name" psql -U postgres -d "$test_database" -v ON_ERROR_STOP=1 < "$migration" > "$work_dir/index.log" 2>&1;then
  cat "$work_dir/index.log";cat "$work_dir/write.log";exit 1
 fi
done
wait "$writer_pid" || { cat "$work_dir/write.log";exit 1; }
docker exec -i "$container_name" psql -U postgres -d "$test_database" -v ON_ERROR_STOP=1 <<'SQL'
do $$begin
 if private.rx_vial_balance('00000000-0000-0000-0000-000000000405')<>9 then raise exception 'Concurrent migration lost or duplicated draw';end if;
 if (select count(*) from public.medication_records where vial_id='00000000-0000-0000-0000-000000000405')<>1 then raise exception 'Concurrent migration lost or duplicated report';end if;
 if not (select count(*)=2 and bool_and(indisvalid and indisready) from pg_index where indexrelid in ('public.vial_movement_chronology'::regclass,'public.vial_record_incidents'::regclass)) then raise exception 'Concurrent indexes not ready and valid';end if;
end$$;
SQL
echo 'Concurrent index builds and the real medication report RPC completed without deadlock or duplicate draw.'

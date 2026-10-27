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
create function public.synthetic_index_write_pause() returns trigger language plpgsql as $$begin
 perform pg_advisory_xact_lock(771155);
 -- Test-controlled release: the writer cannot proceed until the index is observed active.
 perform pg_advisory_xact_lock(771157);
 return new;
end$$;
create trigger synthetic_index_write_pause after insert on public.medication_records for each row
when(new.vial_id='00000000-0000-0000-0000-000000000405') execute function public.synthetic_index_write_pause();
SQL
wait_lock(){
 local marker="$1"
 for attempt in {1..60};do
  if [ "$(docker exec "$container_name" psql -U postgres -d "$test_database" -Atc "select pg_try_advisory_lock($marker)")" = f ];then return;fi
  sleep 0.1
 done
 cat "$work_dir/"*.log;echo 'Index-write test barrier was not reached';exit 1
}
iteration=0
for migration in supabase/migrations/20261027141227_vial_movement_index_concurrent.sql supabase/migrations/20261027141229_vial_incident_index_concurrent.sql;do
 iteration=$((iteration+1))
 # A separate session holds the release lock. Sleep is only a bounded watchdog;
 # the test explicitly terminates this synthetic backend to release the writer.
 docker exec -e PGAPPNAME=vial-index-barrier -i "$container_name" psql -U postgres -d "$test_database" -v ON_ERROR_STOP=1 > "$work_dir/barrier.log" 2>&1 <<'SQL' &
select pg_advisory_lock(771157);
select pg_sleep(30);
SQL
 barrier_pid=$!
 wait_lock 771157
 docker exec -e PGAPPNAME=vial-index-writer -i "$container_name" psql -U postgres -d "$test_database" -v ON_ERROR_STOP=1 > "$work_dir/write.log" 2>&1 <<SQL &
set statement_timeout='20s';
select id as case_id from public.clinical_cases where title='Synthetic medication case' \\gset
select id as product from public.medication_product_versions where product_key='synthetic-permission-liquid' \\gset
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000152',false);
set role authenticated;
select public.rx_medication_report(:'case_id',jsonb_build_object('product_version_id',:'product','quantity','1','unit','ml','route','synthetic route','procedure','cuidados','performed_by',auth.uid(),'observed_at',to_char(clock_timestamp(),'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),'vial_id','00000000-0000-0000-0000-000000000405'),repeat('fa0$iteration',12));
SQL
 writer_pid=$!
 wait_lock 771155
 docker exec -e PGAPPNAME=vial-index-build -e PGOPTIONS='-c statement_timeout=20000' -i "$container_name" psql -U postgres -d "$test_database" -v ON_ERROR_STOP=1 < "$migration" > "$work_dir/index.log" 2>&1 &
 index_pid=$!
 active=false
 for attempt in {1..60};do
  if [ "$(docker exec "$container_name" psql -U postgres -d "$test_database" -Atc "select exists(select 1 from pg_stat_activity where datname='$test_database' and application_name='vial-index-build' and state='active' and query like '%CREATE INDEX CONCURRENTLY%')")" = t ];then active=true;break;fi
  sleep 0.1
 done
 if [ "$active" != true ];then cat "$work_dir/"*.log;echo 'Index build was not observed active';exit 1;fi
 # The writer's transaction still holds its marker while this particular index is active.
 if [ "$(docker exec "$container_name" psql -U postgres -d "$test_database" -Atc 'select pg_try_advisory_lock(771155)')" != f ];then echo 'Writer finished before index build began';exit 1;fi
 docker exec "$container_name" psql -U postgres -d "$test_database" -Atc "select pg_terminate_backend(pid) from pg_stat_activity where datname='$test_database' and application_name='vial-index-barrier'" > /dev/null
 wait "$barrier_pid" || true
 wait "$writer_pid" || { cat "$work_dir/write.log";exit 1; }
 wait "$index_pid" || { cat "$work_dir/index.log";exit 1; }
done
docker exec -i "$container_name" psql -U postgres -d "$test_database" -v ON_ERROR_STOP=1 <<'SQL'
do $$begin
 if private.rx_vial_balance('00000000-0000-0000-0000-000000000405')<>8 then raise exception 'Concurrent migration lost or duplicated draw';end if;
 if (select count(*) from public.medication_records where vial_id='00000000-0000-0000-0000-000000000405')<>2 then raise exception 'Concurrent migration lost or duplicated report';end if;
 if not (select count(*)=2 and bool_and(indisvalid and indisready) from pg_index where indexrelid in ('public.vial_movement_chronology'::regclass,'public.vial_record_incidents'::regclass)) then raise exception 'Concurrent indexes not ready and valid';end if;
end$$;
SQL
echo 'Each concurrent index overlapped an active medication writer; both completed without deadlock or duplicated draws.'

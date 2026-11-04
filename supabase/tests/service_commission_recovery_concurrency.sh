#!/usr/bin/env bash
set -euo pipefail
container_name="$1"
test_database="commission_recovery_race"
work_dir=$(mktemp -d)
docker exec "$container_name" createdb -U postgres -T postgres "$test_database"
trap 'docker exec "$container_name" dropdb -U postgres --force "$test_database" >/dev/null; rm -rf "$work_dir"' EXIT
docker exec -i "$container_name" psql -U postgres -d "$test_database" -v ON_ERROR_STOP=1 <<'SQL'
insert into public.inventory_sale_reversals(clinic_id,sale_id,shift_id,reason,created_by)
select s.clinic_id,s.sale_id,v.shift_id,'Synthetic concurrency reversal',s.recorded_by
from public.clinic_service_commission_settlements s join public.inventory_sales v on v.id=s.sale_id
where s.reference='SYNTHETIC-NO-RETURN';
SQL
pids=()
for operation in fa fb;do
 docker exec -i "$container_name" psql -U postgres -d "$test_database" -v ON_ERROR_STOP=1 > "$work_dir/$operation.log" 2>&1 <<SQL &
begin;
select clinic_id as clinic,id as settlement from public.clinic_service_commission_settlements where reference='SYNTHETIC-NO-RETURN' \gset
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000150',false);
set role authenticated;
select public.ops_commission_recovery(:'clinic',:'settlement','7','transferencia','RACE','Synthetic recovery race',repeat('$operation',24));
select pg_sleep(1);
commit;
SQL
 pids+=("$!")
done
success=0
for pid in "${pids[@]}";do
 if wait "$pid";then success=$((success+1));fi
done
if [ "$success" -ne 1 ] || ! grep -q 'recovery_exceeds_settlement' "$work_dir/"*.log;then
 cat "$work_dir/"*.log;exit 1
fi
docker exec -i "$container_name" psql -U postgres -d "$test_database" -v ON_ERROR_STOP=1 <<'SQL'
do $$begin
 if (select coalesce(sum(r.amount),0) from public.clinic_service_commission_recoveries r
 join public.clinic_service_commission_settlements s on s.id=r.settlement_id
 where s.reference='SYNTHETIC-NO-RETURN')<>7 then
 raise exception 'Concurrent recovery exceeded paid commission';end if;
end$$;
SQL
echo 'Concurrent recoveries cannot exceed the original paid commission.'

#!/usr/bin/env bash
set -euo pipefail
container_name="$1"
test_database="installment_races"
work_dir=$(mktemp -d)
docker exec "$container_name" createdb -U postgres -T postgres "$test_database"
trap 'docker exec "$container_name" dropdb -U postgres --force "$test_database" >/dev/null; rm -rf "$work_dir"' EXIT
for race in collection return;do
 seed=de
 if [ "$race" = return ];then seed=df;fi
 docker exec -i "$container_name" psql -U postgres -d "$test_database" -v ON_ERROR_STOP=1 > "$work_dir/setup.log" <<SQL
select id as shift from public.inventory_cash_shifts where cashier_id='00000000-0000-0000-0000-000000000150' and closed_at is null \\gset
select id as product from public.inventario where nombre='Synthetic partial return product' \\gset
select id as lot from public.lotes_inventario where lote='RETURN-LOT' \\gset
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000150',false);
set role authenticated;
select public.inv_sale_credit_post(:'shift','efectivo',jsonb_build_array(jsonb_build_object('kind','producto','item_id',:'product','lot_id',:'lot','quantity','1','price','10')),'10','0','Synthetic race debtor','00000000-0000-0000-0000-000000000150',repeat('${seed}00',12)) as sale \\gset
reset role;
drop table if exists public.synthetic_installment_race;
create table public.synthetic_installment_race as select :'sale'::uuid as sale, :'shift'::uuid as shift, id as line from public.inventory_sale_lines where sale_id=:'sale';
SQL
 pids=()
 for operation in aa bb;do
  action="select public.inv_sale_collect(:'sale',:'shift','7','efectivo','Synthetic race installment','00000000-0000-0000-0000-000000000150',repeat('$seed$operation',12));"
  if [ "$race" = return ] && [ "$operation" = bb ];then
   action="select public.inv_sale_return_v2(:'sale',:'shift',:'line','1','efectivo',false,'Synthetic race return','10','0','0','00000000-0000-0000-0000-000000000150',repeat('$seed$operation',12));"
  fi
  docker exec -i "$container_name" psql -U postgres -d "$test_database" -v ON_ERROR_STOP=1 > "$work_dir/$operation.log" 2>&1 <<SQL &
begin;
select * from public.synthetic_installment_race \\gset
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000150',false);
set role authenticated;
$action
select pg_sleep(1);
commit;
SQL
  pids+=("$!")
 done
 success=0
 for pid in "${pids[@]}";do if wait "$pid";then success=$((success+1));fi;done
 if [ "$success" -ne 1 ];then cat "$work_dir/"*.log;exit 1;fi
 docker exec -i "$container_name" psql -U postgres -d "$test_database" -v ON_ERROR_STOP=1 <<'SQL'
do $$declare sale uuid;clinic uuid;state jsonb;begin
 select r.sale,s.clinic_id into sale,clinic from public.synthetic_installment_race r join public.inventory_sales s on s.id=r.sale;
 state=private.sale_balance(sale,clinic);
 if (state->>'paid')::numeric-(state->>'refunded')::numeric>(state->>'net_total')::numeric then raise exception 'Concurrent installment overcollected';end if;
 if (select count(*) from public.inventory_sale_collections where sale_id=sale)+(select count(*) from public.inventory_sale_returns where sale_id=sale)<>1 then raise exception 'Race committed two incompatible operations';end if;
end$$;
SQL
done
echo 'Concurrent installments and returns preserve the account balance.'

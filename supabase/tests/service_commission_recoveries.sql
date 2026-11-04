create function pg_temp.recovery_assert(v boolean,msg text) returns void language plpgsql as $$
begin if v is distinct from true then raise exception 'ASSERT: %',msg;end if;end$$;
create function pg_temp.recovery_error(sql text,expected text) returns void language plpgsql as $$
begin begin execute sql;exception when others then if position(expected in sqlerrm)>0 then return;end if;raise;
end;raise exception 'Expected rejection: %',expected;end$$;
select id as clinic from public.clinics where name='Synthetic medication permissions' \gset
select id as settlement,service_act_id as act from public.clinic_service_commission_settlements where reference='SYNTHETIC' \gset
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000181',false);
set role authenticated;
select pg_temp.recovery_error(format('select public.ops_commission_recovery(%L,%L,%L,%L,%L,%L,%L)',:'clinic',:'settlement','10','efectivo','','Synthetic reason',repeat('a',48)),'admin_required');
select pg_temp.recovery_error('select count(*) from public.clinic_service_commission_recoveries','permission denied');
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000150',false);
set role authenticated;
select pg_temp.recovery_error(format('select public.ops_commission_recovery(%L,%L,%L,%L,%L,%L,%L)',:'clinic',:'settlement','26','efectivo','','Synthetic reason',repeat('a',48)),'recovery_exceeds_settlement');
select public.ops_commission_recovery(:'clinic',:'settlement','10','transferencia','SYNTHETIC-R1','Synthetic partial recovery',repeat('a',48)) as recovery \gset
select pg_temp.recovery_assert(public.ops_commission_recovery(:'clinic',:'settlement','10','transferencia','SYNTHETIC-R1','Synthetic partial recovery',repeat('a',48))=:'recovery'::uuid,'recovery retry duplicated');
select pg_temp.recovery_error(format('select public.ops_commission_recovery(%L,%L,%L,%L,%L,%L,%L)',:'clinic',:'settlement','11','transferencia','SYNTHETIC-R1','Synthetic partial recovery',repeat('a',48)),'operation_payload_changed');
select public.ops_commission_recovery(:'clinic',:'settlement','15','efectivo','SYNTHETIC-R2','Synthetic remaining recovery',repeat('b',48));
select pg_temp.recovery_error(format('select public.ops_commission_recovery(%L,%L,%L,%L,%L,%L,%L)',:'clinic',:'settlement','0.01','efectivo','','Synthetic excess',repeat('c',48)),'recovery_exceeds_settlement');
reset role;
select pg_temp.recovery_assert((select count(*)=2 and sum(amount)=25 from public.clinic_service_commission_recoveries),'partial recoveries lost precision');
select pg_temp.recovery_assert((select amount=25 from public.clinic_service_commission_settlements where id=:'settlement'),'original paid amount was changed');
select pg_temp.recovery_error(format('update public.clinic_service_commission_recoveries set amount=1 where id=%L',:'recovery'),'immutable');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000181',false);
set role authenticated;
select pg_temp.recovery_assert(exists(select 1 from jsonb_array_elements(public.ops_commission_account(:'clinic',200)->'items') x
 where x->>'id'=:'act' and x->>'recovered_amount'='25.00' and jsonb_array_length(x->'recoveries')=2),'worker cannot see own recovery history');
select pg_temp.recovery_error(format('select public.clinic_export(%L)',:'clinic'),'backup_export_required');
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000150',false);
set role authenticated;
select public.permission_grant(:'clinic','00000000-0000-0000-0000-000000000150','backup.export',null,clock_timestamp()+interval '1 day','Synthetic financial backup');
select pg_temp.recovery_assert(jsonb_array_length(public.clinic_export(:'clinic')::jsonb->'tables'->'clinic_service_commission_recoveries')=2,'recovery ledger absent from backup');
select pg_temp.recovery_assert(jsonb_array_length(public.clinic_export(:'clinic')::jsonb->'tables'->'clinic_service_commission_settlements')=1,'settlement ledger absent from backup');
reset role;
set role anon;
select pg_temp.recovery_error(format('select public.ops_commission_account(%L)',:'clinic'),'permission denied');
reset role;

-- A paid commission without a reversed sale cannot receive a recovery.
select id as service from public.clinic_services where clinic_id=:'clinic' and name='Synthetic surgery' \gset
insert into public.clinic_service_acts(clinic_id,service_id,professional_id,name,service_version,price,commission,commission_kind,commission_value,created_by)
values(:'clinic',:'service','00000000-0000-0000-0000-000000000181','Synthetic unreversed service',2,100,10,'bono',10,'00000000-0000-0000-0000-000000000150') returning id as live_act \gset
select shift_id as shift from public.inventory_sales where id=(select sale_id from public.clinic_service_commission_settlements where id=:'settlement') \gset
insert into public.inventory_sales(clinic_id,shift_id,cashier_id,method,total,cost,commission)
values(:'clinic',:'shift','00000000-0000-0000-0000-000000000150','efectivo',100,0,10) returning id as live_sale \gset
insert into public.inventory_sale_lines(sale_id,clinic_id,kind,name,quantity,stock_unit,price,cost,total,commission,professional_id,metadata,service_act_id)
values(:'live_sale',:'clinic','servicio','Synthetic unreversed service',1,'servicio',100,0,100,10,'00000000-0000-0000-0000-000000000181','{}',:'live_act');
set role authenticated;
select public.ops_commission_settle(:'clinic',:'live_act','transferencia','SYNTHETIC-NO-RETURN',repeat('d',48)) as live_settlement \gset
select pg_temp.recovery_error(format('select public.ops_commission_recovery(%L,%L,%L,%L,%L,%L,%L)',:'clinic',:'live_settlement','1','efectivo','','Synthetic unreturned',repeat('e',48)),'reversed_sale_required');
select pg_temp.recovery_error(format('select public.ops_commission_recovery(%L,%L,%L,%L,%L,%L,%L)',:'clinic',:'settlement','0','efectivo','','Synthetic zero',repeat('e',48)),'positive_amount_required');
reset role;

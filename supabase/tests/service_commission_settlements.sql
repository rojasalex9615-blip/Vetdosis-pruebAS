-- Runs after permission_clinic_operations.sql, using its synthetic clinic and staff.
create function pg_temp.assert_true(v boolean,msg text) returns void language plpgsql as $$begin if v is distinct from true then raise exception 'ASSERT: %',msg;end if;end$$;
create function pg_temp.expect_error(sql text,expected text) returns void language plpgsql as $$begin begin execute sql;exception when others then if position(expected in sqlerrm)>0 then return;end if;raise;end;raise exception 'Expected rejection: %',expected;end$$;
select id as clinic from public.clinics where name='Synthetic medication permissions' \gset
select id as service_id from public.clinic_services where clinic_id=:'clinic' and name='Synthetic surgery' \gset
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000150',false);set role authenticated;
select public.permission_grant(:'clinic','00000000-0000-0000-0000-000000000150','service.manage',null,clock_timestamp()+interval '1 day','Synthetic commission administration');
reset role;
insert into public.clinic_service_acts(clinic_id,service_id,professional_id,name,service_version,price,commission,commission_kind,commission_value,created_by)
values(:'clinic',:'service_id','00000000-0000-0000-0000-000000000181','Synthetic surgery',2,300,25,'bono',25,'00000000-0000-0000-0000-000000000150') returning id as act_id \gset
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000181',false);set role authenticated;
select pg_temp.assert_true(public.ops_commission_account(:'clinic')->>'outstanding'='0','uncashed service became payable');
select pg_temp.assert_true(public.ops_commission_account(:'clinic')->>'awaiting_collection'='25.00','uncashed service missing');
select pg_temp.expect_error(format('select public.ops_commission_settle(%L,%L,%L,%L,%L)',:'clinic',:'act_id','efectivo','',repeat('1',48)),'admin_required');
select pg_temp.expect_error('select count(*) from public.clinic_service_commission_settlements','permission denied');
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000150',false);set role authenticated;
select pg_temp.expect_error(format('select public.ops_commission_settle(%L,%L,%L,%L,%L)',:'clinic',:'act_id','efectivo','',repeat('2',48)),'sale_not_collected');
reset role;
select id as shift_id from public.inventory_cash_shifts
where clinic_id=:'clinic' and cashier_id='00000000-0000-0000-0000-000000000150'
and closed_at is null \gset
insert into public.inventory_sales(clinic_id,shift_id,cashier_id,method,total,cost,commission)
values(:'clinic',:'shift_id','00000000-0000-0000-0000-000000000150','efectivo',300,0,25) returning id as sale_id \gset
insert into public.inventory_sale_lines(sale_id,clinic_id,kind,name,quantity,stock_unit,price,cost,total,commission,professional_id,metadata,service_act_id)
values(:'sale_id',:'clinic','servicio','Synthetic surgery',1,'servicio',300,0,300,25,'00000000-0000-0000-0000-000000000181','{}'::jsonb,:'act_id');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000181',false);set role authenticated;
select pg_temp.assert_true(public.ops_commission_account(:'clinic')->>'outstanding'='25.00','collected commission missing');
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000150',false);set role authenticated;
select public.ops_commission_settle(:'clinic',:'act_id','transferencia','SYNTHETIC',repeat('3',48)) as settlement_id \gset
select pg_temp.assert_true(public.ops_commission_settle(:'clinic',:'act_id','transferencia','SYNTHETIC',repeat('3',48))=:'settlement_id'::uuid,'retry created a second settlement');
select pg_temp.expect_error(format('select public.ops_commission_settle(%L,%L,%L,%L,%L)',:'clinic',:'act_id','efectivo','',repeat('4',48)),'commission_already_settled');
select pg_temp.assert_true(public.ops_commission_account(:'clinic')->>'outstanding'='0','settled commission remains payable');
reset role;
insert into public.inventory_sale_reversals(clinic_id,sale_id,shift_id,reason,created_by)
values(:'clinic',:'sale_id',:'shift_id','Synthetic reversal','00000000-0000-0000-0000-000000000150');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000181',false);set role authenticated;
select pg_temp.assert_true(exists(select 1 from jsonb_array_elements(public.ops_commission_account(:'clinic')->'items') x
 where x->>'id'=:'act_id' and x->>'settlement_id'=:'settlement_id' and (x->>'sale_collected')::boolean=false),
 'reversal erased settlement history');
reset role;
select pg_temp.expect_error(format('update public.clinic_service_commission_settlements set amount=1 where id=%L',:'settlement_id'),'immutable');
insert into public.clinic_service_acts(clinic_id,service_id,professional_id,name,service_version,price,commission,commission_kind,commission_value,created_by)
select :'clinic',:'service_id','00000000-0000-0000-0000-000000000181','Synthetic bulk',2,300,1,'bono',1,'00000000-0000-0000-0000-000000000150'
from generate_series(1,201);
insert into auth.users(id,email,email_confirmed_at)
values('00000000-0000-0000-0000-000000000182','synthetic-commission-other@example.test',now());
insert into public.clinic_members(clinic_id,user_id,role)
values(:'clinic','00000000-0000-0000-0000-000000000182','mvz');
insert into public.clinic_service_acts(clinic_id,service_id,professional_id,name,service_version,price,commission,commission_kind,commission_value,created_by)
values(:'clinic',:'service_id','00000000-0000-0000-0000-000000000182','Other worker service',2,300,10,'bono',10,'00000000-0000-0000-0000-000000000150') returning id as other_act_id \gset
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000181',false);set role authenticated;
select pg_temp.assert_true(jsonb_array_length(public.ops_commission_account(:'clinic',0)->'items')=200,'first page size');
select pg_temp.assert_true(jsonb_array_length(public.ops_commission_account(:'clinic',200)->'items')=2,'older commissions inaccessible');
select pg_temp.assert_true(exists(select 1 from jsonb_array_elements(public.ops_commission_account(:'clinic',200)->'items') x
 where x->>'id'=:'act_id' and x->>'professional_name' is not null),'settled history missing after pagination');
select pg_temp.assert_true(not exists(select 1 from jsonb_array_elements(public.ops_commission_account(:'clinic',0)->'items') x
 where x->>'id'=:'other_act_id'),'another worker appeared in personal commission account');
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000150',false);set role authenticated;
select pg_temp.assert_true(exists(select 1 from jsonb_array_elements(public.ops_commission_account(:'clinic',0)->'items') x
 where x->>'id'=:'other_act_id'),'admin cannot see clinic worker');
reset role;
set role anon;
select pg_temp.expect_error(format('select public.ops_commission_account(%L)',:'clinic'),'permission denied');
reset role;

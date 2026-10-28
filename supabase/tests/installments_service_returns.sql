-- The earlier financial suites leave user 150 with one open shift and a product lot.
select id as clinic from public.clinics where name='Synthetic medication permissions' \gset
select id as shift from public.inventory_cash_shifts where clinic_id=:'clinic' and cashier_id='00000000-0000-0000-0000-000000000150' and closed_at is null \gset
select id as product from public.inventario where nombre='Synthetic partial return product' \gset
select id as lot from public.lotes_inventario where item_id=:'product' and lote='RETURN-LOT' \gset
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000150',false);
create function pg_temp.credit_assert(v boolean,msg text) returns void language plpgsql as $$begin if v is distinct from true then raise exception 'ASSERT: %',msg;end if;end$$;
create function pg_temp.credit_error(sql text,expected text) returns void language plpgsql as $$begin begin execute sql;exception when others then if position(expected in sqlerrm)>0 then return;end if;raise;end;raise exception 'Expected rejection: %',expected;end$$;
select private.inv_totals(:'clinic',:'shift',null,null) as before_totals \gset
set role authenticated;
select public.inv_sale_credit_post(:'shift','efectivo',jsonb_build_array(jsonb_build_object('kind','producto','item_id',:'product','lot_id',:'lot','quantity','3','price','10')),'30','5','Synthetic debtor','00000000-0000-0000-0000-000000000150',repeat('cb01',12)) as sale \gset
select pg_temp.credit_assert(public.inv_sale_credit_post(:'shift','efectivo',jsonb_build_array(jsonb_build_object('kind','producto','item_id',:'product','lot_id',:'lot','quantity','3','price','10')),'30.00','5.00','Synthetic debtor','00000000-0000-0000-0000-000000000150',repeat('cb01',12))=:'sale'::uuid,'credit retry created another sale');
select public.inv_sale_return_workspace(:'sale',:'shift')->'lines'->0->>'id' as line \gset
select public.inv_credit_accounts(:'clinic');
reset role;
select pg_temp.credit_assert((private.sale_balance(:'sale',:'clinic')->>'balance')::numeric=25,'initial credit balance');
select pg_temp.credit_assert((private.inv_totals(:'clinic',:'shift',null,null)->>'cash')::numeric=(:'before_totals'::jsonb->>'cash')::numeric+5,'sale total counted as cash');
select pg_temp.credit_assert((private.inv_totals(:'clinic',:'shift',null,null)->>'gross')::numeric=(:'before_totals'::jsonb->>'gross')::numeric+30,'credit revenue lost');
set role authenticated;
select public.inv_sale_collect(:'sale',:'shift','5','tarjeta','Synthetic installment','00000000-0000-0000-0000-000000000150',repeat('cb02',12)) as collection \gset
select pg_temp.credit_assert(public.inv_sale_collect(:'sale',:'shift','5.00','tarjeta','Synthetic installment','00000000-0000-0000-0000-000000000150',repeat('cb02',12))=:'collection'::uuid,'collection retry duplicated');
select public.inv_sale_return_v2(:'sale',:'shift',:'line','1','efectivo',false,'Synthetic balance reduction','10','0','0','00000000-0000-0000-0000-000000000150',repeat('cb03',12));
reset role;
select pg_temp.credit_assert((private.sale_balance(:'sale',:'clinic')->>'balance')::numeric=10,'return should reduce outstanding balance');
select pg_temp.credit_assert((private.inv_totals(:'clinic',:'shift',null,null)->>'cash')::numeric=(:'before_totals'::jsonb->>'cash')::numeric+5,'unpaid return removed cash');
set role authenticated;
select public.inv_sale_collect(:'sale',:'shift','10','transferencia','Synthetic final installment','00000000-0000-0000-0000-000000000150',repeat('cb04',12));
select pg_temp.credit_error(format('select public.inv_sale_collect(%L,%L,%L,%L,%L,%L,%L)',:'sale',:'shift','0.01','efectivo','Synthetic excess','00000000-0000-0000-0000-000000000150',repeat('cb05',12)),'collection_exceeds_balance');
select public.inv_sale_return_v2(:'sale',:'shift',:'line','1','tarjeta',true,'Synthetic paid return','10','10','0','00000000-0000-0000-0000-000000000150',repeat('cb06',12));
reset role;
select pg_temp.credit_assert((private.sale_balance(:'sale',:'clinic')->>'balance')::numeric=0,'paid refund created debt');
select pg_temp.credit_assert((private.sale_balance(:'sale',:'clinic')->>'refunded')::numeric=10,'refund did not match excess collected');
set role authenticated;
select pg_temp.credit_error(format('select public.inv_sale_reverse(%L,%L,%L,%L)',:'sale',:'shift','Synthetic credit full reverse',repeat('cb07',12)),'credit_sale_use_line_returns');
select public.inv_shift_snapshot(:'shift');
select public.clinic_export(:'clinic');
reset role;
select id as service from public.clinic_services where clinic_id=:'clinic' and name='Synthetic surgery' \gset
insert into public.clinic_service_acts(clinic_id,service_id,professional_id,name,service_version,price,commission,commission_kind,commission_value,created_by)
values(:'clinic',:'service','00000000-0000-0000-0000-000000000181','Synthetic installment service',2,300,25,'bono',25,'00000000-0000-0000-0000-000000000150') returning id as act \gset
set role authenticated;
select public.inv_sale_credit_post(:'shift','efectivo',jsonb_build_array(
 jsonb_build_object('kind','producto','item_id',:'product','lot_id',:'lot','quantity','1','price','10'),
 jsonb_build_object('kind','servicio','service_act_id',:'act','quantity','1','price','300')),
 '310','100','Synthetic mixed debtor','00000000-0000-0000-0000-000000000150',repeat('cc01',12)) as mixed_sale \gset
select e->>'id' as service_line from jsonb_array_elements(public.inv_sale_return_workspace(:'mixed_sale',:'shift')->'lines') e where e->>'kind'='servicio' \gset
select public.inv_sale_return_v2(:'mixed_sale',:'shift',:'service_line','0.5','efectivo',false,'Synthetic partial service credit','150','0','12.50','00000000-0000-0000-0000-000000000150',repeat('cc02',12));
select pg_temp.credit_error(format('select public.ops_commission_settle(%L,%L,%L,%L,%L)',:'clinic',:'act','transferencia','Synthetic unpaid commission',repeat('cc03',12)),'sale_not_collected');
select pg_temp.credit_error(format('select public.inv_sale_return_v2(%L,%L,%L,%L,%L,true,%L,%L,%L,%L,%L,%L)',:'mixed_sale',:'shift',:'service_line','0.5','efectivo','Synthetic invalid restock','150','0','12.50','00000000-0000-0000-0000-000000000150',repeat('cc04',12)),'service_restock_denied');
select public.inv_sale_collect(:'mixed_sale',:'shift','60','transferencia','Synthetic mixed paid','00000000-0000-0000-0000-000000000150',repeat('cc05',12));
select public.ops_commission_settle(:'clinic',:'act','transferencia','SYNTHETIC-NET-COMMISSION',repeat('cc06',12)) as settlement \gset
reset role;
select pg_temp.credit_assert((select amount=12.50 from public.clinic_service_commission_settlements where id=:'settlement'),'commission paid before adjustment');
select pg_temp.credit_assert((select commission=25 from public.clinic_service_acts where id=:'act'),'original commission overwritten');
set role authenticated;
select public.inv_sale_return_v2(:'mixed_sale',:'shift',:'service_line','0.25','tarjeta',false,'Synthetic refund after commission paid','75','75','6.25','00000000-0000-0000-0000-000000000150',repeat('cc07',12));
select pg_temp.credit_error(format('select public.ops_commission_recovery(%L,%L,%L,%L,%L,%L,%L)',:'clinic',:'settlement','6.26','transferencia','Synthetic excess','Synthetic adjustment',repeat('cc08',12)),'recovery_exceeds_settlement');
select public.ops_commission_recovery(:'clinic',:'settlement','6.25','transferencia','SYNTHETIC-PARTIAL-RECOVERY','Synthetic proportional recovery',repeat('cc09',12));
select public.ops_commission_account(:'clinic');
reset role;
select pg_temp.credit_assert(private.commission_recovery_limit(:'settlement',:'clinic')=6.25,'partial recovery cap');
select pg_temp.credit_assert((select sum(amount)=6.25 from public.clinic_service_commission_recoveries where settlement_id=:'settlement'),'partial recovery missing');
select pg_temp.credit_assert((select amount=12.50 from public.clinic_service_commission_settlements where id=:'settlement'),'original commission payment rewritten');
set role authenticated;
select pg_temp.credit_error('select count(*) from public.inventory_sale_collections','permission denied');
select pg_temp.credit_error('select count(*) from public.inventory_credit_accounts','permission denied');
reset role;
set role anon;
select pg_temp.credit_error(format('select public.inv_credit_accounts(%L)',:'clinic'),'permission denied');
reset role;
-- Freeze the credit-era cut, then collect in a later shift without changing history.
set role authenticated;
select public.inv_shift_snapshot(:'shift')->>'expected_cash' as expected_cash \gset
select public.inv_shift_close(:'shift',:'expected_cash','',repeat('cd01',12));
reset role;
select snapshot as frozen_cut from public.inventory_cash_shifts where id=:'shift' \gset
set role authenticated;
select public.inv_shift_open(:'clinic','20',repeat('cd02',12)) as later_shift \gset
-- Complete the last unreturned product unit; the earlier account is already paid.
select public.inv_sale_return_v2(:'sale',:'later_shift',:'line','1','efectivo',false,'Synthetic later-shift refund','10','10','0','00000000-0000-0000-0000-000000000150',repeat('cd03',12));
reset role;
select pg_temp.credit_assert((select snapshot=:'frozen_cut'::jsonb from public.inventory_cash_shifts where id=:'shift'),'later refund changed closed cut');
select pg_temp.credit_assert((private.inv_totals(:'clinic',:'later_shift',null,null)->>'cash')::numeric=-10,'later refund absent from current cash');
select pg_temp.credit_assert((private.inv_totals(:'clinic',:'later_shift',null,null)->>'gross')::numeric=-10,'later credit absent from current sales');
select pg_temp.credit_assert((private.sale_balance(:'sale',:'clinic')->>'net_total')::numeric=0,'fully returned credit still has principal');
select pg_temp.credit_assert(not private.sale_fully_collected(:'sale',:'clinic'),'fully returned credit marked payable');
-- RLS and function ACLs are separate controls, both required.
select pg_temp.credit_assert(not has_function_privilege('anon','public.inv_sale_collect(uuid,uuid,text,text,text,uuid,text)','EXECUTE'),'anonymous collection callable');
select pg_temp.credit_assert(not has_function_privilege('authenticated','private.sale_balance(uuid,uuid)','EXECUTE'),'private balance callable');
select pg_temp.credit_assert((select bool_and(relrowsecurity) from pg_class where oid in ('public.inventory_credit_accounts'::regclass,'public.inventory_sale_collections'::regclass)),'financial tables lack RLS');
select pg_temp.credit_assert(not exists(select 1 from public.inventory_sales s where
 exists(select 1 from public.inventory_sale_lines l left join public.inventario i on i.id=l.item_id
 where l.sale_id=s.id and (i.m8_kind='farmaco' or l.prescription_item_id is not null or l.application_charge_id is not null or l.delivery_ticket_id is not null))
 and private.sale_return_eligible(s.id,s.clinic_id)), 'medication or clinical charge accepted by return scope');
select pg_temp.credit_error(format('update public.inventory_credit_accounts set debtor=%L where sale_id=%L','Changed',:'sale'),'immutable');
select pg_temp.credit_error(format('update public.inventory_sale_collections set amount=1 where id=%L',:'collection'),'immutable');
-- Catalog prices and service costs use the same credit/refund contract.
select private.inv_totals(:'clinic',:'later_shift',null,null) as before_catalog \gset
select version as service_version,price as original_price from public.clinic_services where id=:'service' \gset
set role authenticated;
select public.permission_grant(:'clinic',auth.uid(),'sales.manual',null,clock_timestamp()+interval '1 day','Synthetic catalog credit');
select public.inv_sale_credit_post(:'later_shift','efectivo',jsonb_build_array(jsonb_build_object('kind','servicio','catalog_service_id',:'service','catalog_service_version',:'service_version','catalog_price_mode','solo_venta','quantity','1','price','100','cost','15')),'100','20','Synthetic catalog debtor','00000000-0000-0000-0000-000000000150',repeat('ce01',12)) as catalog_sale \gset
select public.inv_sale_return_workspace(:'catalog_sale',:'later_shift')->'lines'->0->>'id' as catalog_line \gset
select public.inv_sale_return_v2(:'catalog_sale',:'later_shift',:'catalog_line','1','efectivo',false,'Synthetic full service credit','100','20','0','00000000-0000-0000-0000-000000000150',repeat('ce02',12));
reset role;
select pg_temp.credit_assert((private.inv_totals(:'clinic',:'later_shift',null,null)->>'cost')::numeric=(:'before_catalog'::jsonb->>'cost')::numeric+15,'refund erased performed service costs');
select pg_temp.credit_assert((select price=:'original_price'::numeric from public.clinic_services where id=:'service'),'one-sale credit changed catalog price');
-- An actor mismatch is rejected before looking up the account.
set role authenticated;
select pg_temp.credit_error(format('select public.inv_sale_collect(%L,%L,%L,%L,%L,%L,%L)',:'catalog_sale',:'later_shift','1','efectivo','Synthetic actor mismatch','00000000-0000-0000-0000-000000000181',repeat('ce03',12)),'session_changed');
reset role;
select sale_id as legacy_service_sale from public.clinic_service_commission_settlements where reference='SYNTHETIC-NO-RETURN' \gset
set role authenticated;
select pg_temp.credit_error(format('select public.inv_sale_reverse(%L,%L,%L,%L)',:'legacy_service_sale',:'later_shift','Synthetic service reverse must use line returns',repeat('ce04',12)),'service_sale_use_line_returns');
reset role;

-- Synthetic regression coverage for CodeRabbit #44/#45/#46 corrections.
select id as clinic from public.clinics where name='Synthetic medication permissions' \gset
select id as shift from public.inventory_cash_shifts where clinic_id=:'clinic' and cashier_id='00000000-0000-0000-0000-000000000150' and closed_at is null \gset
select id as product from public.inventario where nombre='Synthetic partial return product' \gset
select id as lot from public.lotes_inventario where item_id=:'product' and lote='RETURN-LOT' \gset
create function pg_temp.check_financial(v boolean,msg text) returns void language plpgsql as $$begin if v is distinct from true then raise exception 'ASSERT: %',msg;end if;end$$;
create function pg_temp.expect_financial(sql text,expected text) returns void language plpgsql as $$begin begin execute sql;exception when others then if position(expected in sqlerrm)>0 then return;end if;raise;end;raise exception 'Expected rejection: %',expected;end$$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000150',false);
set role authenticated;
select public.inv_sale_post(:'shift','efectivo',jsonb_build_array(jsonb_build_object('kind','producto','item_id',:'product','lot_id',:'lot','quantity','3','price','10')),'30',repeat('ed01',12)) as sale \gset
select public.inv_sale_return_workspace(:'sale',:'shift') as workspace \gset
select pg_temp.check_financial((:'workspace'::jsonb->>'schema_version')::integer=3,'workspace contract not v3');
select :'workspace'::jsonb->'lines'->0->>'id' as line \gset
select public.inv_sale_return_v3(:'sale',:'shift',:'line','1','efectivo',false,'Synthetic first refund','10','10','0','00000000-0000-0000-0000-000000000150',repeat('ed02',12),'0') as receipt \gset
select pg_temp.check_financial(public.inv_sale_return_v3(:'sale',:'shift',:'line','1','efectivo',false,'Synthetic first refund','10','10','0','00000000-0000-0000-0000-000000000150',repeat('ed02',12),'0')=:'receipt'::uuid,'lost response duplicated refund');
select pg_temp.expect_financial(format('select public.inv_sale_return_v3(%L,%L,%L,%L,%L,false,%L,%L,%L,%L,%L,%L,%L)',:'sale',:'shift',:'line','1','tarjeta','Changed reason same amount','10','10','0','00000000-0000-0000-0000-000000000150',repeat('ed03',12),'0'),'return_workspace_changed');
select public.inv_sale_return_v3(:'sale',:'shift',:'line','1','tarjeta',false,'Fresh confirmed second refund','10','10','0','00000000-0000-0000-0000-000000000150',repeat('ed04',12),'1');
select pg_temp.expect_financial(format('select public.inv_sale_return_v2(%L,%L,%L,%L,%L,false,%L,%L,%L,%L,%L,%L)',:'sale',:'shift',:'line','1','efectivo','Legacy new request','10','10','0','00000000-0000-0000-0000-000000000150',repeat('ed05',12)),'return_client_upgrade_required');
reset role;
select pg_temp.check_financial((select count(*)=2 and sum(refund_amount)=20 from public.inventory_sale_returns where sale_id=:'sale'),'stale snapshot created extra cash movement');
-- Historical successful v1 and v2 receipts must still be replayable, even after closure.
do $$declare r record;result uuid;begin
 for r in select * from private.vet_operation_receipts where user_id=auth.uid() and fingerprint->>'kind' in ('partial_product_return','partial_sale_return_v2') loop
  if r.fingerprint->>'kind'='partial_product_return' then
   result=public.inv_sale_return((r.fingerprint->>'sale')::uuid,(r.fingerprint->>'shift')::uuid,(r.fingerprint->>'line')::uuid,r.fingerprint->>'quantity',r.fingerprint->>'method',(r.fingerprint->>'restock')::boolean,r.fingerprint->>'reason',r.fingerprint->>'amount',auth.uid(),r.operation_id);
  else
   result=public.inv_sale_return_v2((r.fingerprint->>'sale')::uuid,(r.fingerprint->>'shift')::uuid,(r.fingerprint->>'line')::uuid,r.fingerprint->>'quantity',r.fingerprint->>'method',(r.fingerprint->>'restock')::boolean,r.fingerprint->>'reason',r.fingerprint->>'amount',r.fingerprint->>'refund',r.fingerprint->>'commission',auth.uid(),r.operation_id);
  end if;
  perform pg_temp.check_financial(result=r.entity_id,'legacy receipt changed');
 end loop;
end$$;
-- Fractional quantities distribute a single cent cumulatively, including restored cost.
set role authenticated;
select public.inv_product_save(:'clinic',null,0,'{"name":"Synthetic rounding regression","presentation":"Gram","kind":"producto","unit":"g","price":"0.01","cost":"0.03","minimum":"0","reorder":"0"}',repeat('ed10',12)) as round_product \gset
select public.inv_lot_receive(:'round_product','ROUNDING',current_date+90,'1','0.03',repeat('ed11',12)) as round_lot \gset
select public.inv_sale_post(:'shift','efectivo',jsonb_build_array(jsonb_build_object('kind','producto','item_id',:'round_product','lot_id',:'round_lot','quantity','1','price','0.01')),'0.01',repeat('ed12',12)) as round_sale \gset
select public.inv_sale_return_workspace(:'round_sale',:'shift')->'lines'->0->>'id' as round_line \gset
select public.inv_sale_return_v3(:'round_sale',:'shift',:'round_line','0.34','efectivo',true,'Fraction one','0','0','0','00000000-0000-0000-0000-000000000150',repeat('ed13',12),'0');
select public.inv_sale_return_v3(:'round_sale',:'shift',:'round_line','0.33','efectivo',true,'Fraction two','0.01','0.01','0','00000000-0000-0000-0000-000000000150',repeat('ed14',12),'0.34');
select public.inv_sale_return_v3(:'round_sale',:'shift',:'round_line','0.33','efectivo',true,'Fraction three','0','0','0','00000000-0000-0000-0000-000000000150',repeat('ed15',12),'0.67');
reset role;
select pg_temp.check_financial((select sum(amount)=0.01 and sum(refund_amount)=0.01 and sum(cost)=0.03 from public.inventory_sale_returns where sale_id=:'round_sale'),'fractional return created money or lost cost');
select pg_temp.check_financial((select cantidad=1 from public.lotes_inventario where id=:'round_lot'),'fractional restock wrong');
-- The response as well as storage of a closed cut must remain frozen after a later return.
set role authenticated;
select public.inv_shift_snapshot(:'shift')->>'expected_cash' as counted \gset
select public.inv_shift_close(:'shift',:'counted','',repeat('ed20',12));
select public.inv_shift_snapshot(:'shift')-'live_sale_actions' as frozen \gset
select public.inv_shift_open(:'clinic','100',repeat('ed21',12)) as later_shift \gset
select public.inv_sale_return_v3(:'sale',:'later_shift',:'line','1','efectivo',false,'Later return','10','10','0','00000000-0000-0000-0000-000000000150',repeat('ed22',12),'2');
select pg_temp.check_financial(public.inv_shift_snapshot(:'shift')-'live_sale_actions'=:'frozen'::jsonb,'closed financial response changed');
reset role;
select pg_temp.check_financial(not has_function_privilege('anon','public.inv_sale_return_v3(uuid,uuid,uuid,text,text,boolean,text,text,text,text,uuid,text,text)','EXECUTE'),'anonymous return permitted');
-- Imported historical product line without a lot fails before altering stock.
insert into public.inventory_sales(clinic_id,shift_id,cashier_id,method,total,cost,commission)
values(:'clinic',:'later_shift',auth.uid(),'efectivo',10,2,0) returning id as imported_sale \gset
insert into public.inventory_sale_lines(sale_id,clinic_id,kind,item_id,name,quantity,stock_unit,price,cost,total,metadata)
values(:'imported_sale',:'clinic','producto',:'product','Synthetic legacy lotless line',1,'unidad',10,2,10,'{}') returning id as imported_line \gset
select stock as before_stock from public.inventario where id=:'product' \gset
set role authenticated;
select pg_temp.expect_financial(format('select public.inv_sale_return_v3(%L,%L,%L,%L,%L,true,%L,%L,%L,%L,%L,%L,%L)',:'imported_sale',:'later_shift',:'imported_line','1','efectivo','Legacy lotless restock','10','10','0','00000000-0000-0000-0000-000000000150',repeat('ed30',12),'0'),'return_lot_required');
reset role;
select pg_temp.check_financial((select stock=:'before_stock'::numeric from public.inventario where id=:'product'),'lotless rejection changed stock');
-- Imported line with a valid lot but no unit_cost metadata uses lot cost.
insert into public.inventory_sales(clinic_id,shift_id,cashier_id,method,total,cost,commission)
values(:'clinic',:'later_shift',auth.uid(),'efectivo',10,2,0) returning id as fallback_sale \gset
insert into public.inventory_sale_lines(sale_id,clinic_id,kind,item_id,lot_id,name,quantity,stock_unit,price,cost,total,metadata)
values(:'fallback_sale',:'clinic','producto',:'product',:'lot','Synthetic legacy costless metadata',1,'unidad',10,2,10,'{}') returning id as fallback_line \gset
update public.inventario set stock=stock-1 where id=:'product';
update public.lotes_inventario set cantidad=cantidad-1 where id=:'lot';
set role authenticated;
select public.inv_sale_return_v3(:'fallback_sale',:'later_shift',:'fallback_line','1','efectivo',true,'Fallback unit cost','10','10','0','00000000-0000-0000-0000-000000000150',repeat('ed31',12),'0') as fallback_return \gset
reset role;
select pg_temp.check_financial((select unit_cost=2 from public.inventory_stock_movements where source_id=:'fallback_return'),'missing metadata lost source lot cost');
-- Service financial workspace needs both admin role and explicit service permission.
select id as mixed_sale from public.inventory_sales s where s.clinic_id=:'clinic' and private.sale_return_eligible(s.id,s.clinic_id) and exists(select 1 from public.inventory_sale_lines l where l.sale_id=s.id and l.kind='servicio') limit 1 \gset
set role authenticated;
select public.permission_grant(:'clinic','00000000-0000-0000-0000-000000000181','inventory.read',null,clock_timestamp()+interval '1 day','Synthetic service privacy');
select public.permission_grant(:'clinic','00000000-0000-0000-0000-000000000181','sales.collect',null,clock_timestamp()+interval '1 day','Synthetic service privacy');
select public.permission_grant(:'clinic','00000000-0000-0000-0000-000000000181','sales.reverse',null,clock_timestamp()+interval '1 day','Synthetic service privacy');
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000181',false);
set role authenticated;
select public.inv_shift_open(:'clinic','0',repeat('ed40',12)) as staff_shift \gset
select pg_temp.expect_financial(format('select public.inv_sale_return_workspace(%L,%L)',:'mixed_sale',:'staff_shift'),'admin_required');
reset role;
select id as mixed_line from public.inventory_sale_lines where sale_id=:'mixed_sale' limit 1 \gset
set role authenticated;
select pg_temp.expect_financial(format('select public.inv_sale_return_v3(%L,%L,%L,%L,%L,false,%L,%L,%L,%L,%L,%L,%L)',:'mixed_sale',:'staff_shift',:'mixed_line','1','efectivo','Nonadmin service request','0','0','0','00000000-0000-0000-0000-000000000181',repeat('ed41',12),'0'),'admin_required');
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000150',false);
-- Public RPCs fail closed for pharmaceutical lines (including mixed service sales).
select id as drug from public.inventario where clinic_id=:'clinic' and m8_kind='farmaco' limit 1 \gset
insert into public.inventory_sales(clinic_id,shift_id,cashier_id,method,total,cost,commission)
values(:'clinic',:'later_shift',auth.uid(),'efectivo',10,0,0) returning id as drug_sale \gset
insert into public.inventory_sale_lines(sale_id,clinic_id,kind,item_id,name,quantity,stock_unit,price,cost,total,metadata)
values(:'drug_sale',:'clinic','producto',:'drug','Synthetic excluded pharmaceutical',1,'unidad',10,0,10,'{}') returning id as drug_line \gset
set role authenticated;
select pg_temp.expect_financial(format('select public.inv_sale_return_workspace(%L,%L)',:'drug_sale',:'later_shift'),'non_medication_sale_required');
select pg_temp.expect_financial(format('select public.inv_sale_return_v3(%L,%L,%L,%L,%L,false,%L,%L,%L,%L,%L,%L,%L)',:'drug_sale',:'later_shift',:'drug_line','1','efectivo','Excluded drug refund','10','10','0',auth.uid(),repeat('ed50',12),'0'),'non_medication_sale_required');
reset role;
insert into public.inventory_sale_lines(sale_id,clinic_id,kind,name,quantity,stock_unit,price,cost,total,metadata)
values(:'drug_sale',:'clinic','servicio','Synthetic excluded mixed service',1,'servicio',0,0,0,'{}');
set role authenticated;
select pg_temp.expect_financial(format('select public.inv_sale_return_workspace(%L,%L)',:'drug_sale',:'later_shift'),'non_medication_sale_required');
select pg_temp.expect_financial(format('select public.inv_sale_return_v3(%L,%L,%L,%L,%L,false,%L,%L,%L,%L,%L,%L,%L)',:'drug_sale',:'later_shift',:'drug_line','1','efectivo','Excluded mixed refund','10','10','0',auth.uid(),repeat('ed51',12),'0'),'non_medication_sale_required');
reset role;
-- A service with only reversed sales must not remain awaiting collection.
select pg_temp.check_financial((select count(*)>0 and bool_and(private.service_commission_net(a.id,a.clinic_id)=0)
 from public.clinic_service_acts a where a.clinic_id=:'clinic'
 and exists(select 1 from public.inventory_sale_lines l where l.service_act_id=a.id and l.clinic_id=a.clinic_id)
 and not exists(select 1 from public.inventory_sale_lines l where l.service_act_id=a.id and l.clinic_id=a.clinic_id
  and not exists(select 1 from public.inventory_sale_reversals r where r.sale_id=l.sale_id and r.clinic_id=l.clinic_id))),
 'fully reversed service still has a net commission');

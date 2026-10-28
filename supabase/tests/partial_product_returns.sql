create function pg_temp.return_assert(v boolean,msg text) returns void language plpgsql as $$begin if v is distinct from true then raise exception 'ASSERT: %',msg;end if;end$$;
create function pg_temp.return_error(sql text,expected text) returns void language plpgsql as $$begin begin execute sql;exception when others then if position(expected in sqlerrm)>0 then return;end if;raise;end;raise exception 'Expected rejection: %',expected;end$$;
select id as clinic from public.clinics where name='Synthetic medication permissions' \gset
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000150',false);
do $$declare code text;clinic uuid;begin
 select id into clinic from public.clinics where name='Synthetic medication permissions';
 foreach code in array array['inventory.manage','inventory.receive','sales.collect','sales.reverse','sales.read'] loop
  if private.permission_effective(clinic,auth.uid(),code) is null then
   perform public.permission_grant(clinic,auth.uid(),code,null,clock_timestamp()+interval '1 day','Synthetic partial return permissions');
  end if;
 end loop;
end$$;
select private.inv_totals(:'clinic',null,null,null) as original_totals \gset
select id as shift from public.inventory_cash_shifts where clinic_id=:'clinic' and cashier_id='00000000-0000-0000-0000-000000000150' and closed_at is null \gset
set role authenticated;
select public.inv_product_save(:'clinic',null,0,'{"name":"Synthetic partial return product","presentation":"Unit","kind":"producto","unit":"unidad","price":"10","cost":"2","minimum":"0","reorder":"0"}',repeat('ca01',12)) as product \gset
select public.inv_lot_receive(:'product','RETURN-LOT',current_date+90,'10','2',repeat('ca02',12)) as lot \gset
select public.inv_sale_post(:'shift','efectivo',jsonb_build_array(jsonb_build_object('kind','producto','item_id',:'product','lot_id',:'lot','quantity','3','price','10')),'30',repeat('ca03',12)) as sale \gset
select public.inv_sale_return_workspace(:'sale',:'shift')->'lines'->0->>'id' as line \gset
select public.inv_sale_return(:'sale',:'shift',:'line','1','efectivo',true,'Synthetic usable return','10','00000000-0000-0000-0000-000000000150',repeat('ca04',12)) as first_return \gset
select pg_temp.return_assert(public.inv_sale_return(:'sale',:'shift',:'line','1','efectivo',true,'Synthetic usable return','10','00000000-0000-0000-0000-000000000150',repeat('ca04',12))=:'first_return'::uuid,'retry duplicated a refund');
select pg_temp.return_error(format('select public.inv_sale_reverse(%L,%L,%L,%L)',:'sale',:'shift','Synthetic full reversal',repeat('ca05',12)),'sale_has_partial_returns');
select pg_temp.return_error(format('select public.inv_sale_return(%L,%L,%L,%L,%L,true,%L,%L,%L,%L)',:'sale',:'shift',:'line','3','efectivo','Synthetic excess','30','00000000-0000-0000-0000-000000000150',repeat('ca05',12)),'return_exceeds_sold_quantity');
select pg_temp.return_error(format('select public.inv_sale_return(%L,%L,%L,%L,%L,false,%L,%L,%L,%L)',:'sale',:'shift',:'line','1','efectivo','Synthetic stale quote','9.99','00000000-0000-0000-0000-000000000150',repeat('ca10',12)),'return_amount_changed');
select pg_temp.return_error(format('select public.inv_sale_return(%L,%L,%L,%L,%L,false,%L,%L,%L,%L)',:'sale',:'shift',:'line','1','efectivo','Synthetic changed actor','10','00000000-0000-0000-0000-000000000151',repeat('ca11',12)),'session_changed');
select public.inv_shift_snapshot(:'shift')->>'expected_cash' as counted \gset
select public.inv_shift_close(:'shift',:'counted','',repeat('ca06',12));
reset role;
select snapshot as frozen from public.inventory_cash_shifts where id=:'shift' \gset
select pg_temp.return_assert((select cantidad=8 from public.lotes_inventario where id=:'lot'),'restock did not restore one unit');
set role authenticated;
select public.inv_shift_open(:'clinic','100',repeat('ca07',12)) as new_shift \gset
select public.inv_sale_return(:'sale',:'new_shift',:'line','1','transferencia',false,'Synthetic unusable return','10','00000000-0000-0000-0000-000000000150',repeat('ca08',12));
select public.inv_sale_return(:'sale',:'new_shift',:'line','1','tarjeta',true,'Synthetic last return','10','00000000-0000-0000-0000-000000000150',repeat('ca09',12));
select pg_temp.return_assert(public.inv_shift_snapshot(:'new_shift')->'totals'->>'gross'='-20.00','refund shift net total wrong');
select pg_temp.return_assert((public.inv_shift_snapshot(:'new_shift')->'totals'->>'transfer')::numeric=-10,'transfer refund recorded as cash');
select pg_temp.return_assert((public.inv_shift_snapshot(:'new_shift')->>'expected_cash')::numeric=100,'noncash refunds altered cash');
select pg_temp.return_assert(jsonb_array_length(public.inv_shift_snapshot(:'new_shift')->'partial_returns')=2,'cut omitted refunds');
select pg_temp.return_assert(jsonb_array_length(public.clinic_export(:'clinic')::jsonb->'tables'->'inventory_sale_returns')=3,'refunds absent from backup');
select public.inv_dashboard(:'clinic');
select public.inv_ai_insights(:'clinic');
select public.clinic_statistics(:'clinic');
select pg_temp.return_error('select count(*) from public.inventory_sale_returns','permission denied');
reset role;
select pg_temp.return_assert((select snapshot=:'frozen'::jsonb from public.inventory_cash_shifts where id=:'shift'),'closed cut was changed');
select pg_temp.return_assert((select cantidad=9 from public.lotes_inventario where id=:'lot'),'unusable item reentered stock');
select pg_temp.return_assert((select sum(amount)=30 and sum(cost)=4 from public.inventory_sale_returns where sale_id=:'sale'),'refund or restocked cost total wrong');
select pg_temp.return_assert((private.inv_totals(:'clinic',null,null,null)->>'gross')::numeric=(:'original_totals'::jsonb->>'gross')::numeric,'net gross changed after full refund');
select pg_temp.return_assert((private.inv_totals(:'clinic',null,null,null)->>'cost')::numeric=(:'original_totals'::jsonb->>'cost')::numeric+2,'unusable goods cost was erased');
select pg_temp.return_assert((private.inv_totals(:'clinic',null,null,null)->>'sale_count')::integer=(:'original_totals'::jsonb->>'sale_count')::integer,'fully refunded ticket still counted');
set role anon;
select pg_temp.return_error(format('select public.inv_sale_return_workspace(%L,%L)',:'sale',:'new_shift'),'permission denied');
reset role;
select pg_temp.return_assert(not exists(
 select 1 from public.inventory_sales s where
 exists(select 1 from public.inventory_sale_lines l left join public.inventario i on i.id=l.item_id
 where l.sale_id=s.id and (l.kind<>'producto' or i.m8_kind='farmaco'))
 and private.sale_return_eligible(s.id,s.clinic_id)), 'service or medication sale eligible for partial product return');

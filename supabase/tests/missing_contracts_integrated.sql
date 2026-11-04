create function pg_temp.return_assert(v boolean,msg text) returns void language plpgsql as $$begin if v is distinct from true then raise exception 'ASSERT: %',msg;end if;end$$;
create function pg_temp.return_error(sql text,expected text) returns void language plpgsql as $$begin begin execute sql;exception when others then if position(expected in sqlerrm)>0 then return;end if;raise;end;raise exception 'Expected rejection: %',expected;end$$;
select id as clinic from public.clinics where name='Synthetic medication permissions' \gset
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000150',false);
do $$declare code text;clinic uuid;begin
 select id into clinic from public.clinics where name='Synthetic medication permissions';
 foreach code in array array['inventory.manage','inventory.receive','sales.collect','sales.reverse','sales.read','service.manage'] loop
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

reset role;

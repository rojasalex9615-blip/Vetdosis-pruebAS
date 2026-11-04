-- Candidate after installments/services. Legacy returns replay only; fresh requests use v3.
begin;
create or replace function public.inv_sale_return_workspace(p_sale uuid,p_shift uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare sh public.inventory_cash_shifts;begin
 select * into sh from public.inventory_cash_shifts where id=p_shift;
 perform private.hospital_order_permission(sh.clinic_id,'sales.collect',null,false);
 if sh.cashier_id is distinct from auth.uid() or sh.closed_at is not null then raise exception 'own_open_shift_required';end if;
 if not private.inventory_current(sh.clinic_id,'sales.reverse') then raise exception 'explicit_permission_required';end if;
 if not private.sale_return_eligible(p_sale,sh.clinic_id) then raise exception 'non_medication_sale_required';end if;
 if exists(select 1 from public.inventory_sale_lines where sale_id=p_sale and clinic_id=sh.clinic_id and kind='servicio') then
  if not private.has_clinic_role(sh.clinic_id,array['admin']) then raise exception 'admin_required';end if;
  if not private.ops_permission_active(sh.clinic_id,'service.manage') then raise exception 'explicit_permission_required';end if;
 end if;
 return jsonb_build_object('schema_version',3,'clinic_id',sh.clinic_id,'actor_id',auth.uid(),
 'account',private.sale_balance(p_sale,sh.clinic_id),'lines',
 (select jsonb_agg(jsonb_build_object('id',l.id,'kind',l.kind,'name',case when l.service_act_id is not null and not private.inventory_clinical_read(sh.clinic_id) then 'Servicio registrado' else l.name end,'lot',l.lot,'unit',l.stock_unit,
 'quantity',l.quantity::text,'total',l.total::text,'commission',l.commission::text,
 'returned_quantity',(select coalesce(sum(r.quantity),0)::text from public.inventory_sale_returns r where r.clinic_id=sh.clinic_id and r.line_id=l.id),
 'returned_amount',(select coalesce(sum(r.amount),0)::text from public.inventory_sale_returns r where r.clinic_id=sh.clinic_id and r.line_id=l.id),
 'returned_commission',(select coalesce(sum(r.commission_reduction),0)::text from public.inventory_sale_returns r where r.clinic_id=sh.clinic_id and r.line_id=l.id)))
 from public.inventory_sale_lines l where l.sale_id=p_sale and l.clinic_id=sh.clinic_id));
end$$;

create function public.inv_sale_return_v3(p_sale uuid,p_shift uuid,p_line uuid,p_quantity text,
 p_method text,p_restock boolean,p_reason text,p_expected_amount text,p_expected_refund text,p_expected_commission text,p_actor uuid,p_operation text,p_expected_returned_quantity text)
returns uuid language plpgsql security definer set search_path='' as $$
declare sh public.inventory_cash_shifts;l public.inventory_sale_lines;qty numeric;previous numeric;credited numeric;
 restocked numeric;restored_cost numeric;credit numeric;refund numeric;cost_back numeric;commission numeric;reduced numeric;
 receipt uuid;fp jsonb;account jsonb;expected_previous numeric;source_lot public.lotes_inventario;movement_cost numeric;
begin
 if auth.uid() is null or auth.uid() is distinct from p_actor then raise exception 'session_changed';end if;
 select * into sh from public.inventory_cash_shifts where id=p_shift;
 perform private.inventory_require(sh.clinic_id,'sales.reverse',p_operation,p_sale,false);
 perform private.hospital_order_permission(sh.clinic_id,'sales.collect',null,false);
 perform private.medication_lock(sh.clinic_id);
 select * into sh from public.inventory_cash_shifts where id=p_shift for update;
 if sh.cashier_id is distinct from auth.uid() then raise exception 'own_open_shift_required';end if;
 perform 1 from public.inventory_sales where id=p_sale and clinic_id=sh.clinic_id for update;
 if not found then raise exception 'sale_required';end if;
 qty=private.inv_quantity(p_quantity);
 if qty is null or qty<=0 then raise exception 'positive_quantity_required';end if;
 if p_method is null or p_method not in ('efectivo','tarjeta','transferencia') or p_restock is null
 or coalesce(length(btrim(p_reason)),0) not between 1 and 1000 then raise exception 'return_details_required';end if;
 expected_previous=private.inv_quantity(p_expected_returned_quantity,true);
 fp=jsonb_build_object('kind','partial_sale_return_v3','expected_returned_quantity',expected_previous,'sale',p_sale,'line',p_line,'quantity',qty,
 'shift',p_shift,'method',p_method,'restock',p_restock,'reason',btrim(p_reason),'amount',private.inv_money(p_expected_amount),
 'refund',private.inv_money(p_expected_refund),'commission',private.inv_money(p_expected_commission));
 receipt=private.vet_receipt(sh.clinic_id,p_operation,fp);if receipt is not null then return receipt;end if;
 if sh.closed_at is not null then raise exception 'closed_shift';end if;
 if exists(select 1 from public.inventory_sale_lines where sale_id=p_sale and clinic_id=sh.clinic_id and kind='servicio') then
  if not private.has_clinic_role(sh.clinic_id,array['admin']) then raise exception 'admin_required';end if;
  if not private.ops_permission_active(sh.clinic_id,'service.manage') then raise exception 'explicit_permission_required';end if;
 end if;

 if not private.sale_return_eligible(p_sale,sh.clinic_id) then raise exception 'non_medication_sale_required';end if;
 select * into l from public.inventory_sale_lines where id=p_line and sale_id=p_sale and clinic_id=sh.clinic_id;
 if not found then raise exception 'sale_line_required';end if;
 if l.kind='servicio' then
  if not private.has_clinic_role(sh.clinic_id,array['admin']) then raise exception 'admin_required';end if;
  perform private.permission_require(sh.clinic_id,'service.manage');
  if p_restock then raise exception 'service_restock_denied';end if;
 end if;
 if l.stock_unit in ('unidad','frasco','caja') and qty<>trunc(qty) then raise exception 'whole_package_required';end if;
 select coalesce(sum(r.quantity),0),coalesce(sum(r.amount),0),coalesce(sum(r.quantity) filter(where r.restocked),0),coalesce(sum(r.cost),0),coalesce(sum(r.commission_reduction),0)
 into previous,credited,restocked,restored_cost,reduced from public.inventory_sale_returns r where r.clinic_id=sh.clinic_id and r.line_id=l.id;
 if previous is distinct from expected_previous then raise exception 'return_workspace_changed';end if;
 if previous+qty>l.quantity then raise exception 'return_exceeds_sold_quantity';end if;
 credit=round(l.total*(previous+qty)/l.quantity,2)-credited;
 commission=round(l.commission*(previous+qty)/l.quantity,2)-reduced;
 account=private.sale_balance(p_sale,sh.clinic_id);
 refund=greatest((account->>'paid')::numeric-(account->>'refunded')::numeric-((account->>'net_total')::numeric-credit),0);
 cost_back=case when p_restock then round(l.cost*(restocked+qty)/l.quantity,2)-restored_cost else 0 end;
 if private.inv_money(p_expected_amount) is distinct from credit or private.inv_money(p_expected_refund) is distinct from refund
 or private.inv_money(p_expected_commission) is distinct from commission then raise exception 'return_amount_changed';end if;
 if p_restock then
  perform 1 from public.inventario where id=l.item_id and clinic_id=sh.clinic_id for update;
  if not found then raise exception 'return_item_required';end if;
  select * into source_lot from public.lotes_inventario where id=l.lot_id and clinic_id=sh.clinic_id and item_id=l.item_id for update;
  if not found then raise exception 'return_lot_required';end if;
  movement_cost=case when coalesce(l.metadata->>'unit_cost','')~'^\d{1,12}(\.\d{1,9})?$' then (l.metadata->>'unit_cost')::numeric else source_lot.costo_unitario end;
  update public.inventario set stock=stock+qty,version=version+1 where id=l.item_id and clinic_id=sh.clinic_id;
  update public.lotes_inventario set cantidad=cantidad+qty where id=l.lot_id and clinic_id=sh.clinic_id;
 end if;
 insert into public.inventory_sale_returns(clinic_id,sale_id,line_id,shift_id,quantity,amount,refund_amount,cost,commission_reduction,method,restocked,reason,created_by)
 values(sh.clinic_id,p_sale,l.id,sh.id,qty,credit,refund,cost_back,commission,p_method,p_restock,btrim(p_reason),auth.uid()) returning id into receipt;
 if p_restock then
  insert into public.inventory_stock_movements(clinic_id,item_id,lot_id,delta,kind,unit_cost,reason,source_id,created_by)
  values(sh.clinic_id,l.item_id,l.lot_id,qty,'reverso',movement_cost,p_reason,receipt,auth.uid());
 end if;
 insert into public.audit_log(clinic_id,actor_id,action,entity_id,details)
 values(sh.clinic_id,auth.uid(),'inventory_partial_return_v2',receipt::text,jsonb_build_object('sale',p_sale,'quantity',qty,'credit',credit,'refund',refund,'commission_reduction',commission,'restocked',p_restock));
 insert into private.vet_operation_receipts values(auth.uid(),sh.clinic_id,p_operation,fp,receipt);
 return receipt;
end$$;

revoke all on function public.inv_sale_return_v3(uuid,uuid,uuid,text,text,boolean,text,text,text,text,uuid,text,text) from public,anon,authenticated,service_role;
grant execute on function public.inv_sale_return_v3(uuid,uuid,uuid,text,text,boolean,text,text,text,text,uuid,text,text) to authenticated;
-- Preserve known successful legacy receipts; do not accept unversioned fresh forms.
create function private.legacy_sale_return_receipt(p_sale uuid,p_shift uuid,p_line uuid,p_quantity text,p_method text,p_restock boolean,p_reason text,p_amount text,p_refund text,p_commission text,p_actor uuid,p_operation text,p_version integer)
returns uuid language plpgsql security definer set search_path='' as $$
declare sh public.inventory_cash_shifts;fp jsonb;receipt uuid;qty numeric;begin
 if auth.uid() is null or auth.uid() is distinct from p_actor then raise exception 'session_changed';end if;
 select * into sh from public.inventory_cash_shifts where id=p_shift;
 perform private.inventory_require(sh.clinic_id,'sales.reverse',p_operation,p_sale,false);
 perform private.hospital_order_permission(sh.clinic_id,'sales.collect',null,false);
 perform private.medication_lock(sh.clinic_id);
 select * into sh from public.inventory_cash_shifts where id=p_shift for update;
 if sh.cashier_id is distinct from auth.uid() then raise exception 'own_open_shift_required';end if;
 perform 1 from public.inventory_sales where id=p_sale and clinic_id=sh.clinic_id for update;
 if not found then raise exception 'sale_required';end if;
 qty=private.inv_quantity(p_quantity);
 fp=jsonb_build_object('kind',case when p_version=1 then 'partial_product_return' else 'partial_sale_return_v2' end,
 'sale',p_sale,'line',p_line,'quantity',qty,'shift',p_shift,'method',p_method,'restock',p_restock,'reason',btrim(p_reason),'amount',private.inv_money(p_amount));
 if p_version=2 then fp=fp||jsonb_build_object('refund',private.inv_money(p_refund),'commission',private.inv_money(p_commission));end if;
 receipt=private.vet_receipt(sh.clinic_id,p_operation,fp);if receipt is not null then return receipt;end if;
 raise exception 'return_client_upgrade_required';
end$$;
revoke all on function private.legacy_sale_return_receipt(uuid,uuid,uuid,text,text,boolean,text,text,text,text,uuid,text,integer) from public,anon,authenticated,service_role;
create or replace function public.inv_sale_return(p_sale uuid,p_shift uuid,p_line uuid,p_quantity text,p_method text,p_restock boolean,p_reason text,p_expected_amount text,p_actor uuid,p_operation text)
returns uuid language sql security definer set search_path='' as $$
 select private.legacy_sale_return_receipt(p_sale,p_shift,p_line,p_quantity,p_method,p_restock,p_reason,p_expected_amount,null,null,p_actor,p_operation,1);
$$;
create or replace function public.inv_sale_return_v2(p_sale uuid,p_shift uuid,p_line uuid,p_quantity text,p_method text,p_restock boolean,p_reason text,p_expected_amount text,p_expected_refund text,p_expected_commission text,p_actor uuid,p_operation text)
returns uuid language sql security definer set search_path='' as $$
 select private.legacy_sale_return_receipt(p_sale,p_shift,p_line,p_quantity,p_method,p_restock,p_reason,p_expected_amount,p_expected_refund,p_expected_commission,p_actor,p_operation,2);
$$;

create or replace function private.service_commission_net(p_act uuid,p_clinic uuid) returns numeric
language sql stable security definer set search_path='' as $$
 select case when exists(select 1 from public.inventory_sale_lines l where l.clinic_id=a.clinic_id and l.service_act_id=a.id)
 and not exists(select 1 from public.inventory_sale_lines l where l.clinic_id=a.clinic_id and l.service_act_id=a.id
  and not exists(select 1 from public.inventory_sale_reversals v where v.sale_id=l.sale_id and v.clinic_id=l.clinic_id)) then 0
 else greatest(a.commission-coalesce((select sum(r.commission_reduction) from public.inventory_sale_returns r
 join public.inventory_sale_lines l on l.id=r.line_id and l.clinic_id=r.clinic_id
 where l.service_act_id=a.id and l.clinic_id=a.clinic_id
 and not exists(select 1 from public.inventory_sale_reversals v where v.sale_id=l.sale_id and v.clinic_id=l.clinic_id)),0),0) end
 from public.clinic_service_acts a where a.id=p_act and a.clinic_id=p_clinic;
$$;

alter function public.inv_shift_snapshot(uuid) set schema private;
alter function private.inv_shift_snapshot(uuid) rename to snapshot_before_return_freshness;
revoke all on function private.snapshot_before_return_freshness(uuid) from public,anon,authenticated,service_role;
create function public.inv_shift_snapshot(p_shift uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;sh public.inventory_cash_shifts;begin
 -- Inherit current cash-read authorization. Never return the raw historical clinical lines.
 result=private.snapshot_before_return_freshness(p_shift);
 select * into sh from public.inventory_cash_shifts where id=p_shift;
 if sh.closed_at is not null then result=private.inventory_safe_cut(sh.snapshot,sh.clinic_id);end if;
 return result||jsonb_build_object('credit_supported',true,'partial_returns_supported',true,
 'live_sale_actions',(select coalesce(jsonb_agg(jsonb_build_object('sale_id',s.id,
  'allow_full_reverse',not exists(select 1 from public.inventory_sale_reversals r where r.sale_id=s.id and r.clinic_id=s.clinic_id)
   and not exists(select 1 from public.inventory_credit_accounts a where a.sale_id=s.id and a.clinic_id=s.clinic_id)
   and not exists(select 1 from public.inventory_sale_returns r where r.sale_id=s.id and r.clinic_id=s.clinic_id)
   and not (private.sale_return_eligible(s.id,s.clinic_id) and exists(select 1 from public.inventory_sale_lines l where l.sale_id=s.id and l.clinic_id=s.clinic_id and l.kind='servicio'))
 ) order by s.id),'[]') from public.inventory_sales s where s.shift_id=p_shift and s.clinic_id=sh.clinic_id));
end$$;
revoke all on function public.inv_shift_snapshot(uuid),public.inv_sale_return(uuid,uuid,uuid,text,text,boolean,text,text,uuid,text),public.inv_sale_return_v2(uuid,uuid,uuid,text,text,boolean,text,text,text,text,uuid,text) from public,anon,authenticated,service_role;
grant execute on function public.inv_shift_snapshot(uuid),public.inv_sale_return(uuid,uuid,uuid,text,text,boolean,text,text,uuid,text),public.inv_sale_return_v2(uuid,uuid,uuid,text,text,boolean,text,text,text,text,uuid,text) to authenticated;
select private.beta_install_guards();
notify pgrst,'reload schema';
commit;

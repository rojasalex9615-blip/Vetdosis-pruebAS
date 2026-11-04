-- Candidate: after inventory permissions, financial backup and commission recovery.
begin;
alter table public.inventory_sale_lines add constraint inventory_sale_line_identity unique(clinic_id,sale_id,id);
create table public.inventory_sale_returns (
 id uuid primary key default gen_random_uuid(),clinic_id uuid not null,sale_id uuid not null,line_id uuid not null,
 shift_id uuid not null,quantity numeric(24,9) not null check(quantity>0),
 amount numeric(18,2) not null check(amount>=0),cost numeric(18,2) not null check(cost>=0),
 method text not null check(method in ('efectivo','tarjeta','transferencia')),restocked boolean not null,
 reason text not null check(length(btrim(reason)) between 1 and 1000),
 created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 foreign key(clinic_id,sale_id,line_id) references public.inventory_sale_lines(clinic_id,sale_id,id),
 foreign key(clinic_id,shift_id) references public.inventory_cash_shifts(clinic_id,id)
);
create index sale_returns_line on public.inventory_sale_returns(clinic_id,sale_id,line_id);
create index sale_returns_shift on public.inventory_sale_returns(clinic_id,shift_id,created_at);
create index sale_returns_actor on public.inventory_sale_returns(created_by);
alter table public.inventory_sale_returns enable row level security;
revoke all on public.inventory_sale_returns from public,anon,authenticated,service_role;
create trigger sale_return_immutable before update or delete on public.inventory_sale_returns
 for each row execute function private.inv_history_guard();

create function private.sale_return_eligible(p_sale uuid,p_clinic uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.inventory_sales where id=p_sale and clinic_id=p_clinic and commission=0)
 and not exists(select 1 from public.inventory_sale_reversals where sale_id=p_sale and clinic_id=p_clinic)
 and exists(select 1 from public.inventory_sale_lines where sale_id=p_sale and clinic_id=p_clinic)
 and not exists(select 1 from public.inventory_sale_lines l left join public.inventario i on i.id=l.item_id and i.clinic_id=l.clinic_id
 where l.sale_id=p_sale and l.clinic_id=p_clinic and (l.kind<>'producto' or i.m8_kind is distinct from 'producto'
 or l.prescription_item_id is not null or l.commission<>0
 or coalesce(l.metadata->>'classification','no_controlado')<>'no_controlado' or coalesce(l.metadata->>'quantified','false')='true'));
$$;
revoke all on function private.sale_return_eligible(uuid,uuid) from public,anon,authenticated,service_role;

create function public.inv_sale_return_workspace(p_sale uuid,p_shift uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare sh public.inventory_cash_shifts;begin
 select * into sh from public.inventory_cash_shifts where id=p_shift;
 perform private.hospital_order_permission(sh.clinic_id,'sales.collect',null,false);
 if sh.cashier_id is distinct from auth.uid() or sh.closed_at is not null then raise exception 'own_open_shift_required';end if;
 if not private.inventory_current(sh.clinic_id,'sales.reverse') then raise exception 'explicit_permission_required';end if;
 if not private.sale_return_eligible(p_sale,sh.clinic_id) then raise exception 'non_medication_product_sale_required';end if;
 return jsonb_build_object('clinic_id',sh.clinic_id,'actor_id',auth.uid(),'lines',
 (select jsonb_agg(jsonb_build_object('id',l.id,'name',l.name,'lot',l.lot,'unit',l.stock_unit,
 'quantity',l.quantity::text,'total',l.total::text,
 'returned_quantity',(select coalesce(sum(r.quantity),0)::text from public.inventory_sale_returns r where r.clinic_id=sh.clinic_id and r.line_id=l.id),
 'returned_amount',(select coalesce(sum(r.amount),0)::text from public.inventory_sale_returns r where r.clinic_id=sh.clinic_id and r.line_id=l.id)))
 from public.inventory_sale_lines l where l.sale_id=p_sale and l.clinic_id=sh.clinic_id));
end$$;

create function public.inv_sale_return(p_sale uuid,p_shift uuid,p_line uuid,p_quantity text,
 p_method text,p_restock boolean,p_reason text,p_expected_amount text,p_actor uuid,p_operation text)
returns uuid language plpgsql security definer set search_path='' as $$
declare sh public.inventory_cash_shifts;l public.inventory_sale_lines;qty numeric;previous numeric;paid numeric;
 restocked numeric;restored_cost numeric;refund numeric;cost_back numeric;receipt uuid;fp jsonb;
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
 fp=jsonb_build_object('kind','partial_product_return','sale',p_sale,'line',p_line,'quantity',qty,
 'shift',p_shift,'method',p_method,'restock',p_restock,'reason',btrim(p_reason),'amount',private.inv_money(p_expected_amount));
 receipt=private.vet_receipt(sh.clinic_id,p_operation,fp);if receipt is not null then return receipt;end if;
 if sh.closed_at is not null then raise exception 'closed_shift';end if;
 if not private.sale_return_eligible(p_sale,sh.clinic_id) then raise exception 'non_medication_product_sale_required';end if;
 select * into l from public.inventory_sale_lines where id=p_line and sale_id=p_sale and clinic_id=sh.clinic_id;
 if not found then raise exception 'sale_line_required';end if;
 if l.stock_unit in ('unidad','frasco','caja') and qty<>trunc(qty) then raise exception 'whole_package_required';end if;
 select coalesce(sum(r.quantity),0),coalesce(sum(r.amount),0),
 coalesce(sum(r.quantity) filter(where r.restocked),0),coalesce(sum(r.cost),0)
 into previous,paid,restocked,restored_cost from public.inventory_sale_returns r where r.clinic_id=sh.clinic_id and r.line_id=l.id;
 if previous+qty>l.quantity then raise exception 'return_exceeds_sold_quantity';end if;
 refund=round(l.total*(previous+qty)/l.quantity,2)-paid;
 cost_back=case when p_restock then round(l.cost*(restocked+qty)/l.quantity,2)-restored_cost else 0 end;
 if private.inv_money(p_expected_amount) is distinct from refund then raise exception 'return_amount_changed';end if;
 if p_restock then
  perform 1 from public.inventario where id=l.item_id and clinic_id=sh.clinic_id for update;
  perform 1 from public.lotes_inventario where id=l.lot_id and clinic_id=sh.clinic_id for update;
  update public.inventario set stock=stock+qty,version=version+1 where id=l.item_id and clinic_id=sh.clinic_id;
  update public.lotes_inventario set cantidad=cantidad+qty where id=l.lot_id and clinic_id=sh.clinic_id;
 end if;
 insert into public.inventory_sale_returns(clinic_id,sale_id,line_id,shift_id,quantity,amount,cost,method,restocked,reason,created_by)
 values(sh.clinic_id,p_sale,l.id,sh.id,qty,refund,cost_back,p_method,p_restock,btrim(p_reason),auth.uid()) returning id into receipt;
 if p_restock then
  insert into public.inventory_stock_movements(clinic_id,item_id,lot_id,delta,kind,unit_cost,reason,source_id,created_by)
  values(sh.clinic_id,l.item_id,l.lot_id,qty,'reverso',(l.metadata->>'unit_cost')::numeric,p_reason,receipt,auth.uid());
 end if;
 insert into public.audit_log(clinic_id,actor_id,action,entity_id,details)
 values(sh.clinic_id,auth.uid(),'inventory_partial_return',receipt::text,jsonb_build_object('sale',p_sale,'quantity',qty,'amount',refund,'restocked',p_restock));
 insert into private.vet_operation_receipts values(auth.uid(),sh.clinic_id,p_operation,fp,receipt);
 return receipt;
end$$;
revoke all on function public.inv_sale_return_workspace(uuid,uuid),public.inv_sale_return(uuid,uuid,uuid,text,text,boolean,text,text,uuid,text)
 from public,anon,authenticated,service_role;
grant execute on function public.inv_sale_return_workspace(uuid,uuid),public.inv_sale_return(uuid,uuid,uuid,text,text,boolean,text,text,uuid,text) to authenticated;

alter function public.inv_sale_reverse(uuid,uuid,text,text) set schema private;
alter function private.inv_sale_reverse(uuid,uuid,text,text) rename to sale_reverse_before_partial_returns;
revoke all on function private.sale_reverse_before_partial_returns(uuid,uuid,text,text) from public,anon,authenticated,service_role;
create function public.inv_sale_reverse(p_sale uuid,p_shift uuid,p_reason text,p_operation text) returns uuid
language plpgsql security definer set search_path='' as $$
declare clinic uuid;begin
 select clinic_id into clinic from public.inventory_cash_shifts where id=p_shift;
 perform private.inventory_require(clinic,'sales.reverse',p_operation,p_sale,false);
 perform private.medication_lock(clinic);
 if exists(select 1 from public.inventory_sale_returns where sale_id=p_sale and clinic_id=clinic)
 then raise exception 'sale_has_partial_returns';end if;
 return private.sale_reverse_before_partial_returns(p_sale,p_shift,p_reason,p_operation);
end$$;
revoke all on function public.inv_sale_reverse(uuid,uuid,text,text) from public,anon,authenticated,service_role;
grant execute on function public.inv_sale_reverse(uuid,uuid,text,text) to authenticated;

create or replace function private.inv_totals(clinic uuid,shift uuid,start_time timestamptz,end_time timestamptz) returns jsonb language sql stable security definer set search_path='' as $$
 with valid_sales as (
 select s.total-coalesce((select sum(p.amount) from public.inventory_sale_returns p where p.sale_id=s.id and p.clinic_id=s.clinic_id and ($4 is null or p.created_at<$4)),0) total from public.inventory_sales s
 where s.clinic_id=$1 and ($2 is null or s.shift_id=$2)
 and ($3 is null or s.created_at>=$3) and ($4 is null or s.created_at<$4)
 and not exists(select 1 from public.inventory_sale_reversals r
   where r.sale_id=s.id and ($4 is null or r.created_at<$4))),
 sale_metrics as (select count(*) sale_count,round(avg(total),2) average_ticket from valid_sales where total>0),
 flows as (
 select s.id,s.method,s.total,s.cost,s.commission from public.inventory_sales s where s.clinic_id=$1 and ($2 is null or s.shift_id=$2) and ($3 is null or s.created_at>=$3) and ($4 is null or s.created_at<$4)
 union all select s.id,s.method,-s.total,-s.cost,-s.commission from public.inventory_sale_reversals r join public.inventory_sales s on s.id=r.sale_id where r.clinic_id=$1 and ($2 is null or r.shift_id=$2) and ($3 is null or r.created_at>=$3) and ($4 is null or r.created_at<$4)
 union all select r.sale_id,r.method,-r.amount,-r.cost,0 from public.inventory_sale_returns r where r.clinic_id=$1 and ($2 is null or r.shift_id=$2) and ($3 is null or r.created_at>=$3) and ($4 is null or r.created_at<$4)),
 money as (select coalesce(sum(total),0) gross,coalesce(sum(cost),0) cost,coalesce(sum(commission),0) commission,coalesce(sum(total) filter(where method='efectivo'),0) cash,coalesce(sum(total) filter(where method='tarjeta'),0) card,coalesce(sum(total) filter(where method='transferencia'),0) transfer from flows),
 cashmoves as (select coalesce(sum(amount) filter(where kind='ingreso'),0) income,coalesce(sum(amount) filter(where kind='retiro'),0) withdrawal,coalesce(sum(amount) filter(where kind='gasto'),0) expense from public.inventory_cash_movements m where m.clinic_id=$1 and ($2 is null or m.shift_id=$2) and ($3 is null or m.created_at>=$3) and ($4 is null or m.created_at<$4))
 select jsonb_build_object('sale_count',sale_count,'average_ticket',average_ticket::text,'gross',gross::text,'cost',cost::text,'commission',commission::text,'margin',(gross-cost-commission)::text,'recorded_net',(gross-cost-commission-expense)::text,'cash',cash::text,'card',card::text,'transfer',transfer::text,'income',income::text,'withdrawal',withdrawal::text,'expense',expense::text) from money,cashmoves,sale_metrics;
$$;

create or replace function public.inv_dashboard(p_clinic uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare tz text;today date;start_at timestamptz;end_at timestamptz;
begin
 if not private.inv_access(p_clinic) then raise exception 'inventory_access_required';end if;
 tz=private.inv_timezone(p_clinic);today=(clock_timestamp() at time zone tz)::date;start_at=today::timestamp at time zone tz;end_at=(today+1)::timestamp at time zone tz;
 return jsonb_build_object('professional',private.clinical_professional_at(p_clinic,auth.uid(),clock_timestamp()),'timezone',tz,'today',today,'server_time',clock_timestamp(),
 'products',coalesce((select jsonb_agg(to_jsonb(i)||jsonb_build_object('stock',i.stock::text,'stock_minimo',i.stock_minimo::text,'reorder_point',i.reorder_point::text,'precio_compra',i.precio_compra::text,'precio_venta',i.precio_venta::text,'available_stock',available::text,'low_stock',available<=i.stock_minimo,'reorder',available<=i.reorder_point,'lots',coalesce((select jsonb_agg(to_jsonb(l)||jsonb_build_object('cantidad',l.cantidad::text,'costo_unitario',l.costo_unitario::text,'days',l.caducidad-today,'expired',l.caducidad<=today) order by l.caducidad nulls last,l.created_at) from public.lotes_inventario l where item_id=i.id),'[]')) order by i.nombre) from public.inventario i cross join lateral(select coalesce(sum(l.cantidad),0) available from public.lotes_inventario l where l.item_id=i.id and (l.caducidad>today or (l.caducidad is null and i.m8_kind='producto'))) a where i.clinic_id=p_clinic),'[]'),
 'shifts',coalesce((select jsonb_agg(to_jsonb(sh)-'snapshot'||jsonb_build_object('opening_cash',sh.opening_cash::text,'counted_cash',sh.counted_cash::text) order by sh.opened_at desc) from public.inventory_cash_shifts sh where clinic_id=p_clinic and private.inventory_cash_read(p_clinic,cashier_id)),'[]'),
 'day_totals',case when private.inventory_current(p_clinic,'sales.read') then private.inv_totals(p_clinic,null,start_at,end_at) else null end,
 'catalog',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.name,'presentation',p.presentation,'classification',p.classification,'source_status',p.source_status)) from public.medication_product_versions p where p.version=(select max(v.version) from public.medication_product_versions v where v.product_key=p.product_key)),'[]'),
 'staff',coalesce((select jsonb_agg(jsonb_build_object('id',m.user_id,'role',m.role,'label',coalesce(u.email,m.user_id::text))) from public.clinic_members m join auth.users u on u.id=m.user_id where m.clinic_id=p_clinic),'[]'),
 'prescription_items',coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'product_version_id',x.product_version_id,'prescription_id',r.id,'folio',r.official_folio,'patient_id',r.patient_id)) from public.prescription_items x join public.prescriptions r on r.id=x.prescription_id where r.clinic_id=p_clinic and r.state='issued' and private.dispensing_access(p_clinic,auth.uid()) and private.rx_readable(r)),'[]'),
 'top_products',case when private.inventory_current(p_clinic,'sales.read') then coalesce((
 select jsonb_agg(jsonb_build_object('id',x.item_id,'name',i.nombre,'unit',i.stock_unit,'quantity',x.quantity::text,'amount',x.amount::text) order by x.amount desc) from (
 select f.item_id,sum(f.quantity) quantity,sum(f.amount) amount from (
 select l.item_id,l.quantity,l.total amount from public.inventory_sale_lines l join public.inventory_sales s on s.id=l.sale_id where l.clinic_id=p_clinic and l.kind='producto' and s.created_at>=start_at-interval '29 days' and s.created_at<end_at
 union all select l.item_id,-l.quantity,-l.total from public.inventory_sale_lines l join public.inventory_sale_reversals r on r.sale_id=l.sale_id where l.clinic_id=p_clinic and l.kind='producto' and r.created_at>=start_at-interval '29 days' and r.created_at<end_at
 union all select l.item_id,-r.quantity,-r.amount from public.inventory_sale_returns r join public.inventory_sale_lines l on l.id=r.line_id and l.clinic_id=r.clinic_id where r.clinic_id=p_clinic and r.created_at>=start_at-interval '29 days' and r.created_at<end_at
 ) f group by f.item_id having sum(f.amount)>0 order by sum(f.amount) desc limit 10) x join public.inventario i on i.id=x.item_id),'[]') else '[]'::jsonb end,
 'orders',coalesce((select jsonb_agg(to_jsonb(d)||jsonb_build_object('approval',(select to_jsonb(a) from public.inventory_order_approvals a where draft_id=d.id)) order by d.created_at desc) from public.inventory_order_drafts d where clinic_id=p_clinic),'[]'));
end $$;

create or replace function public.inv_ai_insights(p_clinic uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare today date;boundary timestamptz;previous_boundary timestamptz;end_at timestamptz;can_sales boolean;
begin
 if not private.inv_access(p_clinic) then raise exception 'inventory_access_required';end if;
 today=(clock_timestamp() at time zone private.inv_timezone(p_clinic))::date;
 boundary=(today-29)::timestamp at time zone private.inv_timezone(p_clinic);
 previous_boundary=(today-59)::timestamp at time zone private.inv_timezone(p_clinic);
 end_at=(today+1)::timestamp at time zone private.inv_timezone(p_clinic);
 can_sales=private.inventory_current(p_clinic,'sales.read');
 return jsonb_build_object('today',today,'timezone',private.inv_timezone(p_clinic),'sales_allowed',can_sales,
 'current_from',today-29,'current_to',today,'previous_from',today-59,'previous_to',today-30,
 'products',coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'name',i.nombre,'unit',i.stock_unit,'available',a.qty::text,'minimum',i.stock_minimo::text,'reorder_point',i.reorder_point::text,'low_stock',a.qty<=i.stock_minimo,'reorder',a.qty<=i.reorder_point) order by i.nombre)
 from public.inventario i cross join lateral(select coalesce(sum(l.cantidad),0) qty from public.lotes_inventario l where l.clinic_id=p_clinic and l.item_id=i.id and (l.caducidad>today or (l.caducidad is null and i.m8_kind='producto'))) a
 where i.clinic_id=p_clinic and i.active and i.m8_enabled),'[]'),
 'lots',coalesce((select jsonb_agg(jsonb_build_object('item_id',i.id,'name',i.nombre,'lot',l.lote,'unit',i.stock_unit,'expiry',l.caducidad,'days',l.caducidad-today,'quantity',l.cantidad::text,'expired',l.caducidad<=today) order by l.caducidad)
 from public.lotes_inventario l join public.inventario i on i.id=l.item_id and i.clinic_id=l.clinic_id
 where l.clinic_id=p_clinic and i.active and i.m8_enabled and l.cantidad>0 and l.caducidad<=today+90),'[]'),
 'sales',case when can_sales then coalesce((
  select jsonb_agg(jsonb_build_object('item_id',x.item_id,'name',i.nombre,'unit',i.stock_unit,'current_quantity',x.current_qty::text,'previous_quantity',x.previous_qty::text,'current_amount',x.current_amount::text,'previous_amount',x.previous_amount::text) order by x.current_amount desc)
  from (select e.item_id,sum(case when e.occurred_at>=boundary then e.qty else 0 end) current_qty,sum(case when e.occurred_at<boundary then e.qty else 0 end) previous_qty,
   sum(case when e.occurred_at>=boundary then e.amount else 0 end) current_amount,sum(case when e.occurred_at<boundary then e.amount else 0 end) previous_amount
   from (
    select l.item_id,l.quantity qty,l.total amount,s.created_at occurred_at from public.inventory_sale_lines l join public.inventory_sales s on s.id=l.sale_id and s.clinic_id=l.clinic_id where l.clinic_id=p_clinic and l.kind='producto' and s.created_at>=previous_boundary and s.created_at<end_at
    union all
    select l.item_id,-l.quantity,-l.total,r.created_at from public.inventory_sale_lines l join public.inventory_sale_reversals r on r.sale_id=l.sale_id and r.clinic_id=l.clinic_id where l.clinic_id=p_clinic and l.kind='producto' and r.created_at>=previous_boundary and r.created_at<end_at
    union all select l.item_id,-r.quantity,-r.amount,r.created_at from public.inventory_sale_returns r join public.inventory_sale_lines l on l.id=r.line_id and l.clinic_id=r.clinic_id where r.clinic_id=p_clinic and r.created_at>=previous_boundary and r.created_at<end_at
   ) e group by e.item_id) x join public.inventario i on i.id=x.item_id and i.clinic_id=p_clinic
 ),'[]') else '[]'::jsonb end);
end$$;
revoke all on function public.inv_ai_insights(uuid) from public,anon,service_role;
grant execute on function public.inv_ai_insights(uuid) to authenticated;

create or replace function public.clinic_statistics(p_clinic uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare tz text;begin
 perform public.beta_access_check(false,p_clinic);
 if not exists(select 1 from public.clinic_members where clinic_id=p_clinic and user_id=auth.uid()) or private.permission_effective(p_clinic,auth.uid(),'sales.read') is null then raise exception 'sales_read_required';end if;
 select timezone into tz from public.inventory_clinic_settings where clinic_id=p_clinic;tz=coalesce(tz,'America/Mexico_City');
 return jsonb_build_object('timezone',tz,'sales',(with months as (select generate_series(date_trunc('month',now() at time zone tz)-interval '11 months',date_trunc('month',now() at time zone tz),interval '1 month') m),flows as (
  select s.created_at at time zone tz at,s.total amount from public.inventory_sales s where s.clinic_id=p_clinic
  union all select r.created_at at time zone tz,-s.total from public.inventory_sale_reversals r join public.inventory_sales s on s.id=r.sale_id where r.clinic_id=p_clinic
  union all select r.created_at at time zone tz,-r.amount from public.inventory_sale_returns r where r.clinic_id=p_clinic)
  select jsonb_agg(jsonb_build_object('month',to_char(m,'YYYY-MM'),'amount',amount::text) order by m) from (select m,coalesce(sum(f.amount),0) amount from months left join flows f on f.at>=m and f.at<m+interval '1 month' group by m) x),
  'species',case when private.permission_effective(p_clinic,auth.uid(),'appointment.read') is not null then (select coalesce(jsonb_agg(jsonb_build_object('species',species,'count',n)),'[]') from (select species,count(*) n from public.clinic_appointments where clinic_id=p_clinic and state<>'cancelado' and starts_at>=(date_trunc('month',now() at time zone tz) at time zone tz) and starts_at<((date_trunc('month',now() at time zone tz)+interval '1 month') at time zone tz) group by species) x) else null end,
  'low_stock',case when private.permission_effective(p_clinic,auth.uid(),'inventory.read') is not null then (select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',nombre,'stock',stock::text,'minimum',stock_minimo::text)),'[]') from public.inventario where clinic_id=p_clinic and active and m8_enabled and stock<=stock_minimo) else null end);
end$$;

alter function public.inv_shift_snapshot(uuid) set schema private;
alter function private.inv_shift_snapshot(uuid) rename to shift_snapshot_before_partial_returns;
revoke all on function private.shift_snapshot_before_partial_returns(uuid) from public,anon,authenticated,service_role;
create function public.inv_shift_snapshot(p_shift uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;clinic uuid;begin
 result=private.shift_snapshot_before_partial_returns(p_shift);
 clinic=(result->>'clinic_id')::uuid;
 -- Frozen cut numbers stay frozen; return status is a separate live context.
 return result||jsonb_build_object('partial_returns_supported',true,
 'partial_returns',case when result->>'closed_at' is not null then coalesce(result->'partial_returns','[]') else
  (select coalesce(jsonb_agg(to_jsonb(r)||jsonb_build_object('quantity',r.quantity::text,'amount',r.amount::text,'cost',r.cost::text)),'[]') from public.inventory_sale_returns r where r.clinic_id=clinic and r.shift_id=p_shift) end,
 'sales',(select coalesce(jsonb_agg(e||jsonb_build_object('has_partial_returns',exists(select 1 from public.inventory_sale_returns r where r.clinic_id=clinic and r.sale_id=(e->>'id')::uuid)) order by ord),'[]') from jsonb_array_elements(result->'sales') with ordinality as x(e,ord)));
end$$;
revoke all on function public.inv_shift_snapshot(uuid) from public,anon,authenticated,service_role;
grant execute on function public.inv_shift_snapshot(uuid) to authenticated;

alter function public.clinic_export(uuid) set schema private;
alter function private.clinic_export(uuid) rename to clinic_export_before_partial_returns;
revoke all on function private.clinic_export_before_partial_returns(uuid) from public,anon,authenticated,service_role;
create function public.clinic_export(p_clinic uuid) returns text language plpgsql security definer set search_path='' as $$
declare result jsonb;begin
 result=private.clinic_export_before_partial_returns(p_clinic)::jsonb;
 return jsonb_set(result,'{tables,inventory_sale_returns}',
 (select coalesce(jsonb_agg(to_jsonb(r)),'[]') from public.inventory_sale_returns r where r.clinic_id=p_clinic))::text;
end$$;
revoke all on function public.clinic_export(uuid) from public,anon,authenticated,service_role;
grant execute on function public.clinic_export(uuid) to authenticated;
select private.beta_install_guards();
notify pgrst,'reload schema';
commit;

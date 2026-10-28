-- Candidate after 20261027024532. Local validation only; no remote application.
begin;
create table public.inventory_credit_accounts (
 sale_id uuid primary key,clinic_id uuid not null,debtor text not null check(length(btrim(debtor)) between 1 and 200),
 created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 unique(clinic_id,sale_id),foreign key(clinic_id,sale_id) references public.inventory_sales(clinic_id,id)
);
create index credit_accounts_clinic on public.inventory_credit_accounts(clinic_id,created_at,sale_id);
create index credit_accounts_actor on public.inventory_credit_accounts(created_by);
create table public.inventory_sale_collections (
 id uuid primary key default gen_random_uuid(),clinic_id uuid not null,sale_id uuid not null,shift_id uuid not null,
 amount numeric(18,2) not null check(amount>0),method text not null check(method in ('efectivo','tarjeta','transferencia')),
 reference text not null check(length(btrim(reference)) between 1 and 200),
 created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 foreign key(clinic_id,sale_id) references public.inventory_credit_accounts(clinic_id,sale_id),
 foreign key(clinic_id,shift_id) references public.inventory_cash_shifts(clinic_id,id)
);
create index sale_collections_account on public.inventory_sale_collections(clinic_id,sale_id,created_at,id);
create index sale_collections_shift on public.inventory_sale_collections(clinic_id,shift_id,created_at);
create index sale_collections_actor on public.inventory_sale_collections(created_by);
alter table public.inventory_credit_accounts enable row level security;
alter table public.inventory_sale_collections enable row level security;
revoke all on public.inventory_credit_accounts,public.inventory_sale_collections from public,anon,authenticated,service_role;
create trigger credit_account_immutable before update or delete on public.inventory_credit_accounts for each row execute function private.inv_history_guard();
create trigger sale_collection_immutable before update or delete on public.inventory_sale_collections for each row execute function private.inv_history_guard();
alter table public.inventory_sale_returns add column refund_amount numeric(18,2),add column commission_reduction numeric(18,2) not null default 0 check(commission_reduction>=0);
-- Temporarily disable only the immutable-row guard for this explicit migration backfill.
alter table public.inventory_sale_returns disable trigger sale_return_immutable;
update public.inventory_sale_returns set refund_amount=amount;
alter table public.inventory_sale_returns enable trigger sale_return_immutable;
alter table public.inventory_sale_returns alter column refund_amount set not null;
alter table public.inventory_sale_returns add constraint return_refund_amount_check check(refund_amount between 0 and amount);

create function private.sale_balance(p_sale uuid,p_clinic uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('net_total',(s.total-r.credit)::text,'paid',p.paid::text,'refunded',r.refund::text,
 'balance',greatest(s.total-r.credit-p.paid+r.refund,0)::text)
 from public.inventory_sales s
 cross join lateral(select coalesce(sum(amount),0) credit,coalesce(sum(refund_amount),0) refund from public.inventory_sale_returns where sale_id=s.id and clinic_id=s.clinic_id) r
 cross join lateral(select case when exists(select 1 from public.inventory_credit_accounts where sale_id=s.id and clinic_id=s.clinic_id)
 then coalesce((select sum(amount) from public.inventory_sale_collections where sale_id=s.id and clinic_id=s.clinic_id),0) else s.total end paid) p
 where s.id=p_sale and s.clinic_id=p_clinic;
$$;
revoke all on function private.sale_balance(uuid,uuid) from public,anon,authenticated,service_role;
create function private.sale_fully_collected(p_sale uuid,p_clinic uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce((b->>'net_total')::numeric>0 and (b->>'balance')::numeric=0,false)
 and not exists(select 1 from public.inventory_sale_reversals where sale_id=p_sale and clinic_id=p_clinic)
 from private.sale_balance(p_sale,p_clinic) b;
$$;
revoke all on function private.sale_fully_collected(uuid,uuid) from public,anon,authenticated,service_role;

create function public.inv_sale_credit_post(p_shift uuid,p_method text,p_lines jsonb,p_expected_total text,
 p_initial_amount text,p_debtor text,p_actor uuid,p_operation text) returns uuid
language plpgsql security definer set search_path='' as $$
declare sh public.inventory_cash_shifts;initial numeric;total numeric;sale uuid;fp jsonb;old_receipt uuid;
begin
 if auth.uid() is null or auth.uid() is distinct from p_actor then raise exception 'session_changed';end if;
 select * into sh from public.inventory_cash_shifts where id=p_shift;
 perform private.inventory_require(sh.clinic_id,'sales.collect',p_operation,null,false);
 perform private.medication_lock(sh.clinic_id);
 select * into sh from public.inventory_cash_shifts where id=p_shift for update;
 if sh.cashier_id is distinct from auth.uid() then raise exception 'own_shift_required';end if;
 initial=private.inv_money(p_initial_amount);total=private.inv_money(p_expected_total);
 if initial>=total or coalesce(length(btrim(p_debtor)),0) not between 1 and 200 or p_method is null or p_method not in ('efectivo','tarjeta','transferencia') then raise exception 'credit_details_required';end if;
 fp=jsonb_build_object('kind','credit_sale','shift',p_shift,'method',p_method,'lines',p_lines,'total',total,'initial',initial,'debtor',btrim(p_debtor));
 old_receipt=private.vet_receipt(sh.clinic_id,p_operation,fp);if old_receipt is not null then return old_receipt;end if;
 if sh.closed_at is not null then raise exception 'closed_shift';end if;
 -- A separate child operation protects the existing sale validation and stock transaction.
 if exists(select 1 from jsonb_array_elements(p_lines) l where nullif(l->>'catalog_service_id','') is not null) then
  sale=public.inv_catalog_service_sale_post(p_shift,p_method,p_lines,total::text,substr(encode(sha256(convert_to(p_operation||':sale','UTF8')),'hex'),1,48));
 else
  sale=public.inv_sale_post(p_shift,p_method,p_lines,total::text,substr(encode(sha256(convert_to(p_operation||':sale','UTF8')),'hex'),1,48));
 end if;
 if not private.sale_return_eligible(sale,sh.clinic_id) then raise exception 'non_medication_sale_required';end if;
 insert into public.inventory_credit_accounts(sale_id,clinic_id,debtor,created_by) values(sale,sh.clinic_id,btrim(p_debtor),auth.uid());
 if initial>0 then
  insert into public.inventory_sale_collections(clinic_id,sale_id,shift_id,amount,method,reference,created_by)
  values(sh.clinic_id,sale,sh.id,initial,p_method,'Abono inicial',auth.uid());
 end if;
 insert into private.vet_operation_receipts values(auth.uid(),sh.clinic_id,p_operation,fp,sale);
 insert into public.audit_log(clinic_id,actor_id,action,entity_id,details)
 values(sh.clinic_id,auth.uid(),'credit_sale_opened',sale::text,jsonb_build_object('initial',initial,'total',total));
 return sale;
end$$;

create function public.inv_sale_collect(p_sale uuid,p_shift uuid,p_amount text,p_method text,p_reference text,p_actor uuid,p_operation text)
returns uuid language plpgsql security definer set search_path='' as $$
declare sh public.inventory_cash_shifts;amount numeric;balance numeric;receipt uuid;fp jsonb;
begin
 if auth.uid() is null or auth.uid() is distinct from p_actor then raise exception 'session_changed';end if;
 select * into sh from public.inventory_cash_shifts where id=p_shift;
 perform private.inventory_require(sh.clinic_id,'sales.collect',p_operation,p_sale,false);
 perform private.medication_lock(sh.clinic_id);
 select * into sh from public.inventory_cash_shifts where id=p_shift for update;
 if sh.cashier_id is distinct from auth.uid() then raise exception 'own_shift_required';end if;
 perform 1 from public.inventory_sales s join public.inventory_credit_accounts a on a.sale_id=s.id and a.clinic_id=s.clinic_id
 where s.id=p_sale and s.clinic_id=sh.clinic_id for update of s;
 if not found then raise exception 'credit_sale_required';end if;
 amount=private.inv_money(p_amount);
 if amount<=0 or p_method is null or p_method not in ('efectivo','tarjeta','transferencia') or coalesce(length(btrim(p_reference)),0) not between 1 and 200 then raise exception 'collection_details_required';end if;
 fp=jsonb_build_object('kind','sale_collection','sale',p_sale,'shift',p_shift,'amount',amount,'method',p_method,'reference',btrim(p_reference));
 receipt=private.vet_receipt(sh.clinic_id,p_operation,fp);if receipt is not null then return receipt;end if;
 if sh.closed_at is not null then raise exception 'closed_shift';end if;
 balance=(private.sale_balance(p_sale,sh.clinic_id)->>'balance')::numeric;
 if amount>balance or exists(select 1 from public.inventory_sale_reversals where sale_id=p_sale and clinic_id=sh.clinic_id) then raise exception 'collection_exceeds_balance';end if;
 insert into public.inventory_sale_collections(clinic_id,sale_id,shift_id,amount,method,reference,created_by)
 values(sh.clinic_id,p_sale,sh.id,amount,p_method,btrim(p_reference),auth.uid()) returning id into receipt;
 insert into private.vet_operation_receipts values(auth.uid(),sh.clinic_id,p_operation,fp,receipt);
 insert into public.audit_log(clinic_id,actor_id,action,entity_id,details) values(sh.clinic_id,auth.uid(),'sale_collection_recorded',receipt::text,jsonb_build_object('sale',p_sale,'amount',amount));
 return receipt;
end$$;
create function public.inv_credit_accounts(p_clinic uuid,p_offset integer default 0) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 perform private.hospital_order_permission(p_clinic,'sales.collect',null,false);
 if not private.inventory_current(p_clinic,'sales.read') then raise exception 'explicit_permission_required';end if;
 if p_offset is null or p_offset<0 or p_offset>100000 then raise exception 'invalid_offset';end if;
 return jsonb_build_object('clinic_id',p_clinic,'actor_id',auth.uid(),'items',coalesce((select jsonb_agg(to_jsonb(q) order by q.created_at desc,q.sale_id) from (
 select a.sale_id,a.debtor,a.created_at,private.sale_balance(a.sale_id,a.clinic_id) as account,
 (select coalesce(jsonb_agg(to_jsonb(c)||jsonb_build_object('amount',c.amount::text) order by c.created_at,c.id),'[]') from public.inventory_sale_collections c where c.sale_id=a.sale_id and c.clinic_id=a.clinic_id) collections,
 (select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'quantity',r.quantity::text,'amount',r.amount::text,'refund_amount',r.refund_amount::text,'commission_reduction',r.commission_reduction::text,'method',r.method,'reason',r.reason,'created_at',r.created_at) order by r.created_at,r.id),'[]') from public.inventory_sale_returns r where r.sale_id=a.sale_id and r.clinic_id=a.clinic_id) returns
 from public.inventory_credit_accounts a where a.clinic_id=p_clinic order by a.created_at desc,a.sale_id limit 100 offset p_offset) q),'[]'));
end$$;
revoke all on function public.inv_sale_credit_post(uuid,text,jsonb,text,text,text,uuid,text),public.inv_sale_collect(uuid,uuid,text,text,text,uuid,text),public.inv_credit_accounts(uuid,integer) from public,anon,authenticated,service_role;
grant execute on function public.inv_sale_credit_post(uuid,text,jsonb,text,text,text,uuid,text),public.inv_sale_collect(uuid,uuid,text,text,text,uuid,text),public.inv_credit_accounts(uuid,integer) to authenticated;

create or replace function private.sale_return_eligible(p_sale uuid,p_clinic uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.inventory_sales where id=p_sale and clinic_id=p_clinic)
 and not exists(select 1 from public.inventory_sale_reversals where sale_id=p_sale and clinic_id=p_clinic)
 and exists(select 1 from public.inventory_sale_lines where sale_id=p_sale and clinic_id=p_clinic)
 and not exists(select 1 from public.inventory_sale_lines l left join public.inventario i on i.id=l.item_id and i.clinic_id=l.clinic_id
 where l.sale_id=p_sale and l.clinic_id=p_clinic and (l.kind not in ('producto','servicio')
 or (l.kind='producto' and i.m8_kind is distinct from 'producto')
 or l.prescription_item_id is not null or l.application_charge_id is not null or l.delivery_ticket_id is not null
 or coalesce(l.metadata->>'classification','no_controlado')<>'no_controlado' or coalesce(l.metadata->>'quantified','false')='true'));
$$;
create or replace function public.inv_sale_return_workspace(p_sale uuid,p_shift uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare sh public.inventory_cash_shifts;begin
 select * into sh from public.inventory_cash_shifts where id=p_shift;
 perform private.hospital_order_permission(sh.clinic_id,'sales.collect',null,false);
 if sh.cashier_id is distinct from auth.uid() or sh.closed_at is not null then raise exception 'own_open_shift_required';end if;
 if not private.inventory_current(sh.clinic_id,'sales.reverse') then raise exception 'explicit_permission_required';end if;
 if not private.sale_return_eligible(p_sale,sh.clinic_id) then raise exception 'non_medication_sale_required';end if;
 return jsonb_build_object('schema_version',2,'clinic_id',sh.clinic_id,'actor_id',auth.uid(),
 'account',private.sale_balance(p_sale,sh.clinic_id),'lines',
 (select jsonb_agg(jsonb_build_object('id',l.id,'kind',l.kind,'name',case when l.service_act_id is not null and not private.inventory_clinical_read(sh.clinic_id) then 'Servicio registrado' else l.name end,'lot',l.lot,'unit',l.stock_unit,
 'quantity',l.quantity::text,'total',l.total::text,'commission',l.commission::text,
 'returned_quantity',(select coalesce(sum(r.quantity),0)::text from public.inventory_sale_returns r where r.clinic_id=sh.clinic_id and r.line_id=l.id),
 'returned_amount',(select coalesce(sum(r.amount),0)::text from public.inventory_sale_returns r where r.clinic_id=sh.clinic_id and r.line_id=l.id),
 'returned_commission',(select coalesce(sum(r.commission_reduction),0)::text from public.inventory_sale_returns r where r.clinic_id=sh.clinic_id and r.line_id=l.id)))
 from public.inventory_sale_lines l where l.sale_id=p_sale and l.clinic_id=sh.clinic_id));
end$$;
create function public.inv_sale_return_v2(p_sale uuid,p_shift uuid,p_line uuid,p_quantity text,
 p_method text,p_restock boolean,p_reason text,p_expected_amount text,p_expected_refund text,p_expected_commission text,p_actor uuid,p_operation text)
returns uuid language plpgsql security definer set search_path='' as $$
declare sh public.inventory_cash_shifts;l public.inventory_sale_lines;qty numeric;previous numeric;credited numeric;
 restocked numeric;restored_cost numeric;credit numeric;refund numeric;cost_back numeric;commission numeric;reduced numeric;
 receipt uuid;fp jsonb;account jsonb;
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
 fp=jsonb_build_object('kind','partial_sale_return_v2','sale',p_sale,'line',p_line,'quantity',qty,
 'shift',p_shift,'method',p_method,'restock',p_restock,'reason',btrim(p_reason),'amount',private.inv_money(p_expected_amount),
 'refund',private.inv_money(p_expected_refund),'commission',private.inv_money(p_expected_commission));
 receipt=private.vet_receipt(sh.clinic_id,p_operation,fp);if receipt is not null then return receipt;end if;
 if sh.closed_at is not null then raise exception 'closed_shift';end if;
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
  perform 1 from public.lotes_inventario where id=l.lot_id and clinic_id=sh.clinic_id for update;
  update public.inventario set stock=stock+qty,version=version+1 where id=l.item_id and clinic_id=sh.clinic_id;
  update public.lotes_inventario set cantidad=cantidad+qty where id=l.lot_id and clinic_id=sh.clinic_id;
 end if;
 insert into public.inventory_sale_returns(clinic_id,sale_id,line_id,shift_id,quantity,amount,refund_amount,cost,commission_reduction,method,restocked,reason,created_by)
 values(sh.clinic_id,p_sale,l.id,sh.id,qty,credit,refund,cost_back,commission,p_method,p_restock,btrim(p_reason),auth.uid()) returning id into receipt;
 if p_restock then
  insert into public.inventory_stock_movements(clinic_id,item_id,lot_id,delta,kind,unit_cost,reason,source_id,created_by)
  values(sh.clinic_id,l.item_id,l.lot_id,qty,'reverso',(l.metadata->>'unit_cost')::numeric,p_reason,receipt,auth.uid());
 end if;
 insert into public.audit_log(clinic_id,actor_id,action,entity_id,details)
 values(sh.clinic_id,auth.uid(),'inventory_partial_return_v2',receipt::text,jsonb_build_object('sale',p_sale,'quantity',qty,'credit',credit,'refund',refund,'commission_reduction',commission,'restocked',p_restock));
 insert into private.vet_operation_receipts values(auth.uid(),sh.clinic_id,p_operation,fp,receipt);
 return receipt;
end$$;
revoke all on function public.inv_sale_return_v2(uuid,uuid,uuid,text,text,boolean,text,text,text,text,uuid,text) from public,anon,authenticated,service_role;
grant execute on function public.inv_sale_return_v2(uuid,uuid,uuid,text,text,boolean,text,text,text,text,uuid,text) to authenticated;
-- Preserve old receipt fingerprints for retries. Old clients cannot operate on credit/services.
alter function public.inv_sale_return(uuid,uuid,uuid,text,text,boolean,text,text,uuid,text) set schema private;
alter function private.inv_sale_return(uuid,uuid,uuid,text,text,boolean,text,text,uuid,text) rename to product_return_before_credit;
revoke all on function private.product_return_before_credit(uuid,uuid,uuid,text,text,boolean,text,text,uuid,text) from public,anon,authenticated,service_role;
create function public.inv_sale_return(p_sale uuid,p_shift uuid,p_line uuid,p_quantity text,p_method text,p_restock boolean,p_reason text,p_expected_amount text,p_actor uuid,p_operation text)
returns uuid language plpgsql security definer set search_path='' as $$
declare clinic uuid;begin
 if auth.uid() is null or auth.uid() is distinct from p_actor then raise exception 'session_changed';end if;
 select clinic_id into clinic from public.inventory_cash_shifts where id=p_shift;
 perform private.inventory_require(clinic,'sales.reverse',p_operation,p_sale,false);
 perform private.medication_lock(clinic);
 if exists(select 1 from public.inventory_credit_accounts where sale_id=p_sale and clinic_id=clinic)
 or exists(select 1 from public.inventory_sale_lines where sale_id=p_sale and clinic_id=clinic and kind='servicio') then raise exception 'return_client_upgrade_required';end if;
 -- The historical function inserts no refund_amount. Its insert is completed by a migration trigger below.
 return private.product_return_before_credit(p_sale,p_shift,p_line,p_quantity,p_method,p_restock,p_reason,p_expected_amount,p_actor,p_operation);
end$$;
create function private.sale_return_legacy_refund() returns trigger language plpgsql set search_path='' as $$
begin if new.refund_amount is null then new.refund_amount=new.amount;end if;return new;end$$;
revoke all on function private.sale_return_legacy_refund() from public,anon,authenticated,service_role;
create trigger sale_return_legacy_refund before insert on public.inventory_sale_returns for each row execute function private.sale_return_legacy_refund();
revoke all on function public.inv_sale_return(uuid,uuid,uuid,text,text,boolean,text,text,uuid,text) from public,anon,authenticated,service_role;
grant execute on function public.inv_sale_return(uuid,uuid,uuid,text,text,boolean,text,text,uuid,text) to authenticated;
-- Credit sales use line cancellations, which calculate the actual money refundable.
alter function public.inv_sale_reverse(uuid,uuid,text,text) set schema private;
alter function private.inv_sale_reverse(uuid,uuid,text,text) rename to sale_reverse_before_credit;
revoke all on function private.sale_reverse_before_credit(uuid,uuid,text,text) from public,anon,authenticated,service_role;
create function public.inv_sale_reverse(p_sale uuid,p_shift uuid,p_reason text,p_operation text) returns uuid
language plpgsql security definer set search_path='' as $$
declare clinic uuid;begin
 select clinic_id into clinic from public.inventory_cash_shifts where id=p_shift;
 perform private.inventory_require(clinic,'sales.reverse',p_operation,p_sale,false);
 perform private.medication_lock(clinic);
 if exists(select 1 from public.inventory_credit_accounts where sale_id=p_sale and clinic_id=clinic) then raise exception 'credit_sale_use_line_returns';end if;
 if private.sale_return_eligible(p_sale,clinic) and exists(select 1 from public.inventory_sale_lines where sale_id=p_sale and clinic_id=clinic and kind='servicio') then raise exception 'service_sale_use_line_returns';end if;
 return private.sale_reverse_before_credit(p_sale,p_shift,p_reason,p_operation);
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
 select s.id,s.method,s.total,s.cost,s.commission,case when exists(select 1 from public.inventory_credit_accounts a where a.sale_id=s.id and a.clinic_id=s.clinic_id) then 0 else s.total end cash_total from public.inventory_sales s where s.clinic_id=$1 and ($2 is null or s.shift_id=$2) and ($3 is null or s.created_at>=$3) and ($4 is null or s.created_at<$4)
 union all select s.id,s.method,-s.total,-s.cost,-s.commission,-s.total from public.inventory_sale_reversals r join public.inventory_sales s on s.id=r.sale_id where r.clinic_id=$1 and ($2 is null or r.shift_id=$2) and ($3 is null or r.created_at>=$3) and ($4 is null or r.created_at<$4)
 union all select r.sale_id,r.method,-r.amount,-r.cost,-r.commission_reduction,-r.refund_amount from public.inventory_sale_returns r where r.clinic_id=$1 and ($2 is null or r.shift_id=$2) and ($3 is null or r.created_at>=$3) and ($4 is null or r.created_at<$4)
 union all select c.sale_id,c.method,0,0,0,c.amount from public.inventory_sale_collections c where c.clinic_id=$1 and ($2 is null or c.shift_id=$2) and ($3 is null or c.created_at>=$3) and ($4 is null or c.created_at<$4)),
 money as (select coalesce(sum(total),0) gross,coalesce(sum(cost),0) cost,coalesce(sum(commission),0) commission,coalesce(sum(cash_total) filter(where method='efectivo'),0) cash,coalesce(sum(cash_total) filter(where method='tarjeta'),0) card,coalesce(sum(cash_total) filter(where method='transferencia'),0) transfer from flows),
 cashmoves as (select coalesce(sum(amount) filter(where kind='ingreso'),0) income,coalesce(sum(amount) filter(where kind='retiro'),0) withdrawal,coalesce(sum(amount) filter(where kind='gasto'),0) expense from public.inventory_cash_movements m where m.clinic_id=$1 and ($2 is null or m.shift_id=$2) and ($3 is null or m.created_at>=$3) and ($4 is null or m.created_at<$4))
 select jsonb_build_object('sale_count',sale_count,'average_ticket',average_ticket::text,'gross',gross::text,'cost',cost::text,'commission',commission::text,'margin',(gross-cost-commission)::text,'recorded_net',(gross-cost-commission-expense)::text,'cash',cash::text,'card',card::text,'transfer',transfer::text,'income',income::text,'withdrawal',withdrawal::text,'expense',expense::text) from money,cashmoves,sale_metrics;
$$;

alter function public.inv_dashboard(uuid) set schema private;
alter function private.inv_dashboard(uuid) rename to dashboard_before_credit;
revoke all on function private.dashboard_before_credit(uuid) from public,anon,authenticated,service_role;
create function public.inv_dashboard(p_clinic uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin return private.dashboard_before_credit(p_clinic)||jsonb_build_object('credit_supported',true);end$$;
revoke all on function public.inv_dashboard(uuid) from public,anon,authenticated,service_role;
grant execute on function public.inv_dashboard(uuid) to authenticated;

alter function public.inv_shift_snapshot(uuid) set schema private;
alter function private.inv_shift_snapshot(uuid) rename to shift_snapshot_before_credit;
revoke all on function private.shift_snapshot_before_credit(uuid) from public,anon,authenticated,service_role;
create function public.inv_shift_snapshot(p_shift uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;clinic uuid;begin
 result=private.shift_snapshot_before_credit(p_shift);clinic=(result->>'clinic_id')::uuid;
 return result||jsonb_build_object('credit_supported',true,
 'collections',case when result->>'closed_at' is not null then coalesce(result->'collections','[]') else
 (select coalesce(jsonb_agg(to_jsonb(c)||jsonb_build_object('amount',c.amount::text) order by c.created_at,c.id),'[]') from public.inventory_sale_collections c where c.clinic_id=clinic and c.shift_id=p_shift) end,
 'sales',(select coalesce(jsonb_agg(e||jsonb_build_object('is_credit',exists(select 1 from public.inventory_credit_accounts a where a.sale_id=(e->>'id')::uuid and a.clinic_id=clinic),
 'use_line_returns',exists(select 1 from public.inventory_sale_lines l where l.sale_id=(e->>'id')::uuid and l.clinic_id=clinic and l.kind='servicio') and private.sale_return_eligible((e->>'id')::uuid,clinic),
 'account',private.sale_balance((e->>'id')::uuid,clinic)) order by ord),'[]') from jsonb_array_elements(result->'sales') with ordinality as x(e,ord)));
end$$;
revoke all on function public.inv_shift_snapshot(uuid) from public,anon,authenticated,service_role;
grant execute on function public.inv_shift_snapshot(uuid) to authenticated;

alter function public.clinic_export(uuid) set schema private;
alter function private.clinic_export(uuid) rename to clinic_export_before_credit;
revoke all on function private.clinic_export_before_credit(uuid) from public,anon,authenticated,service_role;
create function public.clinic_export(p_clinic uuid) returns text language plpgsql security definer set search_path='' as $$
declare result jsonb;begin
 result=private.clinic_export_before_credit(p_clinic)::jsonb;
 result=jsonb_set(result,'{tables,inventory_credit_accounts}',(select coalesce(jsonb_agg(to_jsonb(a)),'[]') from public.inventory_credit_accounts a where a.clinic_id=p_clinic));
 return jsonb_set(result,'{tables,inventory_sale_collections}',(select coalesce(jsonb_agg(to_jsonb(c)),'[]') from public.inventory_sale_collections c where c.clinic_id=p_clinic))::text;
end$$;
revoke all on function public.clinic_export(uuid) from public,anon,authenticated,service_role;
grant execute on function public.clinic_export(uuid) to authenticated;

create function private.service_commission_net(p_act uuid,p_clinic uuid) returns numeric
language sql stable security definer set search_path='' as $$
 select greatest(a.commission-coalesce((select sum(r.commission_reduction) from public.inventory_sale_returns r
 join public.inventory_sale_lines l on l.id=r.line_id and l.clinic_id=r.clinic_id
 where l.service_act_id=a.id and l.clinic_id=a.clinic_id
 and not exists(select 1 from public.inventory_sale_reversals v where v.sale_id=l.sale_id and v.clinic_id=l.clinic_id)),0),0)
 from public.clinic_service_acts a where a.id=p_act and a.clinic_id=p_clinic;
$$;
create function private.commission_recovery_limit(p_settlement uuid,p_clinic uuid) returns numeric
language sql stable security definer set search_path='' as $$
 select greatest(s.amount-case when exists(select 1 from public.inventory_sale_reversals r where r.sale_id=s.sale_id and r.clinic_id=s.clinic_id) then 0 else
 greatest(coalesce((select sum(l.commission) from public.inventory_sale_lines l where l.sale_id=s.sale_id and l.clinic_id=s.clinic_id and l.service_act_id=s.service_act_id),s.amount)
 -coalesce((select sum(r.commission_reduction) from public.inventory_sale_returns r join public.inventory_sale_lines l on l.id=r.line_id and l.clinic_id=r.clinic_id
 where r.sale_id=s.sale_id and r.clinic_id=s.clinic_id and l.service_act_id=s.service_act_id),0),0) end,0)
 from public.clinic_service_commission_settlements s where s.id=p_settlement and s.clinic_id=p_clinic;
$$;
revoke all on function private.service_commission_net(uuid,uuid),private.commission_recovery_limit(uuid,uuid) from public,anon,authenticated,service_role;

create or replace function public.ops_commission_settle(p_clinic uuid,p_act uuid,p_method text,p_reference text,p_operation text)
returns uuid language plpgsql security definer set search_path='' as $$
declare a public.clinic_service_acts;v_sale uuid;v_id uuid;fp jsonb;net numeric;
begin
 if auth.uid() is null or not private.has_clinic_role(p_clinic,array['admin']) then raise exception 'admin_required';end if;
 perform private.permission_require(p_clinic,'service.manage');
 perform private.medication_lock(p_clinic);
 perform 1 from public.clinic_members where clinic_id=p_clinic and user_id=auth.uid() for share;
 if not found then raise exception 'access_denied';end if;
 if p_method not in ('efectivo','transferencia','otro') or length(coalesce(p_reference,''))>150 then raise exception 'invalid_settlement';end if;
 fp=jsonb_build_object('kind','commission_settlement','act',p_act,'method',p_method,'reference',coalesce(p_reference,''));
 v_id=private.vet_receipt(p_clinic,p_operation,fp);if v_id is not null then return v_id;end if;
 select * into a from public.clinic_service_acts where clinic_id=p_clinic and id=p_act for update;
 if not found or a.commission<=0 then raise exception 'commission_act_required';end if;
 select s.id into v_sale from public.inventory_sale_lines l
 join public.inventory_sales s on s.id=l.sale_id and s.clinic_id=p_clinic
 where l.clinic_id=p_clinic and l.service_act_id=p_act
 and not exists(select 1 from public.inventory_sale_reversals r where r.sale_id=s.id)
 limit 1 for update of s;
 if v_sale is null then raise exception 'sale_not_collected';end if;
 -- The reversal row can commit while the sale lock was waiting. Read again
 -- after acquiring the lock, in a new READ COMMITTED statement.
 if exists(select 1 from public.inventory_sale_reversals where clinic_id=p_clinic and sale_id=v_sale) then raise exception 'sale_not_collected';end if;
 if not private.sale_fully_collected(v_sale,p_clinic) then raise exception 'sale_not_collected';end if;
 net=private.service_commission_net(p_act,p_clinic);
 if net<=0 then raise exception 'commission_act_required';end if;
 if exists(select 1 from public.clinic_service_commission_settlements x where x.clinic_id=p_clinic and x.service_act_id=p_act) then raise exception 'commission_already_settled';end if;
 insert into public.clinic_service_commission_settlements(clinic_id,service_act_id,professional_id,sale_id,amount,method,reference,recorded_by)
 values(p_clinic,p_act,a.professional_id,v_sale,net,p_method,btrim(coalesce(p_reference,'')),auth.uid()) returning id into v_id;
 insert into public.audit_log(clinic_id,actor_id,action,entity_id,details)
 values(p_clinic,auth.uid(),'service_commission_settled',v_id::text,jsonb_build_object('service_act_id',p_act,'professional_id',a.professional_id,'amount',net));
 insert into private.vet_operation_receipts values(auth.uid(),p_clinic,p_operation,fp,v_id);
 return v_id;
end$$;

create or replace function public.ops_commission_recovery(p_clinic uuid,p_settlement uuid,p_amount text,
 p_method text,p_reference text,p_reason text,p_operation text)
returns uuid language plpgsql security definer set search_path='' as $$
declare s public.clinic_service_commission_settlements;amount numeric;received numeric;fp jsonb;receipt uuid;maximum numeric;
begin
 if auth.uid() is null or not private.has_clinic_role(p_clinic,array['admin']) then raise exception 'admin_required';end if;
 perform private.permission_require(p_clinic,'service.manage');
 perform 1 from public.clinic_members where clinic_id=p_clinic and user_id=auth.uid() for share;
 if not found then raise exception 'access_denied';end if;
 if p_method is null or p_method not in ('efectivo','transferencia','otro')
 or length(coalesce(p_reference,''))>150 or coalesce(length(btrim(p_reason)),0) not between 1 and 1000
 then raise exception 'invalid_commission_recovery';end if;
 amount=private.inv_money(p_amount);
 if amount is null or amount<=0 then raise exception 'positive_amount_required';end if;
 perform private.medication_lock(p_clinic);
 select * into s from public.clinic_service_commission_settlements
 where clinic_id=p_clinic and id=p_settlement for update;
 if not found then raise exception 'settlement_required';end if;
 fp=jsonb_build_object('kind','commission_recovery','settlement',p_settlement,'amount',amount,
  'method',p_method,'reference',coalesce(p_reference,''),'reason',btrim(p_reason));
 receipt=private.vet_receipt(p_clinic,p_operation,fp);if receipt is not null then return receipt;end if;
 maximum=private.commission_recovery_limit(s.id,p_clinic);
 if maximum<=0 then raise exception 'reversed_sale_required';end if;
 select coalesce(sum(r.amount),0) into received from public.clinic_service_commission_recoveries r
 where r.clinic_id=p_clinic and r.settlement_id=s.id;
 if received+amount>maximum then raise exception 'recovery_exceeds_settlement';end if;
 insert into public.clinic_service_commission_recoveries(clinic_id,settlement_id,amount,method,reference,reason,recorded_by)
 values(p_clinic,s.id,amount,p_method,btrim(coalesce(p_reference,'')),btrim(p_reason),auth.uid()) returning id into receipt;
 insert into public.audit_log(clinic_id,actor_id,action,entity_id,details)
 values(p_clinic,auth.uid(),'service_commission_recovery_recorded',receipt::text,
 jsonb_build_object('settlement_id',s.id,'amount',amount,'method',p_method));
 insert into private.vet_operation_receipts values(auth.uid(),p_clinic,p_operation,fp,receipt);
 return receipt;
end$$;
alter function public.ops_commission_account(uuid,integer) set schema private;
alter function private.ops_commission_account(uuid,integer) rename to commission_account_before_credit;
revoke all on function private.commission_account_before_credit(uuid,integer) from public,anon,authenticated,service_role;
create function public.ops_commission_account(p_clinic uuid,p_offset integer default 0) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare base jsonb;items jsonb;is_admin boolean;outstanding numeric;awaiting numeric;
begin
 base=private.commission_account_before_credit(p_clinic,p_offset);
 is_admin=private.has_clinic_role(p_clinic,array['admin']);
 select coalesce(jsonb_agg(item||jsonb_build_object('original_commission',item->>'commission',
 'commission',private.service_commission_net((item->>'id')::uuid,p_clinic)::text,
 'sale_collected',exists(select 1 from public.inventory_sale_lines l where l.clinic_id=p_clinic and l.service_act_id=(item->>'id')::uuid and private.sale_fully_collected(l.sale_id,p_clinic)),
 'recovery_limit',coalesce(private.commission_recovery_limit((item->>'settlement_id')::uuid,p_clinic),0)::text
 ) order by ord),'[]') into items from jsonb_array_elements(base->'items') with ordinality as x(item,ord);
 select coalesce(sum(net) filter(where collected),0),coalesce(sum(net) filter(where not collected),0) into outstanding,awaiting
 from (select private.service_commission_net(a.id,p_clinic) net,
 exists(select 1 from public.inventory_sale_lines l where l.clinic_id=p_clinic and l.service_act_id=a.id and private.sale_fully_collected(l.sale_id,p_clinic)) collected
 from public.clinic_service_acts a where a.clinic_id=p_clinic and a.commission>0 and (is_admin or a.professional_id=auth.uid())
 and not exists(select 1 from public.clinic_service_commission_settlements x where x.clinic_id=p_clinic and x.service_act_id=a.id)) q;
 return base||jsonb_build_object('items',items,'outstanding',outstanding::text,'awaiting_collection',awaiting::text,'adjustment_supported',true);
end$$;
revoke all on function public.ops_commission_account(uuid,integer),public.ops_commission_settle(uuid,uuid,text,text,text),public.ops_commission_recovery(uuid,uuid,text,text,text,text,text) from public,anon,authenticated,service_role;
grant execute on function public.ops_commission_account(uuid,integer),public.ops_commission_settle(uuid,uuid,text,text,text),public.ops_commission_recovery(uuid,uuid,text,text,text,text,text) to authenticated;
select private.beta_install_guards();
notify pgrst,'reload schema';
commit;

-- Candidate only. Requires applied 13B5/13B6 and the explicit backup contract.
begin;
alter table public.clinic_service_commission_settlements
 add constraint commission_settlement_clinic_identity unique(clinic_id,id);
create table public.clinic_service_commission_recoveries (
 id uuid primary key default gen_random_uuid(),
 clinic_id uuid not null,
 settlement_id uuid not null,
 amount numeric(18,2) not null check(amount>0),
 method text not null check(method in ('efectivo','transferencia','otro')),
 reference text not null default '' check(length(reference)<=150),
 reason text not null check(length(btrim(reason)) between 1 and 1000),
 recorded_by uuid not null references auth.users(id),
 recorded_at timestamptz not null default clock_timestamp(),
 foreign key(clinic_id,settlement_id) references public.clinic_service_commission_settlements(clinic_id,id)
);
create index commission_recoveries_settlement on public.clinic_service_commission_recoveries(clinic_id,settlement_id,recorded_at);
create index commission_recoveries_recorder on public.clinic_service_commission_recoveries(recorded_by);
alter table public.clinic_service_commission_recoveries enable row level security;
revoke all on public.clinic_service_commission_recoveries from public,anon,authenticated,service_role;
create trigger commission_recovery_immutable before update or delete on public.clinic_service_commission_recoveries
 for each row execute function private.inv_history_guard();

create function public.ops_commission_recovery(p_clinic uuid,p_settlement uuid,p_amount text,
 p_method text,p_reference text,p_reason text,p_operation text)
returns uuid language plpgsql security definer set search_path='' as $$
declare s public.clinic_service_commission_settlements;amount numeric;received numeric;fp jsonb;receipt uuid;
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
 select * into s from public.clinic_service_commission_settlements
 where clinic_id=p_clinic and id=p_settlement for update;
 if not found then raise exception 'settlement_required';end if;
 fp=jsonb_build_object('kind','commission_recovery','settlement',p_settlement,'amount',amount,
  'method',p_method,'reference',coalesce(p_reference,''),'reason',btrim(p_reason));
 receipt=private.vet_receipt(p_clinic,p_operation,fp);if receipt is not null then return receipt;end if;
 if not exists(select 1 from public.inventory_sale_reversals where clinic_id=p_clinic and sale_id=s.sale_id)
 then raise exception 'reversed_sale_required';end if;
 select coalesce(sum(r.amount),0) into received from public.clinic_service_commission_recoveries r
 where r.clinic_id=p_clinic and r.settlement_id=s.id;
 if received+amount>s.amount then raise exception 'recovery_exceeds_settlement';end if;
 insert into public.clinic_service_commission_recoveries(clinic_id,settlement_id,amount,method,reference,reason,recorded_by)
 values(p_clinic,s.id,amount,p_method,btrim(coalesce(p_reference,'')),btrim(p_reason),auth.uid()) returning id into receipt;
 insert into public.audit_log(clinic_id,actor_id,action,entity_id,details)
 values(p_clinic,auth.uid(),'service_commission_recovery_recorded',receipt::text,
 jsonb_build_object('settlement_id',s.id,'amount',amount,'method',p_method));
 insert into private.vet_operation_receipts values(auth.uid(),p_clinic,p_operation,fp,receipt);
 return receipt;
end$$;
revoke all on function public.ops_commission_recovery(uuid,uuid,text,text,text,text,text) from public,anon,authenticated,service_role;
grant execute on function public.ops_commission_recovery(uuid,uuid,text,text,text,text,text) to authenticated;

alter function public.ops_commission_account(uuid,integer) set schema private;
alter function private.ops_commission_account(uuid,integer) rename to commission_account_before_recovery;
revoke all on function private.commission_account_before_recovery(uuid,integer) from public,anon,authenticated,service_role;
create function public.ops_commission_account(p_clinic uuid,p_offset integer default 0) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare base jsonb;items jsonb;begin
 base=private.commission_account_before_recovery(p_clinic,p_offset);
 select coalesce(jsonb_agg(item||jsonb_build_object(
  'settlement_sale_reversed',exists(select 1 from public.clinic_service_commission_settlements s
   join public.inventory_sale_reversals r on r.sale_id=s.sale_id and r.clinic_id=s.clinic_id
   where s.clinic_id=p_clinic and s.id=(item->>'settlement_id')::uuid),
  'recovered_amount',coalesce((select sum(r.amount) from public.clinic_service_commission_recoveries r
   where r.clinic_id=p_clinic and r.settlement_id=(item->>'settlement_id')::uuid),0)::text,
  'recoveries',coalesce((select jsonb_agg(to_jsonb(q) order by q.recorded_at desc,q.id) from (
   select id,amount::text,method,reference,reason,recorded_at from public.clinic_service_commission_recoveries r
   where r.clinic_id=p_clinic and r.settlement_id=(item->>'settlement_id')::uuid
   order by r.recorded_at desc,r.id limit 20) q),'[]'::jsonb)
 ) order by ord),'[]'::jsonb) into items
 from jsonb_array_elements(base->'items') with ordinality as x(item,ord);
 return base||jsonb_build_object('items',items,'recovery_supported',true);
end$$;
revoke all on function public.ops_commission_account(uuid,integer) from public,anon,authenticated,service_role;
grant execute on function public.ops_commission_account(uuid,integer) to authenticated;

-- Keep the existing authorization and snapshot chain; include both financial ledgers.
alter function public.clinic_export(uuid) set schema private;
alter function private.clinic_export(uuid) rename to clinic_export_before_commission_recovery;
revoke all on function private.clinic_export_before_commission_recovery(uuid) from public,anon,authenticated,service_role;
create function public.clinic_export(p_clinic uuid) returns text
language plpgsql security definer set search_path='' as $$
declare snapshot jsonb;begin
 snapshot=private.clinic_export_before_commission_recovery(p_clinic)::jsonb;
 snapshot=jsonb_set(snapshot,'{tables,clinic_service_commission_settlements}',
  (select coalesce(jsonb_agg(to_jsonb(s)),'[]'::jsonb) from public.clinic_service_commission_settlements s where s.clinic_id=p_clinic));
 snapshot=jsonb_set(snapshot,'{tables,clinic_service_commission_recoveries}',
  (select coalesce(jsonb_agg(to_jsonb(r)),'[]'::jsonb) from public.clinic_service_commission_recoveries r where r.clinic_id=p_clinic));
 return snapshot::text;
end$$;
revoke all on function public.clinic_export(uuid) from public,anon,authenticated,service_role;
grant execute on function public.clinic_export(uuid) to authenticated;
select private.beta_install_guards();
notify pgrst,'reload schema';
commit;

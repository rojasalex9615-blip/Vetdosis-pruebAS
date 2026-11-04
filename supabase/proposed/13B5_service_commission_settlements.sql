-- Apply after 13B4. A settlement records a payment already made to one worker.
begin;
create table public.clinic_service_commission_settlements (
 id uuid primary key default gen_random_uuid(),
 clinic_id uuid not null,
 service_act_id uuid not null,
 professional_id uuid not null references auth.users(id),
 sale_id uuid not null,
 amount numeric(18,2) not null check(amount>0),
 method text not null check(method in ('efectivo','transferencia','otro')),
 reference text not null default '' check(length(reference)<=150),
 recorded_by uuid not null references auth.users(id),
 recorded_at timestamptz not null default clock_timestamp(),
 unique(clinic_id,service_act_id),
 foreign key(clinic_id,service_act_id) references public.clinic_service_acts(clinic_id,id),
 foreign key(clinic_id,sale_id) references public.inventory_sales(clinic_id,id)
);
create index clinic_service_commission_settlements_worker
 on public.clinic_service_commission_settlements(clinic_id,professional_id,recorded_at desc);
create index clinic_service_commission_acts_worker
 on public.clinic_service_acts(clinic_id,professional_id,created_at desc) where commission>0;
create index clinic_service_commission_sale_lines
 on public.inventory_sale_lines(clinic_id,service_act_id) where service_act_id is not null;
alter table public.clinic_service_commission_settlements enable row level security;
revoke all on public.clinic_service_commission_settlements from public,anon,authenticated;
create trigger clinic_service_commission_settlement_immutable
 before update or delete on public.clinic_service_commission_settlements
 for each row execute function private.inv_history_guard();

create function public.ops_commission_account(p_clinic uuid,p_offset integer default 0) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare is_admin boolean;
begin
 if auth.uid() is null or not private.has_clinic_role(p_clinic) then raise exception 'access_denied';end if;
 if p_offset is null or p_offset<0 or p_offset>100000 then raise exception 'invalid_offset';end if;
 is_admin=private.has_clinic_role(p_clinic,array['admin']);
 return jsonb_build_object(
  'outstanding',coalesce((select sum(a.commission) from public.clinic_service_acts a
   where a.clinic_id=p_clinic and a.commission>0 and (is_admin or a.professional_id=auth.uid())
   and not exists(select 1 from public.clinic_service_commission_settlements x where x.clinic_id=p_clinic and x.service_act_id=a.id)
   and exists(select 1 from public.inventory_sale_lines l
    where l.clinic_id=p_clinic and l.service_act_id=a.id
    and not exists(select 1 from public.inventory_sale_reversals r where r.sale_id=l.sale_id))),0)::text,
  'awaiting_collection',coalesce((select sum(a.commission) from public.clinic_service_acts a
   where a.clinic_id=p_clinic and a.commission>0 and (is_admin or a.professional_id=auth.uid())
   and not exists(select 1 from public.clinic_service_commission_settlements x where x.clinic_id=p_clinic and x.service_act_id=a.id)
   and not exists(select 1 from public.inventory_sale_lines l
    where l.clinic_id=p_clinic and l.service_act_id=a.id
    and not exists(select 1 from public.inventory_sale_reversals r where r.sale_id=l.sale_id))),0)::text,
  'items',coalesce((select jsonb_agg(to_jsonb(q) order by q.is_settled,q.service_at desc,q.id) from (
   select a.id,a.name as service_name,a.professional_id,
    coalesce(n.name,a.professional_id::text) as professional_name,a.commission::text,
    a.created_at as service_at,x.id as settlement_id,x.recorded_at as settled_at,
    x.amount::text as settled_amount,x.method as settlement_method,x.id is not null as is_settled,
    exists(select 1 from public.inventory_sale_lines l where l.clinic_id=p_clinic and l.service_act_id=a.id
     and not exists(select 1 from public.inventory_sale_reversals r where r.sale_id=l.sale_id)) as sale_collected
   from public.clinic_service_acts a
   left join public.clinic_service_commission_settlements x on x.clinic_id=a.clinic_id and x.service_act_id=a.id
   left join public.staff_display_names n on n.clinic_id=a.clinic_id and n.user_id=a.professional_id
   where a.clinic_id=p_clinic and a.commission>0 and (is_admin or a.professional_id=auth.uid())
   order by x.id is not null,a.created_at desc,a.id limit 200 offset p_offset
  ) q),'[]'::jsonb));
end$$;

create function public.ops_commission_settle(p_clinic uuid,p_act uuid,p_method text,p_reference text,p_operation text)
returns uuid language plpgsql security definer set search_path='' as $$
declare a public.clinic_service_acts;v_sale uuid;v_id uuid;fp jsonb;
begin
 if auth.uid() is null or not private.has_clinic_role(p_clinic,array['admin']) then raise exception 'admin_required';end if;
 perform private.permission_require(p_clinic,'service.manage');
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
 if exists(select 1 from public.clinic_service_commission_settlements x where x.clinic_id=p_clinic and x.service_act_id=p_act) then raise exception 'commission_already_settled';end if;
 insert into public.clinic_service_commission_settlements(clinic_id,service_act_id,professional_id,sale_id,amount,method,reference,recorded_by)
 values(p_clinic,p_act,a.professional_id,v_sale,a.commission,p_method,btrim(coalesce(p_reference,'')),auth.uid()) returning id into v_id;
 insert into public.audit_log(clinic_id,actor_id,action,entity_id,details)
 values(p_clinic,auth.uid(),'service_commission_settled',v_id::text,jsonb_build_object('service_act_id',p_act,'professional_id',a.professional_id,'amount',a.commission));
 insert into private.vet_operation_receipts values(auth.uid(),p_clinic,p_operation,fp,v_id);
 return v_id;
end$$;
revoke all on function public.ops_commission_account(uuid,integer),public.ops_commission_settle(uuid,uuid,text,text,text) from public,anon;
grant execute on function public.ops_commission_account(uuid,integer),public.ops_commission_settle(uuid,uuid,text,text,text) to authenticated;
notify pgrst,'reload schema';
commit;

-- Additive corrective patch for appointment billing.
-- Apply only after patient_contacts_appointment_links_v1.sql and the inventory credit/return contracts.
-- Payment is first reconciled at sale level, then allocated to all net sale lines in integer-cent
-- increments using a deterministic cumulative allocation. Product returns therefore change the
-- allocation denominator, and line-level rounding cannot lose cents.
-- This file changes only the endpoint function; it does not rewrite historical ledger records.
begin;
create or replace function public.appointment_patient_links(p_clinic uuid,p_appointments uuid[])
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare contacts boolean;finance boolean;begin
 perform private.permission_require(p_clinic,'appointment.read');
 if p_appointments is null or cardinality(p_appointments)>100 then raise exception 'appointment_batch_required';end if;
 contacts=private.permission_effective(p_clinic,auth.uid(),'patient.read') is not null
  and exists(select 1 from public.clinic_members where clinic_id=p_clinic and user_id=auth.uid() and role::text in ('admin','mvz','recepcion'));
 finance=private.permission_effective(p_clinic,auth.uid(),'sales.read') is not null
  and private.permission_effective(p_clinic,auth.uid(),'inventory.read') is not null;
 return jsonb_build_object('schema_version',1,'clinic_id',p_clinic,
 'appointments',coalesce((select jsonb_agg(jsonb_build_object('appointment_id',a.id,
  'contact',case when contacts and o.id is not null then jsonb_build_object(
    'id',o.id,'name',o.name,'phone',o.phone,'phone_alt',o.phone_alt,'address',o.address,
    'contact_name',o.contact_name,'contact_phone',o.contact_phone,'contact_authorized',o.contact_authorized) else null end,
  'billing',case when not finance then null else (
    select jsonb_build_object('total',coalesce(sum(c.price),0)::text,'paid',coalesce(sum(c.paid),0)::text,
      'charge_count',count(*),'state',case when count(*)=0 then 'no_charge'
        when bool_or(c.paid>c.price or c.paid<0) then 'review'
        when sum(c.paid)=sum(c.price) then 'paid' when sum(c.paid)=0 then 'unpaid' else 'partial' end)
    from (
      select greatest(act.price-coalesce(b.returned_amount,0),0) as price,
        least(greatest(act.price-coalesce(b.returned_amount,0),0),coalesce(b.paid,0)) as paid
      from public.clinic_service_acts act
      left join lateral (
        with relevant_sales as (
          select distinct linked_line.clinic_id,linked_line.sale_id
          from public.inventory_sale_lines linked_line
          join public.clinic_service_acts linked_act
            on linked_act.clinic_id=linked_line.clinic_id
           and linked_act.id=linked_line.service_act_id
          where linked_line.clinic_id=p_clinic
            and linked_line.kind='servicio'
            and linked_act.appointment_id=a.id
        ), line_returns as (
          select r.clinic_id,r.sale_id,r.line_id,
            coalesce(sum(r.amount),0)::numeric as returned_amount,
            coalesce(sum(r.refund_amount),0)::numeric as refunded_amount
          from public.inventory_sale_returns r
          where r.clinic_id=p_clinic
            and exists(select 1 from relevant_sales rs where rs.clinic_id=r.clinic_id and rs.sale_id=r.sale_id)
          group by r.clinic_id,r.sale_id,r.line_id
        ), sale_returns as (
          select r.clinic_id,r.sale_id,
            coalesce(sum(r.amount),0)::numeric as returned_amount,
            coalesce(sum(r.refund_amount),0)::numeric as refunded_amount
          from public.inventory_sale_returns r
          where r.clinic_id=p_clinic
            and exists(select 1 from relevant_sales rs where rs.clinic_id=r.clinic_id and rs.sale_id=r.sale_id)
          group by r.clinic_id,r.sale_id
        ), raw_lines as (
          select l.id,l.sale_id,l.clinic_id,l.service_act_id,l.kind,l.total,
            coalesce(lr.returned_amount,0)::numeric as returned_amount,
            coalesce(lr.refunded_amount,0)::numeric as line_refunded_amount,
            greatest(l.total-coalesce(lr.returned_amount,0),0)::numeric as net_line,
            s.total::numeric as sale_total,
            coalesce(sr.returned_amount,0)::numeric as sale_returned_amount,
            coalesce(sr.refunded_amount,0)::numeric as sale_refunded_amount,
            exists(select 1 from public.inventory_credit_accounts ca
              where ca.clinic_id=s.clinic_id and ca.sale_id=s.id) as is_credit,
            coalesce((select sum(sc.amount)::numeric from public.inventory_sale_collections sc
              where sc.clinic_id=s.clinic_id and sc.sale_id=s.id),0)::numeric as collected_amount
          from public.inventory_sale_lines l
          join public.inventory_sales s on s.id=l.sale_id and s.clinic_id=l.clinic_id
          join relevant_sales rs on rs.clinic_id=l.clinic_id and rs.sale_id=l.sale_id
          left join line_returns lr on lr.clinic_id=l.clinic_id and lr.sale_id=l.sale_id and lr.line_id=l.id
          left join sale_returns sr on sr.clinic_id=s.clinic_id and sr.sale_id=s.id
          where l.clinic_id=p_clinic
            and not exists(select 1 from public.inventory_sale_reversals rev
              where rev.clinic_id=p_clinic and rev.sale_id=s.id)
        ), sale_line_totals as (
          select rl.*,
            greatest(rl.sale_total-rl.sale_returned_amount,0)::numeric as sale_net_total,
            case when rl.is_credit then rl.collected_amount else rl.sale_total end::numeric as raw_paid,
            sum(rl.net_line) over(partition by rl.clinic_id,rl.sale_id)::numeric as net_lines_total
          from raw_lines rl
        ), effective_lines as (
          select slt.*,
            least(slt.net_lines_total,
              greatest(slt.sale_net_total -
                greatest(slt.sale_net_total-slt.raw_paid+slt.sale_refunded_amount,0),0)
            )::numeric as effective_paid
          from sale_line_totals slt
        ), cumulative_lines as (
          select el.*,
            coalesce(sum(el.net_line) over(partition by el.clinic_id,el.sale_id
              order by el.id rows between unbounded preceding and 1 preceding),0)::numeric as prior_net_line,
            sum(el.net_line) over(partition by el.clinic_id,el.sale_id
              order by el.id rows between unbounded preceding and current row)::numeric as cumulative_net_line
          from effective_lines el
        ), allocated_lines as (
          select cl.*,
            (round(cl.effective_paid*cl.cumulative_net_line/nullif(cl.net_lines_total,0),2)
             - round(cl.effective_paid*cl.prior_net_line/nullif(cl.net_lines_total,0),2))::numeric as allocated_paid
          from cumulative_lines cl
        )
        select
          coalesce(sum(al.returned_amount) filter(where al.kind='servicio' and al.service_act_id=act.id),0)::numeric as returned_amount,
          coalesce(sum(al.allocated_paid) filter(where al.kind='servicio' and al.service_act_id=act.id),0)::numeric as paid
        from allocated_lines al
      ) b on true
      where act.clinic_id=p_clinic and act.appointment_id=a.id
    ) c
  ) end)) from public.clinic_appointments a
  left join public.vet_patients p on p.clinic_id=a.clinic_id and p.id=a.patient_id
  left join public.vet_owners o on o.clinic_id=p.clinic_id and o.id=p.owner_id
  where a.clinic_id=p_clinic and a.id=any(p_appointments)),'[]'));
end$$;
revoke all on function public.appointment_patient_links(uuid,uuid[]) from public,anon;
grant execute on function public.appointment_patient_links(uuid,uuid[]) to authenticated;
notify pgrst,'reload schema';
commit;

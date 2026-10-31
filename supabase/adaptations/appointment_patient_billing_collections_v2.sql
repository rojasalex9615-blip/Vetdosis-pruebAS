-- Additive corrective patch for appointment billing.
-- Apply only after patient_contacts_appointment_links_v1.sql and the inventory credit/return contracts.
-- Collections are stored per sale, so mixed-sale collections are allocated proportionally to linked service lines.
-- This file changes only the endpoint function; it does not rewrite the historical contact patch.
begin;
create function public.appointment_patient_links(p_clinic uuid,p_appointments uuid[])
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
        select coalesce(sum(ret.amount),0) as returned_amount,
          coalesce(sum(least(greatest(l.total-coalesce(ret.amount,0),0),
            greatest(least(l.total,case
              when s.total>0 then round(l.total*(case when exists(
                select 1 from public.inventory_credit_accounts ca
                where ca.clinic_id=s.clinic_id and ca.sale_id=s.id)
                then coalesce((select sum(sc.amount) from public.inventory_sale_collections sc
                  where sc.clinic_id=s.clinic_id and sc.sale_id=s.id),0)
                else s.total end)/s.total,2)
              else 0 end)-coalesce(ret.refund_amount,0),0))),0) as paid
        from public.inventory_sale_lines l
        join public.inventory_sales s on s.id=l.sale_id and s.clinic_id=l.clinic_id
        left join lateral (
          select coalesce(sum(r.amount),0) as amount,coalesce(sum(r.refund_amount),0) as refund_amount
          from public.inventory_sale_returns r
          where r.clinic_id=l.clinic_id and r.sale_id=l.sale_id and r.line_id=l.id
        ) ret on true
        where l.clinic_id=p_clinic and l.kind='servicio' and l.service_act_id=act.id
          and not exists(select 1 from public.inventory_sale_reversals rev
            where rev.clinic_id=p_clinic and rev.sale_id=s.id)
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

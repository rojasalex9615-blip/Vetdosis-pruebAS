-- Candidate after 13F and vial reconciliation retry candidate. Read-only overview.
begin;
alter function public.rx_vials(uuid) set schema private;
alter function private.rx_vials(uuid) rename to vials_before_incident_overview;
revoke all on function private.vials_before_incident_overview(uuid) from public,anon,authenticated,service_role;
create function public.rx_vials(p_clinic uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare base jsonb;result jsonb;begin
 -- Preserve the existing current vial.read check and movement/clinical filtering.
 base=private.vials_before_incident_overview(p_clinic);
 select coalesce(jsonb_agg(v||jsonb_build_object(
 'incidents_supported',true,
 'has_post_close_movements',exists(select 1 from public.medication_vial_movements m
 join public.medication_vial_reconciliations c on c.vial_id=m.vial_id and c.clinic_id=m.clinic_id
 where m.clinic_id=p_clinic and m.vial_id=(v->>'id')::uuid and m.created_at>c.created_at),
 'incidents',preview.items,
 'more_incidents',preview.total>100
 ) order by ord),'[]') into result
 from jsonb_array_elements(base) with ordinality as entries(v,ord)
 cross join lateral (
  select coalesce(jsonb_agg(jsonb_build_object('id',q.id,'case_id',q.case_id,'quantity',q.quantity::text,
   'unit',q.unit,'incidence',q.incidence,'observed_at',q.observed_at,'reported_at',q.reported_at)
   order by q.reported_at desc,q.id) filter(where q.position<=100),'[]') items,count(*) total
  from (select r.id,r.case_id,r.quantity,r.unit,r.incidence,r.observed_at,r.reported_at,
   row_number() over(order by r.reported_at desc,r.id) as position
   from public.medication_records r join public.clinical_cases c on c.id=r.case_id and c.clinic_id=r.clinic_id
   where r.clinic_id=p_clinic and r.vial_id=(v->>'id')::uuid and r.incidence<>''
   and private.clinical_readable(c)
   and not exists(select 1 from public.medication_records replacement where replacement.replaces_id=r.id and replacement.clinic_id=r.clinic_id)
   order by r.reported_at desc,r.id limit 101) q
 ) preview;
 return result;
end$$;
revoke all on function public.rx_vials(uuid) from public,anon,authenticated,service_role;
grant execute on function public.rx_vials(uuid) to authenticated;
select private.beta_install_guards();
notify pgrst,'reload schema';
commit;

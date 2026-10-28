-- Candidate after 13F; preserves authorization, immutable closure and historical receipt fingerprints.
begin;
create or replace function public.rx_vial_close(p_id uuid,p_measured text,p_reason text,p_operation text) returns uuid language plpgsql security definer set search_path='' as $$
declare v public.medication_vials;id uuid;fp jsonb;measured numeric;expected numeric;difference numeric;g uuid;
begin
 select clinic_id into v.clinic_id from public.medication_vials where medication_vials.id=p_id;
 perform private.medication_lock(v.clinic_id);g=private.hospital_order_permission(v.clinic_id,'vial.manage',null,true);
 select * into v from public.medication_vials where medication_vials.id=p_id for update;
 if not found or v.responsible_id<>auth.uid() then raise exception 'vial_responsible_required';end if;
 if p_measured is null or p_measured !~ '^\d{1,12}(\.\d{1,9})?$' then raise exception 'exact_measured_volume_required';end if;
 fp=jsonb_build_object('kind','vial_close','vial',p_id,'measured',p_measured,'reason',p_reason);id=private.vet_receipt(v.clinic_id,p_operation,fp);if id is not null then return id;end if;
 if exists(select 1 from public.medication_vial_reconciliations where vial_id=v.id and clinic_id=v.clinic_id) then raise exception 'vial_already_closed';end if;
 measured=p_measured::numeric;expected=private.rx_vial_balance(v.id);difference=measured-expected;
 if (difference<>0 or expected<0) and coalesce(length(btrim(p_reason)),0) not between 1 and 1000 then raise exception 'discrepancy_mvZ_note_required';end if;
 insert into public.medication_vial_reconciliations(clinic_id,vial_id,expected,measured,difference,reason,created_by) values(v.clinic_id,v.id,expected,measured,difference,coalesce(p_reason,''),auth.uid()) returning medication_vial_reconciliations.id into id;
 insert into private.vet_operation_receipts values(auth.uid(),v.clinic_id,p_operation,fp,id);
 insert into public.audit_log(clinic_id,actor_id,action,entity_id,details) values(v.clinic_id,auth.uid(),'medication_vial_closed_with_reconciliation',id,jsonb_build_object('permission_grant_id',g));return id;
end $$;
revoke all on function public.rx_vial_close(uuid,text,text,text) from public,anon,authenticated,service_role;
grant execute on function public.rx_vial_close(uuid,text,text,text) to authenticated;
select private.beta_install_guards();
notify pgrst,'reload schema';
commit;

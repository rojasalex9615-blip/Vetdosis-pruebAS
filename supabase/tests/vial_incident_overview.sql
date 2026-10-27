create function pg_temp.overview_assert(v boolean,msg text) returns void language plpgsql as $$begin if v is distinct from true then raise exception 'ASSERT: %',msg;end if;end$$;
create function pg_temp.overview_error(sql text,expected text) returns void language plpgsql as $$begin begin execute sql;exception when others then if position(expected in sqlerrm)>0 then return;end if;raise;end;raise exception 'Expected rejection: %',expected;end$$;
select id as clinic from public.clinics where name='Synthetic medication permissions' \gset
select id as vial from public.medication_vials where clinic_id=:'clinic' and lot='SYNTHETIC-RETRY' \gset
select id as record from public.medication_records where vial_id=:'vial' \gset
-- The prior suite revokes managing the vial; read access is independent and still current.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000151',false);
set role authenticated;
select e as row from jsonb_array_elements(public.rx_vials(:'clinic')) e where e->>'id'=:'vial' \gset
select pg_temp.overview_assert((:'row'::jsonb->>'has_post_close_movements')::boolean,'late movement warning missing');
select pg_temp.overview_assert(jsonb_array_length(:'row'::jsonb->'incidents')=1,'visible incident missing');
select pg_temp.overview_assert(:'row'::jsonb->'incidents'->0->>'id'=:'record','incident linked to wrong record');
select pg_temp.overview_assert((:'row'::jsonb->'closure'->>'expected')::numeric=10 and (:'row'::jsonb->>'balance')::numeric=8,'overview changed frozen closure or current balance');
reset role;
-- Inventory-only read is not a clinical read grant, even for an administrator.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000150',false);
set role authenticated;
select public.permission_grant(:'clinic',auth.uid(),'vial.read',null,clock_timestamp()+interval '1 day','Synthetic physical overview only') as read_grant \gset
select e as physical from jsonb_array_elements(public.rx_vials(:'clinic')) e where e->>'id'=:'vial' \gset
select pg_temp.overview_assert((:'physical'::jsonb->>'has_post_close_movements')::boolean,'physical warning hidden unnecessarily');
select pg_temp.overview_assert(jsonb_array_length(:'physical'::jsonb->'incidents')=0,'physical read exposed clinical incidents');
select pg_temp.overview_assert(jsonb_array_length(:'physical'::jsonb->'movements')=0,'physical read exposed patient record movements');
select public.permission_revoke(:'read_grant','Synthetic read revoked');
select pg_temp.overview_error(format('select public.rx_vials(%L)',:'clinic'),'explicit_permission_required');
reset role;
-- A subsequent correction supersedes the old incidence entry in the overview.
-- Direct owner fixtures below are synthetic and do not grant client mutation rights.
insert into public.medication_records(clinic_id,case_id,patient_id,product_version_id,prescription_id,hospital_task_id,vial_id,quantity,unit,route,procedure,performed_by,reported_by,responsible_id,observed_at,lot,replaces_id,correction_reason,incidence,content_hash)
select clinic_id,case_id,patient_id,product_version_id,null,null,vial_id,quantity,unit,route,procedure,performed_by,reported_by,responsible_id,observed_at,lot,id,'Synthetic corrected context','Synthetic corrected incident remains pending',repeat('e',64) from public.medication_records where id=:'record' returning id as corrected_record \gset
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000151',false);
set role authenticated;
select e as corrected from jsonb_array_elements(public.rx_vials(:'clinic')) e where e->>'id'=:'vial' \gset
select pg_temp.overview_assert(jsonb_array_length(:'corrected'::jsonb->'incidents')=1 and :'corrected'::jsonb->'incidents'->0->>'id'=:'corrected_record','overview did not select the current incident');
select pg_temp.overview_assert((:'corrected'::jsonb->>'has_post_close_movements')::boolean,'correction erased historical late movement warning');
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000153',false);
set role authenticated;
select pg_temp.overview_error(format('select public.rx_vials(%L)',:'clinic'),'explicit_permission_required');
reset role;
select pg_temp.overview_assert(not has_function_privilege('authenticated','private.vials_before_incident_overview(uuid)','EXECUTE'),'private original endpoint callable');
select pg_temp.overview_assert(not has_function_privilege('anon','public.rx_vials(uuid)','EXECUTE'),'anonymous overview allowed');

-- Bound the overview and explicitly signal truncation; full records remain in each case.
insert into public.medication_records(clinic_id,case_id,patient_id,product_version_id,vial_id,quantity,unit,route,procedure,performed_by,reported_by,responsible_id,observed_at,lot,incidence,content_hash)
select r.clinic_id,r.case_id,r.patient_id,r.product_version_id,r.vial_id,r.quantity,r.unit,r.route,r.procedure,r.performed_by,r.reported_by,r.responsible_id,r.observed_at,r.lot,'Synthetic preview limit '||n,repeat('f',64)
from public.medication_records r cross join generate_series(1,101) n where r.id=:'corrected_record';
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000151',false);
set role authenticated;
select e as limited from jsonb_array_elements(public.rx_vials(:'clinic')) e where e->>'id'=:'vial' \gset
select pg_temp.overview_assert(jsonb_array_length(:'limited'::jsonb->'incidents')=100 and (:'limited'::jsonb->>'more_incidents')::boolean,'preview truncated without notice or exceeded bound');
reset role;

select pg_temp.overview_assert((select count(*)=2 and bool_and(indisvalid and indisready) from pg_index where indexrelid in ('public.vial_movement_chronology'::regclass,'public.vial_record_incidents'::regclass)),'concurrent indexes not ready and valid');

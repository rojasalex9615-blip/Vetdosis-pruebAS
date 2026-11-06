-- Synthetic transport queue checks. No provider call or patient data leaves PostgreSQL.
create function pg_temp.delivery_assert(v boolean,msg text) returns void language plpgsql as $$
begin if v is distinct from true then raise exception 'ASSERT: %',msg;end if;end$$;
create function pg_temp.delivery_error(sql text,expected text) returns void language plpgsql as $$
begin begin execute sql;exception when others then
 if position(expected in sqlerrm)>0 then return;end if;raise;
 end;raise exception 'Expected rejection: %',expected;end$$;
select id as clinic from public.clinics where name='Synthetic medication permissions' \gset
select set_config('test.clinic',:'clinic',false);
select pg_temp.delivery_assert(not (select external_delivery_enabled from private.hospital_automation_runtime),'external transport activated');
set role service_role;
select pg_temp.delivery_assert(public.hospital_delivery_claim(20)='[]'::jsonb,'disabled delivery claimed work');
reset role;
select pg_temp.delivery_assert(private.hospital_notice_recipient(:'clinic','00000000-0000-0000-0000-000000000151',
 (select created_at from public.clinic_members where clinic_id=:'clinic' and user_id='00000000-0000-0000-0000-000000000151'),true),'synthetic MVZ not eligible');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000151',false);
set role authenticated;
select pg_temp.delivery_error($q$select public.hospital_delivery_target_set(current_setting('test.clinic')::uuid,'fcm','synthetic_device_token_123456',false)$q$,'explicit_delivery_consent_required');
select public.hospital_delivery_target_set(:'clinic','fcm','synthetic_device_token_123456',true) as fcm_target \gset
select public.hospital_delivery_target_set(:'clinic','whatsapp','+5213312345678',true) as wa_target \gset
select pg_temp.delivery_error('select public.hospital_delivery_claim(1)','permission denied');
reset role;
update private.hospital_automation_runtime set external_delivery_enabled=true;
insert into public.hospital_stays(id,clinic_id,patient_id,cage,admitted_by,admitted_at)
values('00000000-0000-0000-0000-000000000840',:'clinic','00000000-0000-0000-0000-000000000800','Synthetic delivery area','00000000-0000-0000-0000-000000000151',clock_timestamp()-interval '1 day');
insert into public.hospital_tasks(id,clinic_id,stay_id,kind,label,instructions,due_at,escalation_minutes,created_by,procedure_type_id,authority_grant_id)
select '00000000-0000-0000-0000-000000000841',:'clinic','00000000-0000-0000-0000-000000000840',
 'revision','Synthetic delivery care','Synthetic instructions',clock_timestamp()-interval '1 minute',10,
 '00000000-0000-0000-0000-000000000151',o.procedure_id,
 (select id from private.member_permission_grants where clinic_id=:'clinic'
   and user_id='00000000-0000-0000-0000-000000000151' and code='hospital.schedule'
   order by granted_at desc limit 1)
from private.hospital_daily_orders o where o.clinic_id=:'clinic' order by o.created_at limit 1;
insert into private.hospital_notices(clinic_id,task_id,route_id,stage,recipient_id,member_since)
select :'clinic','00000000-0000-0000-0000-000000000841',r.id,'mvz',r.mvz_user,r.mvz_member_since
from private.hospital_notice_routes r where r.clinic_id=:'clinic' order by r.created_at desc limit 1;
select pg_temp.delivery_assert((select count(*)=2 from private.hospital_notice_deliveries),'two consented channels not queued');
set role service_role;
select public.hospital_delivery_claim(20) as claimed \gset
select pg_temp.delivery_assert(jsonb_array_length(:'claimed'::jsonb)=2,'eligible delivery not claimed');
select pg_temp.delivery_assert(:'claimed' not like '%Synthetic delivery care%','clinical details leaked');
select public.hospital_delivery_finish((:'claimed'::jsonb->0->>'id')::uuid,true,'synthetic-provider-id',null);
select public.hospital_delivery_finish((:'claimed'::jsonb->1->>'id')::uuid,false,null,'provider_http_error');
reset role;
select pg_temp.delivery_assert((select count(*)=1 from private.hospital_notice_deliveries where status='sent'),'sent receipt missing');
select pg_temp.delivery_assert((select count(*)=1 from private.hospital_notice_deliveries where status='pending' and attempts=1),'retry missing');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000151',false);
set role authenticated;
select public.hospital_delivery_target_revoke(:'clinic',:'wa_target');
reset role;
update private.hospital_notice_deliveries set next_attempt_at=clock_timestamp()-interval '1 minute' where status='pending';
set role service_role;
select pg_temp.delivery_assert(public.hospital_delivery_claim(20)='[]'::jsonb,'revoked target was delivered');
reset role;
update private.hospital_automation_runtime set external_delivery_enabled=false;

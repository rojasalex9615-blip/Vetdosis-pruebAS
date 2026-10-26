-- Per-device consent and token rotation on the synthetic 14J fixture.
create function pg_temp.push_assert(v boolean,msg text) returns void language plpgsql as $$
begin if v is distinct from true then raise exception 'ASSERT: %',msg;end if;end$$;
create function pg_temp.push_error(sql text,expected text) returns void language plpgsql as $$
begin begin execute sql;exception when others then
 if position(expected in sqlerrm)>0 then return;end if;raise;
 end;raise exception 'Expected rejection: %',expected;end$$;
select id as clinic from public.clinics where name='Synthetic medication permissions' \gset
select set_config('test.clinic',:'clinic',false);
select id as old_target from private.hospital_delivery_targets where clinic_id=:'clinic'
 and user_id='00000000-0000-0000-0000-000000000151' and channel='fcm' and revoked_at is null \gset
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000151',false);
set role authenticated;
select pg_temp.push_assert(jsonb_array_length(public.hospital_delivery_targets_own(:'clinic'))=1,'own active target missing');
select pg_temp.push_assert(public.hospital_delivery_targets_own(:'clinic')::text not like '%synthetic_device_token%','token leaked in status');
select public.hospital_delivery_target_replace(:'clinic',:'old_target','synthetic_new_device_token_123456',true) as new_target \gset
select set_config('test.new_target',:'new_target',false);
select pg_temp.push_assert(:'new_target'<>:'old_target','refresh kept old target');
select pg_temp.push_error($q$select public.hospital_delivery_target_replace(current_setting('test.clinic')::uuid,'00000000-0000-0000-0000-000000000000','synthetic_token_1234567890',true)$q$,'own_active_fcm_target_required');
reset role;
select pg_temp.push_assert((select revoked_at is not null from private.hospital_delivery_targets where id=:'old_target'),'old token not revoked');
select pg_temp.push_assert((select count(*)=1 from private.hospital_delivery_targets where clinic_id=:'clinic' and user_id='00000000-0000-0000-0000-000000000151' and channel='fcm' and revoked_at is null),'duplicate active token');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000160',false);
set role authenticated;
select pg_temp.push_error($q$select public.hospital_delivery_target_revoke(current_setting('test.clinic')::uuid, current_setting('test.new_target')::uuid)$q$,'own_delivery_target_required');
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000151',false);
set role authenticated;
select public.hospital_delivery_target_revoke(:'clinic',:'new_target');
select pg_temp.push_assert(public.hospital_delivery_targets_own(:'clinic')='[]'::jsonb,'revoked target still shown');
reset role;

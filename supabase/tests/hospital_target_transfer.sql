-- Synthetic database only. Roll back setup and target transfers for later suites.
begin;
create function pg_temp.target_assert(v boolean,msg text) returns void language plpgsql as $$
begin if v is distinct from true then raise exception 'ASSERT: %',msg;end if;end$$;
select id as clinic from public.clinics where name='Synthetic medication permissions' \gset
select private.permission_effective(:'clinic','00000000-0000-0000-0000-000000000160','hospital.read') is null as need_read,
 private.permission_effective(:'clinic','00000000-0000-0000-0000-000000000160','hospital.report') is null as need_report \gset
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000150',false);
set role authenticated;
\if :need_read
select public.permission_grant(:'clinic','00000000-0000-0000-0000-000000000160','hospital.read',null,clock_timestamp()+interval '1 day','Synthetic transfer test');
\endif
\if :need_report
select public.permission_grant(:'clinic','00000000-0000-0000-0000-000000000160','hospital.report',null,clock_timestamp()+interval '1 day','Synthetic transfer test');
\endif
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000151',false);
set role authenticated;
select public.hospital_delivery_target_set(:'clinic','fcm','synthetic_shared_device_123456',true) as first_target \gset
select public.hospital_delivery_target_set(:'clinic','fcm','synthetic_other_device_123456',true) as other_target \gset
select public.hospital_delivery_target_set(:'clinic','whatsapp','+5213311111111',true) as first_wa \gset
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000160',false);
set role authenticated;
select public.hospital_delivery_target_set(:'clinic','fcm','synthetic_shared_device_123456',true) as second_target \gset
select public.hospital_delivery_target_set(:'clinic','whatsapp','+5213311111111',true);
reset role;
select pg_temp.target_assert((select revoked_at is not null from private.hospital_delivery_targets where id=:'first_target'),'previous device user was not revoked');
select pg_temp.target_assert((select revoked_at is null from private.hospital_delivery_targets where id=:'other_target'),'another device was revoked');
select pg_temp.target_assert((select revoked_at is null from private.hospital_delivery_targets where id=:'first_wa'),'shared WhatsApp was revoked');
select pg_temp.target_assert((select count(*)=1 from private.hospital_delivery_targets where channel='fcm' and destination='synthetic_shared_device_123456' and revoked_at is null),'multiple users share active FCM destination');

select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000151',false);
set role authenticated;
select public.hospital_delivery_target_replace(:'clinic',:'other_target','synthetic_shared_device_123456',true) as rotated \gset
reset role;
select pg_temp.target_assert((select revoked_at is not null from private.hospital_delivery_targets where id=:'second_target'),'rotation did not revoke other user');

-- Simulate an old duplicate registration: even same-token refresh must clean it.
update private.hospital_delivery_targets set revoked_at=null where id=:'second_target';
set role authenticated;
select pg_temp.target_assert(public.hospital_delivery_target_replace(:'clinic',:'rotated','synthetic_shared_device_123456',true)=:'rotated'::uuid,'same token changed target identity');
reset role;
select pg_temp.target_assert((select revoked_at is not null from private.hospital_delivery_targets where id=:'second_target'),'same-token refresh left another user active');
rollback;

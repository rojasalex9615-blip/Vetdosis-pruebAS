-- Continue after hospital_delivery.sql and 14L in an isolated test database.
create function pg_temp.delivery_assert(v boolean,msg text) returns void language plpgsql as $$
begin if v is distinct from true then raise exception 'ASSERT: %',msg;end if;end$$;
create function pg_temp.delivery_error(sql text,expected text) returns void language plpgsql as $$
begin begin execute sql;exception when others then
 if position(expected in sqlerrm)>0 then return;end if;raise;
 end;raise exception 'Expected rejection: %',expected;end$$;
update private.hospital_automation_runtime set external_delivery_enabled=true;
update private.hospital_automation_runtime
set external_delivery_started_at=(select min(created_at)-interval '1 second'
                                  from private.hospital_notices);
update private.hospital_delivery_targets set revoked_at=null
where channel='whatsapp';
update private.hospital_notice_deliveries
set status='pending',attempts=0,lease_until=null,
    next_attempt_at=clock_timestamp()-interval '1 second';
set role service_role;
select pg_temp.delivery_error(
  $$select public.hospital_delivery_claim(20,array['other']::text[])$$,
  'invalid_delivery_channels');
select public.hospital_delivery_claim(20,array['fcm']::text[]) as fcm_claimed \gset
select pg_temp.delivery_assert(
  jsonb_array_length(:'fcm_claimed'::jsonb)=1 and
  :'fcm_claimed'::jsonb->0->>'channel'='fcm',
  'FCM-only claim included another channel');
reset role;
select pg_temp.delivery_assert(
  (select count(*)=1 from private.hospital_notice_deliveries x
   join private.hospital_delivery_targets t on t.id=x.target_id
   where t.channel='whatsapp' and x.status='pending'),
  'WhatsApp work was leased without provider credentials');
set role authenticated;
select pg_temp.delivery_error(
  $$select public.hospital_delivery_claim(20,array['fcm']::text[])$$,
  'permission denied');
reset role;

-- Expired seventh attempt may be retried once, but an exhausted lease is terminal.
update private.hospital_notice_deliveries x
set status='leased',attempts=7,lease_until=clock_timestamp()-interval '1 second',
    next_attempt_at=clock_timestamp()-interval '1 second'
from private.hospital_delivery_targets t where x.target_id=t.id and t.channel='fcm';
set role service_role;
select public.hospital_delivery_claim(20,array['fcm']::text[]) as last_claim \gset
select pg_temp.delivery_assert(jsonb_array_length(:'last_claim'::jsonb)=1,'seventh attempt was not retried');
select pg_temp.delivery_assert(public.hospital_delivery_claim(20,array['fcm']::text[])='[]'::jsonb,'unexpired last lease was reclaimed');
reset role;
select pg_temp.delivery_assert((select count(*)=1 from private.hospital_notice_deliveries where status='leased' and attempts=8),'unexpired final lease was terminated');
update private.hospital_notice_deliveries set lease_until=clock_timestamp()-interval '1 second'
where status='leased' and attempts=8;
set role service_role;
select pg_temp.delivery_assert(public.hospital_delivery_claim(20,array['fcm']::text[])='[]'::jsonb,'exhausted delivery was reclaimed');
reset role;
select pg_temp.delivery_assert((select count(*)=1 from private.hospital_notice_deliveries
 where status='dead' and attempts=8 and lease_until is null and error_code='lease_expired'),'exhausted expired lease was not finalized');
select pg_temp.delivery_assert((select count(*)=1 from private.hospital_notice_deliveries x
 join private.hospital_delivery_targets t on t.id=x.target_id
 where t.channel='whatsapp' and x.status='pending'),'another channel was altered');

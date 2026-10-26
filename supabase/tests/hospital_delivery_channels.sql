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

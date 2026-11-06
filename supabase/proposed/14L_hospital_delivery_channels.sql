-- Restrict claims to channels whose provider credentials are configured.
-- Apply after 14K, before enabling external delivery.
begin;
drop function public.hospital_delivery_claim(integer);
create function public.hospital_delivery_claim(p_limit integer,p_channels text[])
returns jsonb language plpgsql security definer set search_path='' as $$
declare d record;result jsonb:='[]'::jsonb;begin
 if not (select external_delivery_enabled and external_delivery_started_at is not null
         from private.hospital_automation_runtime) then
  return result;
 end if;
 if p_limit is null or p_limit not between 1 and 50 then raise exception 'invalid_claim_limit';end if;
 if p_channels is null or cardinality(p_channels)=0 or exists(
  select 1 from unnest(p_channels) as channel
  where channel is null or channel not in ('fcm','whatsapp')
 ) then raise exception 'invalid_delivery_channels';end if;
 for d in
  select x.id,x.attempts,t.channel,t.destination,n.clinic_id,n.recipient_id
  from private.hospital_notice_deliveries x
  join private.hospital_notices n on n.id=x.notice_id
  join private.hospital_delivery_targets t on t.id=x.target_id
  join public.hospital_tasks h on h.id=n.task_id and h.clinic_id=n.clinic_id
  join public.hospital_stays s on s.id=h.stay_id and s.clinic_id=n.clinic_id
  where x.status in ('pending','leased') and x.next_attempt_at<=clock_timestamp()
    and (x.status='pending' or x.lease_until<clock_timestamp())
    and x.attempts<8 and t.channel=any(p_channels) and t.revoked_at is null and x.created_at>=t.consent_at
    and n.created_at >= (select external_delivery_started_at from private.hospital_automation_runtime)
    and t.clinic_id=n.clinic_id and t.user_id=n.recipient_id
    and t.member_since=n.member_since
    and private.hospital_notice_recipient(n.clinic_id,n.recipient_id,n.member_since,n.stage='mvz')
    and h.state='pending' and s.discharged_at is null
    and not exists(select 1 from private.hospital_notice_responses a
      join private.hospital_notices responded on responded.id=a.notice_id
      where responded.task_id=n.task_id)
  order by x.next_attempt_at,x.id
  for update of x skip locked limit p_limit
 loop
  update private.hospital_notice_deliveries
  set status='leased',attempts=d.attempts+1,lease_until=clock_timestamp()+interval '2 minutes'
  where id=d.id;
  result=result||jsonb_build_array(jsonb_build_object(
   'id',d.id,'channel',d.channel,'destination',d.destination));
 end loop;
 return result;
end$$;

revoke all on function public.hospital_delivery_claim(integer,text[])
 from public,anon,authenticated,service_role;
grant execute on function public.hospital_delivery_claim(integer,text[]) to service_role;
commit;


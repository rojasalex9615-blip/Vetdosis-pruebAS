-- Apply after 14J. Let each signed-in staff member inspect/revoke their own
-- delivery targets and rotate one device token without revoking other devices.
begin;

create or replace function public.hospital_delivery_target_set(
 p_clinic uuid,p_channel text,p_destination text,p_consent boolean
) returns uuid language plpgsql security definer set search_path='' as $$
declare since timestamptz;target uuid;begin
 if auth.uid() is null or p_consent is distinct from true then
  raise exception 'explicit_delivery_consent_required';end if;
 select created_at into since from public.clinic_members
 where clinic_id=p_clinic and user_id=auth.uid();
 if since is null or not private.hospital_notice_recipient(p_clinic,auth.uid(),since,false)
 then raise exception 'current_hospital_recipient_required';end if;
 if (p_channel='whatsapp' and p_destination ~ '^\+[1-9][0-9]{7,14}$')
    or (p_channel='fcm' and length(p_destination) between 20 and 4096
        and p_destination ~ '^[A-Za-z0-9:._~-]+$') then null;
 else raise exception 'invalid_delivery_destination';end if;
 if p_channel='fcm' then
  perform pg_advisory_xact_lock(hashtextextended(p_destination,9072));
  update private.hospital_delivery_targets set revoked_at=clock_timestamp()
  where channel='fcm' and destination=p_destination
    and user_id<>auth.uid() and revoked_at is null;
 end if;
 insert into private.hospital_delivery_targets
 (clinic_id,user_id,member_since,channel,destination)
 values(p_clinic,auth.uid(),since,p_channel,p_destination)
 on conflict(clinic_id,user_id,channel,destination)
 do update set member_since=excluded.member_since,revoked_at=null,
               consent_at=clock_timestamp()
 returning id into target;
 return target;
end$$;

create function public.hospital_delivery_targets_own(p_clinic uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not exists(
   select 1 from public.clinic_members m
   where m.clinic_id=p_clinic and m.user_id=auth.uid()
 ) then raise exception 'current_clinic_member_required';end if;
 return (select coalesce(jsonb_agg(jsonb_build_object(
   'id',t.id,'channel',t.channel,'label',case when t.channel='fcm'
     then 'Teléfono registrado' else 'WhatsApp ····'||right(t.destination,4) end,
   'consent_at',t.consent_at,'created_at',t.created_at)
   order by t.created_at,t.id),'[]'::jsonb)
 from private.hospital_delivery_targets t
 where t.clinic_id=p_clinic and t.user_id=auth.uid() and t.revoked_at is null);
end$$;

create function public.hospital_delivery_target_replace(
 p_clinic uuid,p_old_target uuid,p_new_token text,p_consent boolean
) returns uuid language plpgsql security definer set search_path='' as $$
declare old_target private.hospital_delivery_targets;new_target uuid;begin
 if auth.uid() is null or p_consent is distinct from true then
  raise exception 'explicit_delivery_consent_required';end if;
 select * into old_target from private.hospital_delivery_targets
 where id=p_old_target and clinic_id=p_clinic and user_id=auth.uid()
   and channel='fcm' and revoked_at is null for update;
 if not found then raise exception 'own_active_fcm_target_required';end if;
 if not private.hospital_notice_recipient(p_clinic,auth.uid(),old_target.member_since,false)
   then raise exception 'current_hospital_recipient_required';end if;
 if p_new_token is null or length(p_new_token) not between 20 and 4096
   or p_new_token !~ '^[A-Za-z0-9:._~-]+$'
   then raise exception 'invalid_delivery_destination';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_new_token,9072));
 update private.hospital_delivery_targets set revoked_at=clock_timestamp()
 where channel='fcm' and destination=p_new_token
   and user_id<>auth.uid() and revoked_at is null;
 if old_target.destination=p_new_token then return old_target.id;end if;
 update private.hospital_delivery_targets set revoked_at=clock_timestamp()
 where id=old_target.id;
 insert into private.hospital_delivery_targets
 (clinic_id,user_id,member_since,channel,destination)
 values(p_clinic,auth.uid(),old_target.member_since,'fcm',p_new_token)
 on conflict(clinic_id,user_id,channel,destination)
 do update set revoked_at=null,member_since=excluded.member_since,
               consent_at=clock_timestamp()
 returning id into new_target;
 return new_target;
end$$;

revoke all on function public.hospital_delivery_targets_own(uuid),
 public.hospital_delivery_target_replace(uuid,uuid,text,boolean)
 from public,anon,authenticated,service_role;
revoke all on function public.hospital_delivery_target_set(uuid,text,text,boolean)
 from public,anon,service_role;
grant execute on function public.hospital_delivery_targets_own(uuid),
 public.hospital_delivery_target_replace(uuid,uuid,text,boolean) to authenticated;
commit;

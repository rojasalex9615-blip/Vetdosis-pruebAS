-- Candidate for coordinated integration only. Do not apply directly to production.
-- Personal data is never exposed directly: reads and writes go through RPCs.
-- Visibility flags are enforced server-side so a client cannot leak hidden fields.
begin;

create table if not exists public.personal_profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null default '' check (char_length(display_name) <= 120),
 birthday date,
 phone text not null default '' check (char_length(phone) <= 40),
 email text not null default '' check (char_length(email) <= 160),
 allergies text not null default '' check (char_length(allergies) <= 500),
 blood_type text not null default '' check (char_length(blood_type) <= 8),
 photo_url text check (char_length(photo_url) <= 500),
 show_phone boolean not null default false,
 show_email boolean not null default false,
 show_allergies boolean not null default false,
 show_blood_type boolean not null default false,
 show_photo boolean not null default true,
 revision integer not null default 1 check (revision >= 1),
 updated_at timestamptz not null default clock_timestamp()
);
alter table public.personal_profiles enable row level security;
revoke all on public.personal_profiles from public, anon, authenticated;
-- No direct table policies; access only by owner/membership-checked RPC.

create or replace function public.personal_profile_get(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare row_data public.personal_profiles;
begin
 if auth.uid() is null or auth.uid() <> p_user then
   raise exception 'personal_profile_owner_required';
 end if;
 select * into row_data from public.personal_profiles p where p.user_id=p_user;
 if not found then return null; end if;
 return jsonb_build_object(
   'user_id', row_data.user_id,
   'display_name', row_data.display_name,
   'birthday', row_data.birthday,
   'phone', row_data.phone,
   'email', row_data.email,
   'allergies', row_data.allergies,
   'blood_type', row_data.blood_type,
   'photo_url', row_data.photo_url,
   'show_phone', row_data.show_phone,
   'show_email', row_data.show_email,
   'show_allergies', row_data.show_allergies,
   'show_blood_type', row_data.show_blood_type,
   'show_photo', row_data.show_photo,
   'revision', row_data.revision);
end$$;

create or replace function public.personal_profile_save(
 p_profile jsonb, p_revision integer
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare
 saved public.personal_profiles;
 owner uuid := auth.uid();
begin
 if owner is null then raise exception 'personal_profile_owner_required'; end if;
 if p_profile is null or jsonb_typeof(p_profile) <> 'object' or
    jsonb_typeof(p_profile->'display_name') <> 'string' or
    char_length(p_profile->>'display_name') > 120 or
    jsonb_typeof(p_profile->'phone') <> 'string' or
    char_length(p_profile->>'phone') > 40 or
    jsonb_typeof(p_profile->'email') <> 'string' or
    char_length(p_profile->>'email') > 160 or
    jsonb_typeof(p_profile->'allergies') <> 'string' or
    char_length(p_profile->>'allergies') > 500 or
    jsonb_typeof(p_profile->'blood_type') <> 'string' or
    char_length(p_profile->>'blood_type') > 8 or
    (p_profile->'photo_url' is not null and
      p_profile->'photo_url' <> 'null'::jsonb and
      (jsonb_typeof(p_profile->'photo_url') <> 'string' or
       char_length(p_profile->>'photo_url') > 500)) or
    jsonb_typeof(p_profile->'show_phone') <> 'boolean' or
    jsonb_typeof(p_profile->'show_email') <> 'boolean' or
    jsonb_typeof(p_profile->'show_allergies') <> 'boolean' or
    jsonb_typeof(p_profile->'show_blood_type') <> 'boolean' or
    jsonb_typeof(p_profile->'show_photo') <> 'boolean'
 then raise exception 'personal_profile_invalid'; end if;
 if p_revision is null or p_revision < 0 then
   raise exception 'personal_profile_invalid';
 end if;
 insert into public.personal_profiles as pp (
   user_id, display_name, birthday, phone, email, allergies, blood_type,
   photo_url, show_phone, show_email, show_allergies, show_blood_type,
   show_photo, revision)
 values (
   owner, p_profile->>'display_name',
   case when p_profile->'birthday' is null or p_profile->>'birthday' = ''
     then null else (p_profile->>'birthday')::date end,
   p_profile->>'phone', p_profile->>'email', p_profile->>'allergies',
   p_profile->>'blood_type', p_profile->>'photo_url',
   (p_profile->>'show_phone')::boolean,
   (p_profile->>'show_email')::boolean,
   (p_profile->>'show_allergies')::boolean,
   (p_profile->>'show_blood_type')::boolean,
   (p_profile->>'show_photo')::boolean, 1)
 on conflict (user_id) do update set
   display_name=excluded.display_name,
   birthday=excluded.birthday,
   phone=excluded.phone,
   email=excluded.email,
   allergies=excluded.allergies,
   blood_type=excluded.blood_type,
   photo_url=excluded.photo_url,
   show_phone=excluded.show_phone,
   show_email=excluded.show_email,
   show_allergies=excluded.show_allergies,
   show_blood_type=excluded.show_blood_type,
   show_photo=excluded.show_photo,
   revision=pp.revision+1,
   updated_at=clock_timestamp()
 where pp.revision=p_revision
 returning * into saved;
 if not found then raise exception 'personal_profile_revision_conflict'; end if;
 return jsonb_build_object(
   'user_id', saved.user_id,
   'display_name', saved.display_name,
   'birthday', saved.birthday,
   'phone', saved.phone,
   'email', saved.email,
   'allergies', saved.allergies,
   'blood_type', saved.blood_type,
   'photo_url', saved.photo_url,
   'show_phone', saved.show_phone,
   'show_email', saved.show_email,
   'show_allergies', saved.show_allergies,
   'show_blood_type', saved.show_blood_type,
   'show_photo', saved.show_photo,
   'revision', saved.revision);
end$$;

create or replace function public.personal_profile_team(p_clinic uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not exists(
   select 1 from public.clinic_members m
   where m.clinic_id=p_clinic and m.user_id=auth.uid()
 ) then raise exception 'personal_profile_membership_required'; end if;
 return coalesce((
   select jsonb_agg(jsonb_build_object(
     'user_id', p.user_id,
     'display_name', p.display_name,
     'birthday', p.birthday,
     'phone', case when p.show_phone then p.phone else '' end,
     'email', case when p.show_email then p.email else '' end,
     'allergies', case when p.show_allergies then p.allergies else '' end,
     'blood_type', case when p.show_blood_type then p.blood_type else '' end,
     'photo_url', case when p.show_photo then p.photo_url else null end,
     'show_phone', p.show_phone,
     'show_email', p.show_email,
     'show_allergies', p.show_allergies,
     'show_blood_type', p.show_blood_type,
     'show_photo', p.show_photo,
     'revision', p.revision) order by p.display_name, p.user_id)
   from public.personal_profiles p
   join public.clinic_members m on m.user_id=p.user_id
   where m.clinic_id=p_clinic
 ), '[]'::jsonb);
end$$;

grant execute on function public.personal_profile_get(uuid) to authenticated;
grant execute on function public.personal_profile_save(jsonb, integer) to authenticated;
grant execute on function public.personal_profile_team(uuid) to authenticated;
commit;

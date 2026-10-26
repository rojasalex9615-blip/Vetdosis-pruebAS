-- Candidate for coordinated integration only. Do not apply directly to production.
-- Presentation preferences NEVER grant server permissions or waive clinical checks.
-- Hospital delivery mode is a requested channel, not an enabled outbound transport.
begin;

create table if not exists public.clinic_experience_settings (
 clinic_id uuid primary key references public.clinics(id) on delete cascade,
 revision integer not null default 1 check (revision >= 1),
 settings jsonb not null,
 updated_by uuid not null references auth.users(id),
 updated_at timestamptz not null default clock_timestamp()
);
alter table public.clinic_experience_settings enable row level security;
revoke all on public.clinic_experience_settings from public, anon, authenticated;
-- No direct table policies; access only by membership-checked, audited RPC.

create or replace function public.clinic_experience_read(p_clinic uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare row_data public.clinic_experience_settings;
begin
 if auth.uid() is null or not exists(
   select 1 from public.clinic_members m
   where m.clinic_id=p_clinic and m.user_id=auth.uid()
 ) then
   raise exception 'clinic_experience_membership_required';
 end if;
 select * into row_data from public.clinic_experience_settings s
 where s.clinic_id=p_clinic;
 if not found then
   return jsonb_build_object('schema_version',1,'revision',0,
     'settings', jsonb_build_object(
       'schema_version',1,'preset','general','hidden_pages','[]'::jsonb,
       'workflow_modes','{}'::jsonb,'default_ai_provider',null,
       'hospital_notice_delivery','phone'));
 end if;
 return jsonb_build_object(
   'schema_version',1,'revision',row_data.revision,'settings',row_data.settings);
end$$;

create or replace function public.clinic_experience_save(
 p_clinic uuid, p_expected_revision integer, p_settings jsonb
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare new_rev integer; flow_entry record; page text;
begin
 if auth.uid() is null or
    not private.has_clinic_role(p_clinic,array['admin']::text[]) or
    not exists(select 1 from public.clinic_members m
      where m.clinic_id=p_clinic and m.user_id=auth.uid())
 then raise exception 'clinic_experience_admin_required'; end if;
 if p_expected_revision is null or p_expected_revision < 0 or p_settings is null or
    jsonb_typeof(p_settings) <> 'object' or
    (select count(*) from jsonb_object_keys(p_settings)) <> 6 or
    not (p_settings ?& array['schema_version','preset','hidden_pages','workflow_modes','default_ai_provider','hospital_notice_delivery']) or
    p_settings->'schema_version' <> '1'::jsonb or
    jsonb_typeof(p_settings->'preset') <> 'string' or
    p_settings->>'preset' not in ('general','smallAnimals','hospital','production','custom') or
    jsonb_typeof(p_settings->'hidden_pages') <> 'array' or
    jsonb_array_length(p_settings->'hidden_pages') > 60 or
    jsonb_typeof(p_settings->'workflow_modes') <> 'object' or
    (select count(*) from jsonb_object_keys(p_settings->'workflow_modes')) > 5 or
    (jsonb_typeof(p_settings->'default_ai_provider') <> 'null' and
       p_settings->>'default_ai_provider' not in ('google','openai','anthropic','zai')) or
    jsonb_typeof(p_settings->'hospital_notice_delivery') <> 'string' or
    p_settings->>'hospital_notice_delivery' not in ('phone','whatsapp','both')
 then raise exception 'clinic_experience_invalid_settings'; end if;

 for page in select jsonb_array_elements_text(p_settings->'hidden_pages') loop
   if page not in (
    'Agenda','Pacientes','Hospitalización','Receta','Formatos',
    'Cálculo rápido','Vademécum','Operaciones de dosis','Cálculos clínicos',
    'Inventario','Escanear producto','Producción y grandes especies',
    'Caja','Planeación financiera','Servicios','Proveedores',
    'Promociones','Productividad y semana','Agenda telefónica',
    'Equipo y avisos','Anuncios y avisos','Pendientes del equipo',
    'Checado','Estadísticas','Asistente IA','Respaldo','Producto y costos',
    'Inicio guiado'
   ) then raise exception 'clinic_experience_unknown_page'; end if;
 end loop;
 if (select count(*) from jsonb_array_elements_text(p_settings->'hidden_pages'))
    <> (select count(distinct value) from jsonb_array_elements_text(p_settings->'hidden_pages') as value)
 then raise exception 'clinic_experience_duplicate_page'; end if;

 for flow_entry in select key, value from jsonb_each_text(p_settings->'workflow_modes') loop
   if flow_entry.key not in ('dose','prescription','hospital','inventory','clinical')
      or flow_entry.value is null
       or flow_entry.value not in ('free','guided','mandatory')
   then raise exception 'clinic_experience_unknown_flow'; end if;
 end loop;

 insert into public.clinic_experience_settings
   (clinic_id,revision,settings,updated_by)
 values(p_clinic,1,p_settings,auth.uid())
 on conflict (clinic_id) do update
   set revision=public.clinic_experience_settings.revision+1,
       settings=excluded.settings,
       updated_by=auth.uid(),updated_at=clock_timestamp()
   where public.clinic_experience_settings.revision=p_expected_revision
 returning revision into new_rev;
 if new_rev is null or (p_expected_revision <> 0 and new_rev <> p_expected_revision+1) then
   raise exception 'clinic_experience_revision_conflict';
 end if;
 return jsonb_build_object('schema_version',1,'revision',new_rev,
   'settings',p_settings);
end$$;

revoke all on function public.clinic_experience_read(uuid) from public,anon,authenticated;
revoke all on function public.clinic_experience_save(uuid,integer,jsonb) from public,anon,authenticated;
grant execute on function public.clinic_experience_read(uuid) to authenticated;
grant execute on function public.clinic_experience_save(uuid,integer,jsonb) to authenticated;
commit;

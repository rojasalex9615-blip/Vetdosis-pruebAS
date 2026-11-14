-- CANDIDATO LOCAL, NO APLICADO. Resultados de laboratorio y sus rangos de
-- referencia. Sigue el modelo de 14F_hospital_care_results.sql: tablas en
-- private, permisos efectivos, autoria, y correcciones que conservan el
-- original; nada se edita ni se borra.
--
-- Numerado 15M: el 15J esta tomado, el 15K queda reservado para
-- 15K_porcino_produccion.sql (atrapado en el repositorio suspendido) y el
-- 15L es la cache de precios.
--
-- LA DECISION QUE GOBIERNA EL DISEÑO, por indicacion de Ale: cuando un
-- analito tiene mas de un rango legitimo, el servidor NO elige. La lectura
-- devuelve TODOS los rangos que aplican, cada uno con su fuente, y el juicio
-- lo arma el cliente mostrando los dos para que el profesional decida. Por
-- eso aqui no hay ninguna funcion que diga «normal» o «alto»: eso vive en
-- readings()/agreedFlag() de lib/modules/laboratory, y es la misma regla que
-- siguen las referencias porcinas con la lactancia de 21 y 28 dias.
--
-- Sin precarga de rangos y SIN via de escritura para ellos: los datos
-- clinicos entran por el modo revision, que es otra pieza. Esta migracion
-- crea la tabla vacia a proposito.
begin;
do $$begin
 if not(select not admissions_enabled and not enforcement_enabled from private.beta_policy)
 or (select enforcement_enabled from private.permission_policy) then raise exception 'closed_beta_and_dormant_permissions_required';end if;
end$$;

-- Rango de referencia universal: no lleva clinic_id porque un rango
-- publicado no es de una clinica. La fuente es obligatoria; un rango sin
-- fuente no existe. verified arranca en falso y solo lo mueve la revision.
create table private.lab_reference_ranges(
 id uuid primary key default gen_random_uuid(),
 analyte_key text not null check(length(btrim(analyte_key)) between 1 and 80),
 species text not null check(length(btrim(species)) between 1 and 120),
 unit text not null check(length(btrim(unit)) between 1 and 30),
 low numeric not null check(low>=0),
 high numeric not null,
 source text not null check(length(btrim(source)) between 1 and 300),
 verified boolean not null default false,
 created_at timestamptz not null default clock_timestamp(),
 check(high>=low)
);
-- Dos fuentes para el mismo analito, especie y unidad son legitimas y
-- conviven: eso es justo lo que hay que poder mostrar. Lo que no puede
-- repetirse es la MISMA fuente dos veces.
create unique index lab_reference_unica on private.lab_reference_ranges
 (lower(btrim(analyte_key)),lower(btrim(species)),lower(btrim(unit)),lower(btrim(source)));
create index lab_reference_busqueda on private.lab_reference_ranges
 (lower(btrim(species)),lower(btrim(analyte_key)));
alter table private.lab_reference_ranges enable row level security;
revoke all on private.lab_reference_ranges from public,anon,authenticated,service_role;

-- Toma de muestra. species se copia del paciente en el momento de la toma:
-- si manana se corrige la especie del expediente, la lectura de ayer sigue
-- siendo contra la especie que se uso entonces.
create table private.lab_panels(
 id uuid primary key default gen_random_uuid(),
 clinic_id uuid not null references public.clinics(id),
 patient_id uuid not null,
 species text not null check(length(btrim(species)) between 1 and 120),
 collected_at timestamptz not null,
 origin text not null check(origin in ('laboratorio_externo','equipo_propio')),
 lab_name text not null default '' check(length(lab_name)<=160),
 notes text not null default '' check(length(notes)<=2000),
 actor_id uuid not null references auth.users(id),
 created_at timestamptz not null default clock_timestamp(),
 unique(clinic_id,id),
 foreign key(clinic_id,patient_id) references public.vet_patients(clinic_id,id),
 check((origin='laboratorio_externo') or lab_name='')
);
create index lab_panels_paciente on private.lab_panels(clinic_id,patient_id,collected_at desc);

-- Un resultado. El valor va en numeric, que en Postgres es decimal exacto, y
-- se devuelve como texto para que no lo toque ningun flotante por el camino.
-- La entrada se valida con la MISMA expresion que el cliente: sin coma, que
-- en Mexico es separador de miles y leerla como decimal metia un valor mil
-- veces menor en silencio.
create table private.lab_results(
 id uuid primary key default gen_random_uuid(),
 clinic_id uuid not null references public.clinics(id),
 panel_id uuid not null,
 analyte_key text not null check(length(btrim(analyte_key)) between 1 and 80),
 value numeric not null check(value>=0),
 unit text not null check(length(btrim(unit)) between 1 and 30),
 actor_id uuid not null references auth.users(id),
 created_at timestamptz not null default clock_timestamp(),
 replaces_id uuid unique references private.lab_results(id),
 correction_reason text,
 foreign key(clinic_id,panel_id) references private.lab_panels(clinic_id,id),
 check((replaces_id is null and correction_reason is null)
  or (replaces_id is not null and correction_reason is not null
      and length(btrim(correction_reason)) between 1 and 1000))
);
-- Un analito no se repite en la misma toma. La correccion no cuenta: lleva
-- replaces_id y es la version nueva del mismo dato, no un dato nuevo.
create unique index lab_result_unico_por_toma on private.lab_results
 (panel_id,lower(btrim(analyte_key))) where replaces_id is null;
create index lab_results_toma on private.lab_results(clinic_id,panel_id);
alter table private.lab_panels enable row level security;
alter table private.lab_results enable row level security;
revoke all on private.lab_panels,private.lab_results from public,anon,authenticated,service_role;
create trigger immutable before update or delete on private.lab_panels for each row execute function private.permission_immutable();
create trigger immutable before update or delete on private.lab_results for each row execute function private.permission_immutable();

-- Lectura. Devuelve las tomas con sus resultados y, por cada resultado,
-- TODOS los rangos de la especie y la unidad, cada uno con su fuente. No
-- emite juicio: eso lo arma el cliente, y cuando las fuentes no coinciden
-- muestra las dos.
create function public.lab_workspace(p_clinic uuid,p_patient uuid default null,p_panel uuid default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 perform private.permission_require(p_clinic,'clinical.read');
 perform private.permission_require(p_clinic,'patient.read');
 return jsonb_build_object('schema_version',1,'clinic_id',p_clinic,'actor_id',auth.uid(),
  'can_record',private.clinical_professional_at(p_clinic,auth.uid(),clock_timestamp())
   and private.permission_effective(p_clinic,auth.uid(),'patient.write') is not null,
  'panels',(select coalesce(jsonb_agg(panel order by panel->>'collected_at' desc),'[]'::jsonb) from (
    select to_jsonb(pa)||jsonb_build_object(
      'patient_name',(select name from public.vet_patients where id=pa.patient_id and clinic_id=pa.clinic_id),
      'results',(select coalesce(jsonb_agg(to_jsonb(re)||jsonb_build_object(
          'value',re.value::text,
          -- Todas las referencias que aplican, sin elegir ninguna.
          'ranges',(select coalesce(jsonb_agg(jsonb_build_object(
              'low',ra.low::text,'high',ra.high::text,'unit',ra.unit,
              'source',ra.source,'verified',ra.verified) order by ra.source),'[]'::jsonb)
            from private.lab_reference_ranges ra
            where lower(btrim(ra.analyte_key))=lower(btrim(re.analyte_key))
              and lower(btrim(ra.species))=lower(btrim(pa.species))
              and lower(btrim(ra.unit))=lower(btrim(re.unit)))
          ) order by re.created_at,re.id),'[]'::jsonb)
        from private.lab_results re
        where re.panel_id=pa.id and re.clinic_id=pa.clinic_id)) as panel
    from private.lab_panels pa
    where pa.clinic_id=p_clinic
      and (p_patient is null or pa.patient_id=p_patient)
      and (p_panel is null or pa.id=p_panel)) q));
end$$;

-- Escritura: la toma entera en una sola llamada idempotente. Si se cae la
-- red a medias no quedan medias tomas, que en un expediente es peor que no
-- tener ninguna.
create function public.lab_panel_record(p_clinic uuid,p_patient uuid,p_data jsonb,p_operation text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_species text;v_at timestamptz;fp jsonb;receipt uuid;panel uuid;item jsonb;k text;vistos text[]:='{}';
begin
 perform private.permission_require(p_clinic,'clinical.read');
 perform private.permission_require(p_clinic,'patient.write');
 select species into v_species from public.vet_patients where id=p_patient and clinic_id=p_clinic;
 if v_species is null then raise exception 'patient_not_found';end if;
 if jsonb_typeof(p_data) is distinct from 'object' then raise exception 'invalid_lab_panel';end if;
 if exists(select 1 from jsonb_object_keys(p_data) key where key not in ('collected_at','origin','lab_name','notes','results','confirmed')) then raise exception 'lab_panel_fields_only';end if;
 if p_data->'confirmed' is distinct from 'true'::jsonb then raise exception 'lab_confirmation_required';end if;
 foreach k in array array['collected_at','origin'] loop
  if jsonb_typeof(p_data->k) is distinct from 'string' then raise exception 'invalid_lab_panel';end if;end loop;
 if jsonb_typeof(p_data->'results') is distinct from 'array' or jsonb_array_length(p_data->'results')=0 then raise exception 'lab_results_required';end if;
 v_at=private.clinical_time(p_data->>'collected_at');
 if v_at>clock_timestamp() then raise exception 'invalid_lab_collection_time';end if;
 -- La habilitacion se exige al REGISTRAR, no al momento de la toma. La
 -- muestra se toma antes de capturarse, y a veces la toma un laboratorio
 -- externo: pedir habilitacion vigente en esa fecha impediria registrar un
 -- resultado legitimo de la semana pasada. Quien atestigua un acto clinico
 -- es 14F; esto transcribe un documento ajeno.
 if not private.clinical_professional_at(p_clinic,auth.uid(),clock_timestamp()) then raise exception 'lab_authority_required';end if;
 -- Se valida TODO antes de insertar nada.
 for item in select * from jsonb_array_elements(p_data->'results') loop
  if jsonb_typeof(item) is distinct from 'object'
   or exists(select 1 from jsonb_object_keys(item) key where key not in ('analyte_key','value','unit')) then raise exception 'invalid_lab_result';end if;
  foreach k in array array['analyte_key','value','unit'] loop
   if jsonb_typeof(item->k) is distinct from 'string' then raise exception 'invalid_lab_result';end if;end loop;
  -- Misma expresion que el cliente: punto decimal, nunca coma.
  if coalesce(item->>'value','') !~ '^\d{1,12}(\.\d{1,9})?$' then raise exception 'exact_lab_value_required';end if;
  if lower(btrim(item->>'analyte_key'))=any(vistos) then raise exception 'lab_analyte_repeated';end if;
  vistos=vistos||lower(btrim(item->>'analyte_key'));
 end loop;
 fp=jsonb_build_object('kind','lab_panel','patient',p_patient,'data',p_data);
 receipt=private.vet_receipt(p_clinic,p_operation,fp);if receipt is not null then return receipt;end if;
 insert into private.lab_panels(clinic_id,patient_id,species,collected_at,origin,lab_name,notes,actor_id)
  values(p_clinic,p_patient,v_species,v_at,p_data->>'origin',
   coalesce(p_data->>'lab_name',''),coalesce(p_data->>'notes',''),auth.uid()) returning id into panel;
 insert into private.lab_results(clinic_id,panel_id,analyte_key,value,unit,actor_id)
  select p_clinic,panel,btrim(r->>'analyte_key'),(r->>'value')::numeric,btrim(r->>'unit'),auth.uid()
  from jsonb_array_elements(p_data->'results') r;
 insert into private.vet_operation_receipts values(auth.uid(),p_clinic,p_operation,fp,panel);
 perform private.permission_event(p_clinic,'lab_panel_recorded',panel,jsonb_build_object('patient_id',p_patient,'results',jsonb_array_length(p_data->'results')));
 return panel;
end$$;

-- Correccion: no edita ni borra, agrega la version nueva apuntando a la
-- anterior y exige decir por que.
create function public.lab_result_correct(p_clinic uuid,p_result uuid,p_data jsonb,p_operation text)
returns uuid language plpgsql security definer set search_path='' as $$
declare old private.lab_results;fp jsonb;receipt uuid;nuevo uuid;k text;
begin
 perform private.permission_require(p_clinic,'clinical.read');
 perform private.permission_require(p_clinic,'patient.write');
 select * into old from private.lab_results where id=p_result and clinic_id=p_clinic;
 if not found then raise exception 'lab_result_not_found';end if;
 if old.actor_id is distinct from auth.uid() then raise exception 'own_lab_correction_required';end if;
 if exists(select 1 from private.lab_results where replaces_id=p_result) then raise exception 'lab_result_already_corrected';end if;
 if jsonb_typeof(p_data) is distinct from 'object'
  or exists(select 1 from jsonb_object_keys(p_data) key where key not in ('value','unit','correction_reason','confirmed')) then raise exception 'invalid_lab_result';end if;
 if p_data->'confirmed' is distinct from 'true'::jsonb then raise exception 'lab_confirmation_required';end if;
 foreach k in array array['value','unit','correction_reason'] loop
  if jsonb_typeof(p_data->k) is distinct from 'string' then raise exception 'invalid_lab_result';end if;end loop;
 if coalesce(p_data->>'value','') !~ '^\d{1,12}(\.\d{1,9})?$' then raise exception 'exact_lab_value_required';end if;
 if not private.clinical_professional_at(p_clinic,auth.uid(),clock_timestamp()) then raise exception 'lab_authority_required';end if;
 fp=jsonb_build_object('kind','lab_result_correction','result',p_result,'data',p_data);
 receipt=private.vet_receipt(p_clinic,p_operation,fp);if receipt is not null then return receipt;end if;
 insert into private.lab_results(clinic_id,panel_id,analyte_key,value,unit,actor_id,replaces_id,correction_reason)
  values(p_clinic,old.panel_id,old.analyte_key,(p_data->>'value')::numeric,btrim(p_data->>'unit'),auth.uid(),p_result,btrim(p_data->>'correction_reason'))
  returning id into nuevo;
 insert into private.vet_operation_receipts values(auth.uid(),p_clinic,p_operation,fp,nuevo);
 perform private.permission_event(p_clinic,'lab_result_corrected',nuevo,jsonb_build_object('replaces_id',p_result,'panel_id',old.panel_id));
 return nuevo;
end$$;

revoke all on function public.lab_workspace(uuid,uuid,uuid),public.lab_panel_record(uuid,uuid,jsonb,text),public.lab_result_correct(uuid,uuid,jsonb,text) from public,anon,service_role;
grant execute on function public.lab_workspace(uuid,uuid,uuid),public.lab_panel_record(uuid,uuid,jsonb,text),public.lab_result_correct(uuid,uuid,jsonb,text) to authenticated;
select private.beta_install_guards();
notify pgrst,'reload schema';
commit;

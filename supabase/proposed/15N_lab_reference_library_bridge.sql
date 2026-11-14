-- CANDIDATO LOCAL, NO APLICADO. Conecta la pantalla de laboratorio del
-- expediente (15M) con la biblioteca de referencias que ya esta instalada en
-- el servidor (15J, esquema vetdosis_reference_staging).
--
-- POR QUE EXISTE. 15M crea private.lab_reference_ranges vacia y a proposito,
-- porque los rangos entran por el modo revision. El efecto practico es que
-- la pantalla del expediente marca «Sin rango de referencia» en todos los
-- analitos aunque el servidor ya tenga 403 filas de laboratorio importadas,
-- 113 de ellas de canino y 103 de felino. Esta migracion hace que la lectura
-- use esas filas, de modo que las clinicas que van a revisar parametros vean
-- el valor, su intervalo y su fuente.
--
-- LO QUE NO HACE. No copia nada a private.lab_reference_ranges, no valida
-- ninguna fuente y no emite juicio. Cada fila importada viaja con
-- verified=false, que en la pantalla se lee como pendiente de validacion
-- MVZ: en el servidor las 2574 filas estan en review_state 'pending'.
-- Cuando el archivo de origen avisa de otro intervalo sin darlo, ese aviso
-- viaja dentro de la fuente; NO se inventa un segundo rango.
--
-- CAMBIO DE COMPORTAMIENTO DELIBERADO. 15M filtraba los rangos por unidad
-- dentro del SQL, asi que un rango en otra unidad desaparecia y el resultado
-- se mostraba como «sin rango». Aqui se devuelven todos los rangos del
-- analito y la especie, con su unidad, y el cliente decide: LabResult
-- .readings() ya distingue unitMismatch de noReference. Para el veterinario
-- la diferencia importa: «la unidad no coincide» se corrige, «sin rango» no.
begin;

-- La biblioteca puede no existir en un entorno limpio (el esquema de
-- preparacion se instala por fuera de estas migraciones). La funcion se
-- arma en SQL dinamico para que la ausencia del esquema no rompa la
-- migracion ni la lectura: sin biblioteca devuelve solo lo que haya en
-- private.lab_reference_ranges.
create function private.lab_reference_for(p_analyte text,p_species text)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare propias jsonb;biblioteca jsonb:='[]'::jsonb;decididas jsonb:='[]'::jsonb;
begin
 select coalesce(jsonb_agg(jsonb_build_object(
   'low',ra.low::text,'high',ra.high::text,'unit',ra.unit,
   'source',ra.source,'verified',ra.verified) order by ra.source),'[]'::jsonb)
  into propias from private.lab_reference_ranges ra
  where lower(btrim(ra.analyte_key))=lower(btrim(p_analyte))
    and lower(btrim(ra.species))=lower(btrim(p_species));

 if to_regclass('vetdosis_reference_staging.raw_intake_rows') is not null then
  execute $q$
   select coalesce(jsonb_agg(jsonb_build_object(
      'low',mn,'high',mx,'unit',unidad,'source',fuente,'verified',false)
      order by fuente,mn),'[]'::jsonb)
   from (
    select r.original_payload->>'Mín.' mn,r.original_payload->>'Máx.' mx,
      btrim(r.original_payload->>'Unidad original') unidad,
      concat_ws(' · ',btrim(r.original_payload->>'Fuente'),
        case when r.original_payload->>'Otro intervalo'='Sí'
          then 'el archivo señala otro intervalo' end,
        'pendiente de validación MVZ') fuente
    from vetdosis_reference_staging.raw_intake_rows r
    where r.original_payload->>'Categoría' in
       ('Hematología','Enzimas','Bioquímica','Metabolitos','Minerales','Endocrinología')
      and lower(btrim(coalesce(r.original_payload->>'Parámetro','')))=lower(btrim($1))
      and lower(btrim(coalesce(r.original_payload->>'Especie','')))=lower(btrim($2))
      -- Una fila sin intervalo numerico, sin unidad o sin fuente no es un
      -- rango: se queda fuera en vez de entrar a medias.
      and coalesce(r.original_payload->>'Mín.','') ~ '^\d{1,12}(\.\d{1,9})?$'
      and coalesce(r.original_payload->>'Máx.','') ~ '^\d{1,12}(\.\d{1,9})?$'
      and (r.original_payload->>'Máx.')::numeric>=(r.original_payload->>'Mín.')::numeric
      and btrim(coalesce(r.original_payload->>'Unidad original','')) not in ('','(NULL)')
      and btrim(coalesce(r.original_payload->>'Fuente','')) <> ''
   ) q$q$ into biblioteca using p_analyte,p_species;

  if to_regclass('vetdosis_reference_staging.reference_display_decisions') is not null then
   execute $q$
    select coalesce(jsonb_agg(jsonb_build_object(
       'low',d.min_value,'high',d.max_value,'unit',d.unit,
       'source',concat_ws(' · ',d.source_title,
         case when d.review_state='aprobada_mvz' then 'aprobada por MVZ'
              else 'fuente contrastada, pendiente de MVZ' end),
       'verified',d.review_state='aprobada_mvz') order by d.source_title),'[]'::jsonb)
    from vetdosis_reference_staging.reference_display_decisions d
    where d.section='laboratorio'
      and lower(btrim(d.parameter))=lower(btrim($1))
      and lower(btrim(d.species))=lower(btrim($2))$q$
    into decididas using p_analyte,p_species;
  end if;
 end if;
 return propias||biblioteca||decididas;
end$$;
revoke all on function private.lab_reference_for(text,text) from public,anon,authenticated,service_role;

-- Catalogo de analitos de la especie, para que la captura ofrezca los
-- nombres que la biblioteca conoce. Sin esto el nombre se teclea libre y una
-- «H» de mas deja el resultado sin referencia para siempre.
-- Toma el paciente, no la especie: la especie se lee del expediente en el
-- servidor. Asi el cliente no puede pedir el catalogo de una especie que no
-- es la del paciente, y la captura ofrece siempre los analitos que de verdad
-- van a resolver un rango para ese expediente.
create function public.lab_analyte_catalog(p_clinic uuid,p_patient uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare items jsonb:='[]'::jsonb;p_species text;
begin
 perform private.permission_require(p_clinic,'clinical.read');
 perform private.permission_require(p_clinic,'patient.read');
 select species into p_species from public.vet_patients where id=p_patient and clinic_id=p_clinic;
 if p_species is null then raise exception 'patient_not_found';end if;
 if to_regclass('vetdosis_reference_staging.raw_intake_rows') is not null then
  execute $q$
   select coalesce(jsonb_agg(jsonb_build_object(
      'analyte_key',parametro,'unit',unidad,'sources',fuentes) order by parametro,unidad),'[]'::jsonb)
   from (
    select btrim(r.original_payload->>'Parámetro') parametro,
      btrim(r.original_payload->>'Unidad original') unidad,
      count(distinct btrim(r.original_payload->>'Fuente')) fuentes
    from vetdosis_reference_staging.raw_intake_rows r
    where r.original_payload->>'Categoría' in
       ('Hematología','Enzimas','Bioquímica','Metabolitos','Minerales','Endocrinología')
      and lower(btrim(coalesce(r.original_payload->>'Especie','')))=lower(btrim($1))
      and btrim(coalesce(r.original_payload->>'Parámetro','')) <> ''
      -- Los MISMOS filtros que lab_reference_for. Sin esto el catalogo
      -- ofrecia nombres que luego no resuelven ningun rango, que es la peor
      -- version: el analito aparece elegible y el resultado sale sin
      -- referencia.
      and coalesce(r.original_payload->>'Mín.','') ~ '^\d{1,12}(\.\d{1,9})?$'
      and coalesce(r.original_payload->>'Máx.','') ~ '^\d{1,12}(\.\d{1,9})?$'
      and (r.original_payload->>'Máx.')::numeric>=(r.original_payload->>'Mín.')::numeric
      and btrim(coalesce(r.original_payload->>'Unidad original','')) not in ('','(NULL)')
      and btrim(coalesce(r.original_payload->>'Fuente','')) <> ''
    group by 1,2
   ) q$q$ into items using p_species;
 end if;
 -- Lo que la clinica haya publicado en private.lab_reference_ranges tambien
 -- se ofrece, para que la captura no dependa solo de la importacion.
 return jsonb_build_object('schema_version',1,'species',btrim(p_species),
   'items',items||(select coalesce(jsonb_agg(distinct jsonb_build_object(
      'analyte_key',btrim(ra.analyte_key),'unit',btrim(ra.unit),'sources',1)),'[]'::jsonb)
    from private.lab_reference_ranges ra
    where lower(btrim(ra.species))=lower(btrim(p_species))));
end$$;
revoke all on function public.lab_analyte_catalog(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.lab_analyte_catalog(uuid,uuid) to authenticated;
-- create or replace conserva los permisos de 15M, pero se reafirman para que
-- este archivo valga por si solo si 15M se aplico en otra sesion.
revoke all on function public.lab_workspace(uuid,uuid,uuid) from public,anon,service_role;
grant execute on function public.lab_workspace(uuid,uuid,uuid) to authenticated;

-- Misma lectura de 15M, con los rangos resueltos por la funcion de arriba.
create or replace function public.lab_workspace(p_clinic uuid,p_patient uuid default null,p_panel uuid default null)
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
          'ranges',private.lab_reference_for(re.analyte_key,pa.species)
          ) order by re.created_at,re.id),'[]'::jsonb)
        from private.lab_results re
        where re.panel_id=pa.id and re.clinic_id=pa.clinic_id)) as panel
    from private.lab_panels pa
    where pa.clinic_id=p_clinic
      and (p_patient is null or pa.patient_id=p_patient)
      and (p_panel is null or pa.id=p_panel)) q));
end$$;
commit;

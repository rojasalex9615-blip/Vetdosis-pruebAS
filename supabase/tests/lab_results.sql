-- Regresion aislada de 15M_lab_results.sql sobre el fixture sintetico.
-- No prueba el corte de RLS remoto, solo el contrato de estas funciones.
create function pg_temp.assert_true(v boolean,msg text) returns void language plpgsql as $$begin if v is distinct from true then raise exception 'ASSERT: %',msg;end if;end$$;
create function pg_temp.expect_error(sql text,expected text) returns void language plpgsql as $$begin begin execute sql;exception when others then if position(expected in sqlerrm)>0 then return;end if;raise;end;raise exception 'Expected rejection: %',expected;end$$;
-- Hay dos clinicas con el mismo nombre en el fixture. Se elige por lo que
-- esta prueba necesita y no por el nombre: aquella donde 151 es profesional
-- verificado, porque capturar un resultado exige habilitacion vigente.
select pp.clinic_id as clinic from public.professional_profiles pp
 join private.professional_verifications v on v.user_id=pp.user_id
 where pp.user_id='00000000-0000-0000-0000-000000000151' limit 1 \gset
select set_config('test.clinic',:'clinic',false);
select set_config('test.patient','00000000-0000-0000-0000-000000000600',false);

-- Dos fuentes para el MISMO analito, especie y unidad: el caso que manda.
insert into private.lab_reference_ranges(analyte_key,species,unit,low,high,source,verified) values
 ('hematocrito','synthetic','%',37,55,'Fuente A',true),
 ('hematocrito','synthetic','%',35,57,'Fuente B',false),
 ('albumina','synthetic','g/dL',2.3,4.0,'Fuente A',true);
-- Un rango sin fuente no existe, y uno invertido tampoco.
select pg_temp.expect_error($q$insert into private.lab_reference_ranges(analyte_key,species,unit,low,high,source) values('x','synthetic','%',1,2,'  ')$q$,'violates check constraint');
select pg_temp.expect_error($q$insert into private.lab_reference_ranges(analyte_key,species,unit,low,high,source) values('x','synthetic','%',9,2,'F')$q$,'violates check constraint');
-- La misma fuente no se repite, aunque venga con otras mayusculas.
select pg_temp.expect_error($q$insert into private.lab_reference_ranges(analyte_key,species,unit,low,high,source) values('Hematocrito ','SYNTHETIC',' % ',1,2,'Fuente A')$q$,'lab_reference_unica');

-- El fixture da clinical.read pero no patient.write: lo concede el admin.
select pg_temp.assert_true(private.clinical_professional_at(:'clinic','00000000-0000-0000-0000-000000000151'::uuid,clock_timestamp()),'151 dejo de ser profesional habilitado');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000150',false);
set role authenticated;
select public.permission_grant(:'clinic','00000000-0000-0000-0000-000000000151','patient.write',null,clock_timestamp()+interval '1 day','Synthetic lab capture') as write_grant \gset
reset role;

select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000151',false);
set role authenticated;
-- La toma va una hora atras y no en una fecha fija: la habilitacion del
-- profesional se comprueba al momento de la toma, asi que una fecha vieja
-- la rechazaria por una razon que no es la que se quiere probar.
select set_config('test.panel_data',jsonb_build_object(
 'confirmed',true,
 'collected_at',to_char((clock_timestamp()-interval '1 hour') at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
 'origin','laboratorio_externo','lab_name','Lab sintetico',
 'results',jsonb_build_array(
  jsonb_build_object('analyte_key','hematocrito','value','36','unit','%'),
  jsonb_build_object('analyte_key','albumina','value','3.25','unit','g/dL')))::text,false);
select public.lab_panel_record(:'clinic',current_setting('test.patient')::uuid,current_setting('test.panel_data')::jsonb,repeat('0a',24)) as panel \gset
select set_config('test.panel',:'panel',false);
select pg_temp.assert_true(:'panel' is not null,'la toma no se guardo');

-- Idempotencia: la misma operacion devuelve la misma toma, no crea otra.
select pg_temp.assert_true(public.lab_panel_record(:'clinic',current_setting('test.patient')::uuid,current_setting('test.panel_data')::jsonb,repeat('0a',24))=:'panel'::uuid,'la operacion repetida creo otra toma');
-- Misma operacion con otro contenido: se rechaza.
select pg_temp.expect_error($q$select public.lab_panel_record(current_setting('test.clinic')::uuid,current_setting('test.patient')::uuid,jsonb_set(current_setting('test.panel_data')::jsonb,'{lab_name}','"Otro"'),repeat('0a',24))$q$,'operation_payload_changed');

-- LA REGLA: la lectura devuelve las DOS fuentes y no emite juicio.
select public.lab_workspace(:'clinic',current_setting('test.patient')::uuid) as ws \gset
select pg_temp.assert_true(jsonb_array_length(:'ws'::jsonb->'panels')=1,'no devolvio la toma');
select pg_temp.assert_true(jsonb_array_length(:'ws'::jsonb#>'{panels,0,results}')=2,'no devolvio los dos resultados');
select pg_temp.assert_true(jsonb_array_length(:'ws'::jsonb#>'{panels,0,results,0,ranges}')=2,'debe devolver las DOS referencias del hematocrito');
select pg_temp.assert_true((:'ws'::jsonb#>>'{panels,0,results,0,ranges,0,source}')='Fuente A','la primera referencia perdio su fuente');
select pg_temp.assert_true((:'ws'::jsonb#>>'{panels,0,results,0,ranges,1,source}')='Fuente B','la segunda referencia perdio su fuente');
select pg_temp.assert_true((:'ws'::jsonb#>>'{panels,0,results,0,ranges,1,verified}')='false','verified debe viajar al cliente');
select pg_temp.assert_true(not(:'ws'::jsonb#>'{panels,0,results,0}' ? 'flag'),'el servidor NO debe emitir juicio');
-- El valor viaja como texto exacto, sin pasar por un flotante.
select pg_temp.assert_true((:'ws'::jsonb#>>'{panels,0,results,1,value}')='3.25','el valor perdio exactitud');
-- La especie queda congelada en la toma.
select pg_temp.assert_true((:'ws'::jsonb#>>'{panels,0,species}')='synthetic','la toma no guardo la especie');

-- Validaciones de entrada.
select pg_temp.expect_error($q$select public.lab_panel_record(current_setting('test.clinic')::uuid,current_setting('test.patient')::uuid,jsonb_set(current_setting('test.panel_data')::jsonb,'{results,0,value}','"1,200"'),repeat('0b',24))$q$,'exact_lab_value_required');
select pg_temp.expect_error($q$select public.lab_panel_record(current_setting('test.clinic')::uuid,current_setting('test.patient')::uuid,jsonb_set(current_setting('test.panel_data')::jsonb,'{results,1,analyte_key}','"Hematocrito "'),repeat('0c',24))$q$,'lab_analyte_repeated');
select pg_temp.expect_error($q$select public.lab_panel_record(current_setting('test.clinic')::uuid,current_setting('test.patient')::uuid,jsonb_set(current_setting('test.panel_data')::jsonb,'{collected_at}','"2099-01-01T00:00:00Z"'),repeat('0d',24))$q$,'invalid_lab_collection_time');
select pg_temp.expect_error($q$select public.lab_panel_record(current_setting('test.clinic')::uuid,current_setting('test.patient')::uuid,jsonb_set(current_setting('test.panel_data')::jsonb,'{results}','[]'),repeat('0e',24))$q$,'lab_results_required');
select pg_temp.expect_error($q$select public.lab_panel_record(current_setting('test.clinic')::uuid,current_setting('test.patient')::uuid,current_setting('test.panel_data')::jsonb-'confirmed',repeat('0f',24))$q$,'lab_confirmation_required');
select pg_temp.expect_error($q$select public.lab_panel_record(current_setting('test.clinic')::uuid,current_setting('test.patient')::uuid,current_setting('test.panel_data')::jsonb||'{"otro":1}'::jsonb,repeat('1a',24))$q$,'lab_panel_fields_only');
select pg_temp.expect_error($q$select public.lab_panel_record(current_setting('test.clinic')::uuid,'00000000-0000-0000-0000-000000000900',current_setting('test.panel_data')::jsonb,repeat('1b',24))$q$,'patient_not_found');

-- Correccion: conserva el original y exige motivo.
-- Las tablas privadas se leen fuera del rol authenticated a proposito: que
-- no las alcance es parte de lo que se esta comprobando.
reset role;
select id as primero from private.lab_results where panel_id=:'panel'::uuid and analyte_key='hematocrito' \gset
select set_config('test.primero',:'primero',false);
set role authenticated;
select public.lab_result_correct(:'clinic',:'primero',$j${"confirmed":true,"value":"41","unit":"%","correction_reason":"Captura equivocada"}$j$::jsonb,repeat('1c',24)) as corregido \gset
reset role;
select pg_temp.assert_true((select count(*) from private.lab_results where panel_id=:'panel'::uuid)=3,'la correccion debe agregar, no reemplazar');
select pg_temp.assert_true((select value from private.lab_results where id=:'primero')=36,'el original cambio');
select pg_temp.assert_true((select replaces_id from private.lab_results where id=:'corregido')=:'primero'::uuid,'la correccion no apunta al original');
set role authenticated;
-- Una correccion de la correccion sobre el mismo original se rechaza.
select pg_temp.expect_error($q$select public.lab_result_correct(current_setting('test.clinic')::uuid,current_setting('test.primero')::uuid,'{"confirmed":true,"value":"42","unit":"%","correction_reason":"Otra"}'::jsonb,repeat('1d',24))$q$,'lab_result_already_corrected');
-- Sin motivo no hay correccion. Se prueba sobre el resultado que NO se ha
-- corregido: sobre el otro saltaria antes la regla de una sola correccion.
reset role;
select id as segundo from private.lab_results where panel_id=:'panel'::uuid and analyte_key='albumina' \gset
select set_config('test.segundo',:'segundo',false);
set role authenticated;
select pg_temp.expect_error($q$select public.lab_result_correct(current_setting('test.clinic')::uuid,current_setting('test.segundo')::uuid,'{"confirmed":true,"value":"3.4","unit":"g/dL"}'::jsonb,repeat('1e',24))$q$,'invalid_lab_result');
-- Y sin confirmar tampoco.
select pg_temp.expect_error($q$select public.lab_result_correct(current_setting('test.clinic')::uuid,current_setting('test.segundo')::uuid,'{"value":"3.4","unit":"g/dL","correction_reason":"Sin confirmar"}'::jsonb,repeat('2b',24))$q$,'lab_confirmation_required');
reset role;

-- Nada se edita ni se borra, ni siquiera fuera de las funciones.
select pg_temp.expect_error($q$update private.lab_results set value=99 where id=current_setting('test.primero')::uuid$q$,'append_only_permission_record');
select pg_temp.expect_error($q$delete from private.lab_panels where id=current_setting('test.panel')::uuid$q$,'append_only_permission_record');

-- Otro profesional, con el mismo permiso, tampoco corrige lo ajeno: lo que
-- lo impide es la autoria, no el permiso. Por eso se le concede primero.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000150',false);
set role authenticated;
select public.permission_grant(:'clinic','00000000-0000-0000-0000-000000000152','patient.write',null,clock_timestamp()+interval '1 day','Synthetic lab capture 152') as write_grant_152 \gset
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000152',false);
set role authenticated;
select pg_temp.expect_error($q$select public.lab_result_correct(current_setting('test.clinic')::uuid,current_setting('test.primero')::uuid,'{"confirmed":true,"value":"42","unit":"%","correction_reason":"Ajena"}'::jsonb,repeat('1f',24))$q$,'own_lab_correction_required');
reset role;

-- Y quien no tiene el permiso no captura, aunque sea del equipo.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000160',false);
set role authenticated;
select pg_temp.expect_error($q$select public.lab_panel_record(current_setting('test.clinic')::uuid,current_setting('test.patient')::uuid,current_setting('test.panel_data')::jsonb,repeat('2a',24))$q$,'explicit_permission_required');
select pg_temp.expect_error($q$select public.lab_workspace(current_setting('test.clinic')::uuid,null,null)$q$,'explicit_permission_required');
reset role;

-- Sin sesion, nada.
set role anon;
select pg_temp.expect_error('select public.lab_workspace(null,null,null)','permission denied');
select pg_temp.expect_error('select public.lab_panel_record(null,null,null,null)','permission denied');
select pg_temp.expect_error('select public.lab_result_correct(null,null,null,null)','permission denied');
reset role;

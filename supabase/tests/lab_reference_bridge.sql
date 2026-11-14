-- Regresion de 15N_lab_reference_library_bridge.sql. Corre despues de
-- lab_results.sql: reutiliza su clinica, su paciente y su permiso de
-- captura, y la biblioteca sintetica de reference_library_fixture.sql.
create function pg_temp.a(v boolean,msg text) returns void language plpgsql as $$begin if v is distinct from true then raise exception 'ASSERT: %',msg;end if;end$$;
create function pg_temp.err(sql text,expected text) returns void language plpgsql as $$begin begin execute sql;exception when others then if position(expected in sqlerrm)>0 then return;end if;raise;end;raise exception 'Expected rejection: %',expected;end$$;

-- Cada archivo corre en su propia sesion de psql, asi que los set_config de
-- lab_results.sql no llegan hasta aqui: la clinica y el paciente se vuelven
-- a fijar con el mismo criterio que alla, por habilitacion y no por nombre.
select pp.clinic_id as clinic from public.professional_profiles pp
 join private.professional_verifications v on v.user_id=pp.user_id
 where pp.user_id='00000000-0000-0000-0000-000000000151' limit 1 \gset
select set_config('test.clinic',:'clinic',false);
select set_config('test.patient','00000000-0000-0000-0000-000000000600',false);

-- Cuantos rangos resuelve la biblioteca para un analito de la especie.
create function pg_temp.n(analito text) returns integer language sql stable as
 $$select jsonb_array_length(private.lab_reference_for(analito,'synthetic'))$$;

-- Las dos fuentes de la biblioteca llegan, y la fila de 'Constantes' con el
-- mismo nombre NO: fisiologia no es laboratorio.
select pg_temp.a(pg_temp.n('eritrocitos')=2,'eritrocitos no trajo las dos fuentes de laboratorio');
select pg_temp.a(pg_temp.n('ERITROCITOS ')=2,'el analito deberia cotejarse sin distinguir mayusculas ni espacios');
-- Y el union con lo que la clinica publico en private sigue en pie.
select pg_temp.a(pg_temp.n('hematocrito')=2,'se perdieron los rangos propios de la clinica');

-- Toda fila importada viaja como pendiente de validacion y sin verificar.
select pg_temp.a((select bool_and((r->>'verified')::boolean is false and r->>'source' like '%pendiente de validación MVZ')
 from jsonb_array_elements(private.lab_reference_for('eritrocitos','synthetic')) r),
 'un rango importado se presento como verificado o sin la nota de validacion');

-- El aviso de otro intervalo viaja dentro de la fuente; no se inventa un
-- segundo rango.
select pg_temp.a(pg_temp.n('glucosa')=1,'glucosa trajo mas de un rango: se invento un intervalo');
select pg_temp.a((select private.lab_reference_for('glucosa','synthetic')->0->>'source')
 like '%el archivo señala otro intervalo%','se perdio el aviso de otro intervalo');

-- Lo que no es un rango se queda fuera, en vez de entrar a medias.
select pg_temp.a(pg_temp.n('indice sin unidad')=0,'entro una fila sin unidad');
select pg_temp.a(pg_temp.n('texto')=0,'entro una fila con limite no numerico');
select pg_temp.a(pg_temp.n('invertida')=0,'entro una fila con el alto menor que el bajo');
select pg_temp.a(pg_temp.n('sin fuente')=0,'entro una fila sin fuente');
-- Ni se cruzan las especies.
select pg_temp.a(jsonb_array_length(private.lab_reference_for('eritrocitos','otra especie sintetica'))=1,'la otra especie no resolvio su propio rango');

-- La lectura del expediente: una toma nueva con los tres casos.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000151',false);
set role authenticated;
select set_config('test.bridge_data',jsonb_build_object(
 'confirmed',true,
 'collected_at',to_char((clock_timestamp()-interval '30 minutes') at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
 'origin','equipo_propio','lab_name','',
 'results',jsonb_build_array(
  jsonb_build_object('analyte_key','eritrocitos','value','7.0','unit','10^6/uL'),
  jsonb_build_object('analyte_key','glucosa','value','90','unit','mg/dL'),
  -- La unidad de la biblioteca es mmol/L: el rango debe llegar igual para
  -- que la pantalla pueda decir «la unidad no coincide».
  jsonb_build_object('analyte_key','urea','value','40','unit','mg/dL')))::text,false);
select public.lab_panel_record(current_setting('test.clinic')::uuid,current_setting('test.patient')::uuid,
 current_setting('test.bridge_data')::jsonb,repeat('b7',24)) as bridge_panel \gset
select set_config('test.bridge_panel',:'bridge_panel',false);

select set_config('test.ws',public.lab_workspace(current_setting('test.clinic')::uuid,
 current_setting('test.patient')::uuid,current_setting('test.bridge_panel')::uuid)::text,false);
-- Cada resultado llega con sus rangos resueltos.
select pg_temp.a((select count(*) from jsonb_array_elements(current_setting('test.ws')::jsonb->'panels'->0->'results') r
 where jsonb_array_length(r->'ranges')>0)=3,'algun resultado llego sin rango de referencia');
select pg_temp.a((select jsonb_array_length(r->'ranges') from jsonb_array_elements(current_setting('test.ws')::jsonb->'panels'->0->'results') r
 where r->>'analyte_key'='eritrocitos')=2,'eritrocitos no llego con las dos fuentes');
select pg_temp.a((select jsonb_array_length(r->'ranges') from jsonb_array_elements(current_setting('test.ws')::jsonb->'panels'->0->'results') r
 where r->>'analyte_key'='urea')=1,'el rango en otra unidad desaparecio en vez de marcarse');
-- El servidor sigue sin emitir juicio: ninguna clave de veredicto.
select pg_temp.a(not (current_setting('test.ws')::jsonb->'panels'->0->'results'->0 ? 'flag')
 and not (current_setting('test.ws')::jsonb->'panels'->0->'results'->0 ? 'status')
 and not (current_setting('test.ws')::jsonb->'panels'->0->'results'->0 ? 'verdict'),
 'el servidor empezo a emitir un veredicto');

-- El catalogo ofrece los nombres que la biblioteca conoce, y solo esos.
select set_config('test.cat',public.lab_analyte_catalog(current_setting('test.clinic')::uuid,current_setting('test.patient')::uuid)::text,false);
select pg_temp.a((select count(*) from jsonb_array_elements(current_setting('test.cat')::jsonb->'items') i
 where i->>'analyte_key' in ('eritrocitos','glucosa','urea'))=3,'el catalogo no ofrecio los tres analitos');
select pg_temp.a((select count(*) from jsonb_array_elements(current_setting('test.cat')::jsonb->'items') i
 where i->>'analyte_key' in ('indice sin unidad','texto','invertida','sin fuente'))=0,'el catalogo ofrecio una fila que no es un rango');
-- Eritrocitos tiene dos fuentes y el catalogo lo dice.
select pg_temp.a((select (i->>'sources')::int from jsonb_array_elements(current_setting('test.cat')::jsonb->'items') i
 where i->>'analyte_key'='eritrocitos')=2,'el catalogo no conto las dos fuentes');
-- Lo publicado por la clinica tambien se ofrece.
select pg_temp.a((select count(*) from jsonb_array_elements(current_setting('test.cat')::jsonb->'items') i
 where i->>'analyte_key'='hematocrito')>0,'el catalogo ignoro los rangos propios de la clinica');
-- La especie sale del expediente: un paciente que no es de la clinica no
-- tiene catalogo.
select pg_temp.err($q$select public.lab_analyte_catalog(current_setting('test.clinic')::uuid,'00000000-0000-0000-0000-0000000009ff'::uuid)$q$,'patient_not_found');
reset role;

-- Sin el permiso del modulo no hay catalogo, y sin sesion no hay nada.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000160',false);
set role authenticated;
select pg_temp.err($q$select public.lab_analyte_catalog(current_setting('test.clinic')::uuid,current_setting('test.patient')::uuid)$q$,'explicit_permission_required');
reset role;
set role anon;
select pg_temp.err($q$select public.lab_analyte_catalog(null,null)$q$,'permission denied');
-- La biblioteca no se lee directo: solo por la funcion.
select pg_temp.err('select count(*) from vetdosis_reference_staging.raw_intake_rows','permission denied');
reset role;

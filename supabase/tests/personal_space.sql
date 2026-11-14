-- 16A · Mi espacio personal. Run after staff_medical_privacy.sql and 16A_espacio_personal.sql.
-- 181 (mvz) owns the profile, 152 (auxiliar) is the chosen colleague, 151 (mvz) is not chosen,
-- 150 (admin) is the clinic administration.
create function pg_temp.ps_assert(v boolean,msg text) returns void language plpgsql as $$begin if v is distinct from true then raise exception 'ASSERT: %',msg;end if;end$$;
create function pg_temp.ps_error(sql text,expected text) returns void language plpgsql as $$begin begin execute sql;exception when others then if position(expected in sqlerrm)>0 then return;end if;raise;end;raise exception 'Expected rejection: %',expected;end$$;
select id as clinic from public.clinics where name='Synthetic medication permissions' \gset
insert into public.staff_display_names(clinic_id,user_id,name) values(:'clinic','00000000-0000-0000-0000-000000000152','Auxiliar sintética')
 on conflict do nothing;

-- Notes, reminders and schedules are visible only to their owner.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000181',false);
set role authenticated;
insert into public.personal_notes(title,body) values('Nota privada','PERSONAL-NOTE-PRIVATE');
insert into public.personal_notes(kind,title,remind_at) values('reminder','Recordatorio',clock_timestamp()+interval '1 day');
select pg_temp.ps_error($$insert into public.personal_notes(kind,title,remind_at) values('note','Sin fecha',clock_timestamp())$$,'check constraint');
insert into public.personal_work_schedules(place,linked_clinic_id,weekday,starts_at,ends_at) values('Clínica sintética',:'clinic',1,'09:00','15:00');
insert into public.personal_work_schedules(place,weekday,starts_at,ends_at) values('Guardia externa',6,'20:00','08:00');
select pg_temp.ps_error(format('insert into public.personal_work_schedules(place,linked_clinic_id,weekday,starts_at,ends_at) values(%L,gen_random_uuid(),2,%L,%L)','Ajena','09:00','10:00'),'row-level security');
select pg_temp.ps_error($$insert into public.personal_notes(user_id,title) values('00000000-0000-0000-0000-000000000152','Suplantada')$$,'row-level security');
select pg_temp.ps_assert((select count(*) from public.personal_notes)=2 and (select count(*) from public.personal_work_schedules)=2,'owner cannot read own notes or schedules');
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000150',false);
set role authenticated;
select pg_temp.ps_assert((select count(*) from public.personal_notes)=0 and (select count(*) from public.personal_work_schedules)=0,'admin reads personal notes or schedules');
update public.personal_notes set title='Cambiada';
delete from public.personal_work_schedules;
reset role;
select pg_temp.ps_assert((select count(*) from public.personal_notes where title='Cambiada')=0 and (select count(*) from public.personal_work_schedules)=2,'admin changed personal rows');

-- The notice changes to version 2 and the new field is accepted.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000181',false);
set role authenticated;
select public.ops_staff_medical_workspace(:'clinic',auth.uid()) as ws \gset
select :'ws'::jsonb->>'member_since' as since,:'ws'::jsonb->'notice'->>'hash' as hash,(:'ws'::jsonb->>'revision')::bigint as rev \gset
select pg_temp.ps_assert((:'ws'::jsonb->'notice'->>'version')::int=2 and :'ws'::jsonb->'notice'->>'text' like '%compañeros de esta clínica que tú elijas%','notice was not updated');
select pg_temp.ps_error(format('select public.ops_staff_medical_write(%L,%L,%L,true,1,%L,%s,%L,%L,%L)',:'clinic','save','{"blood":"O+"}',:'hash',:'rev',:'since',auth.uid(),repeat('fa01',12)),'staff_medical_consent_required');
select pg_temp.ps_error(format('select public.ops_staff_medical_write(%L,%L,%L,true,2,%L,%s,%L,%L,%L)',:'clinic','save','{"diet":"x"}',:'hash',:'rev',:'since',auth.uid(),repeat('fa02',12)),'staff_medical_fields_invalid');
select public.ops_staff_medical_write(:'clinic','save','{"blood":"O+","drug_allergies":"DRUG-ALLERGY-PRIVATE","conditions":"Asma"}',true,2,:'hash',:'rev',:'since',auth.uid(),repeat('fa03',12));
select pg_temp.ps_assert(public.ops_staff_medical_workspace(:'clinic',auth.uid())->'profile'->'details'->>'drug_allergies'='DRUG-ALLERGY-PRIVATE','drug allergies not saved');

-- Choose a colleague. Only members can be chosen, never oneself.
select pg_temp.ps_error(format('select public.ops_staff_medical_delegate_set(%L,%L,%L,true)',:'clinic',auth.uid(),auth.uid()),'staff_medical_delegate_invalid');
select pg_temp.ps_error(format('select public.ops_staff_medical_delegate_set(%L,%L,%L,true)',:'clinic',auth.uid(),'00000000-0000-0000-0000-000000000999'),'staff_medical_delegate_invalid');
select public.ops_staff_medical_delegate_set(:'clinic',auth.uid(),'00000000-0000-0000-0000-000000000152',true);
select public.ops_staff_medical_delegate_set(:'clinic',auth.uid(),'00000000-0000-0000-0000-000000000152',true);
select public.ops_staff_medical_delegates(:'clinic',auth.uid()) as mine \gset
select pg_temp.ps_assert((select count(*) from jsonb_array_elements(:'mine'::jsonb->'colleagues') c where c->>'user_id'='00000000-0000-0000-0000-000000000152' and (c->>'delegated')::boolean and c->>'display_name'='Auxiliar sintética')=1,'chosen colleague not listed');
select pg_temp.ps_assert(not exists(select 1 from jsonb_array_elements(:'mine'::jsonb->'colleagues') c where c->>'user_id'=auth.uid()::text),'owner listed as own colleague');
select pg_temp.ps_error('select count(*) from private.staff_medical_delegates','permission denied');
reset role;
select pg_temp.ps_assert((select count(*) from public.audit_log where clinic_id=:'clinic' and action='staff_medical_delegate_granted')=1,'repeated grant was audited twice');

-- The chosen colleague reads with an explicit purpose; another colleague cannot.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000152',false);
set role authenticated;
select public.ops_staff_medical_delegates(:'clinic',auth.uid()) as shared \gset
select pg_temp.ps_assert(jsonb_array_length(:'shared'::jsonb->'shared_with_me')=1 and (:'shared'::jsonb->'shared_with_me'->0->>'available')::boolean and :'shared' not like '%DRUG-ALLERGY-PRIVATE%','shared list missing or leaks health data');
select pg_temp.ps_error(format('select public.ops_staff_medical_delegate_view(%L,%L,null,%L)',:'clinic','00000000-0000-0000-0000-000000000181',auth.uid()),'staff_medical_purpose_required');
select public.ops_staff_medical_delegate_view(:'clinic','00000000-0000-0000-0000-000000000181','emergency',auth.uid()) as viewed \gset
select pg_temp.ps_assert(:'viewed'::jsonb->'details'->>'drug_allergies'='DRUG-ALLERGY-PRIVATE','delegate did not receive the profile');
select pg_temp.ps_error(format('select public.ops_staff_medical_view(%L,%L,%L,%L)',:'clinic','00000000-0000-0000-0000-000000000181','emergency',auth.uid()),'staff_medical_read_required');
select pg_temp.ps_assert((public.ops_staff_medical_access_log(:'clinic',auth.uid())->>'scope')='own' and jsonb_array_length(public.ops_staff_medical_access_log(:'clinic',auth.uid())->'items')=0,'delegate sees other access logs');
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000151',false);
set role authenticated;
select pg_temp.ps_error(format('select public.ops_staff_medical_delegate_view(%L,%L,%L,%L)',:'clinic','00000000-0000-0000-0000-000000000181','emergency',auth.uid()),'staff_medical_delegate_required');
reset role;
select pg_temp.ps_assert(not exists(select 1 from public.audit_log where details::text like '%DRUG-ALLERGY-PRIVATE%'),'medical text copied to audit');

-- The owner and the administration both see the read; nobody sees the medical content there.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000181',false);
set role authenticated;
select public.ops_staff_medical_access_log(:'clinic',auth.uid()) as own_log \gset
select pg_temp.ps_assert(:'own_log'::jsonb->>'scope'='own' and exists(select 1 from jsonb_array_elements(:'own_log'::jsonb->'items') i where i->>'via'='delegate' and i->>'actor_name'='Auxiliar sintética' and i->>'purpose'='emergency'),'owner cannot see delegate read');
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000150',false);
set role authenticated;
select public.ops_staff_medical_access_log(:'clinic',auth.uid()) as admin_log \gset
select pg_temp.ps_assert(:'admin_log'::jsonb->>'scope'='clinic' and exists(select 1 from jsonb_array_elements(:'admin_log'::jsonb->'items') i where i->>'via'='delegate' and i->>'subject_id'='00000000-0000-0000-0000-000000000181') and :'admin_log' not like '%DRUG-ALLERGY-PRIVATE%','administration cannot see delegate read or log leaks health data');
reset role;

-- Revoking stops the next read.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000181',false);
set role authenticated;
select public.ops_staff_medical_delegate_set(:'clinic',auth.uid(),'00000000-0000-0000-0000-000000000152',false);
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000152',false);
set role authenticated;
select pg_temp.ps_error(format('select public.ops_staff_medical_delegate_view(%L,%L,%L,%L)',:'clinic','00000000-0000-0000-0000-000000000181','emergency',auth.uid()),'staff_medical_delegate_required');
select pg_temp.ps_assert(jsonb_array_length(public.ops_staff_medical_delegates(:'clinic',auth.uid())->'shared_with_me')=0,'revoked profile still listed');
reset role;

-- A choice does not survive leaving and rejoining the clinic.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000181',false);
set role authenticated;
select public.ops_staff_medical_delegate_set(:'clinic',auth.uid(),'00000000-0000-0000-0000-000000000152',true);
reset role;
update public.clinic_members set created_at=clock_timestamp()+interval '1 minute' where clinic_id=:'clinic' and user_id='00000000-0000-0000-0000-000000000152';
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000152',false);
set role authenticated;
select pg_temp.ps_error(format('select public.ops_staff_medical_delegate_view(%L,%L,%L,%L)',:'clinic','00000000-0000-0000-0000-000000000181','emergency',auth.uid()),'staff_medical_delegate_required');
reset role;
select 'personal space passed';

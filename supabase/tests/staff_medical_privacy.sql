create function pg_temp.medical_assert(v boolean,msg text) returns void language plpgsql as $$begin if v is distinct from true then raise exception 'ASSERT: %',msg;end if;end$$;
create function pg_temp.medical_error(sql text,expected text) returns void language plpgsql as $$begin begin execute sql;exception when others then if position(expected in sqlerrm)>0 then return;end if;raise;end;raise exception 'Expected rejection: %',expected;end$$;
select id as clinic from public.clinics where name='Synthetic medication permissions' \gset
insert into public.staff_medical_profiles(clinic_id,user_id,details) values(:'clinic','00000000-0000-0000-0000-000000000151','{"allergies":"LEGACY-HEALTH-PRIVATE"}');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000181',false);
set role authenticated;
select public.ops_staff_medical_workspace(:'clinic',auth.uid()) as workspace \gset
select :'workspace'::jsonb->>'member_since' as member_since,:'workspace'::jsonb->'notice'->>'hash' as notice_hash \gset
select pg_temp.medical_assert(:'workspace'::jsonb->'profile'='null'::jsonb and (:'workspace'::jsonb->>'revision')::bigint=0,'initial workspace has another person profile');
select public.ops_staff_medical_write(:'clinic','save','{"allergies":"HEALTH-NOT-IN-LOGS","emergency":"Synthetic contact"}',true,1,:'notice_hash',0,:'member_since',auth.uid(),repeat('ea01',12)) as acceptance \gset
select pg_temp.medical_assert(public.ops_staff_medical_write(:'clinic','save','{"emergency":"Synthetic contact","allergies":" HEALTH-NOT-IN-LOGS "}',true,1,:'notice_hash',0,:'member_since',auth.uid(),repeat('ea01',12))=:'acceptance'::uuid,'retry duplicated acceptance');
select pg_temp.medical_error(format('select public.ops_staff_medical_write(%L,%L,%L,false,1,%L,1,%L,%L,%L)',:'clinic','save','{"blood":"Synthetic"}',:'notice_hash',:'member_since','00000000-0000-0000-0000-000000000181',repeat('ea02',12)),'staff_medical_consent_required');
select pg_temp.medical_error(format('select public.ops_staff_medical_directory(%L,%L)',:'clinic','00000000-0000-0000-0000-000000000181'),'staff_medical_read_required');
select pg_temp.medical_error('select count(*) from public.staff_medical_profiles','permission denied');
reset role;
select pg_temp.medical_assert((select count(*)=1 from private.staff_medical_events where clinic_id=:'clinic' and user_id='00000000-0000-0000-0000-000000000181'),'duplicate consent event');
select pg_temp.medical_assert(not exists(select 1 from private.vet_operation_receipts where fingerprint::text like '%HEALTH-NOT-IN-LOGS%'),'medical text copied to receipt');
select pg_temp.medical_assert(not exists(select 1 from public.audit_log where details::text like '%HEALTH-NOT-IN-LOGS%'),'medical text copied to audit');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000150',false);
set role authenticated;
select pg_temp.medical_assert(jsonb_array_length(public.ops_medical(:'clinic'))=0,'legacy endpoint exposes coworkers to admin');
select pg_temp.medical_error(format('select public.ops_staff_medical_directory(%L,%L)',:'clinic','00000000-0000-0000-0000-000000000150'),'staff_medical_read_required');
select public.permission_grant(:'clinic',auth.uid(),'staff.medical.read',null,clock_timestamp()+interval '1 day','Synthetic emergency read permission') as read_grant \gset
select public.ops_staff_medical_directory(:'clinic',auth.uid()) as directory \gset
select pg_temp.medical_assert(jsonb_array_length(:'directory'::jsonb->'items')=1 and :'directory' not like '%HEALTH-NOT-IN-LOGS%' and :'directory' not like '%LEGACY-HEALTH-PRIVATE%','directory contains health data or unversioned consent');
select pg_temp.medical_error(format('select public.ops_staff_medical_view(%L,%L,null,%L)',:'clinic','00000000-0000-0000-0000-000000000181',auth.uid()),'staff_medical_purpose_required');
select public.ops_staff_medical_view(:'clinic','00000000-0000-0000-0000-000000000181','emergency',auth.uid()) as viewed \gset
select pg_temp.medical_assert(:'viewed'::jsonb->'details'->>'allergies'='HEALTH-NOT-IN-LOGS','authorized detail missing');
select public.permission_grant(:'clinic',auth.uid(),'backup.export',null,clock_timestamp()+interval '1 day','Synthetic privacy backup');
select pg_temp.medical_assert(jsonb_array_length(public.clinic_export(:'clinic')::jsonb->'tables'->'my_staff_medical_events')=0,'backup copied coworker consent');
select pg_temp.medical_assert(jsonb_array_length(public.clinic_export(:'clinic')::jsonb->'tables'->'my_staff_medical_profile')=0,'backup copied coworker health');
reset role;
select pg_temp.medical_assert((select count(*)=1 from private.staff_medical_accesses where clinic_id=:'clinic' and subject_id='00000000-0000-0000-0000-000000000181'),'access not audited');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000181',false);
set role authenticated;
select pg_temp.medical_assert(jsonb_array_length(public.ops_staff_medical_workspace(:'clinic',auth.uid())->'accesses')=1,'subject cannot see access history');
select pg_temp.medical_error(format('select public.ops_staff_medical_write(%L,%L,null,false,null,null,0,%L,%L,%L)',:'clinic','withdraw',:'member_since',auth.uid(),repeat('ea03',12)),'staff_medical_revision_changed');
select public.ops_staff_medical_write(:'clinic','withdraw',null,false,null,null,1,:'member_since',auth.uid(),repeat('ea04',12)) as withdrawal \gset
select pg_temp.medical_assert(public.ops_staff_medical_write(:'clinic','withdraw',null,false,null,null,1,:'member_since',auth.uid(),repeat('ea04',12))=:'withdrawal'::uuid,'withdraw retry created another event');
select pg_temp.medical_assert(public.ops_staff_medical_workspace(:'clinic',auth.uid())->'profile'='null'::jsonb,'withdrawal retained active profile');
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000150',false);
set role authenticated;
select pg_temp.medical_error(format('select public.ops_staff_medical_view(%L,%L,%L,%L)',:'clinic','00000000-0000-0000-0000-000000000181','emergency',auth.uid()),'staff_medical_profile_unavailable');
select public.permission_revoke(:'read_grant','Synthetic medical read revoked');
select pg_temp.medical_error(format('select public.ops_staff_medical_view(%L,%L,%L,%L)',:'clinic','00000000-0000-0000-0000-000000000181','emergency',auth.uid()),'staff_medical_read_required');
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000181',false);
set role authenticated;
select public.ops_staff_medical_write(:'clinic','save','{"emergency":"Synthetic restored profile"}',true,1,:'notice_hash',2,:'member_since',auth.uid(),repeat('ea05',12));
select pg_temp.medical_error(format('select public.ops_staff_medical_write(%L,%L,%L,true,1,%L,1,%L,%L,%L)',:'clinic','save','{"blood":"Stale form"}',:'notice_hash',:'member_since',auth.uid(),repeat('ea06',12)),'staff_medical_revision_changed');
select pg_temp.medical_error(format('select public.ops_staff_medical_workspace(%L,%L)',:'clinic','00000000-0000-0000-0000-000000000150'),'session_changed');
reset role;
-- Legacy readers see their own data; legacy withdrawal does not require acceptance.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000151',false);
set role authenticated;
select pg_temp.medical_assert(jsonb_array_length(public.ops_medical(:'clinic'))=1,'legacy subject lost access to own profile');
select pg_temp.medical_error(format('select public.ops_medical(%L,%L,true)',:'clinic','{"blood":"Unversioned save"}'),'staff_medical_client_upgrade_required');
select pg_temp.medical_assert(jsonb_array_length(public.ops_medical(:'clinic','{}',false))=0,'legacy withdrawal requires consent');
reset role;
select pg_temp.medical_assert(not has_table_privilege('authenticated','private.staff_medical_events','SELECT'),'private event table exposed');
select pg_temp.medical_assert(not has_function_privilege('anon','public.ops_staff_medical_workspace(uuid,uuid)','EXECUTE'),'anonymous workspace callable');
select pg_temp.medical_assert(not has_function_privilege('authenticated','private.staff_medical_gate(uuid,uuid,boolean,boolean)','EXECUTE'),'private authorization gate callable');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000153',false);
set role authenticated;
select pg_temp.medical_error(format('select public.ops_staff_medical_workspace(%L,%L)',:'clinic',auth.uid()),'clinic_membership_required');
reset role;

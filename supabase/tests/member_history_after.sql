-- Regression assertions use the real public removal/account/payment RPCs.
create function pg_temp.p0_assert(v boolean,message text) returns void language plpgsql as $$begin
 if v is distinct from true then raise exception 'ASSERT: %',message;end if;
end$$;
create function pg_temp.p0_reject(sql text,expected text) returns void language plpgsql as $$begin
 begin execute sql;exception when others then if position(expected in sqlerrm)>0 then return;end if;raise;end;
 raise exception 'Expected rejection: %',expected;
end$$;
select id as clinic from public.clinics where name='Synthetic medication permissions' \gset
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000291',false);
set role authenticated;
select pg_temp.p0_reject(format('select public.remove_clinic_member(%L,%L)',:'clinic','00000000-0000-0000-0000-000000000290'),'workspace_manage_required');
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000150',false);
set role authenticated;
select public.remove_clinic_member(:'clinic','00000000-0000-0000-0000-000000000290');
reset role;
select pg_temp.p0_assert(not exists(select 1 from public.clinic_members where clinic_id=:'clinic' and user_id='00000000-0000-0000-0000-000000000290'),'membership not removed');
do $unchanged$
declare expected record; digest text;
begin
 for expected in select * from private.p0_history_fingerprints loop
  execute format('select md5(coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text)::text,''[]'')) from %s t',expected.relation_name) into digest;
  if digest is distinct from expected.digest then raise exception 'history changed: %',expected.relation_name;end if;
 end loop;
end
$unchanged$;
select pg_temp.p0_assert(exists(select 1 from public.audit_log where clinic_id=:'clinic' and action='member_removed' and entity_id='00000000-0000-0000-0000-000000000290'),'removal audit missing');
set role authenticated;
select pg_temp.p0_assert(exists(select 1 from jsonb_array_elements(public.commission_account(:'clinic')->'accrued') row
 where row->>'professional_id'='00000000-0000-0000-0000-000000000290' and (row->>'amount')::numeric=7),'former staff unpaid balance omitted');
select public.commission_period_pay(:'clinic');
reset role;
select pg_temp.p0_assert((select sum(amount)=10 from public.clinic_commission_payments where clinic_id=:'clinic' and professional_id='00000000-0000-0000-0000-000000000290'),'former staff could not be paid');
-- Stable identity does not permit new assignments to former/nonmembers.
select pg_temp.p0_reject(format('insert into public.clinic_private_messages(clinic_id,author_id,recipient_id,body) values(%L,%L,%L,%L)',:'clinic','00000000-0000-0000-0000-000000000150','00000000-0000-0000-0000-000000000290','New disallowed message'),'current_member_required');
select pg_temp.p0_reject(format('insert into public.clinic_tasks(clinic_id,title,assigned_to,priority,created_by) values(%L,%L,%L,%L,%L)',:'clinic','Invalid assignment','00000000-0000-0000-0000-000000000290','media','00000000-0000-0000-0000-000000000150'),'current_member_required');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000290',false);
set role authenticated;
select pg_temp.p0_reject(format('select public.ops_dashboard(%L)',:'clinic'),'access_denied');
select pg_temp.p0_reject(format('select public.commission_account(%L)',:'clinic'),'access_denied');
select pg_temp.p0_reject(format('select public.app_module_workspace(%L)',:'clinic'),'current_member_required');
reset role;
-- All reviewed historical membership FKs were detached without CASCADE.
select pg_temp.p0_assert(not exists(select 1 from pg_constraint where contype='f' and confrelid='public.clinic_members'::regclass),'unhandled membership FK');

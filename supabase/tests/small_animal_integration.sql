-- Contract composition check, not an HTTP/device end-to-end acceptance test.
-- Executed after finance, prescribing, hospital, storage and patient adapters
-- in the SAME disposable database. Every fixture row is synthetic.
do $integration$
declare required_name text;
begin
 foreach required_name in array array[
  'app_module_workspace','clinical_workspace','rx_create','rx_consultations',
  'rx_authorize_individual','hospital_automation_workspace',
  'inv_sale_return_workspace','inv_sale_return_v3','clinic_experience_read'
 ] loop
  if not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname=required_name) then
   raise exception 'integrated_contract_missing: %',required_name;
  end if;
 end loop;
 if not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='inv_sale_return_workspace'
  and position('schema_version' in pg_get_functiondef(p.oid))>0) then
  raise exception 'financial_workspace_overwritten';
 end if;
 if exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname in
  ('rx_create','rx_authorize_individual','inv_sale_return_v3','hospital_automation_workspace')
  and has_function_privilege('anon',p.oid,'EXECUTE')) then
  raise exception 'anonymous_integrated_write_access';
 end if;
end
$integration$;

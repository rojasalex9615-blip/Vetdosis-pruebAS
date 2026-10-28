"""Generate an explicit upgrade for an already installed, closed TEST backend.

This module never connects or executes SQL. The observed catalog is a reviewed
input, not a dump of patient data. Historical initial-install scripts are excluded.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re

from integration_bundle import literal, unwrap

ROOT = Path(__file__).resolve().parents[2]
PROJECT = 'wtrelwtztkddfktrfdpb'
SOURCES = (
    'supabase/adaptations/patient_contacts_appointment_links_v1.sql',
    'supabase/adaptations/appointment_care_v1.sql',
    'supabase/adaptations/patient_activity_snapshot_v1.sql',
    'supabase/migrations/20261027021257_service_commission_recoveries.sql',
    'supabase/migrations/20261027024532_partial_product_returns.sql',
    'supabase/migrations/20261027031218_installments_service_returns.sql',
    'supabase/migrations/20261027144905_financial_return_freshness.sql',
    'supabase/migrations/20261027142748_staff_medical_consent_access.sql',
    'supabase/migrations/20261027062933_vial_reconciliation_retries.sql',
    'supabase/migrations/20261027064618_vial_incident_overview.sql',
    'supabase/proposed/13Q_restore_preview_staging.sql',
    'supabase/proposed/13R_restore_conflict_preview.sql',
    'supabase/proposed/13S_restore_decision_preview.sql',
    'supabase/proposed/13T_restore_application_preflight.sql',
    'supabase/proposed/13U_restore_owners_apply.sql',
    'supabase/proposed/13V_restore_patients_apply.sql',
    'supabase/migrations/20261028043154_preserve_member_history.sql',
)
INDEX_SOURCES = (
    'supabase/migrations/20261027141227_vial_movement_index_concurrent.sql',
    'supabase/migrations/20261027141229_vial_incident_index_concurrent.sql',
)
MISSING_RPCS = (
    'appointment_care_snapshot', 'appointment_care_write', 'appointment_patient_links',
    'inv_credit_accounts', 'inv_sale_collect', 'inv_sale_credit_post',
    'inv_sale_return', 'inv_sale_return_v2', 'inv_sale_return_v3', 'inv_sale_return_workspace',
    'ops_commission_recovery', 'ops_staff_medical_directory', 'ops_staff_medical_view',
    'ops_staff_medical_workspace', 'ops_staff_medical_write', 'patient_activity_snapshot',
    'patient_contact_log', 'patient_contact_save', 'patient_contact_snapshot',
    'restore_apply_owners', 'restore_apply_patients', 'restore_prepare_owners',
    'restore_prepare_patients', 'restore_preview_conflicts', 'restore_preview_discard',
    'restore_preview_get', 'restore_preview_plan', 'restore_preview_preflight',
    'restore_preview_stage',
)
PROTECTED = (
    'public.vet_owners', 'public.vet_patients', 'public.vet_patient_events',
    'public.clinical_cases', 'public.clinical_observations', 'public.prescriptions',
    'public.medication_records', 'public.medication_vials',
    'public.inventory_sales', 'public.inventory_sale_lines',
    'public.inventory_sale_reversals', 'public.inventory_cash_shifts',
    'public.clinic_members', 'public.clinic_service_acts',
    'public.clinic_service_commission_settlements', 'public.clinic_commission_payments',
    'public.staff_medical_profiles', 'public.attendance_consents',
    'public.attendance_events', 'public.clinic_tasks', 'public.clinic_appointments',
    'public.clinic_private_messages',
    'public.clinic_staff_contacts', 'private.member_job_labels',
    'private.member_permission_grants', 'private.professional_verifications',
    'private.beta_policy', 'private.permission_policy',
)


def sources(root=ROOT):
    return [(name, (root / name).read_text()) for name in SOURCES]


def signature(function):
    value = function['signature']
    if '.' not in value.split('(')[0]:
        value = function['schema'] + '.' + value
    return value


def plan(catalog, root=ROOT):
    if catalog.get('profile') not in ('observed-test-catalog', 'synthetic-local'):
        raise ValueError('Catalog must explicitly identify its reviewed or synthetic provenance.')
    if catalog.get('project_ref') != PROJECT:
        raise ValueError('Catalog project does not match the fixed TEST project.')
    texts = sources(root)
    affected = set(re.findall(r'(?i)(?:create\s+(?:or\s+replace\s+)?function|alter\s+function)\s+((?:public|private)\.\w+)', '\n'.join(s for _, s in texts)))
    new_tables = re.findall(r'(?i)create\s+table\s+(?:if\s+not\s+exists\s+)?((?:public|private)\.\w+)', '\n'.join(s for _, s in texts))
    existing_relations = {r['schema'] + '.' + r['name'] for r in catalog['relations']}
    if any(t in existing_relations for t in new_tables):
        raise ValueError('Partial upgrade: one or more new tables already exist; inspect instead of replaying.')
    existing_public = {f['name'] for f in catalog['functions'] if f['schema'] == 'public'}
    if any(name in existing_public for name in MISSING_RPCS):
        raise ValueError('Partial/already installed RPC upgrade requires a new catalog review.')
    existing = [dict(f, signature=signature(f)) for f in catalog['functions'] if f["schema"] + '.' + f['name'] in affected]
    return {
        'project_ref': PROJECT,
        'profile': catalog['profile'],
        'generator_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'transaction_unwrapper_sha256': hashlib.sha256((ROOT/'scripts/supabase/integration_bundle.py').read_bytes()).hexdigest(),
        'source_order': [{'path': n, 'sha256': hashlib.sha256(s.encode()).hexdigest()} for n, s in texts],
        'indexes_separate': [{'path': n, 'sha256': hashlib.sha256((root / n).read_bytes()).hexdigest()} for n in INDEX_SOURCES],
        'existing_functions': existing,
        'new_tables': sorted(set(new_tables)),
        'missing_rpcs': list(MISSING_RPCS),
        'protected_relations': list(PROTECTED),
    }


def bundle(catalog, *, commit=False, root=ROOT):
    manifest = plan(catalog, root)
    if commit and manifest['profile'] != 'observed-test-catalog':
        raise ValueError('A synthetic catalog may only produce a rollback rehearsal.')
    digest = hashlib.sha256(json.dumps(manifest, sort_keys=True).encode()).hexdigest()
    entries = []
    for f in manifest['existing_functions']:
        entries.append('(' + ','.join([literal(f['signature']), literal(f['source_md5']), literal(json.dumps({k: f[k] for k in ('arg_names', 'returns', 'config')}, sort_keys=True)) + '::jsonb', 'true' if f['security_definer'] else 'false', 'true' if f['anon_execute'] else 'false', 'true' if f['authenticated_execute'] else 'false']) + ')')
    expected = ',\n'.join(entries)
    new_tables = ','.join(literal(t) for t in manifest['new_tables'])
    protected = ','.join(literal(t) for t in PROTECTED)
    missing = ','.join(literal(t) for t in MISSING_RPCS)
    sql = f"""-- Fixed TEST project {PROJECT}; catalog profile {manifest['profile']}.
-- Plan SHA256 {digest}. Does not open admissions or grant clinical authority.
-- Generated from reviewed sources; not the initial 23-candidate installer.
begin isolation level repeatable read;
set local lock_timeout='5s';
set local statement_timeout='120s';
select pg_advisory_xact_lock(hashtextextended('vetdosis-missing-contracts-v1',0));
do $preflight$
declare row record; actual oid; missing text;
begin
 if not exists(select 1 from private.beta_policy where not admissions_enabled and not enforcement_enabled)
 or not exists(select 1 from private.permission_policy where not enforcement_enabled and not migration_reviewed) then
  raise exception 'upgrade_requires_closed_dormant_policies';
 end if;
 if to_regclass('private.missing_contract_upgrade_receipts') is not null then
  raise exception 'upgrade_already_installed_review_required';
 end if;
 select string_agg(name,', ') into missing from unnest(array[{new_tables}]) name where to_regclass(name) is not null;
 if missing is not null then raise exception 'partial_upgrade_tables: %',missing;end if;
 if exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname=any(array[{missing}])) then
  raise exception 'partial_upgrade_rpc';
 end if;
 for row in select * from (values {expected}) expected(signature,source_md5,metadata,definer,anon_execute,authenticated_execute) loop
  actual=to_regprocedure(row.signature);
  if actual is null or not exists(select 1 from pg_proc where oid=actual and md5(prosrc)=row.source_md5 and prosecdef=row.definer
   and jsonb_build_object('arg_names',proargnames,'returns',pg_get_function_result(oid),'config',proconfig)=row.metadata
   and has_function_privilege('anon',oid,'EXECUTE')=row.anon_execute
   and has_function_privilege('authenticated',oid,'EXECUTE')=row.authenticated_execute) then
   raise exception 'preexisting_contract_drift: %',row.signature;
  end if;
 end loop;
end
$preflight$;
-- Project all preexisting columns so newly added default columns do not hide
-- changes to old data. Hashes remain transaction-local; no records are exported.
create temp table upgrade_existing_functions on commit drop as select oid from pg_proc;
create temp table upgrade_invariants(relation_name text primary key,columns_sql text,digest text) on commit drop;
do $snapshot$
declare name text; cols text; value text;
begin
 foreach name in array array[{protected}] loop
  if to_regclass(name) is null then raise exception 'upgrade_missing_protected_relation: %',name;end if;
  select string_agg(format('%I',attname),',' order by attnum) into cols from pg_attribute where attrelid=to_regclass(name) and attnum>0 and not attisdropped;
  execute format('select md5(coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text)::text,''[]'')) from (select %s from %s) t',cols,name) into value;
  insert into upgrade_invariants values(name,cols,value);
 end loop;
end
$snapshot$;
"""
    for name, source in sources(root):
        sql += '\n-- Source: ' + name + '\n' + unwrap(source)
    sql += f"""
do $postflight$
declare old record; value text; missing text;
begin
 for old in select * from upgrade_invariants loop
  execute format('select md5(coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text)::text,''[]'')) from (select %s from %s) t',old.columns_sql,old.relation_name) into value;
  if value is distinct from old.digest then raise exception 'upgrade_changed_existing_data: %',old.relation_name;end if;
 end loop;
 select string_agg(name,', ') into missing from unnest(array[{missing}]) name
 where not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname=name);
 if missing is not null then raise exception 'upgrade_rpc_missing: %',missing;end if;
 if exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname=any(array[{missing}]) and has_function_privilege('anon',p.oid,'EXECUTE')) then
  raise exception 'upgrade_anonymous_rpc_access';
 end if;
 if exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname in ('public','private') and p.prosecdef and not exists(select 1 from upgrade_existing_functions b where b.oid=p.oid)
  and (has_function_privilege('anon',p.oid,'EXECUTE') or (n.nspname='private' and has_function_privilege('authenticated',p.oid,'EXECUTE'))))
 then raise exception 'upgrade_new_definer_exposed';end if;
 if exists(select 1 from unnest(array[{new_tables}]) name join pg_class c on c.oid=to_regclass(name)
  where not c.relrowsecurity or has_table_privilege('anon',c.oid,'SELECT,INSERT,UPDATE,DELETE')
  or has_table_privilege('authenticated',c.oid,'SELECT,INSERT,UPDATE,DELETE'))
 then raise exception 'upgrade_new_table_exposed';end if;
 if exists(select 1 from private.backup_restore_test_targets) then raise exception 'upgrade_enabled_restore_target';end if;
 if exists(select 1 from public.inventory_sale_returns) or exists(select 1 from public.inventory_sale_collections)
 or exists(select 1 from public.clinic_service_commission_recoveries) or exists(select 1 from private.staff_medical_events)
 then raise exception 'upgrade_seeded_operations';end if;
 if not exists(select 1 from private.beta_policy where not admissions_enabled and not enforcement_enabled)
 or not exists(select 1 from private.permission_policy where not enforcement_enabled and not migration_reviewed) then
  raise exception 'upgrade_changed_policies';
 end if;
end
$postflight$;
create table private.missing_contract_upgrade_receipts(
 singleton boolean primary key default true check(singleton),
 plan_sha256 text not null,
 installed_at timestamptz not null default clock_timestamp()
);
alter table private.missing_contract_upgrade_receipts enable row level security;
revoke all on private.missing_contract_upgrade_receipts from public,anon,authenticated,service_role;
insert into private.missing_contract_upgrade_receipts(plan_sha256) values({literal(digest)});
notify pgrst,'reload schema';
"""
    return sql + ('commit;\n' if commit else 'rollback;\n'), manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--catalog', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--commit', action='store_true', help='Generate commit variant only; never executes SQL')
    args = parser.parse_args()
    sql, manifest = bundle(json.loads(args.catalog.read_text()), commit=args.commit)
    args.output.write_text(sql)
    args.output.with_suffix('.manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')


if __name__ == '__main__':
    main()

"""Exercise the incremental upgrade in disposable PostgreSQL; no remote access.

The fixture uses the prior reviewed module chain. Its fingerprints deliberately
identify synthetic provenance, so the production generator refuses --commit.
Only this runner, inside its own network-disabled container, commits the body.
"""
import json
from pathlib import Path
import subprocess
import tempfile
import time
import uuid
from missing_contracts import ROOT, PROJECT, MISSING_RPCS, INDEX_SOURCES, bundle

CATALOG_SQL = """select json_build_object('project_ref','%s','profile','synthetic-local',
'functions',(select json_agg(json_build_object('schema',n.nspname,'name',p.proname,
'signature',p.oid::regprocedure::text,'source_md5',md5(p.prosrc),'security_definer',p.prosecdef,
'arg_names',p.proargnames,'returns',pg_get_function_result(p.oid),'config',p.proconfig,
'anon_execute',has_function_privilege('anon',p.oid,'EXECUTE'),
'authenticated_execute',has_function_privilege('authenticated',p.oid,'EXECUTE')) order by p.oid)
from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','private')),
'relations',(select json_agg(json_build_object('schema',n.nspname,'name',c.relname) order by c.oid)
from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','private')));""" % PROJECT


def run(args, sql=None, check=True):
    result=subprocess.run(args,input=sql,text=True,capture_output=True,cwd=ROOT)
    if check and result.returncode:
        raise RuntimeError(' '.join(args[:5])+'\n'+result.stderr[-5000:]+result.stdout[-1500:])
    return result


def main():
    name='vetdosis-contracts-'+uuid.uuid4().hex[:12]
    def query(sql, check=True):
        return run(['docker','exec','-i',name,'psql','-X','-U','postgres','-v','ON_ERROR_STOP=1','-At'],sql,check)
    def fixture(path, database='postgres'):
        run(['docker','exec',name,'psql','-X','-U','postgres','-d',database,'-v','ON_ERROR_STOP=1','-f','/fixture/'+path])
    def assert_baseline(expected):
        actual=json.loads(query(CATALOG_SQL).stdout)
        if actual != expected: raise AssertionError('Rollback changed the baseline catalog')
    run(['docker','run','-d','--name',name,'--network','none','-e','POSTGRES_HOST_AUTH_METHOD=trust','postgres:17-alpine'])
    try:
        for attempt in range(30):
            if run(['docker','exec',name,'pg_isready','-U','postgres'],check=False).returncode==0: break
            time.sleep(1)
        else: raise RuntimeError('PostgreSQL startup failed')
        run(['docker','exec',name,'mkdir','/fixture'])
        run(['docker','cp',str(ROOT/'supabase'),name+':/fixture/supabase'])
        baseline=json.loads((ROOT/'supabase/tests/missing_contracts_baseline.json').read_text())
        for path in baseline: fixture(path)
        fixture('supabase/tests/member_history_before.sql')
        print('PASS baseline and populated retained-member history',flush=True)
        catalog=json.loads(query(CATALOG_SQL).stdout)
        sql, manifest=bundle(catalog)
        query(sql); assert_baseline(catalog)
        print('PASS complete upgrade with ROLLBACK preserves original catalog',flush=True)
        # Abort after all sources, before verification/receipt. Transaction exit
        # must roll back every new object and every ALTER, including FK changes.
        failure=sql.replace('do $postflight$',"do $$begin raise exception 'synthetic_mid_upgrade_failure';end$$;\ndo $postflight$",1)
        result=query(failure,check=False)
        assert result.returncode and 'synthetic_mid_upgrade_failure' in result.stderr
        assert_baseline(catalog)
        print('PASS late failure atomically rolls back the entire upgrade',flush=True)
        drift=sql.replace('do $preflight$',"alter function public.clinic_export(uuid) set search_path='public';\ndo $preflight$",1)
        result=query(drift,check=False)
        assert result.returncode and 'preexisting_contract_drift' in result.stderr
        assert_baseline(catalog)
        print('PASS search_path drift rejected before installation',flush=True)
        # No remote target or caller-supplied container is accepted by this runner.
        query(sql.removesuffix('rollback;\n')+'commit;\n')
        actual=json.loads(query("""select json_agg(json_build_object('name',p.proname,'args',p.proargnames,'required',p.pronargs-p.pronargdefaults))
         from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public';""").stdout)
        calls=json.loads((ROOT/'review/supabase-missing-contracts-20261028/client-named-arguments.json').read_text())
        checked=0
        for rpc, variants in calls.items():
            for call in variants:
                if not call['params']: continue
                supplied=set(call['params'])
                assert any(f['name']==rpc and supplied<=set(f['args'] or [])
                           and set((f['args'] or [])[:f['required']])<=supplied for f in actual), (rpc,call)
                checked+=1
        assert checked==27, checked
        print('PASS 27 current client named-argument contracts (legacy v1/v2 replay-only)',flush=True)
        result=query(sql,check=False)
        assert result.returncode and 'upgrade_already_installed_review_required' in result.stderr
        print('PASS fixture-only install and replay rejection',flush=True)
        # The upgrade itself already compared all OLD column values. Rebase
        # this existing whole-row fixture to the new row shape (notably the
        # new NULL consent_event_id) before testing member removal separately.
        query("""do $$declare r record;v text;begin
         for r in select relation_name from private.p0_history_fingerprints loop
          execute format('select md5(coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text)::text,''[]'')) from %s t',r.relation_name) into v;
          update private.p0_history_fingerprints set digest=v where relation_name=r.relation_name;
         end loop;end$$;""")
        fixture('supabase/tests/member_history_after.sql')
        print('PASS populated member history and former-member commissions',flush=True)
        fixture('supabase/tests/service_commission_recoveries.sql')
        print('PASS integrated commission settlement and recovery',flush=True)
        fixture('supabase/tests/missing_contracts_integrated.sql')
        fixture('supabase/tests/financial_return_freshness.sql')
        print('PASS latest financial v3, stale quotes, fractional refunds and frozen cash close',flush=True)
        for path in INDEX_SOURCES: fixture(path)
        for test in ['staff_medical_privacy','vial_reconciliation_retries','vial_incident_overview',
                     'restore_preview_staging','restore_conflict_preview','restore_decision_preview',
                     'restore_application_preflight','restore_owners_apply','restore_patients_apply']:
            fixture('supabase/tests/'+test+'.sql')
            print('PASS integrated '+test,flush=True)
        for script in ['member_history_concurrency','staff_medical_privacy_concurrency','vial_index_write_compatibility']:
            run(['bash','supabase/tests/'+script+'.sh',name])
            print('PASS '+script,flush=True)
        # These established endpoint suites construct minimal schemas themselves.
        # Separate databases prevent their test doubles replacing integrated RLS.
        for index, test in enumerate(['patient_contacts_links','appointment_care','patient_activity_snapshot']):
            database='endpoint_'+str(index)
            run(['docker','exec',name,'createdb','-U','postgres',database])
            fixture('supabase/tests/'+test+'.sql',database)
            print('PASS isolated endpoint '+test,flush=True)
        print('ALL missing-contract upgrade checks passed; no remote SQL executed.',flush=True)
    finally:
        run(['docker','rm','-f',name],check=False)


if __name__=='__main__': main()

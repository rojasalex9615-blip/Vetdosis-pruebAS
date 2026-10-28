import concurrent.futures,json,os,pathlib,subprocess,time
root=pathlib.Path(__file__).resolve().parents[2]
import argparse
parser=argparse.ArgumentParser(description='Local synthetic beta checks; never deploys or contacts Supabase.')
parser.add_argument('--output', type=pathlib.Path, required=True)
args=parser.parse_args()
out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
checks=[
('pdf_renderer',['node','--test','supabase/tests/forms_renderer.test.mjs']),
('patient_appointment_links',['bash','supabase/tests/run_patient_appointment_integration.sh']),
('integrated_schema',['bash','supabase/tests/run_small_animal_integration.sh']),
('modules_two_clinics',['bash','supabase/tests/run_module_navigation_dashboard.sh']),
('hospital_channels_history_duty',['env','HOSPITAL_TEST_CHANNELS=1','HOSPITAL_TEST_HISTORY=1','HOSPITAL_TEST_DUTY=1','bash','supabase/tests/run_hospital_automation.sh']),
('finance_and_staff_combined',['env','STAFF_MEDICAL_PRIVACY=1','bash','supabase/tests/run_installments_service_returns.sh','supabase/migrations/20261027144905_financial_return_freshness.sql','supabase/tests/financial_return_freshness.sql','supabase/migrations/20261027142748_staff_medical_consent_access.sql','supabase/tests/staff_medical_privacy.sql']),
('vial_concurrency',['bash','supabase/tests/run_vial_incident_overview.sh']),
('backups_export_permissions',['bash','supabase/tests/run_permission_backups_exports.sh']),
('storage_permissions',['bash','supabase/tests/run_storage_media.sh']),
('restore_staging',['bash','supabase/tests/run_restore_preview_staging.sh']),
('agenda_permissions',['bash','supabase/tests/run_permission_agenda.sh']),
('clinical_vitals',['bash','supabase/tests/run_clinical_vitals.sh']),
('terms_privacy',['bash','supabase/tests/run_terms_acceptances.sh']),
('atomic_rollout',['bash','supabase/tests/run_integration_bundle.sh']),
('python_supabase',['python3','-m','unittest','discover','-s','scripts/supabase','-p','test_*.py']),
('python_android',['python3','-m','unittest','discover','-s','scripts/android','-p','test_*.py']),
('node_hospital',['node','--test','supabase/tests/hospital_delivery.test.mjs','supabase/tests/hospital_dispatch_auth.test.mjs','supabase/tests/hospital_fcm_token.test.mjs']),
]
def check(item):
 name,cmd=item;t=time.monotonic()
 with (out/(name+'.log')).open('w') as log:
  try: r=subprocess.run(cmd,cwd=root,stdout=log,stderr=subprocess.STDOUT,timeout=1000);code=r.returncode
  except subprocess.TimeoutExpired:code=124
 row={'name':name,'command':cmd,'exit_code':code,'seconds':round(time.monotonic()-t,1)}
 print(json.dumps(row),flush=True);return row
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool: results=list(pool.map(check,checks))
(out/'results.json').write_text(json.dumps(results,indent=2)+'\n')
raise SystemExit(any(x['exit_code'] for x in results))

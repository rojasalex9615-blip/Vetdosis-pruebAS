#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
container_name="vetdosis-automation-$$"
work_dir=$(mktemp -d)
docker run -d --name "$container_name" --network none -e POSTGRES_HOST_AUTH_METHOD=trust "${HOSPITAL_TEST_IMAGE:-postgres:17-alpine}" >/dev/null
trap 'docker rm -f "$container_name" >/dev/null; rm -rf "$work_dir"' EXIT
ready=false
for attempt in {1..30};do
 if docker exec "$container_name" pg_isready -h 127.0.0.1 -U postgres >/dev/null 2>&1;then ready=true;break;fi
 sleep 1
done
if [ "$ready" != true ];then echo 'PostgreSQL startup failed';exit 1;fi
for sql_file in supabase/tests/bootstrap.sql supabase/tests/existing_fixture.sql supabase/adaptations/existing_clinics_m2.sql supabase/adaptations/existing_doses_m3.sql supabase/adaptations/existing_patients_m4.sql supabase/adaptations/existing_hospital_m5.sql supabase/adaptations/existing_forms_phase1.sql supabase/adaptations/existing_forms_phase2.sql supabase/adaptations/existing_prescribing_m6.sql supabase/adaptations/existing_inventory_m8.sql supabase/adaptations/existing_inventory_workflow_m8.sql supabase/adaptations/existing_operations_m9.sql supabase/adaptations/existing_attendance_m10.sql supabase/adaptations/existing_statistics_m11.sql supabase/adaptations/existing_payment_references.sql supabase/adaptations/existing_subscriptions_m13.sql supabase/adaptations/existing_ai_m12.sql supabase/tests/storage_fixture.sql supabase/adaptations/existing_inventory_photos_m8.sql supabase/adaptations/existing_plan_files_m13.sql supabase/adaptations/existing_ai_plan_export.sql supabase/adaptations/existing_support_m14.sql supabase/adaptations/existing_starter_ai_review.sql supabase/adaptations/existing_team_management.sql supabase/adaptations/existing_appointments_extension.sql supabase/adaptations/existing_membership_history.sql supabase/proposed/09A_beta_foundation.sql supabase/tests/beta_foundation.sql supabase/proposed/09B_beta_gate.sql supabase/proposed/11A_permission_foundation.sql supabase/proposed/13A_permission_patient_registration.sql supabase/proposed/13B_permission_agenda.sql supabase/proposed/13C_permission_clinical.sql supabase/proposed/13D_hospital_flexible_admission.sql supabase/proposed/13E_permission_hospital_reviews.sql supabase/proposed/13F_permission_medication.sql supabase/tests/permission_medication.sql supabase/proposed/13G_permission_hospital_resolution.sql supabase/tests/permission_hospital_resolution.sql supabase/proposed/14D_hospital_isolation.sql supabase/tests/hospital_isolation.sql supabase/proposed/14F_hospital_care_results.sql supabase/tests/hospital_care_results.sql supabase/proposed/14G_hospital_automation.sql supabase/tests/hospital_automation.sql;do
 docker exec -i "$container_name" psql -U postgres -v ON_ERROR_STOP=1 < "$sql_file" > "$work_dir/test.log" 2>&1 || { echo "FAILED: $sql_file";cat "$work_dir/test.log";exit 1; }
done
bash supabase/tests/permission_hospital_resolution_concurrency.sh "$container_name"
bash supabase/tests/hospital_isolation_concurrency.sh "$container_name"
bash supabase/tests/hospital_care_results_concurrency.sh "$container_name"
bash supabase/tests/hospital_automation_concurrency.sh "$container_name"
if [ "${HOSPITAL_TEST_CHANNELS:-0}" = 1 ];then
 for sql_file in supabase/proposed/14J_hospital_external_delivery.sql supabase/tests/hospital_delivery.sql supabase/proposed/14K_hospital_push_targets.sql supabase/tests/hospital_push_targets.sql supabase/tests/hospital_target_transfer.sql supabase/proposed/14L_hospital_delivery_channels.sql supabase/tests/hospital_delivery_channels.sql;do
  docker exec -i "$container_name" psql -U postgres -v ON_ERROR_STOP=1 < "$sql_file" > "$work_dir/channels.log" 2>&1 || { echo "FAILED: $sql_file";cat "$work_dir/channels.log";exit 1; }
 done
 bash supabase/tests/hospital_target_transfer_concurrency.sh "$container_name"
 echo 'Hospital delivery, target transfer, revocation and exhausted leases passed.'
fi
if [ "${HOSPITAL_TEST_CRON:-0}" = 1 ];then
 for sql_file in supabase/operations/hospital_scheduler.sql supabase/tests/hospital_scheduler.sql;do
  docker exec -i "$container_name" psql -U postgres -v ON_ERROR_STOP=1 < "$sql_file" > "$work_dir/cron.log" 2>&1 || { cat "$work_dir/cron.log";exit 1; }
 done
 echo 'Autonomous pg_cron generation and pause passed.'
fi
if [ "${HOSPITAL_TEST_DUTY:-0}" = 1 ];then
 for sql_file in supabase/proposed/14H_team_duty.sql supabase/tests/team_duty.sql;do
  docker exec -i "$container_name" psql -U postgres -v ON_ERROR_STOP=1 < "$sql_file" > "$work_dir/duty.log" 2>&1 || { cat "$work_dir/duty.log";exit 1; }
 done
 bash supabase/tests/team_duty_concurrency.sh "$container_name"
 echo 'Team duty authorization, absence and coverage assertions passed.'
fi
if [ "${HOSPITAL_TEST_HISTORY:-0}" = 1 ];then
 for sql_file in supabase/proposed/14I_hospital_history.sql supabase/tests/hospital_history.sql;do
  docker exec -i "$container_name" psql -U postgres -v ON_ERROR_STOP=1 < "$sql_file" > "$work_dir/history.log" 2>&1 || { echo "FAILED: $sql_file";cat "$work_dir/history.log";exit 1; }
 done
 echo 'Closed hospital history permissions, isolation, search and pagination passed.'
fi
echo 'Hospital automation and prior care/resolution/isolation suites passed.'

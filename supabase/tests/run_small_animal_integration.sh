#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
# One disposable PostgreSQL database, no network and no remote credentials.
# The base runner also executes permission, prescribing and cash prerequisites.
STAFF_MEDICAL_PRIVACY=1 bash supabase/tests/run_installments_service_returns.sh \
 supabase/migrations/20261027144905_financial_return_freshness.sql \
 supabase/tests/financial_return_freshness.sql \
 supabase/migrations/20261027142748_staff_medical_consent_access.sql \
 supabase/tests/staff_medical_privacy.sql \
 supabase/proposed/13W_clinical_vitals.sql \
 supabase/proposed/13X_storage_media.sql \
 supabase/proposed/14D_hospital_isolation.sql \
 supabase/proposed/14E_clinical_rapid_tests.sql \
 supabase/proposed/14F_hospital_care_results.sql \
 supabase/proposed/14G_hospital_automation.sql \
 supabase/proposed/14H_team_duty.sql \
 supabase/proposed/14I_hospital_history.sql \
 supabase/proposed/14J_hospital_external_delivery.sql \
 supabase/proposed/14K_hospital_push_targets.sql \
 supabase/proposed/14L_hospital_delivery_channels.sql \
 supabase/proposed/14J_clinic_experience.sql \
 supabase/migrations/20261027062933_vial_reconciliation_retries.sql \
 supabase/migrations/20261027064618_vial_incident_overview.sql \
 supabase/migrations/20261027141227_vial_movement_index_concurrent.sql \
 supabase/migrations/20261027141229_vial_incident_index_concurrent.sql \
 supabase/adaptations/patient_contacts_appointment_links_v1.sql \
 supabase/adaptations/appointment_care_v1.sql \
 supabase/adaptations/patient_activity_snapshot_v1.sql \
 supabase/adaptations/preventive_booklet_v2.sql \
 supabase/adaptations/appointment_patient_search_v2.sql \
 supabase/tests/small_animal_integration.sql

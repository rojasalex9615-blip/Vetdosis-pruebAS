#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
STAFF_MEDICAL_PRIVACY=1 MEMBER_HISTORY_PRESERVATION=1 bash supabase/tests/run_installments_service_returns.sh \
 supabase/migrations/20261027144905_financial_return_freshness.sql \
 supabase/tests/financial_return_freshness.sql \
 supabase/migrations/20261027142748_staff_medical_consent_access.sql \
 supabase/tests/staff_medical_privacy.sql \
 supabase/proposed/14E_commission_payroll.sql \
 supabase/proposed/14G_sale_invoice_requests.sql \
 supabase/proposed/14H_supplier_directory.sql \
 supabase/proposed/14I_clinic_contact_directory.sql \
 supabase/proposed/14J_clients_promotions.sql \
 supabase/proposed/14K_client_loyalty.sql \
 supabase/proposed/14L_clinic_productivity.sql \
 supabase/proposed/14M_ai_assisted_workflows.sql \
 supabase/proposed/14N_week_plan_tasks.sql \
 supabase/proposed/14O_team_communications.sql \
 supabase/tests/member_history_before.sql \
 supabase/migrations/20261028043154_preserve_member_history.sql \
 supabase/tests/member_history_after.sql

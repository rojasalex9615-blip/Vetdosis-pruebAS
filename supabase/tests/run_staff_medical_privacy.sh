#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
STAFF_MEDICAL_PRIVACY=1 bash supabase/tests/run_permission_clinic_operations.sh \
 supabase/migrations/20261027142748_staff_medical_consent_access.sql \
 supabase/tests/staff_medical_privacy.sql

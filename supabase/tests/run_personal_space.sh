#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
# 16A replaces the staff medical notice (version 2), so staff_medical_privacy.sql runs before it.
bash supabase/tests/run_permission_clinic_operations.sh \
 supabase/migrations/20261027142748_staff_medical_consent_access.sql \
 supabase/tests/staff_medical_privacy.sql \
 supabase/proposed/16A_espacio_personal.sql \
 supabase/tests/personal_space.sql

#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
bash supabase/tests/run_permission_medication.sh \
 supabase/migrations/20261027062933_vial_reconciliation_retries.sql \
 supabase/tests/vial_reconciliation_retries.sql

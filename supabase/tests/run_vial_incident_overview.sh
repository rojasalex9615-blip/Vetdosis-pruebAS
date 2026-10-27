#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
bash supabase/tests/run_vial_reconciliation_retries.sh \
 supabase/migrations/20261027064618_vial_incident_overview.sql \
 supabase/tests/vial_incident_overview.sql

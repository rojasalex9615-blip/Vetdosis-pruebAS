#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
VIAL_INDEX_WRITE_TEST=1 bash supabase/tests/run_vial_reconciliation_retries.sh \
 supabase/migrations/20261027064618_vial_incident_overview.sql \
 supabase/migrations/20261027141227_vial_movement_index_concurrent.sql \
 supabase/migrations/20261027141229_vial_incident_index_concurrent.sql \
 supabase/tests/vial_incident_overview.sql
